-- ==========================================
-- CORE SCHEMA: IDENTITY + PHYSCHEM + SOLUBILITY
-- ==========================================
-- ملاحظة: مصمم لـ PostgreSQL

-- =========================
-- 1) CHEMICAL IDENTITY
-- =========================

CREATE TABLE IF NOT EXISTS chemical_identity_registry (
  chemical_identity_id BIGSERIAL PRIMARY KEY,
  preferred_name        TEXT,
  iupac_name            TEXT,
  molecular_formula     TEXT,
  canonical_smiles      TEXT,
  standard_inchi        TEXT,
  standard_inchikey     TEXT,
  pubchem_cid           BIGINT,
  chebi_id              TEXT,
  identity_status       TEXT NOT NULL DEFAULT 'candidate',
  curation_level        TEXT,
  source_priority_text  TEXT,
  created_at            TIMESTAMPTZ DEFAULT now(),
  updated_at            TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS chemical_identity_synonym_registry (
  synonym_id            BIGSERIAL PRIMARY KEY,
  chemical_identity_id  BIGINT NOT NULL
    REFERENCES chemical_identity_registry(chemical_identity_id)
    ON DELETE CASCADE,
  synonym_text          TEXT NOT NULL,
  synonym_type          TEXT,
  source_name           TEXT,
  is_preferred          BOOLEAN DEFAULT FALSE,
  created_at            TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS chemical_identity_xref_registry (
  xref_id               BIGSERIAL PRIMARY KEY,
  chemical_identity_id  BIGINT NOT NULL
    REFERENCES chemical_identity_registry(chemical_identity_id)
    ON DELETE CASCADE,
  source_name           TEXT NOT NULL,
  external_id           TEXT NOT NULL,
  xref_type             TEXT,
  created_at            TIMESTAMPTZ DEFAULT now(),
  UNIQUE (source_name, external_id)
);

CREATE TABLE IF NOT EXISTS chemical_identity_classification_registry (
  classification_id     BIGSERIAL PRIMARY KEY,
  chemical_identity_id  BIGINT NOT NULL
    REFERENCES chemical_identity_registry(chemical_identity_id)
    ON DELETE CASCADE,
  classification_source TEXT NOT NULL,
  class_id              TEXT,
  class_name            TEXT,
  relation_type         TEXT,
  created_at            TIMESTAMPTZ DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_identity_inchikey
  ON chemical_identity_registry(standard_inchikey)
  WHERE standard_inchikey IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_identity_pubchem_cid
  ON chemical_identity_registry(pubchem_cid)
  WHERE pubchem_cid IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_identity_chebi_id
  ON chemical_identity_registry(chebi_id)
  WHERE chebi_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_identity_name
  ON chemical_identity_registry(preferred_name);

CREATE INDEX IF NOT EXISTS idx_identity_formula
  ON chemical_identity_registry(molecular_formula);

CREATE INDEX IF NOT EXISTS idx_identity_synonym_text
  ON chemical_identity_synonym_registry(synonym_text);

-- =========================
-- 2) PHYSCHEM PROPERTIES
-- =========================

CREATE TABLE IF NOT EXISTS physchem_property_dictionary (
  property_code      TEXT PRIMARY KEY,
  property_name      TEXT NOT NULL,
  preferred_unit     TEXT,
  value_type         TEXT NOT NULL,
  source_scope_text  TEXT
);

CREATE TABLE IF NOT EXISTS physchem_property_registry (
  physchem_property_id    BIGSERIAL PRIMARY KEY,
  chemical_identity_id    BIGINT NOT NULL
    REFERENCES chemical_identity_registry(chemical_identity_id)
    ON DELETE CASCADE,
  property_code           TEXT NOT NULL
    REFERENCES physchem_property_dictionary(property_code),
  property_name           TEXT NOT NULL,
  property_value_num      NUMERIC,
  property_value_text     TEXT,
  property_unit           TEXT,
  property_method_text    TEXT,
  property_condition_text TEXT,
  source_name             TEXT NOT NULL,
  source_record_ref       TEXT,
  evidence_type           TEXT,
  quality_note            TEXT,
  created_at              TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS physchem_measurement_context_registry (
  measurement_context_id BIGSERIAL PRIMARY KEY,
  physchem_property_id   BIGINT NOT NULL
    REFERENCES physchem_property_registry(physchem_property_id)
    ON DELETE CASCADE,
  temperature_value      NUMERIC,
  temperature_unit       TEXT,
  pressure_value         NUMERIC,
  pressure_unit          TEXT,
  ph_value               NUMERIC,
  medium_text            TEXT,
  notes_text             TEXT,
  created_at             TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_physchem_identity
  ON physchem_property_registry(chemical_identity_id);

CREATE INDEX IF NOT EXISTS idx_physchem_property_code
  ON physchem_property_registry(property_code);

CREATE INDEX IF NOT EXISTS idx_physchem_source_name
  ON physchem_property_registry(source_name);

CREATE UNIQUE INDEX IF NOT EXISTS uq_physchem_property_record
  ON physchem_property_registry(
    chemical_identity_id,
    property_code,
    source_name,
    COALESCE(source_record_ref, '')
  );

INSERT INTO physchem_property_dictionary
  (property_code, property_name, preferred_unit, value_type, source_scope_text)
VALUES
  ('molecular_weight',      'Molecular Weight',                     'g/mol',      'numeric',        'PubChem property table'),
  ('xlogp',                 'XLogP',                                NULL,         'numeric',        'PubChem property table'),
  ('tpsa',                  'Topological Polar Surface Area',       'angstrom^2', 'numeric',        'PubChem property table'),
  ('hbond_donor_count',     'Hydrogen Bond Donor Count',            NULL,         'numeric',        'PubChem property table'),
  ('hbond_acceptor_count',  'Hydrogen Bond Acceptor Count',         NULL,         'numeric',        'PubChem property table'),
  ('rotatable_bond_count',  'Rotatable Bond Count',                 NULL,         'numeric',        'PubChem property table'),
  ('heavy_atom_count',      'Heavy Atom Count',                     NULL,         'numeric',        'PubChem property table'),
  ('boiling_point',         'Boiling Point',                        'K',          'numeric_or_text','NIST Chemistry WebBook'),
  ('heat_of_fusion',        'Heat of Fusion',                       NULL,         'numeric_or_text','NIST Chemistry WebBook'),
  ('heat_of_sublimation',   'Heat of Sublimation',                  NULL,         'numeric_or_text','NIST Chemistry WebBook'),
  ('henrys_law_constant',   'Henrys Law Constant',                  NULL,         'numeric_or_text','NIST Chemistry WebBook')
ON CONFLICT (property_code) DO NOTHING;

-- =========================
-- 3) SOLUBILITY & OBSERVATIONS
-- =========================

CREATE TABLE IF NOT EXISTS experimental_endpoint_registry (
  experimental_endpoint_id BIGSERIAL PRIMARY KEY,
  endpoint_code            TEXT NOT NULL UNIQUE,
  endpoint_name            TEXT NOT NULL,
  endpoint_family          TEXT,
  preferred_unit           TEXT,
  preferred_scale          TEXT,
  oecd_alignment_text      TEXT,
  created_at               TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS experimental_dataset_registry (
  experimental_dataset_id  BIGSERIAL PRIMARY KEY,
  dataset_code             TEXT NOT NULL UNIQUE,
  dataset_name             TEXT NOT NULL,
  dataset_scope_text       TEXT,
  source_citation_text     TEXT,
  source_url               TEXT,
  record_count_text        TEXT,
  curation_method_text     TEXT,
  created_at               TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS experimental_observation_registry (
  experimental_observation_id BIGSERIAL PRIMARY KEY,
  chemical_identity_id        BIGINT NOT NULL
    REFERENCES chemical_identity_registry(chemical_identity_id)
    ON DELETE CASCADE,
  experimental_endpoint_id    BIGINT NOT NULL
    REFERENCES experimental_endpoint_registry(experimental_endpoint_id)
    ON DELETE CASCADE,
  observed_value_num          NUMERIC,
  observed_value_text         TEXT,
  observed_unit               TEXT,
  observed_scale              TEXT,
  temperature_value           NUMERIC,
  temperature_unit            TEXT,
  pressure_value              NUMERIC,
  pressure_unit               TEXT,
  ph_value                    NUMERIC,
  medium_text                 TEXT,
  protocol_text               TEXT,
  source_name                 TEXT NOT NULL,
  source_record_ref           TEXT,
  source_year                 INT,
  reliability_label           TEXT,
  evidence_type               TEXT,
  curation_note               TEXT,
  created_at                  TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS experimental_dataset_membership (
  membership_id               BIGSERIAL PRIMARY KEY,
  experimental_dataset_id     BIGINT NOT NULL
    REFERENCES experimental_dataset_registry(experimental_dataset_id)
    ON DELETE CASCADE,
  experimental_observation_id BIGINT NOT NULL
    REFERENCES experimental_observation_registry(experimental_observation_id)
    ON DELETE CASCADE,
  UNIQUE (experimental_dataset_id, experimental_observation_id)
);

CREATE INDEX IF NOT EXISTS idx_obs_identity
  ON experimental_observation_registry(chemical_identity_id);

CREATE INDEX IF NOT EXISTS idx_obs_endpoint
  ON experimental_observation_registry(experimental_endpoint_id);

CREATE INDEX IF NOT EXISTS idx_obs_source
  ON experimental_observation_registry(source_name);

CREATE UNIQUE INDEX IF NOT EXISTS uq_obs_source_record
  ON experimental_observation_registry(
    chemical_identity_id,
    experimental_endpoint_id,
    source_name,
    COALESCE(source_record_ref, ''),
    COALESCE(observed_scale, ''),
    COALESCE(observed_unit, '')
  );

INSERT INTO experimental_endpoint_registry (
  endpoint_code,
  endpoint_name,
  endpoint_family,
  preferred_unit,
  preferred_scale,
  oecd_alignment_text
)
VALUES (
  'aqueous_solubility',
  'Aqueous Solubility',
  'physicochemical_experimental',
  'mol/L_or_contextual',
  'LogS_or_native',
  'Aligned conceptually with OECD endpoint-oriented reporting'
)
ON CONFLICT (endpoint_code) DO NOTHING;

INSERT INTO experimental_dataset_registry (
  dataset_code,
  dataset_name,
  dataset_scope_text,
  source_citation_text,
  source_url,
  record_count_text,
  curation_method_text
)
VALUES
(
  'aqsoldb',
  'AqSolDB',
  'Curated aqueous solubility dataset',
  'Sorkun MC, Khetan A, Er S. Sci Data. 2019.',
  'https://www.nature.com/articles/s41597-019-0151-1',
  '9982 unique compounds',
  'Merged and standardized from public datasets'
),
(
  'esol_delaney',
  'Delaney ESOL Dataset',
  'Measured aqueous solubility dataset used in ESOL context',
  'Delaney JS. J Chem Inf Comput Sci. 2004.',
  'https://pubs.acs.org/doi/10.1021/ci034243x',
  '2874 measured solubilities',
  'Measured dataset used for model context'
)
ON CONFLICT (dataset_code) DO NOTHING;
