# دليل الهجرة من Firestore إلى Supabase — attendance_app

## ⚠️ أولاً: مشكلة أمنية عاجلة (منفصلة عن الهجرة)

ملف `sheets_service.dart` الذي أرسلته يحتوي على **مفتاح خاص (Private Key) حقيقي وفعّال** لحساب خدمة Google
(`safi-sheets-474@attendance-app-87047.iam.gserviceaccount.com`). هذا المفتاح يمنح صلاحية كاملة على Google Sheets المرتبطة به.

بغض النظر عن مشروع Supabase، يجب عليك:
1. الذهاب إلى Google Cloud Console → IAM & Admin → Service Accounts → هذا الحساب → Keys، وحذف (Delete/Revoke) هذا المفتاح فوراً، ثم إصدار مفتاح جديد.
2. إذا كان هذا الملف موجوداً في مستودع Git (GitHub/GitLab)، افترض أنه **مسرّب حتى لو كان الريبو خاصاً** — امسحه من تاريخ الـ commits (`git filter-repo` أو BFG)، وليس فقط من آخر نسخة.
3. لا تضع المفتاح الجديد كنص صريح في كود Dart مطلقاً. انقله إلى Backend بسيط (Supabase Edge Function مثلاً) يستقبل طلب "أضف صف" من التطبيق، ويستخدم المفتاح من متغيرات بيئة سرّية على السيرفر فقط. تطبيق موبايل لا يمكن إخفاء أسرار بداخله أبداً — أي مفتاح مدمج فيه قابل للاستخراج من ملف الـ APK.

هذا لا علاقة له بانتقال قاعدة البيانات، لكنه أهم وأخطر بند في كامل هذه الرسالة، لذلك بدأت به.

---

## نظرة عامة على الهجرة

بنية المشروع الحالية (Firebase):
- **قاعدة البيانات**: Cloud Firestore → المجموعات: `users`, `employees`, `violations`, `leaves`, `reports`, `notifications`
- **تسجيل الدخول**: مخصص (مقارنة يدوية لكلمة مرور نصية) على مجموعة `users`، وليس Firebase Auth فعلياً
- **الصور/الفيديو**: Cloudinary (ليس Firebase Storage — لا تأثير من هذه الهجرة)
- **الإشعارات**: Firebase Cloud Messaging + Firestore (إرسال الـ Push الفعلي كان أصلاً غير مُفعّل في الكود، معلّق فقط)

الخطة: استبدال Firestore بـ **Supabase Postgres**، مع الحفاظ على نفس منطق الشاشات قدر الإمكان.

مشروعك على Supabase (من الصورة المرفقة) جاهز:
- Project: **Security and safety system**
- URL: `https://iqoskmehpfytecnbdfhn.supabase.co`

---

## الخطوات بالترتيب

### 1) إنشاء الجداول
افتح **Supabase Dashboard → SQL Editor → New query**، الصق محتوى الملف المرفق `supabase_schema.sql` بالكامل، ثم Run.
هذا ينشئ الجداول الست، الفهارس، تفعيل Realtime، و RLS مبدئي (انظر تحذير RLS أدناه).

### 2) نقل البيانات الحالية من Firestore (إن وُجدت)
إذا كان لديك بيانات فعلية في Firestore تريد الاحتفاظ بها:
```bash
# تصدير كل مجموعة إلى JSON من Firebase Console أو باستخدام:
npx node-firestore-import-export export --accountCredentials service-account.json --backupFile violations.json --nodePath violations
```
ثم اكتب سكربت صغير (Node.js أو Python) يقرأ كل ملف JSON ويستخدم Supabase REST API (`POST /rest/v1/<table>`) لإدخال الصفوف، مع تحويل أسماء الحقول من camelCase إلى snake_case (كما في الجداول)، وتحويل `Timestamp` إلى نص ISO8601.
إن كانت البيانات الحالية قليلة/تجريبية، الأبسط هو تجاهل الاستيراد والبدء بقاعدة بيانات فارغة.

### 3) الحصول على مفاتيح Supabase
من **Project Settings → API**:
- انسخ **Project URL** (نفس الرابط أعلاه)
- انسخ **anon public key** فقط (ليس service_role — هذا الأخير لا يوضع أبداً داخل تطبيق موبايل)

### 4) تحديث pubspec.yaml
استخدم الملف المرفق `pubspec.yaml` (أزلت `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_messaging`, `firebase_storage` وأضفت `supabase_flutter`). ثم:
```bash
flutter pub get
```

### 5) حذف ملفات Firebase غير المطلوبة
```bash
rm lib/firebase_options.dart
# احذف ملفات google-services.json / GoogleService-Info.plist من android/ios إن رغبت بإزالة Firebase كلياً من المشاريع الأصلية
```

### 6) استبدال الملفات الأساسية
انسخ الملفات المرفقة فوق الملفات الحالية:
- `lib/main.dart` → استبدل `kSupabaseAnonKey` بالمفتاح الحقيقي (والأفضل تمريره عبر `--dart-define=SUPABASE_ANON_KEY=...` بدل كتابته مباشرة في الكود)
- `lib/models/user_model.dart`, `violation_model.dart`, `leave_model.dart`, `report_model.dart`
- `lib/services/auth_service.dart`
- `lib/services/database_service.dart` **(جديد — يحل محل firestore_service.dart، احذف firestore_service.dart القديم)**
- `lib/services/notification_service.dart`

### 7) تعديل الشاشات (10 ملفات)
هذه الملفات تستورد `cloud_firestore` مباشرة وتحتاج تعديلاً يدوياً:
```
lib/screens/admin/reports_list_screen.dart
lib/screens/admin/leaves_list_screen.dart
lib/screens/admin/review_panel_screen.dart
lib/screens/admin/admin_dashboard.dart
lib/screens/admin/violations_list_screen.dart   ← تم تجهيزه كاملاً كمثال (مرفق)
lib/screens/security/my_violations_screen.dart
lib/screens/security/add_violation_screen.dart
lib/screens/security/leave_request_screen.dart
lib/screens/security/fix_upload_screen.dart
lib/widgets/employee_search.dart
```

استخدم `violations_list_screen.dart` المرفق كمرجع — نفس النمط ينطبق على البقية ميكانيكياً حسب الجدول التالي (Find & Replace):

| القديم (Firestore) | الجديد (Supabase) |
|---|---|
| `import 'package:cloud_firestore/cloud_firestore.dart';` | احذف السطر |
| `import '../../services/firestore_service.dart';` | `import '../../services/database_service.dart';` |
| `FirestoreService()` | `DatabaseService()` |
| `StreamBuilder<QuerySnapshot>` | `StreamBuilder<List<ViolationModel>>` (أو `LeaveModel`/`ReportModel` حسب الشاشة) |
| `snap.data!.docs.isEmpty` | `snap.data!.isEmpty` |
| `snap.data!.docs.map((d) => X.fromFirestore(d)).toList()` | `snap.data!` (البيانات جاهزة كـ List<Model> مباشرة من DatabaseService) |
| `doc.id` (داخل شاشة تستخدم Map خام كالموظفين) | `map['employee_id']` أو `map['uid']` (أضفناه في `getEmployeeById`/`searchEmployees`) |
| `Timestamp.now()` / `Timestamp.fromDate(x)` | `DateTime.now().toIso8601String()` / `x.toIso8601String()` |
| `(data['x'] as Timestamp).toDate()` | `DateTime.parse(map['x'] as String)` |

ملاحظات خاصة ببعض الشاشات:
- **employee_search.dart**: يستخدم `getAllEmployees()`/`searchEmployees()` التي تُعيد الآن `Stream<List<Map<String,dynamic>>>` أو `List<Map<String,dynamic>>` (بدون تغيير في التوقيع الخارجي، فقط احذف استيراد `cloud_firestore` واستبدل `FirestoreService` بـ `DatabaseService`).
- **add_violation_screen.dart**: يستخدم أيضاً `SheetsService` — هذا لا علاقة له بـ Supabase، اتركه كما هو (بعد تدوير المفتاح المسرّب كما في القسم الأول).
- أي مكان يستخدم `doc.id` بعد إضافة عنصر جديد (`addViolation`, `addLeave`, `addReport`) لا يحتاج تعديل — الدوال في `DatabaseService` ما زالت تُعيد `Future<String>` بالمعرّف الجديد بنفس الطريقة.

### 8) تشغيل فحص شامل
```bash
flutter analyze
flutter run
```
`flutter analyze` سيُظهر لك بالضبط أي سطر متبقٍ يستورد `cloud_firestore` أو يستخدم `Timestamp`/`QuerySnapshot` — عالجها سطراً سطراً حسب الجدول أعلاه حتى يختفي كل الأخطاء.

### 9) تفعيل Row Level Security بشكل صحيح (مهم قبل الإطلاق)
السكربت المرفق يفعّل RLS لكنه يسمح بكل شيء لأي شخص يملك مفتاح anon (وهذا المفتاح موجود داخل تطبيق الموبايل نفسه، أي عملياً مكشوف). هذا مقبول فقط للتطوير. قبل الإطلاق الفعلي اختر أحد الحلين:
- **الأسرع**: أضف عمود `device_secret` أو انتقل لاستخدام **Supabase Auth** الحقيقي (تسجيل دخول بالبريد وكلمة مرور مُدارة من Supabase بدل مقارنة نصية يدوية)، ثم اكتب Policies تعتمد على `auth.uid()` بدل `using (true)`.
- **الأبسط مؤقتاً**: أبقِ التطبيق كما هو الآن (بدون Auth حقيقي) لكن قيّد الكتابة عبر Edge Functions فقط بدل السماح بالكتابة المباشرة من التطبيق.

كذلك: كلمة المرور تُخزَّن حالياً كنص صريح في عمود `password` (كما كانت في Firestore). يُنصح بشدة باستبدالها بتجزئة (bcrypt) عبر Supabase Edge Function عند إتاحة الفرصة.

---

## ملخص الأوامر
```bash
flutter pub remove firebase_core firebase_auth cloud_firestore firebase_messaging firebase_storage
flutter pub add supabase_flutter
flutter pub get
flutter analyze
flutter run
```
