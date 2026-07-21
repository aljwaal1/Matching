import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:matching/services/file_import_service.dart';

void main() {
  test('detects closing balance from the latest transaction date', () {
    final csv = '''Date,Reference,Description,Debit,Credit,Balance
2026-07-03,A3,Third,0,30,1030
2026-07-01,A1,First,100,0,1100
2026-07-02,A2,Second,70,0,1170
''';
    final service = FileImportService();
    final prepared = service.prepareBytes(
      fileName: 'statement.csv',
      bytes: Uint8List.fromList(utf8.encode(csv)),
    );
    final mapping = prepared.suggestedMapping;

    expect(mapping, isNotNull);
    expect(mapping!.balance, isNotNull);

    final imported = service.buildStatement(prepared, mapping);
    expect(imported.detectedBalance, 1030);
    expect(imported.balanceRowNumber, 2);
  });
}
