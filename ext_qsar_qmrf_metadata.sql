-- ==========================================
-- EXTENSION: QSAR / QSPR QMRF-LIKE METADATA
-- ==========================================
-- Depends on:
--   core_schema_predictions_regulatory.sql
-- Target DB: PostgreSQL
-- ==========================================

-- الهدف:
-- تمثيل ميتاداتا النموذج كما في بنية QMRF (sections)،
-- بحيث تكون منفصلة عن سجل النموذج الأساسي لكنها مرتبطة به
-- عبر qsar_model_id.

-- ------------------------------------------
-- 1) QMRF SECTION METADATA (HIGH-LEVEL)
-- ------------------------------------------

CREATE TABLE IF NOT EXISTS qsar_qmrf_section_metadata (
  qmrf_section_id          BIGSERIAL PRIMARY KEY,
  qsar_model_id            BIGINT NOT NULL
    REFERENCES qsar_model_registry(qsar_model_id)
    ON DELETE CASCADE,
  section_code             TEXT NOT NULL,  -- e.g. '1.1', '2.4', '3.2', '4.1', ...
  section_title            TEXT NOT NULL,  -- text label of section (e.g. 'Endpoint', 'Algorithm')
  section_text             TEXT,           -- primary content
  section_language_code    TEXT,           -- e.g. 'en'
  is_regulatory_critical   BOOLEAN DEFAULT FALSE,
  created_at               TIMESTAMPTZ DEFAULT now(),
  UNIQUE (qsar_model_id, section_code)
);

CREATE INDEX IF NOT EXISTS idx_qmrf_section_model
  ON qsar_qmrf_section_metadata(qsar_model_id);

-- هذا الجدول يسمح بتوثيق أقسام QMRF الرئيسية:
-- 1. IDENTIFICATION
-- 2. GENERAL INFORMATION
-- 3. DEFINING THE ENDPOINT
-- 4. DEFINING THE ALGORITHM
-- 5. APPLICABILITY DOMAIN
-- 6. INTERNAL VALIDATION
-- 7. EXTERNAL VALIDATION
-- 8. MECHANISTIC INTERPRETATION
-- إلخ، مع section_code مثل '3.1', '5.2'، وفق الوثائق الرسمية. [web:895][web:897][web:900]

-- ------------------------------------------
-- 2) STRUCTURED KEY ELEMENTS (QAF PRINCIPLES)
-- ------------------------------------------
-- هذا الجدول يكثّف مبادئ OECD QAF في عناصر قابلة للاستعلام
-- (defined endpoint, defined algorithm, defined domain, goodness-of-fit, robustness, predictivity, mechanistic interpretation, uncertainty). [web:893][web:895][web:903]

CREATE TABLE IF NOT EXISTS qsar_qaf_key_element_registry (
  qaf_element_id           BIGSERIAL PRIMARY KEY,
  qsar_model_id            BIGINT NOT NULL
    REFERENCES qsar_model_registry(qsar_model_id)
    ON DELETE CASCADE,
  qaf_element_code         TEXT NOT NULL,  -- e.g. 'defined_endpoint', 'defined_algorithm', ...
  qaf_element_label        TEXT NOT NULL,
  assessment_result_text   TEXT,           -- e.g. 'fully_documented', 'partially_documented'
  uncertainty_level_text   TEXT,           -- e.g. 'low', 'medium', 'high'
  assessor_note            TEXT,
  created_at               TIMESTAMPTZ DEFAULT now(),
  UNIQUE (qsar_model_id, qaf_element_code)
);

CREATE INDEX IF NOT EXISTS idx_qaf_element_model
  ON qsar_qaf_key_element_registry(qsar_model_id);

-- أمثلة qaf_element_code المقترحة:
-- 'defined_endpoint'
-- 'defined_algorithm'
-- 'defined_domain'
-- 'goodness_of_fit'
-- 'robustness'
-- 'predictivity'
-- 'mechanistic_interpretation'
-- 'uncertainty_analysis'

-- ------------------------------------------
-- 3) TRAINING / TEST / EXTERNAL DATASET LINKS
-- ------------------------------------------
-- الهدف: توثيق datasets المستخدمة في التدريب/الاختبار/التحقق الخارجي،
-- وربطها بالـ experimental_dataset_registry عندما يكون ذلك منطقيًا
-- (مثل AqSolDB أو ESOL أو غيرها). [web:642][web:653][web:897]

CREATE TABLE IF NOT EXISTS qsar_dataset_link_registry (
  qsar_dataset_link_id     BIGSERIAL PRIMARY KEY,
  qsar_model_id            BIGINT NOT NULL
    REFERENCES qsar_model_registry(qsar_model_id)
    ON DELETE CASCADE,
  link_role_code           TEXT NOT NULL,  -- 'training', 'test', 'validation_external', 'calibration', ...
  link_role_label          TEXT NOT NULL,
  experimental_dataset_id  BIGINT
    REFERENCES experimental_dataset_registry(experimental_dataset_id)
    ON DELETE SET NULL,
  dataset_name_text        TEXT,
  dataset_scope_text       TEXT,
  dataset_reference_text   TEXT,           -- citation or URL
  record_selection_text    TEXT,           -- description of how records were selected
  created_at               TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_qsar_dataset_link_model
  ON qsar_dataset_link_registry(qsar_model_id);

-- ------------------------------------------
-- 4) HYPERPARAMETERS / ALGORITHM SETTINGS
-- ------------------------------------------
-- الهدف: تمثيل إعدادات الخوارزمية (hyperparameters) بشكل مرن،
-- بحيث يتماشى مع نماذج مختلفة (linear regression, RF, SVM, NN...). [web:896][web:903]

CREATE TABLE IF NOT EXISTS qsar_hyperparameter_registry (
  hyperparameter_id        BIGSERIAL PRIMARY KEY,
  qsar_model_id            BIGINT NOT NULL
    REFERENCES qsar_model_registry(qsar_model_id)
    ON DELETE CASCADE,
  parameter_name           TEXT NOT NULL,   -- e.g. 'n_estimators', 'max_depth'
  parameter_value_text     TEXT NOT NULL,   -- stored as text for flexibility
  parameter_scope_text     TEXT,            -- 'training', 'final_model', 'grid_search'
  created_at               TIMESTAMPTZ DEFAULT now(),
  UNIQUE (qsar_model_id, parameter_name, parameter_scope_text)
);

CREATE INDEX IF NOT EXISTS idx_qsar_hyperparam_model
  ON qsar_hyperparameter_registry(qsar_model_id);

-- ------------------------------------------
-- 5) SEED EXAMPLE FOR ESOL-LIKE MODEL (OPTIONAL)
-- ------------------------------------------
-- مثال تعبئة مبدئية لربط نموذج ESOL-like بـ QMRF/QAF metadata

-- ملاحظة: هذه الإدخالات توضيحية وليست بديلًا عن QMRF كامل.

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
  '3.1',
  'Endpoint',
  'Aqueous solubility, typically expressed as LogS, used for environmental fate and exposure assessment (illustrative).',
  'en',
  TRUE
FROM qsar_model_registry
WHERE model_code = 'esol_linear_regression'
ON CONFLICT (qsar_model_id, section_code) DO NOTHING;

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
  '4.1',
  'Explicit algorithm',
  'Linear regression model using simple molecular descriptors (illustrative; full details should be in the QMRF).',
  'en',
  TRUE
FROM qsar_model_registry
WHERE model_code = 'esol_linear_regression'
ON CONFLICT (qsar_model_id, section_code) DO NOTHING;

INSERT INTO qsar_qaf_key_element_registry (
  qsar_model_id,
  qaf_element_code,
  qaf_element_label,
  assessment_result_text,
  uncertainty_level_text,
  assessor_note
)
SELECT
  qsar_model_id,
  'defined_endpoint',
  'Defined endpoint',
  'fully_documented',
  'low',
  'Endpoint is chemically and toxicologically well-defined (illustrative).'
FROM qsar_model_registry
WHERE model_code = 'esol_linear_regression'
ON CONFLICT (qsar_model_id, qaf_element_code) DO NOTHING;

INSERT INTO qsar_qaf_key_element_registry (
  qsar_model_id,
  qaf_element_code,
  qaf_element_label,
  assessment_result_text,
  uncertainty_level_text,
  assessor_note
)
SELECT
  qsar_model_id,
  'defined_domain',
  'Defined applicability domain',
  'partially_documented',
  'medium',
  'Leverage-based applicability domain defined (illustrative); boundary conditions need further documentation.'
FROM qsar_model_registry
WHERE model_code = 'esol_linear_regression'
ON CONFLICT (qsar_model_id, qaf_element_code) DO NOTHING;

INSERT INTO qsar_dataset_link_registry (
  qsar_model_id,
  link_role_code,
  link_role_label,
  experimental_dataset_id,
  dataset_name_text,
  dataset_scope_text,
  dataset_reference_text,
  record_selection_text
)
SELECT
  qm.qsar_model_id,
  'training',
  'Training dataset',
  ed.experimental_dataset_id,
  ed.dataset_name,
  ed.dataset_scope_text,
  ed.source_citation_text,
  'Records selected according to ESOL-like criteria (illustrative).'
FROM qsar_model_registry qm
LEFT JOIN experimental_dataset_registry ed
  ON ed.dataset_code = 'esol_delaney'
WHERE qm.model_code = 'esol_linear_regression'
ON CONFLICT DO NOTHING;
