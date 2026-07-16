import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:matching/models/transaction_record.dart';
import 'package:matching/services/file_import_service.dart';

void main() {
  test('يقرأ اختلاف ترتيب الأعمدة ويحدد المدين والدائن', () {
    const csv = '''الرصيد,المبلغ الدائن,التاريخ,رقم المستند,المبلغ المدين,البيان
1000,,2026-07-01,INV-1,500,فاتورة
500,500,2026-07-02,RCP-1,,قبض
''';
    final imported = FileImportService().importBytes(
      fileName: 'supplier.csv',
      bytes: Uint8List.fromList(utf8.encode(csv)),
    );
    expect(imported.records, hasLength(2));
    expect(imported.records[0].side, EntrySide.debit);
    expect(imported.records[1].side, EntrySide.credit);
  });

  test('يعطي المحتوى نفسه البصمة نفسها رغم اختلاف اسم الملف', () {
    const csv = 'التاريخ,المبلغ\n2026-01-01,100\n';
    final bytes = Uint8List.fromList(utf8.encode(csv));
    final first = FileImportService().importBytes(fileName: 'a.csv', bytes: bytes);
    final second = FileImportService().importBytes(fileName: 'b.csv', bytes: bytes);
    expect(first.fingerprint, second.fingerprint);
    expect(first.records.single.id, second.records.single.id);
  });

  test('يسمح ببناء الملف بعد اختيار الأعمدة يدويًا', () {
    const csv = 'عمود 1,عمود 2,عمود 3\n2026-01-01,100,A1\n';
    final service = FileImportService();
    final prepared = service.prepareBytes(
      fileName: 'manual.csv',
      bytes: Uint8List.fromList(utf8.encode(csv)),
    );
    final imported = service.buildStatement(
      prepared,
      const ColumnMapping(date: 0, amount: 1, document: 2),
    );
    expect(imported.records.single.documentNumber, 'A1');
  });
}
