# فشل بناء تطبيق Matching

Commit: 8803817b6255aefbb7bf9f6237d2f220353aabda

## analyze.log
```text
Resolving dependencies...
Downloading packages...
  archive 3.6.1 (4.0.9 available)
  csv 6.0.0 (8.0.0 available)
  file_picker 10.3.10 (12.0.0 available)
  flutter_lints 5.0.0 (6.0.0 available)
  google_mobile_ads 9.0.0 (9.1.0 available)
  hooks 2.0.2 (2.1.0 available)
  image 4.3.0 (4.9.1 available)
  jni 1.0.0 (1.0.3 available)
  jni_flutter 1.0.1 (1.0.2 available)
  lints 5.1.1 (6.1.0 available)
  matcher 0.12.19 (0.12.20 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  meta 1.18.0 (1.19.0 available)
  objective_c 9.4.1 (9.5.0 available)
  package_config 2.2.0 (3.0.0 available)
  pdf 3.12.0 (3.13.0 available)
  qr 3.0.2 (4.0.0 available)
  record_use 0.6.0 (1.1.0 available)
  share_plus 11.1.0 (13.3.0 available)
  share_plus_platform_interface 6.1.0 (7.2.0 available)
  syncfusion_flutter_core 30.2.7 (34.2.3 available)
  syncfusion_flutter_pdf 30.2.7 (34.2.3 available)
  test_api 0.7.11 (0.7.13 available)
  vector_math 2.2.0 (2.4.2 available)
  webview_flutter_android 4.13.0 (4.14.0 available)
  win32 5.15.0 (6.4.0 available)
  xml 6.6.1 (7.0.1 available)
Got dependencies!
27 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Analyzing Matching...                                           

   info • 'groupValue' is deprecated and shouldn't be used. Use a RadioGroup ancestor to manage group value instead. This feature was deprecated after v3.32.0-0.0.pre. Try replacing the use of the deprecated member with the replacement • lib/screens/bank_reconciliation_screen.dart:220:27 • deprecated_member_use
   info • 'onChanged' is deprecated and shouldn't be used. Use RadioGroup to handle value change instead. This feature was deprecated after v3.32.0-0.0.pre. Try replacing the use of the deprecated member with the replacement • lib/screens/bank_reconciliation_screen.dart:223:27 • deprecated_member_use
   info • 'groupValue' is deprecated and shouldn't be used. Use a RadioGroup ancestor to manage group value instead. This feature was deprecated after v3.32.0-0.0.pre. Try replacing the use of the deprecated member with the replacement • lib/screens/bank_reconciliation_screen.dart:229:27 • deprecated_member_use
   info • 'onChanged' is deprecated and shouldn't be used. Use RadioGroup to handle value change instead. This feature was deprecated after v3.32.0-0.0.pre. Try replacing the use of the deprecated member with the replacement • lib/screens/bank_reconciliation_screen.dart:232:27 • deprecated_member_use
   info • 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre. Try replacing the use of the deprecated member with the replacement • lib/screens/bank_reconciliation_screen.dart:550:17 • deprecated_member_use
   info • 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre. Try replacing the use of the deprecated member with the replacement • lib/screens/bank_reconciliation_screen.dart:567:17 • deprecated_member_use
   info • 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre. Try replacing the use of the deprecated member with the replacement • lib/screens/bank_reconciliation_screen.dart:891:19 • deprecated_member_use
   info • 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre. Try replacing the use of the deprecated member with the replacement • lib/screens/column_mapping_screen.dart:254:15 • deprecated_member_use
   info • 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre. Try replacing the use of the deprecated member with the replacement • lib/screens/column_mapping_screen.dart:336:15 • deprecated_member_use
   info • 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre. Try replacing the use of the deprecated member with the replacement • lib/screens/support_screen.dart:143:27 • deprecated_member_use
   info • The import of 'dart:typed_data' is unnecessary because all of the used elements are also provided by the import of 'package:flutter/services.dart'. Try removing the import directive • lib/services/arabic_pdf_support.dart:1:8 • unnecessary_import
   info • The import of 'dart:typed_data' is unnecessary because all of the used elements are also provided by the import of 'package:flutter/foundation.dart'. Try removing the import directive • lib/services/bank_reconciliation_export_service.dart:2:8 • unnecessary_import
   info • The import of 'dart:typed_data' is unnecessary because all of the used elements are also provided by the import of 'package:flutter/services.dart'. Try removing the import directive • lib/services/sample_bank_files_service.dart:1:8 • unnecessary_import
   info • The import of 'dart:typed_data' is unnecessary because all of the used elements are also provided by the import of 'package:flutter/services.dart'. Try removing the import directive • tool/generate_store_screenshots.dart:2:8 • unnecessary_import

14 issues found. (ran in 9.9s)
```

## test.log
```text
Resolving dependencies...
Downloading packages...
  archive 3.6.1 (4.0.9 available)
  csv 6.0.0 (8.0.0 available)
  file_picker 10.3.10 (12.0.0 available)
  flutter_lints 5.0.0 (6.0.0 available)
  google_mobile_ads 9.0.0 (9.1.0 available)
  hooks 2.0.2 (2.1.0 available)
  image 4.3.0 (4.9.1 available)
  jni 1.0.0 (1.0.3 available)
  jni_flutter 1.0.1 (1.0.2 available)
  lints 5.1.1 (6.1.0 available)
  matcher 0.12.19 (0.12.20 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  meta 1.18.0 (1.19.0 available)
  objective_c 9.4.1 (9.5.0 available)
  package_config 2.2.0 (3.0.0 available)
  pdf 3.12.0 (3.13.0 available)
  qr 3.0.2 (4.0.0 available)
  record_use 0.6.0 (1.1.0 available)
  share_plus 11.1.0 (13.3.0 available)
  share_plus_platform_interface 6.1.0 (7.2.0 available)
  syncfusion_flutter_core 30.2.7 (34.2.3 available)
  syncfusion_flutter_pdf 30.2.7 (34.2.3 available)
  test_api 0.7.11 (0.7.13 available)
  vector_math 2.2.0 (2.4.2 available)
  webview_flutter_android 4.13.0 (4.14.0 available)
  win32 5.15.0 (6.4.0 available)
  xml 6.6.1 (7.0.1 available)
Got dependencies!
27 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
00:00 +0: loading /home/runner/work/Matching/Matching/test/file_save_strategy_test.dart
00:00 +0: /home/runner/work/Matching/Matching/test/file_save_strategy_test.dart: keeps Excel on file_picker and PDF on native Android writer
00:00 +0 -1: /home/runner/work/Matching/Matching/test/file_save_strategy_test.dart: keeps Excel on file_picker and PDF on native Android writer [E]
  Expected: false
    Actual: <true>
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/file_save_strategy_test.dart 9:5               main.<fn>
  
00:00 +0 -1: /home/runner/work/Matching/Matching/test/bank_reconciliation_archive_test.dart: يحفظ تسوية واحدة لكل حساب وشهر ويستبدل النسخة السابقة
00:00 +1 -1: /home/runner/work/Matching/Matching/test/bank_reconciliation_archive_test.dart: يعيد آخر تسوية سابقة لنفس الحساب فقط
00:00 +2 -1: /home/runner/work/Matching/Matching/test/bank_reconciliation_archive_test.dart: يرحل فقط البنود المحددة للترحيل وغير الموجودة في الشهر الحالي
00:00 +3 -1: /home/runner/work/Matching/Matching/test/bank_reconciliation_archive_test.dart: يحذف التسوية المحددة فقط
00:00 +4 -1: /home/runner/work/Matching/Matching/test/bank_reconciliation_archive_test.dart: يحفظ قاعدة المرجع ونتيجة التحليل لإعادة التصدير
00:00 +5 -1: /home/runner/work/Matching/Matching/test/archive_service_test.dart: يحفظ الأرشيف جهة الحركة ويستعيدها
00:00 +6 -1: /home/runner/work/Matching/Matching/test/archive_service_test.dart: يرحل أرشيف v1 دون حذف النسخة القديمة
00:00 +7 -1: /home/runner/work/Matching/Matching/test/archive_service_test.dart: لا يحذف السجل التالف عند حفظ سجل جديد
00:01 +8 -1: /home/runner/work/Matching/Matching/test/bank_reconciliation_test.dart: calculates the two adjusted balances and final difference
00:01 +9 -1: /home/runner/work/Matching/Matching/test/bank_reconciliation_test.dart: cleared items do not affect adjusted balances
00:01 +10 -1: /home/runner/work/Matching/Matching/test/bank_reconciliation_test.dart: review-required items do not affect totals or falsely balance
00:01 +11 -1: /home/runner/work/Matching/Matching/test/bank_reconciliation_test.dart: bank statement debit decreases books and credit increases books
00:01 +12 -1: /home/runner/work/Matching/Matching/test/bank_reconciliation_test.dart: unknown transaction direction requires review
00:01 +13 -1: /home/runner/work/Matching/Matching/test/bank_reconciliation_test.dart: pending document mismatch remains a classification only
00:01 +14 -1: /home/runner/work/Matching/Matching/test/bank_reconciliation_test.dart: changing standard classification updates accounting treatment
00:01 +15 -1: /home/runner/work/Matching/Matching/test/bank_reconciliation_test.dart: does not carry a previous item that appears in current month
00:01 +16 -1: /home/runner/work/Matching/Matching/test/bank_reconciliation_test.dart: carries unique uncleared previous items only once
00:01 +17 -1: /home/runner/work/Matching/Matching/test/bank_reconciliation_test.dart: prevents adding the same manual item twice
00:01 +18 -1: /home/runner/work/Matching/Matching/test/bank_reconciliation_test.dart: classifies fees interest returned cheques and direct deposits
00:03 +19 -1: /home/runner/work/Matching/Matching/test/bank_reconciliation_archived_pdf_test.dart: creates PDF from archived reconciliation without matching result
Helvetica has no Unicode support see https://github.com/DavBfr/dart_pdf/wiki/Fonts-Management
00:03 +20 -1: /home/runner/work/Matching/Matching/test/bank_reconciliation_large_pdf_test.dart: creates comprehensive PDF for 216 matching rows without one huge table
Helvetica has no Unicode support see https://github.com/DavBfr/dart_pdf/wiki/Fonts-Management
00:05 +21 -1: /home/runner/work/Matching/Matching/test/sample_bank_files_test.dart: bank demo files produce a balanced reconciliation
00:06 +22 -1: /home/runner/work/Matching/Matching/test/reconciliation_performance_test.dart: يطابق عشرة آلاف عملية دون تكرار النتائج
00:06 +23 -1: /home/runner/work/Matching/Matching/test/bank_reconciliation_excel_integrity_test.dart: creates a valid workbook without default or empty sheets
00:06 +24 -1: /home/runner/work/Matching/Matching/test/bank_reconciliation_excel_integrity_test.dart: adds only sheets that contain actual reconciliation rows
00:07 +25 -1: /home/runner/work/Matching/Matching/test/reconciliation_engine_test.dart: يطابق مدين الطرف الأول مع دائن الطرف الثاني
00:07 +26 -1: /home/runner/work/Matching/Matching/test/reconciliation_engine_test.dart: يرفض مدين مقابل مدين ويعرض السبب الحقيقي
00:07 +27 -1: /home/runner/work/Matching/Matching/test/reconciliation_engine_test.dart: يرفض الجهة غير المحددة في مطابقة العملاء والموردين
00:07 +28 -1: /home/runner/work/Matching/Matching/test/reconciliation_engine_test.dart: يسمح بالمبلغ والتاريخ دون جهة في مطابقة البنك
00:07 +29 -1: /home/runner/work/Matching/Matching/test/reconciliation_engine_test.dart: يرفض تطابق رقم المستند إذا تجاوز فرق التاريخ المسموح
00:07 +30 -1: /home/runner/work/Matching/Matching/test/reconciliation_engine_test.dart: لا يطابق العملية نفسها حتى عند تغيير اسم الملف لأن الهوية من المحتوى
00:07 +31 -1: /home/runner/work/Matching/Matching/test/reconciliation_engine_test.dart: يعلق اختلاف رقم المستند في البنك عند اختيار المراجعة
00:07 +32 -1: /home/runner/work/Matching/Matching/test/reconciliation_engine_test.dart: يرفض اختلاف رقم المستند في البنك افتراضياً
00:07 +33 -1: /home/runner/work/Matching/Matching/test/reconciliation_engine_test.dart: يسمح بمطابقة البنك مع ملاحظة اختلاف المرجع
00:07 +34 -1: /home/runner/work/Matching/Matching/test/reconciliation_engine_test.dart: يوضح غياب مرجع أحد طرفي مطابقة البنك
00:07 +35 -1: /home/runner/work/Matching/Matching/test/reconciliation_engine_test.dart: يرفض اختلاف رقم المستند افتراضياً في مطابقة الأطراف
00:07 +36 -1: /home/runner/work/Matching/Matching/test/reconciliation_engine_test.dart: يعلق اختلاف رقم المستند للمراجعة حسب اختيار المستخدم
00:07 +37 -1: /home/runner/work/Matching/Matching/test/reconciliation_engine_test.dart: لا يستخدم العملية المقابلة أكثر من مرة
00:07 +38 -1: /home/runner/work/Matching/Matching/test/file_import_service_test.dart: يقرأ اختلاف ترتيب الأعمدة ويحدد المدين والدائن
00:07 +39 -1: /home/runner/work/Matching/Matching/test/file_import_service_test.dart: يعطي المحتوى نفسه البصمة نفسها رغم اختلاف اسم الملف
00:07 +40 -1: /home/runner/work/Matching/Matching/test/file_import_service_test.dart: يسمح ببناء الملف بعد اختيار الأعمدة يدويًا
00:07 +41 -1: /home/runner/work/Matching/Matching/test/file_import_service_test.dart: يستخرج عمليات من كشف PDF نصي
00:08 +42 -1: /home/runner/work/Matching/Matching/test/balance_detection_test.dart: detects closing balance from the latest transaction date
00:08 +43 -1: Some tests failed.

Failing tests:
  /home/runner/work/Matching/Matching/test/file_save_strategy_test.dart: keeps Excel on file_picker and PDF on native Android writer
```

