# فشل بناء تطبيق Matching

Commit: b39a4d53d1c751621505d07cd7c7932a848a3c1f

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
  error • Invalid constant value • test/sample_bank_files_test.dart:35:15 • invalid_constant
  error • Undefined name 'ReconciliationMode'. Try correcting the name to one that is defined, or defining the name • test/sample_bank_files_test.dart:35:15 • undefined_identifier
   info • The import of 'dart:typed_data' is unnecessary because all of the used elements are also provided by the import of 'package:flutter/services.dart'. Try removing the import directive • tool/generate_store_screenshots.dart:2:8 • unnecessary_import

16 issues found. (ran in 12.2s)
```

