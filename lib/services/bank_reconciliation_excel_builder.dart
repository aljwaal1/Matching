import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../models/bank_reconciliation.dart';
import '../models/transaction_record.dart';
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
        .where((item) => item.adjustBankBalance && item.includedInCalculation)
        .toList(growable: false);
    final activeBookItems = statement.items
        .where((item) => !item.adjustBankBalance && item.includedInCalculation)
        .toList(growable: false);
    final reviewItems = statement.items
        .where(
          (item) =>
              item.type == BankDifferenceType.reviewRequired && !item.cleared,
        )
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
    _buildItemsSheet(workbook['تحتاج مراجعة'], reviewItems, includeSide: true);
    _buildItemsSheet(
      workbook['المرحل للشهر القادم'],
      carried,
      includeSide: true,
    );
    final matchingResult = statement.matchingResult;
    if (matchingResult != null) {
      _buildMatchingSheet(workbook['تحليل المطابقة'], matchingResult);
    }

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
      TextCellValue('تقرير التسوية البنكية'),
      TextCellValue(''),
    ]);
    _appendText(sheet, 'الشركة', companyName);
    _appendText(sheet, 'البنك أو الحساب', bankName);
    _appendText(
      sheet,
      'شهر التسوية',
      DateFormat('yyyy/MM', 'en_US').format(statement.period),
    );
    _appendText(
      sheet,
      'قاعدة اختلاف رقم المرجع',
      _ruleLabel(statement.documentMismatchRule),
    );
    final moneyStartRow = sheet.maxRows;
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
    final matchingResult = statement.matchingResult;
    if (matchingResult != null) {
      _appendText(sheet, 'العمليات المتطابقة', '${matchingResult.matchedCount}');
      _appendText(sheet, 'المعلقة للمراجعة', '${matchingResult.pendingCount}');
      _appendText(
        sheet,
        'العمليات غير المتطابقة',
        '${matchingResult.unmatchedCount}',
      );
    }

    ExcelReportStyle.styleSummary(
      sheet,
      rows: sheet.maxRows,
      moneyRows: {
        for (var row = moneyStartRow; row <= differenceRow; row++) row,
      },
      totalRows: {adjustedBankRow, adjustedBookRow, differenceRow},
    );
  }

  void _buildMatchingSheet(Sheet sheet, ReconciliationResult result) {
    const headers = [
      'الحالة',
      'السبب',
      'درجة المطابقة',
      'تاريخ دفاتر الشركة',
      'مستند دفاتر الشركة',
      'بيان دفاتر الشركة',
      'مدين دفاتر الشركة',
      'دائن دفاتر الشركة',
      'رصيد دفاتر الشركة',
      'تاريخ كشف البنك',
      'مرجع كشف البنك',
      'بيان كشف البنك',
      'مدين كشف البنك',
      'دائن كشف البنك',
      'رصيد كشف البنك',
    ];
    sheet.appendRow(headers.map(TextCellValue.new).toList());
    for (final pair in result.pairs) {
      sheet.appendRow(
        _matchingRow(
          status: pair.status,
          reason: pair.reason,
          score: pair.score,
          left: pair.left,
          right: pair.right,
        ),
      );
    }
    for (final right in result.unmatchedRight) {
      sheet.appendRow(
        _matchingRow(
          status: MatchStatus.unmatched,
          reason: 'غير موجودة في دفاتر الشركة',
          score: 0,
          left: null,
          right: right,
        ),
      );
    }
    ExcelReportStyle.styleTable(
      sheet,
      headerRow: 0,
      lastRow: sheet.maxRows - 1,
      columnCount: headers.length,
      moneyColumns: const {6, 7, 8, 12, 13, 14},
      centeredColumns: const {0, 2, 3, 4, 9, 10},
      widths: const [
        18,
        34,
        15,
        16,
        20,
        38,
        17,
        17,
        18,
        16,
        20,
        38,
        17,
        17,
        18,
      ],
    );
  }

  List<CellValue> _matchingRow({
    required MatchStatus status,
    required String reason,
    required double score,
    required TransactionRecord? left,
    required TransactionRecord? right,
  }) =>
      [
        TextCellValue(_statusLabel(status)),
        TextCellValue(reason),
        TextCellValue('${score.toStringAsFixed(1)}%'),
        ..._transactionCells(left),
        ..._transactionCells(right),
      ];

  List<CellValue> _transactionCells(TransactionRecord? item) => [
        TextCellValue(item == null ? '' : _date(item.date)),
        TextCellValue(item?.documentNumber?.trim() ?? ''),
        TextCellValue(item?.description ?? ''),
        item?.side == EntrySide.debit
            ? DoubleCellValue(item!.amount)
            : TextCellValue(''),
        item?.side == EntrySide.credit
            ? DoubleCellValue(item!.amount)
            : TextCellValue(''),
        item?.balance == null
            ? TextCellValue('')
            : DoubleCellValue(item!.balance!),
      ];

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
      TextCellValue(''),
      growable: false,
    );
    totalValues[2] = TextCellValue('الإجمالي');
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

  String _statusLabel(MatchStatus status) => switch (status) {
        MatchStatus.matched => 'متطابقة',
        MatchStatus.pending => 'معلقة للمراجعة',
        MatchStatus.unmatched => 'غير متطابقة',
      };

  String _ruleLabel(DocumentMismatchRule rule) => switch (rule) {
        DocumentMismatchRule.unmatched => 'اعتبارها غير مطابقة',
        DocumentMismatchRule.pending => 'اعتبارها معلقة للمراجعة',
        DocumentMismatchRule.matchedWithNote => 'اعتبارها مطابقة مع ملاحظة',
      };
}

class _SummaryLine {
  const _SummaryLine({required this.label, required this.amount});

  final String label;
  final double amount;
}
