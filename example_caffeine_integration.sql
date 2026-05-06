-- ==========================================
-- EXAMPLE INTEGRATION: CAFFEINE
-- Requires:
--   core_schema_identity_physchem_solubility.sql
--   core_schema_predictions_regulatory.sql
-- Target DB: PostgreSQL
-- ==========================================

BEGIN;

-- ------------------------------------------
-- 1) CHEMICAL IDENTITY FOR CAFFEINE
-- ------------------------------------------

WITH inserted_identity AS (
  INSERT INTO chemical_identity_registry (
    preferred_name,
    iupac_name,
    molecular_formula,
    canonical_smiles,
    standard_inchi,
    standard_inchikey,
    pubchem_cid,
    chebi_id,
    identity_status,
    curation_level,
    source_priority_text
  ) VALUES (
    'Caffeine',
    '1,3,7-Trimethylpurine-2,6-dione',
    'C8H10N4O2',
    'Cn1c(=O)n(c(=O)n2c1ncn(c2)C)C',
    NULL,                                -- يمكن استكماله من PubChem عند الحاجة
    'RYYVLZVUVIJVGH-UHFFFAOYSA-N',       -- Standard InChIKey من PubChem
    2519,
    'CHEBI:27732',
    'curated',
    'high',
    'PubChem; ChEBI'
  )
  ON CONFLICT (standard_inchikey) DO UPDATE
    SET preferred_name = EXCLUDED.preferred_name
  RETURNING chemical_identity_id
)
SELECT chemical_identity_id
INTO TEMP TABLE tmp_caf_identity
FROM inserted_identity;

-- في حالة وجود السجل مسبقًا، نحصل عليه
INSERT INTO tmp_caf_identity (chemical_identity_id)
SELECT chemical_identity_id
FROM chemical_identity_registry
WHERE standard_inchikey = 'RYYVLZVUVIJVGH-UHFFFAOYSA-N'
ON CONFLICT DO NOTHING;

-- ------------------------------------------
-- 2) PHYSCHEM PROPERTIES (EXAMPLES)
-- ------------------------------------------

-- وزن جزيئي من PubChem (قيمة تقريبية مثال)
INSERT INTO physchem_property_registry (
  chemical_identity_id,
  property_code,
  property_name,
  property_value_num,
  property_unit,
  source_name,
  source_record_ref,
  evidence_type
)
SELECT
  chemical_identity_id,
  'molecular_weight',
  'Molecular Weight',
  194.19,                 -- مثال تقريبي
  'g/mol',
  'PubChem',
  'CID:2519',
  'reference_database'
FROM tmp_caf_identity
ON CONFLICT (chemical_identity_id, property_code, source_name, COALESCE(source_record_ref, ''))
DO NOTHING;

-- XLogP من PubChem (قيمة تقريبية مثال)
INSERT INTO physchem_property_registry (
  chemical_identity_id,
  property_code,
  property_name,
  property_value_num,
  source_name,
  source_record_ref,
  evidence_type
)
SELECT
  chemical_identity_id,
  'xlogp',
  'XLogP',
  -0.1,                   -- مثال تقريبي
  'PubChem',
  'CID:2519',
  'calculated_in_database'
FROM tmp_caf_identity
ON CONFLICT (chemical_identity_id, property_code, source_name, COALESCE(source_record_ref, ''))
DO NOTHING;

-- ------------------------------------------
-- 3) AQUEOUS SOLUBILITY OBSERVATION (AQSOLDB-LIKE)
-- ------------------------------------------

-- التأكد من وجود endpoint وdataset من seed
WITH caf_ids AS (
  SELECT chemical_identity_id FROM tmp_caf_identity
),
aq_endpoint AS (
  SELECT experimental_endpoint_id
  FROM experimental_endpoint_registry
  WHERE endpoint_code = 'aqueous_solubility'
),
aq_dataset AS (
  SELECT experimental_dataset_id
  FROM experimental_dataset_registry
  WHERE dataset_code = 'aqsoldb'
),
insert_obs AS (
  INSERT INTO experimental_observation_registry (
    chemical_identity_id,
    experimental_endpoint_id,
    observed_value_num,
    observed_unit,
    observed_scale,
    temperature_value,
    temperature_unit,
    pressure_value,
    pressure_unit,
    ph_value,
    medium_text,
    protocol_text,
    source_name,
    source_record_ref,
    source_year,
    reliability_label,
    evidence_type
  )
  SELECT
    caf_ids.chemical_identity_id,
    aq_endpoint.experimental_endpoint_id,
    -2.0,                            -- مثال LogS
    NULL,
    'LogS',
    298.15,
    'K',
    NULL,
    NULL,
    NULL,
    'water',
    'Standard aqueous solubility conditions (example)',
    'AqSolDB',
    'AqSolDB_record_for_caffeine_example',
    2019,
    'reliable_with_restrictions',
    'measured'
  FROM caf_ids, aq_endpoint
  ON CONFLICT (chemical_identity_id,
               experimental_endpoint_id,
               source_name,
               COALESCE(source_record_ref, ''),
               COALESCE(observed_scale, ''),
               COALESCE(observed_unit, ''))
  DO UPDATE
    SET observed_value_num = EXCLUDED.observed_value_num
  RETURNING experimental_observation_id
)
INSERT INTO experimental_dataset_membership (
  experimental_dataset_id,
  experimental_observation_id
)
SELECT
  aq_dataset.experimental_dataset_id,
  insert_obs.experimental_observation_id
FROM insert_obs, aq_dataset
ON CONFLICT (experimental_dataset_id, experimental_observation_id)
DO NOTHING;

-- ------------------------------------------
-- 4) QSAR MODEL VALIDATION & APPLICABILITY DOMAIN (ESOL-LIKE)
-- ------------------------------------------

-- External validation metric (مثال R2) وفق QAF
INSERT INTO qsar_model_validation_registry (
  qsar_model_id,
  validation_scope,
  metric_name,
  metric_value,
  metric_text,
  validation_note
)
SELECT
  qsar_model_id,
  'external',
  'R2',
  0.85,
  NULL,
  'External validation on ESOL-like dataset split (illustrative)'
FROM qsar_model_registry
WHERE model_code = 'esol_linear_regression'
ON CONFLICT DO NOTHING;

-- Applicability domain description وفق QAF
INSERT INTO qsar_applicability_domain_registry (
  qsar_model_id,
  ad_method_text,
  ad_threshold_text,
  ad_interpretation_text
)
SELECT
  qsar_model_id,
  'leverage_based',
  'Hat diagonal threshold = 3p/n',
  'Compounds with leverage > threshold are considered outside the model domain'
FROM qsar_model_registry
WHERE model_code = 'esol_linear_regression'
ON CONFLICT DO NOTHING;

-- ------------------------------------------
-- 5) QSAR PREDICTION FOR CAFFEINE (QPRF-LIKE)
-- ------------------------------------------

WITH caf_ids AS (
  SELECT chemical_identity_id FROM tmp_caf_identity
),
esol_model AS (
  SELECT qsar_model_id
  FROM qsar_model_registry
  WHERE model_code = 'esol_linear_regression'
)
INSERT INTO qsar_prediction_registry (
  chemical_identity_id,
  qsar_model_id,
  predicted_value_num,
  predicted_value_text,
  predicted_unit,
  predicted_scale,
  prediction_confidence_text,
  ad_result_text,
  qprf_status,
  source_context_text
)
SELECT
  caf_ids.chemical_identity_id,
  esol_model.qsar_model_id,
  -2.1,      -- مثال LogS متنبأ به
  NULL,
  NULL,
  'LogS',
  'Prediction within calibration domain; moderate confidence (illustrative)',
  'inside_domain',
  'draft',
  'Internal ESOL-like example run for caffeine'
FROM caf_ids, esol_model
ON CONFLICT (chemical_identity_id, qsar_model_id)
DO UPDATE
  SET predicted_value_num = EXCLUDED.predicted_value_num;

-- ------------------------------------------
-- 6) ENDPOINT SUMMARY & REGULATORY TRACE (OHT / IUCLID-LIKE)
-- ------------------------------------------

WITH caf_ids AS (
  SELECT chemical_identity_id FROM tmp_caf_identity
),
caf_summary AS (
  INSERT INTO endpoint_summary_registry (
    chemical_identity_id,
    endpoint_code,
    summary_type,
    summary_conclusion_text,
    key_study_reference_text,
    weight_of_evidence_text,
    reliability_text,
    oht_template_code,
    iuclid_section_text,
    framework_code
  )
  SELECT
    chemical_identity_id,
    'aqueous_solubility',
    'weight_of_evidence',
    'Caffeine shows moderate aqueous solubility around LogS -2 at ambient conditions (illustrative).',
    'AqSolDB curated record(s); ESOL-like model support (illustrative).',
    'Measured aqueous solubility data from AqSolDB supported by QSAR prediction within applicability domain (illustrative).',
    'key_supporting_studies_and_QSAR',
    'OHT-XXX-placeholder',
    'IUCLID Section 4 - Physicochemical properties',
    'oecd_oht'
  FROM caf_ids
  ON CONFLICT DO NOTHING
  RETURNING endpoint_summary_id, chemical_identity_id
),
caf_summary_fallback AS (
  -- في حالة وجود summary سابق، نستخدمه
  SELECT
    es.endpoint_summary_id,
    es.chemical_identity_id
  FROM endpoint_summary_registry es
  JOIN caf_ids ON es.chemical_identity_id = caf_ids.chemical_identity_id
  WHERE es.endpoint_code = 'aqueous_solubility'
  LIMIT 1
)
INSERT INTO regulatory_submission_trace_registry (
  chemical_identity_id,
  endpoint_summary_id,
  qsar_prediction_id,
  framework_code,
  dossier_context_text,
  iuclid_document_type_text,
  trace_status
)
SELECT
  COALESCE(caf_summary.chemical_identity_id, caf_summary_fallback.chemical_identity_id),
  COALESCE(caf_summary.endpoint_summary_id, caf_summary_fallback.endpoint_summary_id),
  qp.qsar_prediction_id,
  'iuclid_context',
  'Internal illustrative dossier for solubility endpoint integration (caffeine example).',
  'endpoint_summary_with_supporting_study_record_and_QSAR',
  'draft'
FROM qsar_prediction_registry qp
JOIN caf_ids ON qp.chemical_identity_id = caf_ids.chemical_identity_id
JOIN qsar_model_registry qm ON qp.qsar_model_id = qm.qsar_model_id
LEFT JOIN caf_summary ON TRUE
LEFT JOIN caf_summary_fallback ON caf_summary.endpoint_summary_id IS NULL
WHERE qm.model_code = 'esol_linear_regression'
ON CONFLICT DO NOTHING;

COMMIT;
