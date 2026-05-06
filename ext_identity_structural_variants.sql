-- ==========================================
-- EXTENSION: ADVANCED CHEMICAL IDENTITY
-- Structural variants, mixtures, polymers
-- ==========================================
-- Depends on:
--   core_schema_identity_physchem_solubility.sql
-- Target DB: PostgreSQL
-- ==========================================

-- ------------------------------------------
-- 1) GENERIC RELATIONSHIPS BETWEEN IDENTITIES
-- ------------------------------------------
-- الهدف: تمثيل العلاقات البنيوية والتنظيمية بين المواد
-- مثل: isomer, tautomer, salt, hydrate, metabolite, parent/child, component

CREATE TABLE IF NOT EXISTS chemical_identity_relationship_registry (
  identity_relationship_id    BIGSERIAL PRIMARY KEY,
  subject_identity_id         BIGINT NOT NULL
    REFERENCES chemical_identity_registry(chemical_identity_id)
    ON DELETE CASCADE,
  object_identity_id          BIGINT NOT NULL
    REFERENCES chemical_identity_registry(chemical_identity_id)
    ON DELETE CASCADE,
  relationship_type_code      TEXT NOT NULL,
  relationship_type_label     TEXT NOT NULL,
  relationship_source_text    TEXT,         -- PubChem, InChI, regulatory_list, internal_mapping
  relationship_scope_text     TEXT,         -- structural, compositional, metabolic, regulatory, ...
  created_at                  TIMESTAMPTZ DEFAULT now(),
  UNIQUE (subject_identity_id, object_identity_id, relationship_type_code)
);

CREATE INDEX IF NOT EXISTS idx_identity_rel_subject
  ON chemical_identity_relationship_registry(subject_identity_id);

CREATE INDEX IF NOT EXISTS idx_identity_rel_object
  ON chemical_identity_relationship_registry(object_identity_id);

-- أمثلة علاقة (يمكن إدراجها يدوياً أو عبر ETL):
-- relationship_type_code / relationship_type_label
-- 'isomer_of' / 'isomer of'
-- 'tautomer_of' / 'tautomer of'
-- 'salt_form_of' / 'salt form of'
-- 'hydrate_form_of' / 'hydrate form of'
-- 'metabolite_of' / 'metabolite of'
-- 'parent_of' / 'parent of'
-- 'mixture_component_of' / 'mixture component of'
-- 'polymer_of' / 'polymer of'
-- 'monomer_unit_of' / 'monomer unit of'
-- إلخ

-- ------------------------------------------
-- 2) MIXTURES AND FORMULATIONS (INCLUDING UVCBs)
-- ------------------------------------------
-- الهدف: تمثيل المواد التي ليست "جزيء واحد" فقط
-- بل خلائط (mixtures)، توليفات (formulations)، أو UVCBs

CREATE TABLE IF NOT EXISTS mixture_identity_registry (
  mixture_identity_id         BIGSERIAL PRIMARY KEY,
  chemical_identity_id        BIGINT NOT NULL
    REFERENCES chemical_identity_registry(chemical_identity_id)
    ON DELETE CASCADE,
  mixture_type_code           TEXT,      -- mixture, formulation, UVCB, reaction_mass, ...
  mixture_type_label          TEXT,
  description_text            TEXT,
  regulatory_category_text    TEXT,      -- e.g. UVCB category, mixture category
  created_at                  TIMESTAMPTZ DEFAULT now(),
  UNIQUE (chemical_identity_id)
);

-- مكوّنات الخليط (n..n بين mixture identity و component identities)
CREATE TABLE IF NOT EXISTS mixture_component_registry (
  mixture_component_id        BIGSERIAL PRIMARY KEY,
  mixture_identity_id         BIGINT NOT NULL
    REFERENCES mixture_identity_registry(mixture_identity_id)
    ON DELETE CASCADE,
  component_identity_id       BIGINT NOT NULL
    REFERENCES chemical_identity_registry(chemical_identity_id)
    ON DELETE CASCADE,
  typical_fraction_low        NUMERIC,   -- optional, e.g. 0.10
  typical_fraction_high       NUMERIC,   -- optional, e.g. 0.30
  typical_fraction_unit       TEXT,      -- 'mass_fraction', 'mole_fraction', 'percent', ...
  is_key_component            BOOLEAN DEFAULT FALSE,
  component_role_text         TEXT,      -- e.g. active, solvent, stabiliser
  created_at                  TIMESTAMPTZ DEFAULT now(),
  UNIQUE (mixture_identity_id, component_identity_id)
);

CREATE INDEX IF NOT EXISTS idx_mixture_component_mixture
  ON mixture_component_registry(mixture_identity_id);

CREATE INDEX IF NOT EXISTS idx_mixture_component_component
  ON mixture_component_registry(component_identity_id);

-- ------------------------------------------
-- 3) POLYMERS AND REPEATING UNITS
-- ------------------------------------------
-- الهدف: تقريب تمثيل البوليمرات من ممارسات InChI/Polymer InChI
-- ومنطق PubChem، مع الحفاظ على مرونة تنظيمية.

CREATE TABLE IF NOT EXISTS polymer_identity_registry (
  polymer_identity_id         BIGSERIAL PRIMARY KEY,
  chemical_identity_id        BIGINT NOT NULL
    REFERENCES chemical_identity_registry(chemical_identity_id)
    ON DELETE CASCADE,
  polymer_class_text          TEXT,      -- e.g. homopolymer, copolymer, graft, block
  average_molecular_weight_num NUMERIC,  -- optional, if known
  average_molecular_weight_unit TEXT,    -- e.g. 'g/mol'
  distribution_type_text      TEXT,      -- e.g. 'Mn', 'Mw', 'Mz', polydispersity
  structural_description_text TEXT,      -- textual description (where InChI is insufficient)
  regulatory_polymer_flag_text TEXT,     -- e.g. 'polymer_of_low_concern'
  created_at                  TIMESTAMPTZ DEFAULT now(),
  UNIQUE (chemical_identity_id)
);

-- وحدات التكرار (repeating units) المرتبطة بالبوليمر
CREATE TABLE IF NOT EXISTS polymer_repeating_unit_registry (
  polymer_repeating_unit_id   BIGSERIAL PRIMARY KEY,
  polymer_identity_id         BIGINT NOT NULL
    REFERENCES polymer_identity_registry(polymer_identity_id)
    ON DELETE CASCADE,
  unit_identity_id            BIGINT
    REFERENCES chemical_identity_registry(chemical_identity_id)
    ON DELETE SET NULL,
  unit_label_text             TEXT,      -- e.g. 'A', 'B', 'C'
  fraction_low                NUMERIC,   -- mol% أو mass% حدود دنيا
  fraction_high               NUMERIC,   -- حدود عليا
  fraction_unit               TEXT,      -- 'mol_percent', 'mass_percent', ...
  position_text               TEXT,      -- e.g. backbone, side_chain
  created_at                  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_polymer_unit_polymer
  ON polymer_repeating_unit_registry(polymer_identity_id);

-- ------------------------------------------
-- 4) OPTIONAL SEED VALUES FOR RELATIONSHIP TYPES (AS REFERENCE)
-- ------------------------------------------
-- يمكن التعبئة بهذه القيم عبر ETL أو يدوياً، حسب الحاجة التنظيمية.
-- هنا نضعها فقط كتعليقات مرجعية، لأن تمثيلها كقاموس مستقل اختياري.

-- مثال على قاموس علاقات (اختياري):
-- CREATE TABLE IF NOT EXISTS identity_relationship_type_dictionary (
--   relationship_type_code   TEXT PRIMARY KEY,
--   relationship_type_label  TEXT NOT NULL,
--   description_text         TEXT
-- );
--
-- INSERT INTO identity_relationship_type_dictionary
--   (relationship_type_code, relationship_type_label, description_text)
-- VALUES
--   ('isomer_of',           'isomer of',            'Same composition, different structure'),
--   ('tautomer_of',         'tautomer of',          'Tautomeric forms'),
--   ('salt_form_of',        'salt form of',         'Salt form of a parent structure'),
--   ('hydrate_form_of',     'hydrate form of',      'Hydrate form of a parent structure'),
--   ('metabolite_of',       'metabolite of',        'Metabolic transformation product'),
--   ('parent_of',           'parent of',            'Parent substance for a derivative'),
--   ('mixture_component_of','mixture component of', 'Component of a mixture/formulation'),
--   ('polymer_of',          'polymer of',           'Polymer derived from monomer(s)'),
--   ('monomer_unit_of',     'monomer unit of',      'Monomeric unit within a polymer')
-- ON CONFLICT (relationship_type_code) DO NOTHING;

-- ==========================================
-- END OF EXTENSION
-- ==========================================
