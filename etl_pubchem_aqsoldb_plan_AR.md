# خطة ETL أولية – PubChem / ChEBI / AqSolDB / ESOL

## الهدف

تصميم مسار ETL أولي (تصميمي + تشغيلي) لاستيراد مجموعة بيانات صغيرة
من PubChem + ChEBI + AqSolDB (+ ESOL context) إلى قاعدة البيانات، مع الحفاظ على:

- هوية كيميائية موحّدة (InChIKey + PubChem CID + ChEBI ID).[web:783][web:899][web:905][web:614]
- فصل صارم بين:
  - الهوية،
  - الخصائص الفيزيائية‑الكيميائية،
  - المشاهدات التجريبية (observations),
  - التنبؤات (predictions).[web:778][web:895]
- التوافق مع مبادئ FAIR (قابلة للإيجاد، الوصول، التشغيل البيني، وإعادة الاستخدام).[web:862]

---

## 1. نطاق ETL في المرحلة الأولى

### 1.1 مصادر البيانات

- **PubChem**:
  - Chemical structure, identifiers, synonyms, basic properties.[web:783][web:899][web:905]
- **ChEBI**:
  - Ontological classification, additional identifiers.[web:614]
- **NIST Chemistry WebBook** (اختياري للمرحلة الأولى):
  - بعض الخصائص المرجعية (boiling point وما شابه).[page:0]
- **AqSolDB**:
  - مشاهدات الذوبانية المائية (LogS) مع identifiers.[web:642]
- **ESOL (Delaney) context**:
  - Dataset تاريخي للذوبانية يستخدم بوصفه سياقًا نمذجيًا (training/validation)،
    لا لنقل البيانات خام مباشرة في هذه المرحلة.[web:653]

### 1.2 حجم البيانات (Pilot)

- 100–500 مادة فقط، لاختبار المسار:
  - مجموعة من AqSolDB يُمكن ربطها بوضوح مع PubChem CID وعناوين SMILES.[web:642]
  - يمكن اختيار subset جاهز من AqSolDB dataset.

---

## 2. مراحل ETL العامة

نلتزم دورة ETL مكوّنة من 5 مراحل لكل مصدر:

1. **Extract**  
2. **Validate**  
3. **Normalize**  
4. **Load**  
5. **Review**  

كما هو موضّح في سياسة الاستيراد العامة (MASTER_IMPORT_POLICY_AR).[web:848]

---

## 3. مسار PubChem / ChEBI → الهوية + PhysChem

### 3.1 Extract

- استعلام PubChem (REST أو bulk):
  - استخدام InChIKey أو CID أو SMILES من AqSolDB لبناء قائمة CID.[web:783][web:905]
- البيانات المستخرجة:
  - `CID`, `InChIKey`, `Canonical SMILES`, `IUPAC Name`, `Synonyms`,
    `Molecular Formula`, `Molecular Weight`, `XLogP`, `TPSA`, counts.[web:783][web:899]
- استعلام ChEBI:
  - باستخدام InChIKey أو synonym للوصول إلى ChEBI ID + classification.[web:614]

### 3.2 Validate

- التحقق من:
  - أن `Standard InChIKey` متوفر لكل compound أو أغلبها.[web:905]
  - تطابق SMILES/Formula بين PubChem وAqSolDB إن توفّر.
  - عدم وجود تعارض واضح في IDs (CID واحد لكل InChIKey قدر الإمكان).[web:899][web:783]

### 3.3 Normalize

- تمثيل جميع الهويات وفق:
  - `standard_inchikey` كمفتاح بنيوي رئيسي،
  - `pubchem_cid` كمفتاح خارجي قياسي،
  - `chebi_id` إن توفّر.[web:899][web:905][web:614]
- توحيد الوحدات:
  - Molecular weight → `g/mol`،
  - خصائص أخرى وفق قاموس `physchem_property_dictionary` الموجود في السكربت.[page:0][web:783]

### 3.4 Load

- تحميل الهوية إلى:
  - `chemical_identity_registry`:
    - مع preferred_name, iupac_name, formula, SMILES, InChIKey, CID, ChEBI ID.
  - `chemical_identity_synonym_registry`:
    - مرادفات PubChem/ChEBI (اسماء عامة وتجارية).[web:783][web:614]
  - `chemical_identity_xref_registry`:
    - روابط إلى PubChem / ChEBI / CAS إن توفّر.
  - `chemical_identity_classification_registry`:
    - استخدام ChEBI لأصناف (roles, classes).[web:614]

- تحميل الخصائص إلى:
  - `physchem_property_registry`:
    - molecular_weight, xlogp, tpsa, counts, مع source_name = 'PubChem'.[web:783]
  - لاحقًا يمكن إضافة خصائص من NIST مع source_name = 'NIST'.[page:0]

### 3.5 Review

- تحقّق من:
  - عدم وجود duplicate records بفضل القيود:
    - `uq_identity_inchikey`, `uq_identity_pubchem_cid`, إلخ.
  - تشخيص حالات تضارب (InChIKey واحد مع أكثر من CID) إن ظهرت.[web:899][web:783]

---

## 4. مسار AqSolDB / ESOL → Observations + Dataset Metadata

### 4.1 Extract

- تحميل نسخة من AqSolDB dataset (ملف CSV أو ما شابه).[web:642]
- الحقول المهمة:
  - Compound ID, SMILES, LogS, conditions (temperature, pH إن وجدت),
    references, dataset-of-origin (لأن AqSolDB دمج عدة مصادر).[web:642]

### 4.2 Validate

- ربط كل compound بـ InChIKey/CID:
  - إمّا من AqSolDB مباشرة إن توفّر،
  - أو عبر SMILES → طلب PubChem InChIKey/CID.[web:783][web:905][web:899]
- التأكد من أن:
  - كل record في AqSolDB يمكن ربطه بـ `chemical_identity_id` في النظام،
  - أو يُعلّم كـ unresolved في جدول staging مؤقت (خارج الـ schema الأساسي).

### 4.3 Normalize

- تطبيع مقياس الذوبانية:
  - إذا كان LogS، يوثّق في `observed_scale = 'LogS'`.
  - إذا كانت وحدات أخرى، توحيدها أو حفظها في `observed_unit` مع scale مناسب.
- الموائمة مع endpoint/dataset:
  - `endpoint_code = 'aqueous_solubility'` (موجود في seed).[web:778]
  - `dataset_code = 'aqsoldb'` (موجود في seed).[web:642]

### 4.4 Load

- تحميل metadata لـ dataset (لو لم يكن موجودًا):
  - `experimental_dataset_registry` (AqSolDB + ESOL context).[web:642][web:653]
- لكل record:
  - إدراج observation في:
    - `experimental_observation_registry`:
      - `chemical_identity_id` (من الهوية)،
      - `experimental_endpoint_id` لـ aqueous_solubility،
      - `observed_value_num` (LogS)، `observed_scale = 'LogS'`,
      - `temperature_value`, `medium_text`, `source_name = 'AqSolDB'`,
      - `source_record_ref`، `source_year`.[web:642]
  - إدراج membership:
    - في `experimental_dataset_membership` مع dataset AqSolDB.

### 4.5 Review

- التحقق من القيود:
  - `uq_obs_source_record` يمنع تكرار نفس observation لنفس المادة/المصدر/المقياس.[web:642]
- عمل تقارير جودة:
  - عدد records المربوطة بـ identity بشكل ناجح،
  - توزيع LogS، القيم الشاذة، إلخ.

---

## 5. مسار ESOL (Delaney) كنموذج وسياق (ليس كـ raw observations)

### 5.1 الدور

- ESOL dataset يُستخدم هنا:
  - بوصفه **training/validation dataset** لنموذج ESOL‑like،
  - لا لإضافة مشاهدات جديدة تكرارية؛ لأن AqSolDB بالفعل دمج كثيرًا من المصادر بما في ذلك ESOL.[web:642][web:653]

### 5.2 التنفيذ

- تسجيل ESOL dataset في:
  - `experimental_dataset_registry` (موجود في seed كـ `esol_delaney`).[web:653]
- ربطه بالنموذج في:
  - `qsar_dataset_link_registry` مع:
    - `link_role_code = 'training'` أو `validation_external` لنموذج `esol_linear_regression`.[web:895][web:897]
- تخزين مقاييس validation في:
  - `qsar_model_validation_registry` (R², RMSE، إلخ).[web:895][web:903]

---

## 6. الطبقة التنظيمية والحوكمة خلال ETL

### 6.1 تسجيل الأطر (frameworks)

- أطر OHT/QAF/IUCLID مسجلة في:
  - `regulatory_framework_registry` من seed في core_regulatory.[web:898][web:895][web:904]

### 6.2 ربط endpoint summaries بالتنبؤات والمشاهدات

- بعد وجود:
  - identity + observations (AqSolDB),
  - model + predictions (ESOL-like),
- يمكن توليد:
  - `endpoint_summary_registry` لكل مادة أو subset:
    - شخص خبير علميًا يكتب weight-of-evidence summary.[web:901][web:904]
  - `regulatory_submission_trace_registry`:
    - يربط summary + prediction + framework (iuclid_context).[web:898][web:904][web:907]

---

## 7. خطوات عملية مقترحة لتنفيذ ETL داخل شركة رقمية

1. إعداد بيئة ETL (مثلاً Python + Airflow أو dbt أو سكربتات بسيطة).
2. بناء طبقة staging خارجية (جداول مؤقتة) لاستقبال:
   - raw PubChem/ChEBI,
   - raw AqSolDB,
   - raw ESOL metadata.
3. تنفيذ مراحل:
   - Mapping من staging إلى:
     - `chemical_identity_*`
     - `physchem_property_*`
     - `experimental_*`
     - `qsar_*`
4. تشغيل تقارير جودة أولية:
   - نسبة المواد المرتبطة بـ InChIKey وCID،
   - نسبة observations المرتبطة بـ identity،
   - تحقّق من عدم وجود duplicates عبر القيود.
5. إشراك خبير تنظيم/سمية لمراجعة:
   - أول مجموعة من endpoint summaries،
   - أول تقييمات QAF للنماذج.

---

## 8. ملاحظات ختامية

- هذا المخطط يلتزم بممارسات موصى بها في:
  - PubChem وInChI لتحديد الهوية البنيوية.[web:899][web:905][web:902]
  - NIST في توثيق الخصائص الفيزيائية‑الكيميائية.[page:0]
  - AqSolDB وESOL في إدارة بيانات الذوبانية.[web:642][web:653]
  - OECD QMRF/QPRF/QAF وOHT وIUCLID في تنظيم endpoints والنماذج والحوكمة.[web:895][web:897][web:898][web:901][web:904][web:907]
- يمكن توسيع هذه الخطة لاحقًا لتشمل:
  - بيانات tox/env إضافية،
  - نماذج QSAR جديدة،
  - وتكامل مع أنظمة تنظيمية فعلية (مثلاً عبر IUCLID APIs).

