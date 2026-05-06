# خريطة المجالات (Domain Map) – منصة البيانات الكيميائية

هذه الوثيقة تلخّص المجالات العلمية الرئيسية (حوالي 10–15 مجالًا) وتربط كل مجال
بالسكريبتات والجداول التي تغطيه في قاعدة البيانات.

تم تصميم المجالات بالاستناد إلى مصادر علمية وتنظيمية عالمية، تشمل:
PubChem, InChI, ChEBI, NIST Chemistry WebBook, AqSolDB, Delaney ESOL context,
OECD Harmonised Templates (OHT), OECD QMRF/QPRF/QAF, IUCLID context, FAIR principles.[web:783][web:614][page:0][web:642][web:653][web:898][web:895][web:897][web:904]

---

## 1. مجال الهوية الكيميائية الأساسية (Core Chemical Identity)

**الغرض:** تعريف كل مادة كيميائية بهوية بنيوية ومرجعية موحّدة  
**المراجع:** PubChem + InChI + ChEBI.[web:783][web:899][web:905][web:614]

- السكربتات:
  - `core_schema_identity_physchem_solubility.sql`

- الجداول الأساسية:
  - `chemical_identity_registry`
  - `chemical_identity_synonym_registry`
  - `chemical_identity_xref_registry`
  - `chemical_identity_classification_registry`

- ملاحظات:
  - استخدام `standard_inchikey` كمُعرِّف بنيوي تشغيلي رئيسي (كما في PubChem/InChI).[web:899][web:902][web:905]
  - ربط PubChem CID وChEBI ID كمراجع خارجية قوية.

---

## 2. مجال الهوية البنيوية المتقدّمة (Isomers / Mixtures / Polymers)

**الغرض:** تمثيل العلاقات البنيوية المعقّدة والمخلّطات والبوليمرات  
**المراجع:** InChI / Polymer InChI, PubChem structural relationships.[web:899][web:902][web:905]

- السكربتات:
  - `ext_identity_structural_variants.sql`

- الجداول الأساسية:
  - `chemical_identity_relationship_registry`
  - `mixture_identity_registry`
  - `mixture_component_registry`
  - `polymer_identity_registry`
  - `polymer_repeating_unit_registry`

- أمثلة علاقات:
  - `isomer_of`, `tautomer_of`, `salt_form_of`, `hydrate_form_of`,
    `mixture_component_of`, `polymer_of`, `monomer_unit_of` (كقيم محتملة لـ relationship_type_code).

---

## 3. مجال الخصائص الفيزيائية‑الكيميائية (PhysChem Properties)

**الغرض:** تخزين الخصائص الفيزيائية‑الكيميائية بمصادر موثوقة وقيود واضحة  
**المراجع:** PubChem property tables + NIST Chemistry WebBook.[web:783][page:0]

- السكربتات:
  - `core_schema_identity_physchem_solubility.sql`

- الجداول الأساسية:
  - `physchem_property_dictionary`
  - `physchem_property_registry`
  - `physchem_measurement_context_registry`

- ملاحظات:
  - قاموس الخصائص يحتوي خصائص مثل: `molecular_weight`, `xlogp`, `tpsa`,
    `boiling_point`, `heat_of_fusion`, `henrys_law_constant`.[page:0][web:783]
  - يمكن توثيق سياق القياس (درجة الحرارة، الضغط، الوسط) عبر measurement context.

---

## 4. مجال الذوبانية والمشاهدات التجريبية (Solubility & Experimental Observations)

**الغرض:** تمثيل بيانات مشاهدات مقاسة (خصوصًا الذوبانية المائية)  
**المراجع:** AqSolDB + ESOL + منطق OECD endpoint‑oriented reporting.[web:642][web:653][web:778]

- السكربتات:
  - `core_schema_identity_physchem_solubility.sql`

- الجداول الأساسية:
  - `experimental_endpoint_registry`
  - `experimental_dataset_registry`
  - `experimental_observation_registry`
  - `experimental_dataset_membership`

- ملاحظات:
  - `endpoint_code = 'aqueous_solubility'` مع alignment مفهومي لـ OECD endpoint reporting.[web:778]
  - datasets مرجعية:
    - `aqsoldb` (AqSolDB)
    - `esol_delaney` (ESOL context).[web:642][web:653]
  - الفصل الواضح بين endpoint, dataset, observation.

---

## 5. مجال endpoints التجريبية المتقدّمة (Tox / Env / Exposure)

**الغرض:** تصنيف endpoints في عائلات وفئات متوافقة مع OHT/IUCLID  
**المراجع:** OECD Harmonised Templates, IUCLID sections, TG references.[web:898][web:901][web:904][web:907]

- السكربتات:
  - `ext_experimental_endpoints_tox_env_exposure.sql`

- الجداول الأساسية:
  - `experimental_endpoint_family_dictionary`
  - `experimental_endpoint_category_dictionary`
  - توسيع `experimental_endpoint_registry` بحقول:
    - `endpoint_family`
    - `endpoint_category_code`
    - `guidance_reference_text`
    - `iuclid_field_reference_text`

- أمثلة families:
  - `physchem`, `toxicological`, `environmental_fate`, `ecotoxicological`, `exposure`.[web:898][web:904]
- أمثلة categories:
  - `acute_toxicity`, `skin_sensitisation`, `mutagenicity_genotoxicity`,
    `biodegradation_ready`, `bioaccumulation`, `acute_aquatic_toxicity`,
    `worker_exposure`, `consumer_exposure`, `environmental_exposure`.[web:898][web:901][web:904]

---

## 6. مجال النماذج (QSAR/QSPR Model Core)

**الغرض:** تعريف النماذج الكمية، فصلها عن التنبؤات والتحقق  
**المراجع:** OECD QMRF, JRC QSAR Model Database, OECD Principles for QSAR Validation.[web:895][web:897][web:900][web:903]

- السكربتات:
  - `core_schema_predictions_regulatory.sql`

- الجداول الأساسية:
  - `qsar_model_registry`
  - `qsar_model_validation_registry`
  - `qsar_applicability_domain_registry`
  - `qsar_prediction_registry`

- ملاحظات:
  - فصل واضح بين:
    - تعريف النموذج (metadata)
    - مقاييس التحقق (validation)
    - مجال التطبيق (AD)
    - التنبؤات لكل مادة (QPRF‑like).[web:895][web:897]
  - مثال seed: `esol_linear_regression` كنموذج ESOL‑like للذوبانية.[web:653][web:196]

---

## 7. مجال ميتاداتا النماذج (QMRF / QAF Metadata)

**الغرض:** تمثيل الأقسام النصية والمبادئ السبعة لـ QAF بشكل منظّم  
**المراجع:** OECD (Q)SAR Assessment Framework, QMRF structure.[web:893][web:895][web:897][web:903]

- السكربتات:
  - `ext_qsar_qmrf_metadata.sql`

- الجداول الأساسية:
  - `qsar_qmrf_section_metadata`
  - `qsar_qaf_key_element_registry`
  - `qsar_dataset_link_registry`
  - `qsar_hyperparameter_registry`

- ملاحظات:
  - `qsar_qmrf_section_metadata` يسمح بتوثيق أقسام QMRF (1–8) بنصوص قابلة للاستعلام.
  - `qsar_qaf_key_element_registry` يجسد مبادئ QAF مثل:
    - defined endpoint, defined algorithm, defined domain,
      goodness-of-fit, robustness, predictivity, mechanistic interpretation, uncertainty.[web:893][web:903]
  - `qsar_dataset_link_registry` يربط النموذج بـ datasets مثل ESOL/AqSolDB.[web:642][web:653][web:897]

---

## 8. مجال الحوكمة التنظيمية (Regulatory Governance)

**الغرض:** ربط البيانات العلمية بالأطر والنُظم التنظيمية (OHT, QAF, IUCLID)  
**المراجع:** OECD Harmonised Templates, QAF, IUCLID implementation context.[web:898][web:895][web:904][web:907]

- السكربتات:
  - `core_schema_predictions_regulatory.sql`

- الجداول الأساسية:
  - `regulatory_framework_registry`
  - `endpoint_summary_registry`
  - `model_assessment_registry`
  - `regulatory_submission_trace_registry`

- ملاحظات:
  - `regulatory_framework_registry` يعرّف الأطر:
    - `oecd_oht`, `oecd_qaf`, `iuclid_context`.[web:898][web:895][web:904]
  - `endpoint_summary_registry` تمثيل لـ Endpoint Summaries المنسقة (IUCLID Section 4–7).[web:901][web:904]
  - `model_assessment_registry` يربط تقييم النماذج بمبادئ QAF.[web:895][web:893]
  - `regulatory_submission_trace_registry` يربط المواد، summaries، التنبؤات، والسياق التنظيمي (IUCLID dossier).[web:898][web:904][web:907]

---

## 9. مجال الأمثلة التكاملية (Integrated Examples)

**الغرض:** توفير حالات اختبار تُظهر الربط بين المجالات  
**المراجع:** نفس المراجع المستخدمة في الحقول (PubChem, AqSolDB, ESOL, OECD).[web:899][web:642][web:653][web:895]

- السكربتات:
  - `example_caffeine_integration.sql`

- ما يغطيه:
  - إدخال هوية الكافيين (PubChem CID, InChIKey, ChEBI).[web:899][web:905][web:614]
  - إدخال خصائص PhysChem مختارة.[page:0][web:783]
  - إدخال observation للذوبانية المائية (AqSolDB‑like) وربطها بـ dataset.[web:642]
  - تنبؤ ESOL‑like، مع validation وAD وQAF/QMRF‑like metadata.[web:653][web:895][web:893]
  - Endpoint summary + regulatory trace وفق OHT/IUCLID context.[web:898][web:901][web:904]

---

## 10. كيف تُطوَّر خريطة المجالات لاحقًا؟

هذه الخريطة تمثل **المستوى العلوي** (High‑level domains).  
عند الحاجة، يمكن إضافة سكربتات امتداد جديدة مثل:

- `ext_exposure_scenarios_detailed.sql`  
- `ext_study_design_details_tg_specific.sql`  
- `ext_nanomaterial_specific_endpoints.sql`

مع الحفاظ على المبادئ التالية:

1. كل سكربت امتداد يعتمد على الـ core ولا يكسره.  
2. كل مجال جديد يُربط بمراجع علمية أو تنظيمية واضحة (TG، OHT، QAF، IUCLID).  
3. الحفاظ على فصل واضح بين:
   - الهوية،
   - البيانات التجريبية،
   - النماذج والتنبؤات،
   - الحوكمة التنظيمية.

بهذا يمكن للعاملين في المكاتب العلمية أو الشركات الرقمية أن يفهموا بسرعة **أين تقع بياناتهم** داخل المنظومة، وما المرجع العلمي/التنظيمي الذي يستند إليه كل جزء.
