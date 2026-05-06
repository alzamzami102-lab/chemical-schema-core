-- ==========================================
-- EXTENSION: CHEMICAL FAMILY DICTIONARY
-- Functional / structural / descriptive families
-- ==========================================
-- Depends on:
--   core_schema_identity_physchem_solubility.sql
-- Target DB: PostgreSQL
-- ==========================================

-- ------------------------------------------
-- 1) جدول قاموس العائلات الكيميائية
-- ------------------------------------------
-- يمثل أنواع العائلات (سلاسل بنيوية، مجموعات وظيفية، أبعاد ChEBI...)

CREATE TABLE IF NOT EXISTS chemical_family_dictionary (
  chemical_family_code       TEXT PRIMARY KEY,      -- معرف قصير ثابت، مثل 'alkane', 'alcohol', ...
  chemical_family_label      TEXT NOT NULL,        -- اسم العائلة (مجالي/وصفي)
  family_dimension_code      TEXT NOT NULL,        -- 'structural', 'functional_group', 'homologous_series', 'chebi_ontology', 'application', 'role'
  family_dimension_label     TEXT NOT NULL,        -- وصف البعد (مثلاً 'Structural class', 'Functional group')
  description_text           TEXT,                 -- وصف موجز للعائلة
  typical_pattern_text       TEXT,                 -- وصف نمطي، مثل الصيغة العامة أو المجموعة الوظيفية (R-OH, R-COOH, ...)
  reference_source_text      TEXT,                 -- مثل 'IUPAC functional groups; ChEBI ontology'
  external_ontology_ref_text TEXT,                 -- مثل معرف فئة في ChEBI أو مصطلح تصنيف في PubChem
  created_at                 TIMESTAMPTZ DEFAULT now()
);

-- ------------------------------------------
-- 2) جدول ربط الهوية بالعائلات
-- ------------------------------------------
-- يسمح بإسناد أكثر من عائلة لكل مادة (مثلاً: aromatic + amine)

CREATE TABLE IF NOT EXISTS chemical_identity_family_membership (
  identity_family_membership_id BIGSERIAL PRIMARY KEY,
  chemical_identity_id          BIGINT NOT NULL
    REFERENCES chemical_identity_registry(chemical_identity_id)
    ON DELETE CASCADE,
  chemical_family_code          TEXT NOT NULL
    REFERENCES chemical_family_dictionary(chemical_family_code)
    ON DELETE RESTRICT,
  membership_source_text        TEXT,              -- 'rule_based_assignment', 'ChEBI_mapping', 'manual_curation'
  membership_confidence_text    TEXT,              -- 'high', 'medium', 'low'
  created_at                    TIMESTAMPTZ DEFAULT now(),
  UNIQUE (chemical_identity_id, chemical_family_code)
);

CREATE INDEX IF NOT EXISTS idx_identity_family_identity
  ON chemical_identity_family_membership(chemical_identity_id);

CREATE INDEX IF NOT EXISTS idx_identity_family_family
  ON chemical_identity_family_membership(chemical_family_code);

-- ------------------------------------------
-- 3) بذور لعائلات بنيوية ووظيفية أساسية + أبعاد ChEBI عامة
-- ------------------------------------------
-- مستندة إلى تصنيف المجموعات الوظيفية في المراجع التعليمية وإلى
-- بنية ChEBI الهيكلية (structure) وأدوارها ووظائفها. [web:909][web:916][web:913]

INSERT INTO chemical_family_dictionary (
  chemical_family_code,
  chemical_family_label,
  family_dimension_code,
  family_dimension_label,
  description_text,
  typical_pattern_text,
  reference_source_text,
  external_ontology_ref_text
) VALUES
  -- *** بُعد: Structural / Homologous Series ***
  ('alkane',
   'Alkanes',
   'homologous_series',
   'Homologous series (structural)',
   'Saturated acyclic hydrocarbons containing only C–C and C–H single bonds.',
   'C_nH_(2n+2); only single C–C bonds',
   'IUPAC organic classification; ChEBI molecular structure ontology (e.g. "alkane" class).',
   'e.g. CHEBI:18310 (alkane)'),
  ('alkene',
   'Alkenes',
   'homologous_series',
   'Homologous series (structural)',
   'Acyclic hydrocarbons containing at least one C=C double bond.',
   'C=C functional unit; general formula C_nH_(2n)',
   'IUPAC organic classification; functional group = C=C.',
   'e.g. CHEBI:32878 (alkene)'),
  ('alkyne',
   'Alkynes',
   'homologous_series',
   'Homologous series (structural)',
   'Acyclic hydrocarbons containing at least one C≡C triple bond.',
   'C≡C functional unit; general formula C_nH_(2n-2)',
   'IUPAC organic classification; functional group = C≡C.',
   'e.g. CHEBI:33659 (alkyne)'),
  ('aromatic_hydrocarbon',
   'Aromatic hydrocarbons',
   'structural',
   'Structural class',
   'Hydrocarbons containing at least one aromatic ring.',
   'Aryl ring system; conjugated π-system',
   'IUPAC aromaticity; ChEBI aromatic hydrocarbon classes.',
   'e.g. aromatic hydrocarbon classes in ChEBI'),

  -- *** بُعد: Functional group-based families ***
  ('alcohol',
   'Alcohols',
   'functional_group',
   'Functional group family',
   'Organic compounds containing a hydroxyl (-OH) group bonded to a saturated carbon atom.',
   'R–OH (hydroxyl)',
   'IUPAC functional groups; standard organic chemistry texts.',
   'ChEBI alcohol classes'),
  ('phenol',
   'Phenols',
   'functional_group',
   'Functional group family',
   'Aromatic compounds bearing a hydroxyl group directly attached to an aromatic ring.',
   'Ar–OH',
   'IUPAC functional groups; phenolic classes.',
   'ChEBI phenol classes'),
  ('ether',
   'Ethers',
   'functional_group',
   'Functional group family',
   'Compounds with an oxygen atom bonded to two carbon atoms.',
   'R–O–R''',
   'IUPAC functional groups; ethers.',
   'ChEBI ether class (e.g. CHEBI:22333)'),
  ('aldehyde',
   'Aldehydes',
   'functional_group',
   'Functional group family',
   'Compounds containing a terminal carbonyl group (R-CHO).',
   'R–CHO (terminal C=O)',
   'IUPAC functional groups; carbonyl compounds.',
   'ChEBI aldehyde classes'),
  ('ketone',
   'Ketones',
   'functional_group',
   'Functional group family',
   'Compounds containing an internal carbonyl group (R-CO-R).',
   'R–CO–R'' (internal C=O)',
   'IUPAC functional groups; carbonyl compounds.',
   'ChEBI ketone classes'),
  ('carboxylic_acid',
   'Carboxylic acids',
   'functional_group',
   'Functional group family',
   'Compounds with a carboxyl group (-COOH).',
   'R–COOH',
   'IUPAC carboxylic acids; high-priority group in nomenclature.',
   'ChEBI carboxylic acid classes'),
  ('ester',
   'Esters',
   'functional_group',
   'Functional group family',
   'Compounds with a carboxylate ester functional group.',
   'R–COO–R''',
   'IUPAC functional groups; esters.',
   'ChEBI ester classes'),
  ('amide',
   'Amides',
   'functional_group',
   'Functional group family',
   'Compounds with a carbonyl attached to nitrogen (R–CONH2 or derivatives).',
   'R–CONH2 (or substituted)',
   'IUPAC functional groups; amides.',
   'ChEBI amide classes'),
  ('amine',
   'Amines',
   'Amines',
   'functional_group',
   'Functional group family',
   'Compounds containing an amino group (-NH2, -NHR, -NR2).',
   'R–NH2, R–NHR, R–NR2',
   'IUPAC functional groups; amines.',
   'ChEBI amine classes'),
  ('nitrile',
   'Nitriles',
   'functional_group',
   'Functional group family',
   'Compounds containing a cyano group (-C≡N).',
   'R–C≡N',
   'IUPAC functional groups; nitriles.',
   'ChEBI nitrile classes'),

  -- *** بُعد: ChEBI ontology-based families (structure/role/application) ***
  ('chebi_structural_class',
   'ChEBI structural class (generic)',
   'chebi_ontology',
   'Ontology: molecular structure',
   'Generic placeholder representing mapping to ChEBI structural ontology nodes.',
   NULL,
   'ChEBI molecular structure ontology.',
   'ChEBI structural ontology nodes'),
  ('chebi_biological_role',
   'ChEBI biological role class (generic)',
   'chebi_ontology',
   'Ontology: biological role',
   'Generic placeholder representing mapping to ChEBI biological role ontology nodes (e.g. antibiotic, coenzyme).',
   NULL,
   'ChEBI biological role ontology.',
   'Biological role nodes in ChEBI'),
  ('chebi_application',
   'ChEBI application class (generic)',
   'chebi_ontology',
   'Ontology: application',
   'Generic placeholder representing mapping to ChEBI application ontology nodes (e.g. pesticide, drug).',
   NULL,
   'ChEBI application ontology.',
   'Application nodes in ChEBI')
ON CONFLICT (chemical_family_code) DO NOTHING;

-- ==========================================
-- END OF EXTENSION
-- ==========================================
