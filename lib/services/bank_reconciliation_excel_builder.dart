import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../models/bank_reconciliation.dart';
import 'excel_report_style.dart';

class BankReconciliationExcelBuilder {
  const BankReconciliationExcelBuilder();

  List<int> build({
    required String companyName,
    required String bankName,
    required BankReconciliationStatement statement,
  }) {
    final workbook = Excel.createExcel();
    workbook.delete('Sheet1');

    final activeBankItems = statement.items
        .where((item) => item.adjustBankBalance && !item.cleared)
        .toList(growable: false);
    final activeBookItems = statement.items
        .where((item) => !item.adjustBankBalance && !item.cleared)
        .toList(growable: false);
    final bankPending = activeBankItems
        .where((item) => item.status == BankItemStatus.pending)
        .toList(growable: false);
    final bookPending = activeBookItems
        .where((item) => item.status == BankItemStatus.pending)
        .toList(growable: false);
    final carried = statement.items
        .where((item) => item.status == BankItemStatus.carryForward)
        .toList(growable: false);

    _buildSummary(
      workbook['ملخص التسوية'],
      companyName: companyName,
      bankName: bankName,
      statement: statement,
      bankItems: activeBankItems,
      bookItems: activeBookItems,
    );
    _buildItemsSheet(workbook['معلقات كشف البنك'], bankPending);
    _buildItemsSheet(workbook['معلقات دفاتر الشركة'], bookPending);
    _buildItemsSheet(
      workbook['المرحل للشهر القادم'],
      carried,
      includeSide: true,
    );

    final bytes = workbook.encode();
    if (bytes == null) throw Exception('تعذر إنشاء ملف Excel للتسوية.');
    return bytes;
  }

  void _buildSummary(
    Sheet sheet, {
    required String companyName,
    required String bankName,
    required BankReconciliationStatement statement,
    required List<BankAdjustmentItem> bankItems,
    required List<BankAdjustmentItem> bookItems,
  }) {
    sheet.appendRow([
      const TextCellValue('تقرير التسوية البنكية'),
      const TextCellValue(''),
    ]);
    _appendText(sheet, 'الشركة', companyName);
    _appendText(sheet, 'البنك أو الحساب', bankName);
    _appendText(
      sheet,
      'شهر التسوية',
      DateFormat('yyyy/MM', 'en_US').format(statement.period),
    );
    _appendMoney(sheet, 'رصيد كشف البنك', statement.bankBalance);
    for (final line in _aggregate(bankItems)) {
      _appendMoney(sheet, line.label, line.amount);
    }
    _appendMoney(
      sheet,
      'الرصيد المعدل حسب كشف البنك',
      statement.adjustedBankBalance,
    );
    final adjustedBankRow = sheet.maxRows - 1;
    _appendMoney(sheet, 'رصيد دفاتر الشركة', statement.bookBalance);
    for (final line in _aggregate(bookItems)) {
      _appendMoney(sheet, line.label, line.amount);
    }
    _appendMoney(
      sheet,
      'الرصيد المعدل حسب دفاتر الشركة',
      statement.adjustedBookBalance,
    );
    final adjustedBookRow = sheet.maxRows - 1;
    _appendMoney(sheet, 'الفرق النهائي', statement.difference);
    final differenceRow = sheet.maxRows - 1;
    _appendText(
      sheet,
      'حالة التسوية',
      statement.isBalanced ? 'متوازنة' : 'غير متوازنة',
    );

    ExcelReportStyle.styleSummary(
      sheet,
      rows: sheet.maxRows,
      moneyRows: {for (var row = 4; row <= differenceRow; row++) row},
      totalRows: {adjustedBankRow, adjustedBookRow, differenceRow},
    );
  }

  void _buildItemsSheet(
    Sheet sheet,
    List<BankAdjustmentItem> items, {
    bool includeSide = false,
  }) {
    final headers = <String>[
      'التاريخ',
      'رقم المرجع أو المستند',
      'البيان',
      'التصنيف',
      if (includeSide) 'الجهة',
      'المعالجة',
      'المبلغ',
      'الحالة',
    ];
    sheet.appendRow(headers.map(TextCellValue.new).toList());
    for (final item in items) {
      final transaction = item.transaction;
      sheet.appendRow([
        TextCellValue(transaction == null ? '' : _date(transaction.date)),
        TextCellValue(transaction?.documentNumber?.trim() ?? ''),
        TextCellValue(item.description),
        TextCellValue(item.type.label),
        if (includeSide)
          TextCellValue(
            item.adjustBankBalance ? 'كشف البنك' : 'دفاتر الشركة',
          ),
        TextCellValue(item.add ? 'إضافة' : 'خصم'),
        DoubleCellValue(item.add ? item.amount : -item.amount),
        TextCellValue(item.status.label),
      ]);
    }

    final amountColumn = headers.indexOf('المبلغ');
    ExcelReportStyle.styleTable(
      sheet,
      headerRow: 0,
      lastRow: sheet.maxRows - 1,
      columnCount: headers.length,
      moneyColumns: {amountColumn},
      centeredColumns: {
        0,
        1,
        3,
        if (includeSide) 4,
        includeSide ? 5 : 4,
        amountColumn,
        headers.length - 1,
      },
      widths: includeSide
          ? const [15, 21, 42, 28, 20, 14, 18, 20]
          : const [15, 21, 42, 28, 14, 18, 20],
    );

    final totalRow = sheet.maxRows;
    final totalValues = List<CellValue>.filled(
      headers.length,
      const TextCellValue(''),
      growable: false,
    );
    totalValues[2] = const TextCellValue('الإجمالي');
    totalValues[amountColumn] = DoubleCellValue(
      items.fold<double>(
        0,
        (sum, item) => sum + (item.add ? item.amount : -item.amount),
      ),
    );
    sheet.appendRow(totalValues);
    for (var column = 0; column < headers.length; column++) {
      sheet
          .cell(CellIndex.indexByColumnRow(
            columnIndex: column,
            rowIndex: totalRow,
          ))
          .cellStyle = column == amountColumn
          ? ExcelReportStyle.totalMoney
          : ExcelReportStyle.total;
    }
  }

  List<_SummaryLine> _aggregate(List<BankAdjustmentItem> items) {
    final totals = <BankDifferenceType, double>{};
    for (final item in items) {
      totals.update(
        item.type,
        (value) => value + (item.add ? item.amount : -item.amount),
        ifAbsent: () => item.add ? item.amount : -item.amount,
      );
    }
    return totals.entries
        .where((entry) => entry.value.abs() > 0.0001)
        .map(
          (entry) => _SummaryLine(
            label: '${entry.value >= 0 ? 'يضاف' : 'يخصم'}: إجمالي ${entry.key.label}',
            amount: entry.value,
          ),
        )
        .toList(growable: false);
  }

  void _appendText(Sheet sheet, String label, String value) {
    sheet.appendRow([TextCellValue(label), TextCellValue(value)]);
  }

  void _appendMoney(Sheet sheet, String label, double value) {
    sheet.appendRow([TextCellValue(label), DoubleCellValue(value)]);
  }

  String _date(DateTime date) =>
      DateFormat('yyyy-MM-dd', 'en_US').format(date);
}

class _SummaryLine {
  const _SummaryLine({required this.label, required this.amount});

  final String label;
  final double amount;
}
