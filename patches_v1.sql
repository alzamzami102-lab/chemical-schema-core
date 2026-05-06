-- ==========================================
-- PATCHES v1: تصحيحات شاملة لجميع السكربتات
-- ==========================================
-- يُطبَّق بعد تنفيذ جميع السكربتات الأساسية:
--   1. core_schema_identity_physchem_solubility.sql
--   2. core_schema_predictions_regulatory.sql
--   3. ext_identity_structural_variants.sql
--   4. ext_qsar_qmrf_metadata.sql
--   5. ext_experimental_endpoints_tox_env_exposure.sql
--   6. ext_chemical_family_dictionary.sql
-- Target DB: PostgreSQL
--
-- المصادر العلمية:
-- - InChI v1.06 (Batchelor et al. 2021, J. Cheminform. 13:40)
-- - AqSolDB (Sorkun et al. 2019, Sci. Data 6:143)
-- - OECD QMRF v2.1 + QPRF v2.0 (OECD 2023, ENV/CBC/MONO(2023)32)
-- - OECD QAF 2023 (ENV/CBC/MONO(2023)32)
-- - ChEBI Ontology (Hastings et al. 2016, Nucleic Acids Res. 44:D1214)
-- - RDKit Functional_Group_Hierarchy.txt (Landrum/Novartis)
-- ==========================================

BEGIN;

-- ==========================================
-- PATCH 1: حقول AqSolDB الناقصة
-- ==========================================
-- المصدر: Sorkun et al. 2019, Sci. Data 6:143
-- AqSolDB يحتوي فعليًا على:
--   SD          = standard deviation لقيم LogS المجمّعة
--   Occurrences = عدد قياسات LogS من المصادر
--   Group       = تصنيف موثوقية القياس

ALTER TABLE experimental_observation_registry
  ADD COLUMN IF NOT EXISTS sd_value           NUMERIC,
  ADD COLUMN IF NOT EXISTS occurrences_count  INTEGER,
  ADD COLUMN IF NOT EXISTS reliability_group  TEXT;

COMMENT ON COLUMN experimental_observation_registry.sd_value
  IS 'Standard deviation of LogS across aggregated sources (AqSolDB field: SD). Source: Sorkun et al. 2019, Sci. Data 6:143.';

COMMENT ON COLUMN experimental_observation_registry.occurrences_count
  IS 'Number of source measurements aggregated for this record (AqSolDB field: Occurrences). Source: Sorkun et al. 2019, Sci. Data 6:143.';

COMMENT ON COLUMN experimental_observation_registry.reliability_group
  IS 'Reliability group classification from source dataset (AqSolDB). Source: Sorkun et al. 2019, Sci. Data 6:143.';

-- ==========================================
-- PATCH 2: تحديث seed QMRF version إلى v2.1
-- ==========================================
-- المصدر: OECD (2023), ENV/CBC/MONO(2023)32, Annex I: QMRF v2.1

UPDATE qsar_model_registry
SET
  qmrf_version_text = 'QMRF v2.1 (OECD 2023)',
  qmrf_status       = 'conceptual_seed_aligned_to_v2.1'
WHERE model_code = 'esol_linear_regression';

COMMENT ON COLUMN qsar_model_registry.qmrf_version_text
  IS 'QMRF version reference. Current official version: QMRF v2.1 (OECD 2023, ENV/CBC/MONO(2023)32, Annex I).';

-- ==========================================
-- PATCH 3: حقل endpoint_family_code في qsar_model_registry
-- ==========================================
-- يربط النموذج بعائلة الـ endpoint (physchem/tox/env)
-- لتسهيل التصفية بدون JOIN معقّد.

ALTER TABLE qsar_model_registry
  ADD COLUMN IF NOT EXISTS endpoint_family_code TEXT;

COMMENT ON COLUMN qsar_model_registry.endpoint_family_code
  IS 'Optional link to experimental_endpoint_family_dictionary.endpoint_family_code. Enables filtering models by endpoint family (physchem, toxicological, environmental_fate, etc.).';

UPDATE qsar_model_registry
SET endpoint_family_code = 'physchem'
WHERE model_code = 'esol_linear_regression';

-- ==========================================
-- PATCH 4: حقل prediction_scope_code
-- ==========================================
-- المصدر: OECD QAF 2023, ENV/CBC/MONO(2023)32, Section 3.4
-- يُفرّق بين:
--   single                    = تنبؤ نموذج واحد (QPRF v2.0)
--   multiple_predictions_based = نتيجة مبنية على تنبؤات متعددة

ALTER TABLE qsar_prediction_registry
  ADD COLUMN IF NOT EXISTS prediction_scope_code TEXT NOT NULL DEFAULT 'single';

COMMENT ON COLUMN qsar_prediction_registry.prediction_scope_code
  IS 'Scope per OECD QAF 2023: "single" (one model, QPRF v2.0) or "multiple_predictions_based". Source: OECD ENV/CBC/MONO(2023)32.';

-- ==========================================
-- PATCH 5: FOREIGN KEY صريح لـ endpoint_category_code
-- ==========================================
-- يمنع إدخال قيم غير موجودة في قاموس الفئات.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'fk_endpoint_category_code'
      AND table_name = 'experimental_endpoint_registry'
  ) THEN
    ALTER TABLE experimental_endpoint_registry
      ADD CONSTRAINT fk_endpoint_category_code
      FOREIGN KEY (endpoint_category_code)
      REFERENCES experimental_endpoint_category_dictionary(endpoint_category_code)
      ON DELETE SET NULL;
  END IF;
END$$;

-- ==========================================
-- PATCH 6: تصحيح خطأ INSERT الـ amine
-- ==========================================
-- المشكلة: family_dimension_code كانت 'Amines' بدل 'functional_group'
-- المصدر: RDKit Functional_Group_Hierarchy.txt (Landrum/Novartis)

INSERT INTO chemical_family_dictionary (
  chemical_family_code,
  chemical_family_label,
  family_dimension_code,
  parent_family_code,
  description_text,
  typical_pattern_text,
  smarts_pattern_text,
  reference_source_text,
  external_ontology_ref_text
) VALUES (
  'amine',
  'Amines',
  'functional_group',
  NULL,
  'Compounds containing an amino group (-NH2, -NHR, -NR2).',
  'R-NH2 / R-NHR / R-NR2',
  '[N;$(N-[#6]);!$(N-[!#6;!#1]);!$(N-C=[O,N,S])]',
  'RDKit Functional_Group_Hierarchy.txt (Amine); IUPAC',
  'ChEBI amine classes'
)
ON CONFLICT (chemical_family_code) DO UPDATE
  SET
    family_dimension_code      = 'functional_group',
    description_text           = EXCLUDED.description_text,
    typical_pattern_text       = EXCLUDED.typical_pattern_text,
    smarts_pattern_text        = EXCLUDED.smarts_pattern_text,
    reference_source_text      = EXCLUDED.reference_source_text,
    external_ontology_ref_text = EXCLUDED.external_ontology_ref_text;

-- ==========================================
-- PATCH 7: Self-referential FK في chemical_family_dictionary
-- ==========================================
-- يضمن أن parent_family_code يشير لسجل موجود فعلًا.
-- يُطبَّق بعد PATCH 6 لضمان وجود جميع الآباء.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'fk_parent_family_code'
      AND table_name = 'chemical_family_dictionary'
  ) THEN
    ALTER TABLE chemical_family_dictionary
      ADD CONSTRAINT fk_parent_family_code
      FOREIGN KEY (parent_family_code)
      REFERENCES chemical_family_dictionary(chemical_family_code)
      ON DELETE SET NULL;
  END IF;
END$$;

-- ==========================================
-- PATCH 8: حقل Polymer InChI notation + تنبيه علمي
-- ==========================================
-- المصدر: Batchelor et al. 2021, J. Cheminform. 13:40
-- InChI v1.06 يدعم البوليمرات بشكل جزئي فقط.

ALTER TABLE polymer_identity_registry
  ADD COLUMN IF NOT EXISTS polymer_inchi_notation_text TEXT,
  ADD COLUMN IF NOT EXISTS inchi_polymer_support_note  TEXT
    DEFAULT 'Polymer InChI support is partial as of InChI v1.06 (Batchelor et al. 2021, J. Cheminform. 13:40). Full structural encoding of polymers is not guaranteed.';

COMMENT ON COLUMN polymer_identity_registry.polymer_inchi_notation_text
  IS 'InChI polymer notation string if available. Note: partial support only in InChI v1.06.';

COMMENT ON COLUMN polymer_identity_registry.inchi_polymer_support_note
  IS 'Scientific caveat on InChI polymer support. Source: Batchelor et al. 2021, J. Cheminform. 13:40.';

-- ==========================================
-- PATCH 9: QMRF Section 9.1 للـ multiple predictions
-- ==========================================
-- المصدر: OECD QAF 2023, ENV/CBC/MONO(2023)32
-- QMRF v2.1 يُضيف اعتبارات لـ "results based on multiple predictions".

INSERT INTO qsar_qmrf_section_metadata (
  qsar_model_id,
  section_code,
  section_title,
  section_text,
  section_language_code,
  is_regulatory_critical
)
SELECT
  qsar_model_id,
  '9.1',
  'Results based on multiple predictions (QMRF v2.1)',
  'Optional section per QMRF v2.1 (OECD 2023): documentation when multiple QSAR predictions are combined or compared. Applies when prediction_scope_code = ''multiple_predictions_based''.',
  'en',
  FALSE
FROM qsar_model_registry
WHERE model_code = 'esol_linear_regression'
ON CONFLICT (qsar_model_id, section_code) DO NOTHING;

-- ==========================================
-- PATCH 10: تحديث توثيق سجل الكافيين
-- ==========================================
-- PubChem CID 2519 | ChEBI CHEBI:27732
-- InChIKey: RYYVLZVUVIJVGH-UHFFFAOYSA-N

UPDATE chemical_identity_registry
SET
  curation_level       = 'high',
  source_priority_text = 'PubChem CID 2519; ChEBI CHEBI:27732; InChI v1.06'
WHERE standard_inchikey = 'RYYVLZVUVIJVGH-UHFFFAOYSA-N';

COMMENT ON COLUMN chemical_identity_registry.standard_inchikey
  IS 'Standard InChIKey (27 chars, hashed). Reliability: >99.99% per InChI v1.06 (Batchelor et al. 2021, J. Cheminform. 13:40). Collision probability negligible for databases of PubChem scale.';

-- ==========================================
-- PATCH 11: COMMENT توثيقية على الجداول الرئيسية
-- ==========================================

COMMENT ON TABLE chemical_identity_registry
  IS 'Core chemical identity registry. InChIKey uniqueness based on InChI v1.06 (Batchelor et al. 2021). PubChem CID and ChEBI ID as external reference anchors.';

COMMENT ON TABLE experimental_observation_registry
  IS 'Experimental observations per endpoint. Solubility data aligned with AqSolDB (Sorkun et al. 2019, Sci. Data 6:143). Strict separation of measured data from predicted data.';

COMMENT ON TABLE qsar_model_registry
  IS 'QSAR/QSPR model registry. Aligned with OECD QMRF v2.1 (OECD 2023, ENV/CBC/MONO(2023)32, Annex I). Model metadata separated from validation metrics and predictions.';

COMMENT ON TABLE qsar_prediction_registry
  IS 'Per-compound QSAR predictions. Aligned with OECD QPRF v2.0 (OECD 2023, ENV/CBC/MONO(2023)32, Annex II). Includes applicability domain result and prediction scope.';

COMMENT ON TABLE regulatory_framework_registry
  IS 'Regulatory frameworks registry. Covers OECD OHT, OECD QAF 2023, and IUCLID implementation context.';

COMMENT ON TABLE chemical_family_dictionary
  IS 'Chemical family classification dictionary. Functional group SMARTS from RDKit Functional_Group_Hierarchy.txt (Landrum/Novartis). ChEBI class IDs from ChEBI Ontology (Hastings et al. 2016, Nucleic Acids Res. 44:D1214).';

COMMIT;

-- ==========================================
-- END OF PATCHES v1
-- ==========================================
