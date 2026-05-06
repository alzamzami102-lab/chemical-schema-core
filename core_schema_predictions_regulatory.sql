-- ==========================================
-- CORE SCHEMA: PREDICTIONS (QSAR) + REGULATORY GOVERNANCE
-- ==========================================
-- Designed for PostgreSQL
-- Built conceptually in line with OECD QMRF/QPRF/QAF and OHT/IUCLID context
-- ==========================================

-- =========================
-- 4) QSAR / QSPR MODELS & PREDICTIONS
-- =========================

CREATE TABLE IF NOT EXISTS qsar_model_registry (
  qsar_model_id                BIGSERIAL PRIMARY KEY,
  model_code                   TEXT NOT NULL UNIQUE,
  model_name                   TEXT NOT NULL,
  endpoint_code                TEXT NOT NULL, -- e.g. 'aqueous_solubility'
  model_type                   TEXT,          -- e.g. 'QSAR', 'QSPR'
  algorithm_family             TEXT,          -- e.g. 'linear_regression', 'random_forest'
  descriptor_space_text        TEXT,          -- description of descriptors used
  training_dataset_text        TEXT,          -- description of dataset used
  response_variable_text       TEXT,          -- description of response variable
  qmrf_version_text            TEXT,          -- QMRF version or reference
  qmrf_status                  TEXT,          -- e.g. 'candidate', 'draft', 'final'
  mechanistic_interpretation_text TEXT,       -- notes on mechanistic interpretation
  model_owner_text             TEXT,          -- internal or external owner
  source_name                  TEXT,          -- publication or system reference
  source_ref_text              TEXT,          -- citation or link
  created_at                   TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS qsar_model_validation_registry (
  validation_id                BIGSERIAL PRIMARY KEY,
  qsar_model_id                BIGINT NOT NULL
    REFERENCES qsar_model_registry(qsar_model_id)
    ON DELETE CASCADE,
  validation_scope             TEXT NOT NULL,  -- e.g. 'internal', 'external', 'cross_validation'
  metric_name                  TEXT NOT NULL,  -- e.g. 'R2', 'RMSE', 'Q2', 'accuracy'
  metric_value                 NUMERIC,
  metric_text                  TEXT,
  validation_note              TEXT,
  created_at                   TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS qsar_applicability_domain_registry (
  applicability_domain_id      BIGSERIAL PRIMARY KEY,
  qsar_model_id                BIGINT NOT NULL
    REFERENCES qsar_model_registry(qsar_model_id)
    ON DELETE CASCADE,
  ad_method_text               TEXT NOT NULL,  -- e.g. 'distance-based', 'leverage', 'probability density'
  ad_threshold_text            TEXT,
  ad_interpretation_text       TEXT,
  created_at                   TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS qsar_prediction_registry (
  qsar_prediction_id           BIGSERIAL PRIMARY KEY,
  chemical_identity_id         BIGINT NOT NULL
    REFERENCES chemical_identity_registry(chemical_identity_id)
    ON DELETE CASCADE,
  qsar_model_id                BIGINT NOT NULL
    REFERENCES qsar_model_registry(qsar_model_id)
    ON DELETE CASCADE,
  predicted_value_num          NUMERIC,
  predicted_value_text         TEXT,
  predicted_unit               TEXT,
  predicted_scale              TEXT,
  prediction_confidence_text   TEXT,        -- e.g. CI, probability, qualitative confidence
  ad_result_text               TEXT,        -- e.g. 'inside_domain', 'outside_domain'
  qprf_status                  TEXT,        -- e.g. 'draft', 'final'
  source_context_text          TEXT,        -- e.g. 'internal prediction pipeline run 2026-05'
  created_at                   TIMESTAMPTZ DEFAULT now(),
  UNIQUE (chemical_identity_id, qsar_model_id)
);

-- Indexes for QSAR domain

CREATE INDEX IF NOT EXISTS idx_qsar_model_endpoint
  ON qsar_model_registry(endpoint_code);

CREATE INDEX IF NOT EXISTS idx_qsar_validation_model
  ON qsar_model_validation_registry(qsar_model_id);

CREATE INDEX IF NOT EXISTS idx_qsar_ad_model
  ON qsar_applicability_domain_registry(qsar_model_id);

CREATE INDEX IF NOT EXISTS idx_qsar_prediction_identity
  ON qsar_prediction_registry(chemical_identity_id);

CREATE INDEX IF NOT EXISTS idx_qsar_prediction_model
  ON qsar_prediction_registry(qsar_model_id);

-- Seed example for an ESOL-like model (conceptual, not a full QMRF)

INSERT INTO qsar_model_registry (
  model_code,
  model_name,
  endpoint_code,
  model_type,
  algorithm_family,
  descriptor_space_text,
  training_dataset_text,
  response_variable_text,
  qmrf_version_text,
  qmrf_status,
  mechanistic_interpretation_text,
  model_owner_text,
  source_name,
  source_ref_text
) VALUES (
  'esol_linear_regression',
  'Delaney ESOL Linear Regression',
  'aqueous_solubility',
  'QSAR/QSPR',
  'linear_regression',
  'Simple molecular properties and structural descriptors',
  'Measured aqueous solubility dataset used in Delaney 2004',
  'Aqueous solubility (often LogS)',
  'QMRF-compatible conceptual seed',
  'candidate',
  'Mechanistic interpretation is partial and descriptor-linked',
  'project_internal_seed',
  'Delaney 2004 / OECD-aligned internal mapping',
  'J Chem Inf Comput Sci. 2004; OECD QMRF/QPRF alignment'
)
ON CONFLICT (model_code) DO NOTHING;

-- =========================
-- 5) REGULATORY GOVERNANCE (OECD OHT/QAF, IUCLID CONTEXT)
-- =========================

CREATE TABLE IF NOT EXISTS regulatory_framework_registry (
  regulatory_framework_id  BIGSERIAL PRIMARY KEY,
  framework_code           TEXT NOT NULL UNIQUE,   -- e.g. 'oecd_oht', 'oecd_qaf', 'iuclid_context'
  framework_name           TEXT NOT NULL,
  jurisdiction_text        TEXT,
  framework_scope_text     TEXT,
  source_name              TEXT,
  source_ref_text          TEXT,
  created_at               TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS endpoint_summary_registry (
  endpoint_summary_id      BIGSERIAL PRIMARY KEY,
  chemical_identity_id     BIGINT NOT NULL
    REFERENCES chemical_identity_registry(chemical_identity_id)
    ON DELETE CASCADE,
  endpoint_code            TEXT NOT NULL,   -- same endpoint_code as used in experimental/QSAR domains
  summary_type             TEXT NOT NULL,   -- e.g. 'key_study_summary', 'weight_of_evidence'
  summary_conclusion_text  TEXT,
  key_study_reference_text TEXT,
  weight_of_evidence_text  TEXT,
  reliability_text         TEXT,
  oht_template_code        TEXT,           -- e.g. OECD OHT template code
  iuclid_section_text      TEXT,           -- e.g. IUCLID section
  framework_code           TEXT,           -- reference to regulatory_framework_registry.framework_code
  created_at               TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS model_assessment_registry (
  model_assessment_id      BIGSERIAL PRIMARY KEY,
  qsar_model_id            BIGINT NOT NULL
    REFERENCES qsar_model_registry(qsar_model_id)
    ON DELETE CASCADE,
  framework_code           TEXT NOT NULL,  -- e.g. 'oecd_qaf'
  assessment_scope         TEXT NOT NULL,  -- e.g. 'model', 'prediction', 'multiple_predictions'
  assessment_element_text  TEXT NOT NULL,  -- e.g. 'defined_endpoint', 'defined_algorithm', 'uncertainty'
  assessment_result_text   TEXT,           -- e.g. 'acceptable', 'not acceptable', 'partially documented'
  uncertainty_level_text   TEXT,           -- e.g. 'low', 'medium', 'high'
  assessor_note            TEXT,
  created_at               TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS regulatory_submission_trace_registry (
  submission_trace_id      BIGSERIAL PRIMARY KEY,
  chemical_identity_id     BIGINT
    REFERENCES chemical_identity_registry(chemical_identity_id)
    ON DELETE CASCADE,
  endpoint_summary_id      BIGINT
    REFERENCES endpoint_summary_registry(endpoint_summary_id)
    ON DELETE CASCADE,
  qsar_prediction_id       BIGINT
    REFERENCES qsar_prediction_registry(qsar_prediction_id)
    ON DELETE CASCADE,
  framework_code           TEXT,
  dossier_context_text     TEXT,      -- description of dossier or submission context
  iuclid_document_type_text TEXT,     -- e.g. 'study record', 'endpoint summary'
  trace_status             TEXT,      -- e.g. 'draft', 'submitted', 'accepted'
  created_at               TIMESTAMPTZ DEFAULT now()
);

-- Indexes for regulatory domain

CREATE INDEX IF NOT EXISTS idx_endpoint_summary_identity
  ON endpoint_summary_registry(chemical_identity_id);

CREATE INDEX IF NOT EXISTS idx_endpoint_summary_endpoint
  ON endpoint_summary_registry(endpoint_code);

CREATE INDEX IF NOT EXISTS idx_model_assessment_model
  ON model_assessment_registry(qsar_model_id);

CREATE INDEX IF NOT EXISTS idx_submission_trace_identity
  ON regulatory_submission_trace_registry(chemical_identity_id);

CREATE INDEX IF NOT EXISTS idx_submission_trace_prediction
  ON regulatory_submission_trace_registry(qsar_prediction_id);

-- Seed frameworks aligned with OECD OHT, QAF, and IUCLID context

INSERT INTO regulatory_framework_registry (
  framework_code,
  framework_name,
  jurisdiction_text,
  framework_scope_text,
  source_name,
  source_ref_text
) VALUES
(
  'oecd_oht',
  'OECD Harmonised Templates',
  'OECD / multi-jurisdictional',
  'Standard endpoint-oriented data templates for chemical information exchange',
  'OECD',
  'Harmonised Templates portal'
),
(
  'oecd_qaf',
  'OECD (Q)SAR Assessment Framework',
  'OECD / regulatory assessment',
  'Framework for assessing (Q)SAR models and predictions in regulatory contexts',
  'OECD',
  'QAF 2023'
),
(
  'iuclid_context',
  'IUCLID-aligned dossier context',
  'Multi-jurisdictional implementation context',
  'Dossier management and structured submission context aligned with OECD formats',
  'OECD / ECHA',
  'IUCLID implementation context'
)
ON CONFLICT (framework_code) DO NOTHING;
