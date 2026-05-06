# منصة بيانات كيميائية – سكربتات PostgreSQL أساسية

هذه المستودع يحتوي على سكربتات SQL أساسية لبناء بنية بيانات كيميائية مؤسسية
(هوية + خصائص + ذوبانية + نماذج + حوكمة تنظيمية) قابلة للتنفيذ في شركة رقمية.

تم تصميم السكربتات بالاستناد إلى مصادر علمية وتنظيمية عالمية، مثل:
PubChem, ChEBI, NIST Chemistry WebBook, AqSolDB, Delaney ESOL context,
OECD Harmonised Templates (OHT), OECD QMRF/QPRF/QAF, IUCLID context, FAIR principles.
[web:783][web:614][page:0][web:642][web:653][web:778][web:196][web:604][web:862]

## الملفات الرئيسية

1. `core_schema_identity_physchem_solubility.sql`  
   - يبني:
     - سجل الهوية الكيميائية (chemical_identity_registry + مشتقاته).
     - سجل الخصائص الفيزيائية‑الكيميائية (physchem_property_*).
     - سجل المشاهدات التجريبية للذوبانية (experimental_*).
   - يتضمن قيودًا وفهارس وقيَم seed لقاموس الخصائص وdatasets الذوبانية.

2. `core_schema_predictions_regulatory.sql`  
   - يبني:
     - سجل نماذج QSAR/QSPR والتحقق وApplicability Domain والتنبؤات.
     - سجل الأطر التنظيمية (OECD OHT, QAF, IUCLID context).
     - سجل ملخصات الـ endpoints والتقييمات التنظيمية وآثار التقديم (submission trace).

## المتطلبات

- قاعدة بيانات: PostgreSQL (يفضَّل إصدار 13 أو أحدث).  
- صلاحيات لإنشاء جداول وفهارس في الـ schema المستهدف.

## ترتيب التنفيذ

نفّذ السكربتات بالترتيب التالي:

1. تنفيذ `core_schema_identity_physchem_solubility.sql`
   - هذا السكربت ينشئ:
     - الهوية الكيميائية.
     - الخصائص الفيزيائية‑الكيميائية.
     - مشاهدات الذوبانية وdatasets المرجعية (AqSolDB, ESOL).
   - يجب أن يُنفَّذ أولًا لأنه يوفّر الجداول المرجعية التي تعتمد عليها
     التنبؤات والحوكمة التنظيمية لاحقًا.

2. تنفيذ `core_schema_predictions_regulatory.sql`
   - هذا السكربت ينشئ:
     - نماذج QSAR/QSPR + التحققات + AD + التنبؤات.
     - الأطر التنظيمية وملخصات الـ endpoints وتتبع التقديمات.
   - يعتمد على وجود:
     - `chemical_identity_registry`
     - `experimental_endpoint_registry` (مثل `aqueous_solubility`)
     - `experimental_dataset_registry`
     التي تنشأ في السكربت الأول.

## طريقة التنفيذ (PostgreSQL)

### من سطر الأوامر (psql)

1. أنشئ قاعدة بيانات جديدة (اختياري):

```bash
createdb chem_platform
```

2. نفّذ السكربت الأول:

```bash
psql -d chem_platform -f core_schema_identity_physchem_solubility.sql
```

3. نفّذ السكربت الثاني:

```bash
psql -d chem_platform -f core_schema_predictions_regulatory.sql
```

### من أدوات GUI (مثل pgAdmin / DBeaver / DataGrip)

1. أنشئ اتصالًا بقاعدة PostgreSQL (مثلاً قاعدة `chem_platform`).  
2. افتح ملف `core_schema_identity_physchem_solubility.sql` في أداة SQL، ثم نفّذه.  
3. افتح ملف `core_schema_predictions_regulatory.sql`، ثم نفّذه بنفس الطريقة.

## نطاق الاستخدام

هذه السكربتات تمثّل:

- تصميمًا مرجعيًا (reference design) لبنية بيانات كيميائية مبنية على مصادر موثوقة،
  لكنها لا تحتوي بيانات إنتاجية كاملة ولا تشكّل بحد ذاتها نظامًا إنتاجيًا جاهزًا.
- نقطة انطلاق لبناء:
  - ETL pipelines (استيراد من PubChem, ChEBI, AqSolDB, ...).
  - واجهات برمجية (APIs) وخدمات تطبيقية.
  - طبقات حوكمة إضافية (أمن، مراقبة، مراجعة الجودة).

## ملاحظات حوكمة علمية

- لا يجب خلط observations (البيانات المقاسة) مع predictions (البيانات المتنبأ بها)
  في نفس الجداول.
- يجب توثيق المصدر ونوع القيمة (مقاسة / مرجعية / محسوبة / متنبأ بها) لكل سجل.
- يجب الحفاظ على الهوية الكيميائية عبر معرّف بنيوي موثوق
  مثل Standard InChIKey وربط PubChem CID وChEBI ID عند التوفر.
[web:783][web:614][web:642][web:778]

## حقوق وقيود

- السكربتات هنا مقدّمة كنموذج تصميمي/تقني عام، ويجب على كل جهة تنفيذية:
  - استكمال التحقق القانوني والتنظيمي.
  - إضافة طبقات الأمن والخصوصية والـ audit trail.
  - التكيّف مع متطلبات الجهة التنظيمية في البلد أو المنطقة.
