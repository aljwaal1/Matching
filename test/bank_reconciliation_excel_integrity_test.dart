import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matching/models/bank_reconciliation.dart';
import 'package:matching/services/bank_reconciliation_excel_builder.dart';

void main() {
  test('creates a valid workbook without default or empty sheets', () {
    final statement = BankReconciliationStatement(
      accountName: 'الحساب البنكي',
      period: DateTime(2026, 7),
      bookBalance: 48088325.92,
      bankBalance: 40277467.62,
      items: const [],
      bookSourceName: 'دفاتر الشركة',
      bankSourceName: 'كشف البنك',
      matchingResult: null,
    );

    final bytes = const BankReconciliationExcelBuilder().build(
      companyName: 'دفاتر الشركة',
      bankName: 'الحساب البنكي',
      statement: statement,
    );

    expect(bytes.length, greaterThan(500));
    expect(bytes.take(2).toList(), [0x50, 0x4B]);

    final workbook = Excel.decodeBytes(bytes);
    expect(workbook.tables.keys.toSet(), {'ملخص التسوية'});
    expect(workbook.tables.keys, isNot(contains('Sheet1')));

    for (final entry in workbook.tables.entries) {
      final hasContent = entry.value.rows.any(
        (row) => row.any(
          (cell) =>
              cell?.value != null &&
              cell!.value.toString().trim().isNotEmpty,
        ),
      );
      expect(hasContent, isTrue, reason: 'الورقة ${entry.key} فارغة');
    }
  });

  test('adds only sheets that contain actual reconciliation rows', () {
    final statement = BankReconciliationStatement(
      accountName: 'الحساب البنكي',
      period: DateTime(2026, 7),
      bookBalance: 1000,
      bankBalance: 900,
      items: const [
        BankAdjustmentItem(
          id: 'bank-1',
          description: 'إيداع بالطريق',
          amount: 100,
          type: BankDifferenceType.depositInTransit,
          adjustBankBalance: true,
          add: true,
        ),
      ],
      bookSourceName: 'دفاتر الشركة',
      bankSourceName: 'كشف البنك',
      matchingResult: null,
    );

    final bytes = const BankReconciliationExcelBuilder().build(
      companyName: 'دفاتر الشركة',
      bankName: 'الحساب البنكي',
      statement: statement,
    );
    final workbook = Excel.decodeBytes(bytes);
    final names = workbook.tables.keys.toSet();

    expect(names, containsAll({'ملخص التسوية', 'معلقات كشف البنك'}));
    expect(names, isNot(contains('Sheet1')));
    expect(names, isNot(contains('معلقات دفاتر الشركة')));
    expect(names, isNot(contains('تحتاج مراجعة')));
    expect(names, isNot(contains('المرحل للشهر القادم')));
    expect(names, isNot(contains('تحليل المطابقة')));
  });
}
