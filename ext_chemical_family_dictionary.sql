-- ==========================================
-- EXTENSION: CHEMICAL FAMILY DICTIONARY
-- Functional / structural / descriptive families
-- ==========================================
-- Depends on:
--   core_schema_identity_physchem_solubility.sql
-- Target DB: PostgreSQL
-- ==========================================
--
-- المصادر العلمية المعتمدة:
-- 1. RDKit Functional Group Hierarchy (Landrum/Novartis 2006/2021)
-- 2. ChEBI Ontology (Hastings et al. 2016 / EBI)
-- 3. IUPAC Nomenclature / organic chemistry texts
-- 4. PubChem Classification Browser (NIH/NCBI)
-- 5. HMDB (Human Metabolome Database)
-- ==========================================

-- ------------------------------------------
-- PART A: الجداول الأساسية
-- ------------------------------------------

CREATE TABLE IF NOT EXISTS chemical_family_dimension_dictionary (
  family_dimension_code   TEXT PRIMARY KEY,
  family_dimension_label  TEXT NOT NULL,
  description_text        TEXT,
  reference_source_text   TEXT,
  created_at              TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS chemical_family_dictionary (
  chemical_family_code        TEXT PRIMARY KEY,
  chemical_family_label       TEXT NOT NULL,
  family_dimension_code       TEXT NOT NULL
    REFERENCES chemical_family_dimension_dictionary(family_dimension_code)
    ON DELETE RESTRICT,
  parent_family_code          TEXT,
  description_text            TEXT,
  typical_pattern_text        TEXT,
  smarts_pattern_text         TEXT,
  reference_source_text       TEXT,
  external_ontology_ref_text  TEXT,
  created_at                  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chem_family_dimension
  ON chemical_family_dictionary(family_dimension_code);

CREATE INDEX IF NOT EXISTS idx_chem_family_parent
  ON chemical_family_dictionary(parent_family_code);

CREATE TABLE IF NOT EXISTS chemical_identity_family_membership (
  identity_family_membership_id BIGSERIAL PRIMARY KEY,
  chemical_identity_id          BIGINT NOT NULL
    REFERENCES chemical_identity_registry(chemical_identity_id)
    ON DELETE CASCADE,
  chemical_family_code          TEXT NOT NULL
    REFERENCES chemical_family_dictionary(chemical_family_code)
    ON DELETE RESTRICT,
  membership_source_text        TEXT,
  membership_confidence_text    TEXT,
  created_at                    TIMESTAMPTZ DEFAULT now(),
  UNIQUE (chemical_identity_id, chemical_family_code)
);

CREATE INDEX IF NOT EXISTS idx_identity_family_identity
  ON chemical_identity_family_membership(chemical_identity_id);

CREATE INDEX IF NOT EXISTS idx_identity_family_family
  ON chemical_identity_family_membership(chemical_family_code);

-- ------------------------------------------
-- PART B: بذور أبعاد التصنيف
-- ------------------------------------------

INSERT INTO chemical_family_dimension_dictionary (
  family_dimension_code,
  family_dimension_label,
  description_text,
  reference_source_text
) VALUES
  ('homologous_series',
   'Homologous series (structural)',
   'Families of compounds sharing the same general formula and differing by repeating units.',
   'IUPAC organic classification; standard organic chemistry texts'),
  ('structural',
   'Structural class',
   'Broader structural classification (aromatic, cyclic, heterocyclic) not strictly a homologous series.',
   'IUPAC organic classification; ChEBI molecular structure ontology'),
  ('functional_group',
   'Functional group family',
   'Families defined by specific functional groups (R-OH, R-COOH, etc.) as in RDKit FGH and IUPAC.',
   'RDKit Functional_Group_Hierarchy.txt (Landrum/Novartis); IUPAC functional groups'),
  ('chebi_role',
   'ChEBI biological or chemical role',
   'Families derived from ChEBI role ontology nodes (biological, chemical, application roles).',
   'ChEBI ontology (Hastings et al.; EBI)'),
  ('chebi_application',
   'ChEBI application class',
   'Families derived from ChEBI application ontology nodes (drug, pesticide, food additive).',
   'ChEBI ontology (Hastings et al.; EBI)'),
  ('physicochemical_class',
   'Physicochemical class',
   'Families based on physicochemical properties (electrolyte, surfactant, volatile compound).',
   'IUPAC; physicochemical classification literature')
ON CONFLICT (family_dimension_code) DO NOTHING;

-- ------------------------------------------
-- PART C: بذور العائلات الرئيسية
-- ------------------------------------------

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
) VALUES

-- *** C.1: السلاسل المتجانسة والعائلات البنيوية ***

  ('alkane',
   'Alkanes',
   'homologous_series', NULL,
   'Saturated acyclic hydrocarbons; only C-C and C-H single bonds.',
   'C_nH_(2n+2)',
   NULL,
   'IUPAC organic classification; ChEBI molecular structure ontology',
   'CHEBI:18310'),

  ('alkene',
   'Alkenes',
   'homologous_series', NULL,
   'Acyclic hydrocarbons containing at least one C=C double bond.',
   'C_nH_(2n); C=C',
   NULL,
   'IUPAC organic classification; ChEBI molecular structure ontology',
   'CHEBI:32878'),

  ('alkyne',
   'Alkynes',
   'homologous_series', NULL,
   'Acyclic hydrocarbons with at least one triple bond C≡C.',
   'C_nH_(2n-2); C≡C',
   '[C;$(C#[CH])]',
   'IUPAC organic classification; RDKit FGH (TerminalAlkyne)',
   'CHEBI:33659'),

  ('cycloalkane',
   'Cycloalkanes',
   'structural', NULL,
   'Saturated cyclic hydrocarbons.',
   'Cyclic C-C ring; no double or triple bonds',
   NULL,
   'IUPAC organic classification',
   NULL),

  ('aromatic_hydrocarbon',
   'Aromatic hydrocarbons',
   'structural', NULL,
   'Hydrocarbons containing at least one aromatic ring (conjugated pi-system satisfying Hückel rule).',
   'Aryl ring; conjugated pi-system',
   'c1ccccc1',
   'IUPAC aromaticity criteria; ChEBI aromatic hydrocarbon classes',
   NULL),

  ('heterocyclic_compound',
   'Heterocyclic compounds',
   'structural', NULL,
   'Cyclic compounds where one or more ring atoms are heteroatoms (N, O, S, etc.).',
   'Ring with at least one heteroatom',
   '[r;!c;!C]',
   'IUPAC nomenclature; ChEBI heterocyclic compound classes',
   'CHEBI:27171'),

  ('purine',
   'Purines',
   'structural', 'heterocyclic_compound',
   'Heterocyclic aromatic compounds with pyrimidine ring fused to imidazole ring.',
   'Bicyclic N-containing heterocycle',
   NULL,
   'IUPAC; ChEBI purine class',
   'CHEBI:26401'),

  ('xanthine',
   'Xanthines',
   'structural', 'purine',
   'Purine derivatives with a ketone group at C2 and C6; parent of caffeine and theophylline.',
   'Purine-2,6-dione skeleton',
   NULL,
   'ChEBI xanthine class; HMDB classification',
   'CHEBI:17712'),

-- *** C.2: المجموعات الوظيفية (Functional Groups) ***
-- SMARTS مستخرجة من RDKit Functional_Group_Hierarchy.txt

  ('alcohol',
   'Alcohols',
   'functional_group', NULL,
   'Compounds with hydroxyl group (-OH) on saturated carbon.',
   'R-OH',
   '[O;H1;$(O-!@[#6;!$(C=!@[O,N,S])])]',
   'RDKit Functional_Group_Hierarchy.txt (Alcohol); IUPAC',
   'ChEBI alcohol classes'),

  ('alcohol_aliphatic',
   'Aliphatic alcohols',
   'functional_group', 'alcohol',
   'Hydroxyl group on aliphatic (non-aromatic) carbon.',
   'R(aliphatic)-OH',
   '[O;H1;$(O-!@[C;!$(C=!@[O,N,S])])]',
   'RDKit Functional_Group_Hierarchy.txt (Alcohol.Aliphatic)',
   NULL),

  ('alcohol_aromatic',
   'Aromatic alcohols',
   'functional_group', 'alcohol',
   'Hydroxyl group on aromatic carbon (phenols).',
   'Ar-OH',
   '[O;H1;$(O-!@c)]',
   'RDKit Functional_Group_Hierarchy.txt (Alcohol.Aromatic)',
   'CHEBI:15882'),

  ('aldehyde',
   'Aldehydes',
   'functional_group', NULL,
   'Terminal carbonyl group (-CHO).',
   'R-CHO',
   '[CH;D2;!$(C-[!#6;!#1])]=O',
   'RDKit Functional_Group_Hierarchy.txt (Aldehyde); IUPAC',
   'ChEBI aldehyde classes'),

  ('aldehyde_aliphatic',
   'Aliphatic aldehydes',
   'functional_group', 'aldehyde',
   'Aldehyde attached to aliphatic carbon.',
   'R(aliphatic)-CHO',
   '[CH;D2;$(C-!@C)](=O)',
   'RDKit Functional_Group_Hierarchy.txt (Aldehyde.Aliphatic)',
   NULL),

  ('aldehyde_aromatic',
   'Aromatic aldehydes',
   'functional_group', 'aldehyde',
   'Aldehyde attached to aromatic ring.',
   'Ar-CHO',
   '[CH;D2;$(C-!@[a])](=O)',
   'RDKit Functional_Group_Hierarchy.txt (Aldehyde.Aromatic)',
   NULL),

  ('carboxylic_acid',
   'Carboxylic acids',
   'functional_group', NULL,
   'Compounds with a -COOH group; highest-priority functional group in IUPAC nomenclature.',
   'R-COOH',
   'C(=O)[O;H,-]',
   'RDKit Functional_Group_Hierarchy.txt (CarboxylicAcid); IUPAC',
   'ChEBI carboxylic acid classes'),

  ('carboxylic_acid_aliphatic',
   'Aliphatic carboxylic acids',
   'functional_group', 'carboxylic_acid',
   'Carboxylic acid attached to aliphatic carbon.',
   'R(aliphatic)-COOH',
   '[$(C-!@[A;!O])](=O)([O;H,-])',
   'RDKit Functional_Group_Hierarchy.txt (CarboxylicAcid.Aliphatic)',
   NULL),

  ('carboxylic_acid_aromatic',
   'Aromatic carboxylic acids',
   'functional_group', 'carboxylic_acid',
   'Carboxylic acid attached to aromatic ring.',
   'Ar-COOH',
   '[$(C-!@[a])](=O)([O;H,-])',
   'RDKit Functional_Group_Hierarchy.txt (CarboxylicAcid.Aromatic)',
   NULL),

  ('alpha_amino_acid',
   'Alpha-amino acids',
   'functional_group', 'carboxylic_acid',
   'Amino acids with amino group on alpha carbon adjacent to carboxyl group.',
   'NH2-CH(R)-COOH',
   '[$(C-[C;!$(C=[!#6])]-[N;!H0;!$(N-[!#6;!#1]);!$(N-C=[O,N,S])])](=O)([O;H,-])',
   'RDKit Functional_Group_Hierarchy.txt (CarboxylicAcid.AlphaAmino)',
   NULL),

  ('amine',
   'Amines',
   'functional_group', NULL,
   'Compounds with amino group (-NH2, -NHR, -NR2).',
   'R-NH2 / R-NHR / R-NR2',
   '[N;$(N-[#6]);!$(N-[!#6;!#1]);!$(N-C=[O,N,S])]',
   'RDKit Functional_Group_Hierarchy.txt (Amine); IUPAC',
   'ChEBI amine classes'),

  ('amine_primary',
   'Primary amines',
   'functional_group', 'amine',
   'Amine with two hydrogen atoms on nitrogen.',
   'R-NH2',
   '[N;H2;D1;$(N-!@[#6]);!$(N-C=[O,N,S])]',
   'RDKit Functional_Group_Hierarchy.txt (Amine.Primary)',
   NULL),

  ('amine_secondary',
   'Secondary amines',
   'functional_group', 'amine',
   'Amine with one hydrogen atom on nitrogen.',
   'R-NH-R''',
   '[N;H1;D2;$(N(-[#6])-[#6]);!$(N-C=[O,N,S])]',
   'RDKit Functional_Group_Hierarchy.txt (Amine.Secondary)',
   NULL),

  ('amine_tertiary',
   'Tertiary amines',
   'functional_group', 'amine',
   'Amine with no hydrogen atoms on nitrogen.',
   'R-N(R'')(R'''')',
   '[N;H0;D3;$(N(-[#6])(-[#6])-[#6]);!$(N-C=[O,N,S])]',
   'RDKit Functional_Group_Hierarchy.txt (Amine.Tertiary)',
   NULL),

  ('amine_aromatic',
   'Aromatic amines',
   'functional_group', 'amine',
   'Amine attached to aromatic ring.',
   'Ar-NH2 or Ar-NHR',
   '[N;$(N-c);!$(N-[!#6;!#1]);!$(N-C=[O,N,S])]',
   'RDKit Functional_Group_Hierarchy.txt (Amine.Aromatic)',
   NULL),

  ('amide',
   'Amides',
   'functional_group', NULL,
   'Compounds with carbonyl group attached to nitrogen (-CONH2 or substituted).',
   'R-CONH2',
   NULL,
   'IUPAC functional groups; amides',
   'ChEBI amide classes'),

  ('ester',
   'Esters',
   'functional_group', NULL,
   'Compounds with carboxylate ester group (-COO-).',
   'R-COO-R''',
   NULL,
   'IUPAC functional groups; esters',
   'ChEBI ester classes'),

  ('ether',
   'Ethers',
   'functional_group', NULL,
   'Compounds with oxygen atom bonded to two carbon groups.',
   'R-O-R''',
   NULL,
   'IUPAC functional groups; ethers',
   'CHEBI:22333'),

  ('ketone',
   'Ketones',
   'functional_group', NULL,
   'Internal carbonyl group (R-CO-R).',
   'R-CO-R''',
   NULL,
   'IUPAC functional groups; carbonyl compounds',
   'ChEBI ketone classes'),

  ('nitrile',
   'Nitriles',
   'functional_group', NULL,
   'Compounds with cyano group (-C≡N).',
   'R-C≡N',
   NULL,
   'IUPAC functional groups; nitriles',
   'ChEBI nitrile classes'),

  ('halogen_compound',
   'Halogen compounds',
   'functional_group', NULL,
   'Compounds with one or more halogen atoms (F, Cl, Br, I) bonded to carbon.',
   'R-X (X = F, Cl, Br, I)',
   '[$([F,Cl,Br,I]-!@[#6]);!$([F,Cl,Br,I]-!@C-!@[F,Cl,Br,I]);!$([F,Cl,Br,I]-[C,S](=[O,S,N]))]',
   'RDKit Functional_Group_Hierarchy.txt (Halogen); IUPAC',
   NULL),

  ('halogen_aliphatic',
   'Aliphatic halogen compounds',
   'functional_group', 'halogen_compound',
   'Halogen bonded to aliphatic carbon.',
   'R(aliphatic)-X',
   '[$([F,Cl,Br,I]-!@C);!$([F,Cl,Br,I]-!@C-!@[F,Cl,Br,I])]',
   'RDKit Functional_Group_Hierarchy.txt (Halogen.Aliphatic)',
   NULL),

  ('halogen_aromatic',
   'Aromatic halogen compounds',
   'functional_group', 'halogen_compound',
   'Halogen bonded to aromatic carbon.',
   'Ar-X',
   '[F,Cl,Br,I;$(*-!@c)]',
   'RDKit Functional_Group_Hierarchy.txt (Halogen.Aromatic)',
   NULL),

  ('nitro_compound',
   'Nitro compounds',
   'functional_group', NULL,
   'Compounds containing a nitro group (-NO2).',
   'R-NO2',
   '[N;H0;$(N-[#6]);D3](=[O;D1])~[O;D1]',
   'RDKit Functional_Group_Hierarchy.txt (Nitro); IUPAC',
   NULL),

  ('acid_chloride',
   'Acid chlorides (acyl chlorides)',
   'functional_group', NULL,
   'Compounds with -COCl group.',
   'R-COCl',
   'C(=O)Cl',
   'RDKit Functional_Group_Hierarchy.txt (AcidChloride)',
   NULL),

  ('sulfonyl_chloride',
   'Sulfonyl chlorides',
   'functional_group', NULL,
   'Compounds with -SO2Cl group.',
   'R-SO2Cl',
   '[$(S-!@[#6])](=O)(=O)(Cl)',
   'RDKit Functional_Group_Hierarchy.txt (SulfonylChloride)',
   NULL),

  ('boronic_acid',
   'Boronic acids',
   'functional_group', NULL,
   'Compounds containing a boronic acid group -B(OH)2.',
   'R-B(OH)2',
   '[$(B-!@[#6])](O)(O)',
   'RDKit Functional_Group_Hierarchy.txt (BoronicAcid)',
   NULL),

  ('isocyanate',
   'Isocyanates',
   'functional_group', NULL,
   'Compounds containing an isocyanate group -N=C=O.',
   'R-N=C=O',
   '[$(N-!@[#6])](=!@C=!@O)',
   'RDKit Functional_Group_Hierarchy.txt (Isocyanate)',
   NULL),

  ('azide',
   'Azides',
   'functional_group', NULL,
   'Compounds containing an azide group -N3.',
   'R-N=N+=N-',
   '[N;H0;$(N-[#6]);D2]=[N;D2]=[N;D1]',
   'RDKit Functional_Group_Hierarchy.txt (Azide)',
   NULL),

-- *** C.3: أدوار ChEBI (biological / chemical roles) ***

  ('alkaloid',
   'Alkaloids',
   'chebi_role', NULL,
   'Plant or animal metabolites containing nitrogen in a ring; typically pharmacologically active.',
   NULL, NULL,
   'ChEBI biological role ontology',
   'CHEBI:22315'),

  ('purine_alkaloid',
   'Purine alkaloids',
   'chebi_role', 'alkaloid',
   'Alkaloids based on the purine skeleton (caffeine, theophylline, theobromine).',
   NULL, NULL,
   'ChEBI biological role ontology; HMDB classification',
   'CHEBI:26385'),

  ('plant_metabolite',
   'Plant metabolites',
   'chebi_role', NULL,
   'Compounds produced by plant metabolism.',
   NULL, NULL,
   'ChEBI biological role ontology',
   'CHEBI:76924'),

  ('xenobiotic',
   'Xenobiotics',
   'chebi_role', NULL,
   'Compounds foreign to a living organism or absent in nature.',
   NULL, NULL,
   'ChEBI chemical role ontology',
   'CHEBI:35703'),

  ('environmental_contaminant',
   'Environmental contaminants',
   'chebi_role', NULL,
   'Substances introduced to the environment with undesired effects.',
   NULL, NULL,
   'ChEBI chemical role ontology',
   'CHEBI:78298'),

  ('mutagen',
   'Mutagens',
   'chebi_role', NULL,
   'Agents that increase mutation frequency above background, typically by interacting with DNA.',
   NULL, NULL,
   'ChEBI biological role ontology',
   'CHEBI:25435'),

  ('psychotropic_drug',
   'Psychotropic drugs',
   'chebi_role', NULL,
   'Drugs that affect mental state, perception, mood, or behavior.',
   NULL, NULL,
   'ChEBI biological role ontology',
   'CHEBI:35471'),

-- *** C.4: تطبيقات ChEBI (application classes) ***

  ('food_additive',
   'Food additives',
   'chebi_application', NULL,
   'Substances added to food to preserve or enhance flavour and/or appearance.',
   NULL, NULL,
   'ChEBI application ontology',
   'CHEBI:64047'),

  ('pharmaceutical',
   'Pharmaceuticals',
   'chebi_application', NULL,
   'Compounds with approved or investigated therapeutic applications.',
   NULL, NULL,
   'ChEBI application ontology',
   NULL),

  ('pesticide',
   'Pesticides',
   'chebi_application', NULL,
   'Compounds used to prevent, destroy, or control pests.',
   NULL, NULL,
   'ChEBI application ontology',
   NULL),

-- *** C.5: فئات فيزيائية‑كيميائية ***

  ('electrolyte',
   'Electrolytes',
   'physicochemical_class', NULL,
   'Compounds that ionize in solution to produce electrically conducting solutions.',
   NULL, NULL,
   'IUPAC; physicochemical classification',
   NULL),

  ('surfactant',
   'Surfactants',
   'physicochemical_class', NULL,
   'Amphiphilic compounds that reduce surface or interfacial tension.',
   NULL, NULL,
   'IUPAC; physicochemical classification',
   NULL),

  ('volatile_compound',
   'Volatile compounds',
   'physicochemical_class', NULL,
   'Compounds with high vapour pressure at ambient conditions (VOCs and related).',
   NULL, NULL,
   'IUPAC; EPA VOC classification',
   NULL)

ON CONFLICT (chemical_family_code) DO NOTHING;


-- ------------------------------------------
-- PART D: مثال ربط الكافيين بعائلاته
-- ------------------------------------------
-- فعّل هذا القسم بعد تشغيل example_caffeine_integration.sql
-- بإزالة علامات التعليق -- من DO $$ إلى END $$;

-- DO $$
-- DECLARE caf_id BIGINT;
-- BEGIN
--   SELECT chemical_identity_id INTO caf_id
--   FROM chemical_identity_registry
--   WHERE standard_inchikey = 'RYYVLZVUVIJVGH-UHFFFAOYSA-N';
--   IF caf_id IS NOT NULL THEN
--     INSERT INTO chemical_identity_family_membership
--       (chemical_identity_id, chemical_family_code, membership_source_text, membership_confidence_text)
--     VALUES
--       (caf_id, 'heterocyclic_compound',    'ChEBI_ontology_mapping',    'high'),
--       (caf_id, 'purine',                   'ChEBI_ontology_mapping',    'high'),
--       (caf_id, 'xanthine',                 'ChEBI_HMDB_mapping',        'high'),
--       (caf_id, 'purine_alkaloid',          'ChEBI_ontology_mapping',    'high'),
--       (caf_id, 'plant_metabolite',         'ChEBI_role_mapping',        'high'),
--       (caf_id, 'psychotropic_drug',        'ChEBI_role_mapping',        'high'),
--       (caf_id, 'food_additive',            'ChEBI_application_mapping', 'high'),
--       (caf_id, 'environmental_contaminant','ChEBI_role_mapping',        'high'),
--       (caf_id, 'amine_tertiary',           'RDKit_SMARTS_rule_based',   'high')
--     ON CONFLICT (chemical_identity_id, chemical_family_code) DO NOTHING;
--   END IF;
-- END $$;

-- ==========================================
-- END OF EXTENSION
-- ==========================================
