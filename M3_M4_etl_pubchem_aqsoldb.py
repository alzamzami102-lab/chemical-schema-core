#!/usr/bin/env python3
"""
M3 + M4: ETL ط³ظƒط±ط¨طھ ط§ط³طھظٹط±ط§ط¯ PubChem + AqSolDB
================================================
ط§ظ„ط®ط·ظˆط© ط§ظ„ط£ظˆظ„ظ‰ ظ…ظ† ظ…ط³ط§ط± ETL ط§ظ„ظپط¹ظ„ظٹ

ط§ظ„ظ…طµط§ط¯ط± ط§ظ„ط¹ظ„ظ…ظٹط©:
  - PubChem PUG REST API (Kim et al. 2016, Nucleic Acids Res. 44:D1202)
  - AqSolDB (Sorkun et al. 2019, Sci. Data 6:143)
  - InChI v1.06 (Batchelor et al. 2021, J. Cheminform. 13:40)
  - psycopg2 PostgreSQL adapter (psycopg.org)

ط§ظ„ط§ط³طھط®ط¯ط§ظ…:
  pip install requests psycopg2-binary pandas
  python M3_M4_etl_pubchem_aqsoldb.py

ط§ظ„ط¥ط¹ط¯ط§ط¯:
  ظٹط¬ط¨ طھط­ط¯ظٹط« DB_CONFIG ط£ط¯ظ†ط§ظ‡ ط¨ظ…ط¹ظ„ظˆظ…ط§طھ ظ‚ط§ط¹ط¯ط© ط§ظ„ط¨ظٹط§ظ†ط§طھ ط§ظ„ط®ط§طµط© ط¨ظƒ.
"""

import os
import re
import time
import logging
import requests
import pandas as pd
import psycopg2
import psycopg2.extras
from typing import Optional, Dict, Any, List, Tuple

# --------------------------------------------------
# ط§ظ„ط¥ط¹ط¯ط§ط¯ ط§ظ„ط¹ط§ظ…
# --------------------------------------------------

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)
log = logging.getLogger(__name__)

# *** ط¹ط¯ظ‘ظ„ ظ‡ط°ظ‡ ط§ظ„ظ‚ظٹظ… ظ„طھظ†ط§ط³ط¨ ط¨ظٹط¦طھظƒ ***
DB_CONFIG = {
    "host":     os.getenv("DB_HOST",     "localhost"),
    "port":     int(os.getenv("DB_PORT", "5432")),
    "dbname":   os.getenv("DB_NAME",     "chem_platform"),
    "user":     os.getenv("DB_USER",     "postgres"),
    "password": os.getenv("DB_PASSWORD", ""),
}

# PubChem PUG REST base URL
PUBCHEM_BASE = "https://pubchem.ncbi.nlm.nih.gov/rest/pug"

# ظ…ط¹ط¯ظ„ ط§ظ„ط·ظ„ط¨ط§طھ: PubChem ظٹظˆطµظٹ ط¨ظ€ <= 5 ط·ظ„ط¨ط§طھ/ط«ط§ظ†ظٹط©
PUBCHEM_DELAY_SEC = 0.25

# ط­ط¬ظ… ط§ظ„ط¯ظپط¹ط© ظ„ظ„ط§ط³طھظٹط±ط§ط¯ ط¥ظ„ظ‰ PostgreSQL
BATCH_SIZE = 50

# ط§ظ„ط®طµط§ط¦طµ ط§ظ„ظ…ط·ظ„ظˆط¨ط© ظ…ظ† PubChem
PUBCHEM_PROPERTIES = ",".join([
    "IUPACName",
    "MolecularFormula",
    "MolecularWeight",
    "CanonicalSMILES",
    "IsomericSMILES",
    "InChI",
    "InChIKey",
    "XLogP",
    "TPSA",
    "HBondDonorCount",
    "HBondAcceptorCount",
    "RotatableBondCount",
    "HeavyAtomCount",
    "Charge",
])

# --------------------------------------------------
# SECTION A: ط§ظ„طھط­ظ‚ظ‚ ظ…ظ† طµط­ط© ط§ظ„ظ‡ظˆظٹط©
# ط§ظ„ظ…طµط¯ط±: Batchelor et al. 2021, J. Cheminform. 13:40
# InChIKey format: 14 + 10 + 1 chars separated by hyphens
# --------------------------------------------------

INCHIKEY_PATTERN = re.compile(r'^[A-Z]{14}-[A-Z]{10}-[A-Z]$')

def validate_inchikey(inchikey: str) -> bool:
    """
    ظٹطھط­ظ‚ظ‚ ظ…ظ† طµط­ط© طھظ†ط³ظٹظ‚ InChIKey.
    ط§ظ„طھظ†ط³ظٹظ‚ ط§ظ„طµط­ظٹط­: XXXXXXXXXXXXXX-XXXXXXXXXX-X
    14 ط­ط±ظپظ‹ط§ ظƒط¨ظٹط±ظ‹ط§ + ط´ط±ط·ط© + 10 ط£ط­ط±ظپ + ط´ط±ط·ط© + ط­ط±ظپ ظˆط§ط­ط¯.
    ط§ظ„ظ…طµط¯ط±: InChI v1.06 (Batchelor et al. 2021, J. Cheminform. 13:40).
    """
    if not inchikey or not isinstance(inchikey, str):
        return False
    return bool(INCHIKEY_PATTERN.match(inchikey.strip()))


def validate_logs(logs_value) -> bool:
    """
    ظٹطھط­ظ‚ظ‚ ظ…ظ† ط£ظ† ظ‚ظٹظ…ط© LogS ط¶ظ…ظ† ط§ظ„ظ†ط·ط§ظ‚ ط§ظ„ظ…ط¹ظ‚ظˆظ„.
    ط§ظ„ظ†ط·ط§ظ‚: -15 ط¥ظ„ظ‰ +5 mol/L ظˆظپظ‚ AqSolDB (Sorkun et al. 2019).
    """
    try:
        v = float(logs_value)
        return -15.0 <= v <= 5.0
    except (TypeError, ValueError):
        return False

# --------------------------------------------------
# SECTION B: PubChem PUG REST API
# ط§ظ„ظ…طµط¯ط±: PubChem PUG REST (Kim et al. 2016, Nucleic Acids Res.)
# --------------------------------------------------

def fetch_pubchem_by_inchikey(inchikey: str) -> Optional[Dict[str, Any]]:
    """
    ظٹط¬ظ„ط¨ ط®طµط§ط¦طµ ظ…ط±ظƒظ‘ط¨ ظ…ظ† PubChem ط¨ط§ظ„ط§ط³طھط¹ظ„ط§ظ… ط¹ط¨ط± InChIKey.
    
    URL pattern:
    GET /compound/inchikey/{inchikey}/property/{props}/JSON
    
    ط§ظ„ظ…طµط¯ط±: PubChem PUG REST API documentation
    (https://pubchem.ncbi.nlm.nih.gov/docs/pug-rest)
    """
    if not validate_inchikey(inchikey):
        log.warning(f"Invalid InChIKey format: {inchikey}")
        return None

    url = (
        f"{PUBCHEM_BASE}/compound/inchikey/{inchikey}"
        f"/property/{PUBCHEM_PROPERTIES}/JSON"
    )

    try:
        time.sleep(PUBCHEM_DELAY_SEC)
        resp = requests.get(url, timeout=15)

        if resp.status_code == 404:
            log.warning(f"Not found in PubChem: {inchikey}")
            return None

        resp.raise_for_status()
        data = resp.json()
        props_list = data.get("PropertyTable", {}).get("Properties", [])

        if not props_list:
            return None

        return props_list[0]

    except requests.RequestException as e:
        log.error(f"PubChem request error for {inchikey}: {e}")
        return None


def fetch_pubchem_synonyms(cid: int) -> List[str]:
    """
    ظٹط¬ظ„ط¨ ظ…ط±ط§ط¯ظپط§طھ ظ…ط±ظƒظ‘ط¨ ظ…ظ† PubChem ط¨ط§ظ„ظ€ CID.
    
    URL pattern:
    GET /compound/cid/{cid}/synonyms/JSON
    """
    url = f"{PUBCHEM_BASE}/compound/cid/{cid}/synonyms/JSON"
    try:
        time.sleep(PUBCHEM_DELAY_SEC)
        resp = requests.get(url, timeout=15)
        if resp.status_code != 200:
            return []
        data = resp.json()
        return data.get("InformationList", {}).get("Information", [{}])[0].get("Synonym", [])[:20]
    except Exception as e:
        log.error(f"Synonyms fetch error for CID {cid}: {e}")
        return []

# --------------------------------------------------
# SECTION C: ظ‚ط±ط§ط،ط© AqSolDB
# ط§ظ„ظ…طµط¯ط±: Sorkun et al. 2019, Sci. Data 6:143
# ط§ظ„ط­ظ‚ظˆظ„: ID, Name, InChI, InChIKey, SMILES, Solubility,
#         SD, Ocurrences, Group, MolWt, MolLogP, ...
# --------------------------------------------------

AQSOLDB_URL = (
    "https://raw.githubusercontent.com/mcsorkun/AqSolDB/master/data/"
    "curated-solubility-dataset.csv"
)

def load_aqsoldb(filepath: Optional[str] = None) -> pd.DataFrame:
    """
    ظٹط­ظ…ظ‘ظ„ AqSolDB ظ…ظ† ظ…ظ„ظپ ظ…ط­ظ„ظٹ ط£ظˆ ظ…ظ† GitHub.
    
    ط§ظ„ط­ظ‚ظˆظ„ ط§ظ„ظ…ط­ظ…ظ‘ظ„ط©:
      ID, Name, InChIKey, SMILES, Solubility (LogS),
      SD, Ocurrences, Group
    
    ط§ظ„ظ…طµط¯ط±: Sorkun et al. 2019, Sci. Data 6:143
    GitHub: https://github.com/mcsorkun/AqSolDB
    """
    if filepath and os.path.exists(filepath):
        log.info(f"Loading AqSolDB from local file: {filepath}")
        df = pd.read_csv(filepath)
    else:
        log.info(f"Downloading AqSolDB from GitHub...")
        df = pd.read_csv(AQSOLDB_URL)

    log.info(f"AqSolDB loaded: {len(df)} compounds, columns: {list(df.columns)}")

    # طھظˆط­ظٹط¯ ط§ط³ظ… ط¹ظ…ظˆط¯ InChIKey
    rename_map = {}
    for col in df.columns:
        if col.lower() in ("inchikey", "inchi_key"):
            rename_map[col] = "InChIKey"
        elif col.lower() == "solubility":
            rename_map[col] = "Solubility"
        elif col.lower() in ("ocurrences", "occurrences"):
            rename_map[col] = "Occurrences"
        elif col.lower() == "sd":
            rename_map[col] = "SD"
        elif col.lower() == "group":
            rename_map[col] = "Group"
    df.rename(columns=rename_map, inplace=True)

    # ظپظ„طھط±ط©: ط¥ط¨ظ‚ط§ط، ظپظ‚ط· ط§ظ„ط³ط¬ظ„ط§طھ ط°ط§طھ InChIKey طµط§ظ„ط­
    df = df[df["InChIKey"].apply(validate_inchikey)].copy()

    # ظپظ„طھط±ط©: ط¥ط¨ظ‚ط§ط، ظپظ‚ط· ط§ظ„ط³ط¬ظ„ط§طھ ط°ط§طھ LogS ط¶ظ…ظ† ط§ظ„ظ†ط·ط§ظ‚ ط§ظ„ظ…ط¹ظ‚ظˆظ„
    df = df[df["Solubility"].apply(validate_logs)].copy()

    log.info(f"AqSolDB after validation: {len(df)} valid compounds")
    return df

# --------------------------------------------------
# SECTION D: ط¥ط¯ط±ط§ط¬ ط§ظ„ط¨ظٹط§ظ†ط§طھ ظپظٹ PostgreSQL
# ط¨ط§ط³طھط®ط¯ط§ظ… psycopg2 + ON CONFLICT DO UPDATE (upsert)
# ط§ظ„ظ…طµط¯ط±: psycopg2 docs + PostgreSQL UPSERT syntax
# --------------------------------------------------

def get_db_connection():
    """ظٹظ†ط´ط¦ ط§طھطµط§ظ„ظ‹ط§ ط¨ظ‚ط§ط¹ط¯ط© ط§ظ„ط¨ظٹط§ظ†ط§طھ."""
    return psycopg2.connect(**DB_CONFIG)


def upsert_chemical_identity(
    cur,
    inchikey: str,
    pubchem_data: Dict[str, Any],
    aqsoldb_name: Optional[str] = None
) -> Optional[int]:
    """
    ظٹظڈط¯ط±ط¬ ط£ظˆ ظٹظڈط­ط¯ظ‘ط« ط³ط¬ظ„ ط§ظ„ظ‡ظˆظٹط© ط§ظ„ظƒظٹظ…ظٹط§ط¦ظٹط©.
    ظٹط¹ظٹط¯ chemical_identity_id.
    
    ظٹط³طھط®ط¯ظ… ON CONFLICT DO UPDATE ظ„طھط¬ظ†ط¨ ط§ظ„طھظƒط±ط§ط±
    ظ…ط¹ ط§ظ„ط­ظپط§ط¸ ط¹ظ„ظ‰ ط§ظ„ط¨ظٹط§ظ†ط§طھ ط§ظ„ط£ط­ط¯ط«.
    """
    cid_val    = pubchem_data.get("CID")
    iupac_name = pubchem_data.get("IUPACName")
    formula    = pubchem_data.get("MolecularFormula")
    mw         = pubchem_data.get("MolecularWeight")
    smiles     = pubchem_data.get("CanonicalSMILES")
    isomeric_smiles = pubchem_data.get("IsomericSMILES")
    inchi_str  = pubchem_data.get("InChI")

    preferred_name = iupac_name or aqsoldb_name or inchikey

    sql = """
        INSERT INTO chemical_identity_registry (
            preferred_name,
            iupac_name,
            molecular_formula,
            molecular_weight_num,
            canonical_smiles_text,
            isomeric_smiles_text,
            standard_inchi_text,
            standard_inchikey,
            pubchem_cid,
            curation_level,
            source_priority_text
        ) VALUES (
            %(preferred_name)s,
            %(iupac_name)s,
            %(formula)s,
            %(mw)s,
            %(smiles)s,
            %(isomeric_smiles)s,
            %(inchi)s,
            %(inchikey)s,
            %(pubchem_cid)s,
            'medium',
            'PubChem PUG REST API; AqSolDB (Sorkun et al. 2019)'
        )
        ON CONFLICT (standard_inchikey) DO UPDATE SET
            iupac_name          = COALESCE(EXCLUDED.iupac_name, chemical_identity_registry.iupac_name),
            molecular_formula   = COALESCE(EXCLUDED.molecular_formula, chemical_identity_registry.molecular_formula),
            molecular_weight_num= COALESCE(EXCLUDED.molecular_weight_num, chemical_identity_registry.molecular_weight_num),
            canonical_smiles_text = COALESCE(EXCLUDED.canonical_smiles_text, chemical_identity_registry.canonical_smiles_text),
            pubchem_cid         = COALESCE(EXCLUDED.pubchem_cid, chemical_identity_registry.pubchem_cid),
            source_priority_text = EXCLUDED.source_priority_text
        RETURNING chemical_identity_id
    """

    params = {
        "preferred_name":  preferred_name,
        "iupac_name":      iupac_name,
        "formula":         formula,
        "mw":              float(mw) if mw is not None else None,
        "smiles":          smiles,
        "isomeric_smiles": isomeric_smiles,
        "inchi":           inchi_str,
        "inchikey":        inchikey,
        "pubchem_cid":     int(cid_val) if cid_val else None,
    }

    cur.execute(sql, params)
    row = cur.fetchone()
    return row[0] if row else None


def upsert_physchem_properties(
    cur,
    identity_id: int,
    pubchem_data: Dict[str, Any]
):
    """
    ظٹظڈط¯ط±ط¬ ط£ظˆ ظٹظڈط­ط¯ظ‘ط« ط§ظ„ط®طµط§ط¦طµ ط§ظ„ظپظٹط²ظٹط§ط¦ظٹط©â€‘ط§ظ„ظƒظٹظ…ظٹط§ط¦ظٹط© ظ…ظ† PubChem.
    
    ط§ظ„ط®طµط§ط¦طµ: XLogP, TPSA, HBD, HBA, RotatableBonds, HeavyAtomCount
    ط§ظ„ظ…طµط¯ط±: PubChem Compound Property Tables
    """
    property_map = {
        "xlogp":            pubchem_data.get("XLogP"),
        "tpsa":             pubchem_data.get("TPSA"),
        "hbd_count":        pubchem_data.get("HBondDonorCount"),
        "hba_count":        pubchem_data.get("HBondAcceptorCount"),
        "rotatable_bonds":  pubchem_data.get("RotatableBondCount"),
        "heavy_atom_count": pubchem_data.get("HeavyAtomCount"),
        "formal_charge":    pubchem_data.get("Charge"),
        "molecular_weight": pubchem_data.get("MolecularWeight"),
    }

    # ظ…ط·ط§ط¨ظ‚ط© property_code ظ…ط¹ physchem_property_dictionary
    code_map = {
        "xlogp":            "xlogp",
        "tpsa":             "tpsa",
        "hbd_count":        "hbd_count",
        "hba_count":        "hba_count",
        "rotatable_bonds":  "rotatable_bonds",
        "heavy_atom_count": "heavy_atom_count",
        "formal_charge":    "formal_charge",
        "molecular_weight": "molecular_weight",
    }

    for prop_key, value in property_map.items():
        if value is None:
            continue
        try:
            float_val = float(value)
        except (TypeError, ValueError):
            continue

        prop_code = code_map.get(prop_key)
        if not prop_code:
            continue

        sql = """
            INSERT INTO physchem_property_registry (
                chemical_identity_id,
                property_code,
                property_name,
                property_value_num,
                source_name,
                source_record_ref
            ) VALUES (
                %(identity_id)s,
                %(prop_code)s,
                %(prop_code)s,
                %(value)s,
                'PubChem',
                %(source_ref)s
            )
            ON CONFLICT (chemical_identity_id, property_code)
            DO UPDATE SET
                property_value_num = EXCLUDED.property_value_num,
                source_name        = EXCLUDED.source_name
        """
        cid_ref = pubchem_data.get("CID")
        cur.execute(sql, {
            "identity_id": identity_id,
            "prop_code":   prop_code,
            "value":       float_val,
            "source_ref":  f"PubChem CID {cid_ref}" if cid_ref else "PubChem",
        })


def upsert_solubility_observation(
    cur,
    identity_id: int,
    row: pd.Series,
    dataset_id: str = "aqsoldb"
):
    """
    ظٹظڈط¯ط±ط¬ ظ‚ظٹط§ط³ ط°ظˆط¨ط§ظ†ظٹط© ظ…ظ† AqSolDB.
    
    ط§ظ„ط­ظ‚ظˆظ„: LogS (Solubility), SD, Occurrences, Group
    ط§ظ„ظ…طµط¯ط±: Sorkun et al. 2019, Sci. Data 6:143
    ظˆط­ط¯ط© ط§ظ„ظ‚ظٹط§ط³: log(mol/L)
    """
    logs_val     = row.get("Solubility")
    sd_val       = row.get("SD")
    occ_val      = row.get("Occurrences")
    group_val    = row.get("Group")
    source_id    = row.get("ID", "")
    source_name  = row.get("Name", "")

    # endpoint_id ظ„ظ„ط°ظˆط¨ط§ظ†ظٹط© ط§ظ„ظ…ط§ط¦ظٹط©
    sql_ep = """
        SELECT experimental_endpoint_id
        FROM experimental_endpoint_registry
        WHERE endpoint_code = 'aqueous_solubility'
        LIMIT 1
    """
    cur.execute(sql_ep)
    ep_row = cur.fetchone()
    endpoint_id = ep_row[0] if ep_row else None

    sql = """
        INSERT INTO experimental_observation_registry (
            chemical_identity_id,
            experimental_endpoint_id,
            observed_value_num,
            observed_unit,
            observed_scale,
            sd_value,
            occurrences_count,
            reliability_group,
            source_name,
            source_record_ref,
            reliability_label
        ) VALUES (
            %(identity_id)s,
            %(endpoint_id)s,
            %(logs)s,
            'log(mol/L)',
            'LogS',
            %(sd)s,
            %(occ)s,
            %(group)s,
            'AqSolDB',
            %(source_ref)s,
            %(group)s
        )
        ON CONFLICT (chemical_identity_id, experimental_endpoint_id, source_name, source_record_ref)
        DO UPDATE SET
            observed_value_num = EXCLUDED.observed_value_num,
            sd_value           = EXCLUDED.sd_value,
            occurrences_count  = EXCLUDED.occurrences_count,
            reliability_group  = EXCLUDED.reliability_group
    """

    cur.execute(sql, {
        "identity_id": identity_id,
        "endpoint_id": endpoint_id,
        "logs":        float(logs_val),
        "sd":          float(sd_val) if sd_val is not None and not pd.isna(sd_val) else None,
        "occ":         int(occ_val)  if occ_val is not None and not pd.isna(occ_val) else None,
        "group":       str(group_val) if group_val and not pd.isna(group_val) else None,
        "source_ref":  f"AqSolDB:{source_id}:{source_name}",
    })


def insert_dataset_membership(cur, identity_id: int, dataset_id: str):
    """ظٹط±ط¨ط· ط³ط¬ظ„ ظ‡ظˆظٹط© ط¨ظ…ط¬ظ…ظˆط¹ط© ط¨ظٹط§ظ†ط§طھ."""
    sql_ds = """
        SELECT experimental_dataset_id
        FROM experimental_dataset_registry
        WHERE dataset_code = %(dataset_code)s
        LIMIT 1
    """
    cur.execute(sql_ds, {"dataset_code": dataset_id})
    ds_row = cur.fetchone()
    if not ds_row:
        return

    sql = """
        INSERT INTO experimental_dataset_membership (
            experimental_dataset_id,
            experimental_observation_id
        )
        SELECT %(ds_id)s, ero.experimental_observation_id
        FROM experimental_observation_registry ero
        WHERE ero.chemical_identity_id = %(id)s
          AND ero.source_name = 'AqSolDB'
        ON CONFLICT DO NOTHING
    """
    cur.execute(sql, {"ds_id": ds_row[0], "id": identity_id})

# --------------------------------------------------
# SECTION E: ط§ظ„ظ…ط³ط§ط± ط§ظ„ط±ط¦ظٹط³ظٹ (Main ETL pipeline)
# --------------------------------------------------

def run_etl_pilot(
    aqsoldb_filepath: Optional[str] = None,
    pilot_limit: int = 100
):
    """
    ظٹظ†ظپط° ظ…ط³ط§ط± ETL ط§ظ„ظƒط§ظ…ظ„ ط¹ظ„ظ‰ pilot (100 ظ…ط§ط¯ط©).
    
    ط§ظ„ط®ط·ظˆط§طھ:
    1. طھط­ظ…ظٹظ„ AqSolDB
    2. ظ„ظƒظ„ ظ…ط§ط¯ط©: ط§ط³طھط¹ظ„ط§ظ… PubChem ط¨ط§ظ„ظ€ InChIKey
    3. ط¥ط¯ط±ط§ط¬ ط§ظ„ظ‡ظˆظٹط© + ط§ظ„ط®طµط§ط¦طµ + ظ‚ظٹظ… ط§ظ„ط°ظˆط¨ط§ظ†ظٹط©
    
    ط§ظ„ظ…طµط§ط¯ط±:
    - PubChem PUG REST (Kim et al. 2016, Nucleic Acids Res. 44:D1202)
    - AqSolDB (Sorkun et al. 2019, Sci. Data 6:143)
    """
    log.info("=" * 60)
    log.info("Starting ETL Pilot")
    log.info(f"Pilot limit: {pilot_limit} compounds")
    log.info("=" * 60)

    # طھط­ظ…ظٹظ„ AqSolDB
    df = load_aqsoldb(aqsoldb_filepath)
    df_pilot = df.head(pilot_limit).copy()
    log.info(f"Processing {len(df_pilot)} compounds from AqSolDB")

    conn = get_db_connection()
    stats = {
        "total":        len(df_pilot),
        "identity_ok":  0,
        "pubchem_ok":   0,
        "pubchem_miss": 0,
        "solubility_ok":0,
        "errors":       0,
    }

    try:
        for idx, row in df_pilot.iterrows():
            inchikey = row.get("InChIKey", "")

            if not validate_inchikey(inchikey):
                log.warning(f"Row {idx}: invalid InChIKey '{inchikey}', skipping.")
                stats["errors"] += 1
                continue

            # ط§ط³طھط¹ظ„ط§ظ… PubChem
            pubchem_data = fetch_pubchem_by_inchikey(inchikey)

            if pubchem_data is None:
                log.warning(f"PubChem: no data for {inchikey}")
                stats["pubchem_miss"] += 1
                # ظ†ط¯ط±ط¬ ط¨ظٹط§ظ†ط§طھ ط£ط³ط§ط³ظٹط© ظ…ظ† AqSolDB ظپظ‚ط·
                pubchem_data = {
                    "InChIKey": inchikey,
                    "MolecularFormula": None,
                    "MolecularWeight":  row.get("MolWt"),
                    "XLogP":            row.get("MolLogP"),
                }
            else:
                stats["pubchem_ok"] += 1

            with conn.cursor() as cur:
                try:
                    # 1. ط¥ط¯ط±ط§ط¬ ط§ظ„ظ‡ظˆظٹط©
                    identity_id = upsert_chemical_identity(
                        cur, inchikey, pubchem_data, aqsoldb_name=row.get("Name")
                    )
                    if identity_id is None:
                        # ط¥ط°ط§ ظƒط§ظ† ON CONFLICT DO UPDATE ط¨ط¯ظˆظ† RETURNING
                        cur.execute(
                            "SELECT chemical_identity_id FROM chemical_identity_registry WHERE standard_inchikey = %s",
                            (inchikey,)
                        )
                        res = cur.fetchone()
                        identity_id = res[0] if res else None

                    if identity_id is None:
                        log.error(f"Could not get identity_id for {inchikey}")
                        conn.rollback()
                        stats["errors"] += 1
                        continue

                    stats["identity_ok"] += 1

                    # 2. ط¥ط¯ط±ط§ط¬ ط§ظ„ط®طµط§ط¦طµ ط§ظ„ظپظٹط²ظٹط§ط¦ظٹط©â€‘ط§ظ„ظƒظٹظ…ظٹط§ط¦ظٹط©
                    upsert_physchem_properties(cur, identity_id, pubchem_data)

                    # 3. ط¥ط¯ط±ط§ط¬ ظ‚ظٹظ…ط© ط§ظ„ط°ظˆط¨ط§ظ†ظٹط© ظ…ظ† AqSolDB
                    upsert_solubility_observation(cur, identity_id, row, "aqsoldb")
                    stats["solubility_ok"] += 1

                    # 4. ط±ط¨ط· ط¨ظ…ط¬ظ…ظˆط¹ط© ط¨ظٹط§ظ†ط§طھ AqSolDB
                    insert_dataset_membership(cur, identity_id, "aqsoldb")

                    conn.commit()
                    log.info(f"[{idx+1}/{len(df_pilot)}] OK: {inchikey} (identity_id={identity_id})")

                except Exception as e:
                    conn.rollback()
                    log.error(f"[{idx+1}] Error for {inchikey}: {e}")
                    stats["errors"] += 1

    finally:
        conn.close()

    # طھظ‚ط±ظٹط± ظ†ظ‡ط§ط¦ظٹ
    log.info("=" * 60)
    log.info("ETL Pilot Complete")
    log.info(f"  Total processed:    {stats['total']}")
    log.info(f"  Identity inserted:  {stats['identity_ok']}")
    log.info(f"  PubChem matched:    {stats['pubchem_ok']}")
    log.info(f"  PubChem missing:    {stats['pubchem_miss']}")
    log.info(f"  Solubility loaded:  {stats['solubility_ok']}")
    log.info(f"  Errors:             {stats['errors']}")
    log.info("=" * 60)
    return stats


# --------------------------------------------------
# SECTION F: Unit Tests ظ„ظ„طھط­ظ‚ظ‚
# ط§ظ„ظ…طµط¯ط±: Python unittest + InChI v1.06 format specs
# --------------------------------------------------

import unittest

class TestValidators(unittest.TestCase):

    def test_valid_inchikey(self):
        # InChIKey ط§ظ„ظƒط§ظپظٹظٹظ† â€” PubChem CID 2519
        self.assertTrue(validate_inchikey("RYYVLZVUVIJVGH-UHFFFAOYSA-N"))

    def test_valid_inchikey_aspirin(self):
        # InChIKey ط£ط³ط¨ط±ظٹظ† â€” PubChem CID 2244
        self.assertTrue(validate_inchikey("BSYNRYMUTXBXSQ-UHFFFAOYSA-N"))

    def test_invalid_inchikey_short(self):
        self.assertFalse(validate_inchikey("TOOSHORT-UHFFFAOYSA-N"))

    def test_invalid_inchikey_none(self):
        self.assertFalse(validate_inchikey(None))

    def test_invalid_inchikey_lowercase(self):
        self.assertFalse(validate_inchikey("ryyvlzvuvijvgh-uhfffaoysa-n"))

    def test_valid_logs_typical(self):
        # LogS = -2.0 ظ‚ظٹظ…ط© ظ†ظ…ظˆط°ط¬ظٹط© ظ„ظ„ظƒط§ظپظٹظٹظ†
        self.assertTrue(validate_logs(-2.0))

    def test_valid_logs_boundary_low(self):
        self.assertTrue(validate_logs(-15.0))

    def test_valid_logs_boundary_high(self):
        self.assertTrue(validate_logs(5.0))

    def test_invalid_logs_too_low(self):
        self.assertFalse(validate_logs(-20.0))

    def test_invalid_logs_too_high(self):
        self.assertFalse(validate_logs(10.0))

    def test_invalid_logs_none(self):
        self.assertFalse(validate_logs(None))

    def test_invalid_logs_string(self):
        self.assertFalse(validate_logs("not_a_number"))


# --------------------------------------------------
# SECTION G: ظ†ظ‚ط·ط© ط§ظ„ط¯ط®ظˆظ„
# --------------------------------------------------

if __name__ == "__main__":
    import sys

    if "--test" in sys.argv:
        # طھط´ط؛ظٹظ„ unit tests
        print("Running Unit Tests...")
        loader = unittest.TestLoader()
        suite  = loader.loadTestsFromTestCase(TestValidators)
        runner = unittest.TextTestRunner(verbosity=2)
        result = runner.run(suite)
        sys.exit(0 if result.wasSuccessful() else 1)

    elif "--etl" in sys.argv:
        # طھط´ط؛ظٹظ„ ETL pilot
        limit = 100
        filepath = None

        for arg in sys.argv:
            if arg.startswith("--limit="):
                limit = int(arg.split("=")[1])
            if arg.startswith("--file="):
                filepath = arg.split("=")[1]

        run_etl_pilot(aqsoldb_filepath=filepath, pilot_limit=limit)

    else:
        print("""
Usage:
  python M3_M4_etl_pubchem_aqsoldb.py --test        # run unit tests
  python M3_M4_etl_pubchem_aqsoldb.py --etl          # run ETL pilot (100 compounds)
  python M3_M4_etl_pubchem_aqsoldb.py --etl --limit=500 --file=aqsoldb.csv

Environment variables:
  DB_HOST      (default: localhost)
  DB_PORT      (default: 5432)
  DB_NAME      (default: chem_platform)
  DB_USER      (default: postgres)
  DB_PASSWORD  (default: empty)
        """)
