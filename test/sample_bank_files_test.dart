import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:matching/services/bank_reconciliation_service.dart';
import 'package:matching/services/file_import_service.dart';
import 'package:matching/services/reconciliation_engine.dart';

void main() {
  final importer = FileImportService();
  Uint8List csv(String value) => Uint8List.fromList(utf8.encode(value));

  test('bank demo files produce a balanced reconciliation', () {
    const booksCsv = '''التاريخ,رقم المستند,الوصف,مدين,دائن,الرصيد
2026-08-01,101,إيداع نقدي,500,,1500
2026-08-03,201,شيك مورد,,120,1380
2026-08-05,102,تحصيل من عميل,350,,1730
2026-08-07,202,شيك مصروف,,245,1485
2026-08-10,203,شيك لم يظهر في البنك,,80,1405
''';
    const bankCsv = '''التاريخ,رقم المستند,الوصف,مدين,دائن,الرصيد
2026-08-01,101,إيداع نقدي,,500,1500
2026-08-03,201,شيك مورد,120,,1380
2026-08-05,102,تحصيل من عميل,,350,1730
2026-08-07,202,شيك مصروف,245,,1485
2026-08-11,301,رسوم بنكية,45,,1440
''';

    final books = importer.importBytes(fileName: 'books.csv', bytes: csv(booksCsv));
    final bank = importer.importBytes(fileName: 'bank.csv', bytes: csv(bankCsv));
    final result = const ReconciliationEngine().reconcile(
      left: books.records,
      right: bank.records,
      settings: const ReconciliationSettings(
        mode: ReconciliationMode.bank,
        allowedDateDifferenceDays: 3,
      ),
    );
    final statement = const BankReconciliationService().build(
      period: DateTime(2026, 8),
      bookBalance: 1405,
      bankBalance: 1440,
      matchingResult: result,
    );

    expect(statement.items.length, 2);
    expect(statement.adjustedBookBalance, 1360);
    expect(statement.adjustedBankBalance, 1360);
    expect(statement.isBalanced, isTrue);
  });
}
