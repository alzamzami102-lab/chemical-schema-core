-- ==========================================
-- EXTENSION: ADVANCED EXPERIMENTAL ENDPOINTS
-- Toxicological, environmental fate, exposure
-- ==========================================
-- Depends on:
--   core_schema_identity_physchem_solubility.sql
-- Target DB: PostgreSQL
-- ==========================================

-- الهدف:
-- توسيع experimental_endpoint_registry بقاموس تصنيفي
-- يغطي مجموعات endpoints الرئيسية كما في OECD OHT / IUCLID:
--   - Physicochemical (جزء منها موجود)
--   - Toxicological
--   - Environmental fate and behaviour
--   - Exposure / use
-- مع الحفاظ على endpoint_registry كجدول مركزي. [web:898][web:901][web:904]

-- ------------------------------------------
-- 1) ENDPOINT FAMILY DICTIONARY
-- ------------------------------------------

CREATE TABLE IF NOT EXISTS experimental_endpoint_family_dictionary (
  endpoint_family_code      TEXT PRIMARY KEY,   -- e.g. 'physchem', 'toxicological', 'environmental_fate', 'exposure'
  endpoint_family_label     TEXT NOT NULL,
  description_text          TEXT,
  oht_group_reference_text  TEXT,              -- e.g. 'OHT physico-chemical properties', 'OHT toxicological'
  iuclid_section_reference_text TEXT,          -- e.g. 'IUCLID Section 4', 'Section 7', ...
  created_at                TIMESTAMPTZ DEFAULT now()
);

-- ------------------------------------------
-- 2) ENDPOINT CATEGORY DICTIONARY
-- ------------------------------------------
-- فئات فرعية داخل كل family: مثل 'acute_toxicity', 'mutagenicity', 'biodegradation', ...

CREATE TABLE IF NOT EXISTS experimental_endpoint_category_dictionary (
  endpoint_category_code    TEXT PRIMARY KEY,   -- e.g. 'acute_toxicity', 'mutagenicity', 'biodegradation_ready'
  endpoint_category_label   TEXT NOT NULL,
  endpoint_family_code      TEXT NOT NULL
    REFERENCES experimental_endpoint_family_dictionary(endpoint_family_code)
    ON DELETE RESTRICT,
  description_text          TEXT,
  typical_oht_template_text TEXT,              -- e.g. 'OHT 401 acute oral toxicity'
  iuclid_section_reference_text TEXT,
  created_at                TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_endpoint_category_family
  ON experimental_endpoint_category_dictionary(endpoint_family_code);

-- ------------------------------------------
-- 3) EXTENDED METADATA ON experimental_endpoint_registry
-- ------------------------------------------
-- إضافة حقول اختيارية، مع عدم كسر الجدول القائم.

ALTER TABLE experimental_endpoint_registry
  ADD COLUMN IF NOT EXISTS endpoint_category_code TEXT,
  ADD COLUMN IF NOT EXISTS guidance_reference_text TEXT,  -- e.g. OECD TG reference
  ADD COLUMN IF NOT EXISTS iuclid_field_reference_text TEXT; -- specific field/code if needed

-- ربط category إن استخدم
-- (لا نضيف FOREIGN KEY صارم هنا لتجنّب مشاكل legacy، لكن يمكن إضافته لاحقًا)
-- يمكن تفعيل الربط هكذا لو رغبت:
-- ALTER TABLE experimental_endpoint_registry
--   ADD CONSTRAINT fk_endpoint_category
--   FOREIGN KEY (endpoint_category_code)
--   REFERENCES experimental_endpoint_category_dictionary(endpoint_category_code);

-- ------------------------------------------
-- 4) SEED VALUES FOR FAMILIES
-- ------------------------------------------
-- هذه القائمة مستوحاة من تنظيم IUCLID/OHT إلى أقسام physchem/tox/env/exposure. [web:898][web:901][web:904]

INSERT INTO experimental_endpoint_family_dictionary (
  endpoint_family_code,
  endpoint_family_label,
  description_text,
  oht_group_reference_text,
  iuclid_section_reference_text
) VALUES
  ('physchem', 'Physicochemical properties',
   'Physicochemical endpoints such as solubility, partition coefficient, vapour pressure, etc.',
   'OHT physico-chemical properties',
   'IUCLID Section 4'),
  ('toxicological', 'Toxicological properties',
   'Human and mammalian toxicology endpoints (acute, repeated dose, sensitisation, mutagenicity, etc.).',
   'OHT toxicological studies',
   'IUCLID Section 7'),
  ('environmental_fate', 'Environmental fate and behaviour',
   'Endpoints related to degradation, bioaccumulation, distribution, and behaviour in the environment.',
   'OHT environmental fate and behaviour',
   'IUCLID Section 5'),
  ('ecotoxicological', 'Ecotoxicological properties',
   'Endpoints on effects in aquatic and terrestrial organisms.',
   'OHT ecotoxicological studies',
   'IUCLID Section 6'),
  ('exposure', 'Exposure and uses',
   'Endpoints describing uses, exposure scenarios, and measured exposure levels.',
   'OHT exposure-related information',
   'IUCLID Section 3 and exposure-related formats')
ON CONFLICT (endpoint_family_code) DO NOTHING;

-- ------------------------------------------
-- 5) SEED VALUES FOR KEY TOX / ENV / EXPOSURE CATEGORIES
-- ------------------------------------------

INSERT INTO experimental_endpoint_category_dictionary (
  endpoint_category_code,
  endpoint_category_label,
  endpoint_family_code,
  description_text,
  typical_oht_template_text,
  iuclid_section_reference_text
) VALUES
  -- Toxicological
  ('acute_toxicity', 'Acute toxicity',
   'toxicological',
   'Acute toxicity via various routes (oral, dermal, inhalation).',
   'e.g. OECD TG 401, 402, 403; OHT acute toxicity templates',
   'IUCLID Section 7.2'),
  ('skin_irritation_corrosion', 'Skin irritation/corrosion',
   'toxicological',
   'Skin corrosion and irritation studies.',
   'OECD TG 404, 430, 431; OHT skin irritation/corrosion',
   'IUCLID Section 7.3'),
  ('eye_irritation', 'Serious eye damage/eye irritation',
   'toxicological',
   'Eye irritation and serious eye damage studies.',
   'OECD TG 405, 437, 438; OHT eye irritation',
   'IUCLID Section 7.3'),
  ('skin_sensitisation', 'Skin sensitisation',
   'toxicological',
   'Skin sensitisation endpoints including in vivo and in vitro assays.',
   'OECD TG 406, 429, 442; OHT sensitisation',
   'IUCLID Section 7.4'),
  ('mutagenicity_genotoxicity', 'Mutagenicity/Genotoxicity',
   'toxicological',
   'In vitro and in vivo genotoxicity endpoints.',
   'OECD TG 471, 473, 474, 475, etc.; OHT genotoxicity',
   'IUCLID Section 7.6'),
  ('repeated_dose_toxicity', 'Repeated dose toxicity',
   'toxicological',
   'Sub-acute / sub-chronic repeated dose toxicity studies.',
   'OECD TG 407, 408, 409; OHT repeated dose',
   'IUCLID Section 7.5'),
  ('reproductive_developmental', 'Reproductive and developmental toxicity',
   'toxicological',
   'Fertility and developmental toxicity endpoints.',
   'OECD TG 414, 421, 422, 443; OHT reproductive/developmental',
   'IUCLID Section 7.8'),

  -- Environmental fate
  ('biodegradation_ready', 'Ready biodegradability',
   'environmental_fate',
   'Ready biodegradability in aquatic systems.',
   'OECD TG 301 series; OHT ready biodegradation',
   'IUCLID Section 5.2'),
  ('biodegradation_inherent', 'Inherent biodegradability',
   'environmental_fate',
   'Inherent, screening biodegradability.',
   'OECD TG 302; OHT inherent biodegradation',
   'IUCLID Section 5.2'),
  ('bioaccumulation', 'Bioaccumulation',
   'environmental_fate',
   'Bioconcentration and bioaccumulation in aquatic organisms.',
   'OECD TG 305; OHT bioaccumulation',
   'IUCLID Section 5.3'),
  ('adsorption_desorption', 'Adsorption/desorption',
   'environmental_fate',
   'Adsorption/desorption behaviour in soils and sediments.',
   'OECD TG 106; OHT adsorption/desorption',
   'IUCLID Section 5.4'),

  -- Ecotoxicological
  ('acute_aquatic_toxicity', 'Acute aquatic toxicity',
   'ecotoxicological',
   'Acute toxicity to fish, invertebrates, algae, etc.',
   'OECD TG 201, 202, 203; OHT acute aquatic toxicity',
   'IUCLID Section 6.1'),
  ('chronic_aquatic_toxicity', 'Chronic aquatic toxicity',
   'ecotoxicological',
   'Chronic toxicity in aquatic organisms.',
   'OECD TG 210, 211, 212; OHT chronic aquatic toxicity',
   'IUCLID Section 6.1'),

  -- Exposure / use
  ('worker_exposure', 'Worker exposure',
   'exposure',
   'Measured or estimated exposure of workers.',
   'OHT exposure scenarios / worker exposure',
   'IUCLID Section 3 / exposure formats'),
  ('consumer_exposure', 'Consumer exposure',
   'exposure',
   'Measured or estimated exposure of consumers.',
   'OHT exposure scenarios / consumer exposure',
   'IUCLID Section 3 / exposure formats'),
  ('environmental_exposure', 'Environmental exposure',
   'exposure',
   'Measured or modelled environmental concentrations (air, water, soil).',
   'OHT exposure and environmental release',
   'IUCLID Section 3 / Section 6/7 exposure-related fields')
ON CONFLICT (endpoint_category_code) DO NOTHING;

-- ------------------------------------------
-- 6) OPTIONAL: LINK EXISTING ENDPOINTS TO FAMILIES/CATEGORIES
-- ------------------------------------------
-- مثال: ربط aqueous_solubility بالـ family physchem
UPDATE experimental_endpoint_registry
SET endpoint_family = 'physchem',
    endpoint_category_code = NULL
WHERE endpoint_code = 'aqueous_solubility'
  AND (endpoint_family IS NULL OR endpoint_family = 'physicochemical_experimental');

-- يمكن لاحقاً إضافة endpoints أخرى وربطها بـ endpoint_category_code المناسب
-- مثل LC50 fish في acute_aquatic_toxicity, إلخ.

-- ==========================================
-- END OF EXTENSION
-- ==========================================
