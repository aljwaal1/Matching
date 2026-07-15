import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:matching/services/file_import_service.dart';

void main() {
  test('يسجل الصفوف ذات التاريخ أو المبلغ غير الصالح بدلاً من إسقاطها بصمت', () {
    final csv = '''التاريخ,المبلغ,رقم المستند,البيان
2026-01-01,100,A1,عملية صحيحة
تاريخ غير صالح,200,A2,تاريخ غير صالح
2026-01-03,مبلغ غير صالح,A3,مبلغ غير صالح
''';

    final imported = FileImportService().importBytes(
      fileName: 'test.csv',
      bytes: Uint8List.fromList(utf8.encode(csv)),
    );

    expect(imported.records, hasLength(1));
    expect(imported.skippedRows, hasLength(2));
    expect(imported.skippedRows.first.rowNumber, 3);
    expect(imported.skippedRows.first.reason, contains('التاريخ'));
    expect(imported.skippedRows.last.rowNumber, 4);
    expect(imported.skippedRows.last.reason, contains('المبلغ'));
    expect(imported.fileName, contains('تم تجاهل 2 صف'));
  });
}
