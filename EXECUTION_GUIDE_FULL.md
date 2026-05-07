# ط¯ظ„ظٹظ„ ط§ظ„طھط´ط؛ظٹظ„ ط§ظ„ظƒط§ظ…ظ„ â€” Chemical Platform DB (Files 01â€“13)

## طھط±طھظٹط¨ ط§ظ„طھط´ط؛ظٹظ„ ط§ظ„ظƒط§ظ…ظ„ (ظ†ط³ط® ظˆطھط´ط؛ظٹظ„ ظ…ط±ط© ظˆط§ط­ط¯ط©)

```bash
psql -d chem_platform -f 01_core_identity_physchem_solubility.sql
psql -d chem_platform -f 02_core_predictions_regulatory.sql
psql -d chem_platform -f 03_ext_identity_structural_variants.sql
psql -d chem_platform -f 04_ext_qsar_qmrf_metadata.sql
psql -d chem_platform -f 05_ext_experimental_endpoints_tox_env.sql
psql -d chem_platform -f 06_ext_chemical_family_dictionary.sql
psql -d chem_platform -f 07_patches_v1.sql
psql -d chem_platform -f 08_ext_olfactory_fragrance_layer.sql
psql -d chem_platform -f 09_ext_molecular_twin_iot_layer.sql
psql -d chem_platform -f 10_ext_iuclid_reach_esr_layer.sql
psql -d chem_platform -f 11_ext_formula_version_market_analytics.sql
psql -d chem_platform -f 12_ext_concept_matching_flavor_cosmetics_layer.sql
psql -d chem_platform -f 13_ext_education_api_layer.sql
psql -d chem_platform -f example_caffeine_integration.sql
psql -d chem_platform -f example_linalool_olfactory_integration.sql
```

## ظ…ط§ ظٹط؛ط·ظٹظ‡ ظƒظ„ ظ…ظ„ظپ

| ط§ظ„ظ…ظ„ظپ | ط§ظ„ط·ط¨ظ‚ط© | ط§ظ„ظ…ط¬ط§ظ„ط§طھ |
|-------|--------|----------|
| 01 | ط§ظ„ظ†ظˆط§ط© | ط§ظ„ظ‡ظˆظٹط© ط§ظ„ط¬ط²ظٹط¦ظٹط©طŒ InChI/InChIKeyطŒ ط§ظ„ط®طµط§ط¦طµ ط§ظ„ظپظٹط²ظٹظˆظƒظٹظ…ظٹط§ط¦ظٹط©طŒ AqSolDB |
| 02 | ط§ظ„ظ†ظˆط§ط© | QSARطŒ QMRF v2.1/OECD 2023طŒ ط§ظ„طھظ†ط¸ظٹظ… |
| 03 | ط§ظ…طھط¯ط§ط¯ | ط§ظ„ظ…طھطµط§ظˆط؛ط§طھطŒ ط§ظ„ظ…ظ„ط­طŒ UVCBطŒ ط§ظ„طھظˆطھظˆظ…ط±ط§طھ |
| 04 | ط§ظ…طھط¯ط§ط¯ | QMRF ط§ظ„ظƒط§ظ…ظ„طŒ QPRFطŒ Applicability Domain |
| 05 | ط§ظ…طھط¯ط§ط¯ | Endpoints طھط¬ط±ظٹط¨ظٹط© (TOX/ENV/PHYSCHEM) |
| 06 | ط§ظ…طھط¯ط§ط¯ | ظ‚ط§ظ…ظˆط³ ط§ظ„ط¹ط§ط¦ظ„ط§طھ ط§ظ„ظƒظٹظ…ظٹط§ط¦ظٹط© (SMARTS + ChEBI) |
| 07 | طھطµط­ظٹط­ط§طھ | 11 ط¥طµظ„ط§ط­ ط¨ظ†ظٹظˆظٹ (FKطŒ NULLطŒ AqSolDB fields) |
| 08 | ط¹ط·ظˆط± | IFRA Amendment 51 (2023)طŒ FEMA GRASطŒ PyrfumeطŒ GoodScents |
| 09 | ط±ظ‚ظ…ظٹ/IoT | Molecular TwinطŒ IoT devicesطŒ ظ…ط³طھظ‚ط¨ظ„ط§طھ ط´ظ…ظٹط©طŒ AROMMAطŒ NOSE |
| 10 | طھظ†ط¸ظٹظ… | IUCLID6 ESRطŒ REACH Annex VII-XطŒ Klimisch scale |
| 11 | طھط­ظ„ظٹظ„ط§طھ | Formula versioningطŒ Materialized ViewsطŒ Innovation Gap |
| 12 | ظ…طھط¹ط¯ط¯ ط§ظ„ظ…ط¬ط§ظ„ط§طھ | Concept MatchingطŒ طھط¬ظ…ظٹظ„ (1223/2009)طŒ ظ†ظƒظ‡ط§طھ (1334/2008)طŒ ظ…ظ†ط²ظ„ظٹ |
| 13 | طھط¹ظ„ظٹظ…/API | Learning UnitsطŒ FlashcardsطŒ REST API catalog (12 endpoint)طŒ Usage Log |

## ط§ظ„ظ…طµط§ط¯ط± ط§ظ„ط¹ظ„ظ…ظٹط© ط§ظ„ط±ط¦ظٹط³ظٹط©

| ط§ظ„ظ…طµط¯ط± | ط§ظ„ظˆطµظپ |
|--------|-------|
| InChI Trust v1.06 | IUPAC/InChI Trust (2023) |
| OECD QAF 2023, Series No. 386 | QMRF v2.1 |
| IFRA Amendment 51 | 30 June 2023, 18 product categories |
| FEMA GRAS Registry | ~2800 flavor substances |
| EU Regulation 1223/2009 | Cosmetics + Annex III allergens 2022 |
| EU Regulation 1334/2008/EC | Flavourings |
| REACH 1907/2006/EC | IUCLID6 format |
| Klimisch et al., Chemosphere 1997 | PMID:9134683, reliability scale 1-4 |
| Lee et al., Science 381:999 (2023) | Principal Odor Map (POM) |
| NOSE, arXiv:2604.10452 (2026) | Zero-shot tri-modal olfactory retrieval |
| AROMMA, arXiv:2601.19561 (2025) | 512-dim SMILESâ†’descriptor embedding |
| Odor Strength, arXiv:2512.08683 (2024) | Ordinal 4-class model |
| AqSolDB, Sorkun et al. Sci. Data (2019) | 9982 measured LogS values |
| Pyrfume, Sci. Data (2024) | DOI:10.1038/s41597-024-04051-z |
| M2OR, Mayhew et al. Chem.Senses (2022) | Molecule-receptor activation DB |
| Bushdid et al. Science (2014) | >1 trillion olfactory stimuli |
| Spence (2011) i-Perception | Crossmodal correspondences (>600 studies) |
| Russell (1980) Psych. Rev. | Circumplex model of affect |
| Dravnieks (1985) | Atlas of Odor Character Profiles (146 descriptors) |
