# فشل بناء تطبيق Matching

Commit: 5c701f27985118e077f9b24a64c87f04fec2e635

## analyze.log
```text
Analyzing Matching...                                           

   info • The private field _usePreviousReconciliation could be 'final'. Try making the field 'final' • lib/screens/bank_reconciliation_screen.dart:37:8 • prefer_final_fields
warning • The value of the field '_usePreviousReconciliation' isn't used. Try removing the field, or using it • lib/screens/bank_reconciliation_screen.dart:37:8 • unused_field
  error • The name '_usePreviousReconciliation' is already defined. Try renaming one of the declarations • lib/screens/bank_reconciliation_screen.dart:38:8 • duplicate_definition
   info • 'groupValue' is deprecated and shouldn't be used. Use a RadioGroup ancestor to manage group value instead. This feature was deprecated after v3.32.0-0.0.pre. Try replacing the use of the deprecated member with the replacement • lib/screens/bank_reconciliation_screen.dart:188:27 • deprecated_member_use
   info • 'onChanged' is deprecated and shouldn't be used. Use RadioGroup to handle value change instead. This feature was deprecated after v3.32.0-0.0.pre. Try replacing the use of the deprecated member with the replacement • lib/screens/bank_reconciliation_screen.dart:191:27 • deprecated_member_use
   info • 'groupValue' is deprecated and shouldn't be used. Use a RadioGroup ancestor to manage group value instead. This feature was deprecated after v3.32.0-0.0.pre. Try replacing the use of the deprecated member with the replacement • lib/screens/bank_reconciliation_screen.dart:197:27 • deprecated_member_use
   info • 'onChanged' is deprecated and shouldn't be used. Use RadioGroup to handle value change instead. This feature was deprecated after v3.32.0-0.0.pre. Try replacing the use of the deprecated member with the replacement • lib/screens/bank_reconciliation_screen.dart:200:27 • deprecated_member_use
   info • 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre. Try replacing the use of the deprecated member with the replacement • lib/screens/bank_reconciliation_screen.dart:505:17 • deprecated_member_use
   info • 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre. Try replacing the use of the deprecated member with the replacement • lib/screens/bank_reconciliation_screen.dart:522:17 • deprecated_member_use
warning • The value of the local variable 'previousPending' isn't used. Try removing the variable or using it • lib/screens/bank_reconciliation_screen.dart:604:11 • unused_local_variable
  error • The name 'previousPending' is already defined. Try renaming one of the declarations • lib/screens/bank_reconciliation_screen.dart:604:11 • duplicate_definition
   info • 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre. Try replacing the use of the deprecated member with the replacement • lib/screens/bank_reconciliation_screen.dart:794:19 • deprecated_member_use
   info • 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre. Try replacing the use of the deprecated member with the replacement • lib/screens/column_mapping_screen.dart:244:15 • deprecated_member_use
   info • 'value' is deprecated and shouldn't be used. Use initialValue instead. This will set the initial value for the form field. This feature was deprecated after v3.33.0-1.0.pre. Try replacing the use of the deprecated member with the replacement • lib/screens/column_mapping_screen.dart:326:15 • deprecated_member_use
   info • The import of 'dart:typed_data' is unnecessary because all of the used elements are also provided by the import of 'package:flutter/services.dart'. Try removing the import directive • lib/services/arabic_pdf_support.dart:1:8 • unnecessary_import

15 issues found. (ran in 11.6s)
```

