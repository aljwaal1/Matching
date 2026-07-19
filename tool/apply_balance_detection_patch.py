from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected one match, found {count}')
    return text.replace(old, new, 1)


def patch_file_import() -> None:
    path = Path('lib/services/file_import_service.dart')
    text = path.read_text(encoding='utf-8')
    if 'final double? detectedBalance;' in text:
        return

    text = replace_once(
        text,
        "    this.credit,\n    this.description,",
        "    this.credit,\n    this.balance,\n    this.description,",
        'ColumnMapping constructor',
    )
    text = replace_once(
        text,
        "  final int? credit;\n  final int? description;",
        "  final int? credit;\n  final int? balance;\n  final int? description;",
        'ColumnMapping balance field',
    )
    text = replace_once(
        text,
        "    required this.records,\n    required this.skippedRows,",
        "    required this.records,\n    required this.skippedRows,\n    this.detectedBalance,\n    this.balanceRowNumber,",
        'ImportedStatement constructor',
    )
    text = replace_once(
        text,
        "  final List<TransactionRecord> records;\n  final List<SkippedRow> skippedRows;",
        "  final List<TransactionRecord> records;\n  final List<SkippedRow> skippedRows;\n  final double? detectedBalance;\n  final int? balanceRowNumber;",
        'ImportedStatement balance fields',
    )
    text = replace_once(
        text,
        "                credit: credit,\n                description:",
        "                credit: credit,\n                balance: balance,\n                description:",
        'suggested balance mapping',
    )
    text = replace_once(
        text,
        "    final records = <TransactionRecord>[];\n    final skipped = <SkippedRow>[];",
        "    final detectedBalance = _detectClosingBalance(prepared, mapping);\n    final records = <TransactionRecord>[];\n    final skipped = <SkippedRow>[];",
        'balance detection call',
    )
    text = replace_once(
        text,
        "      records: List.unmodifiable(records),\n      skippedRows: List.unmodifiable(skipped),",
        "      records: List.unmodifiable(records),\n      skippedRows: List.unmodifiable(skipped),\n      detectedBalance: detectedBalance?.value,\n      balanceRowNumber: detectedBalance?.rowNumber,",
        'ImportedStatement detected balance output',
    )
    helper = r'''
  _DetectedBalance? _detectClosingBalance(
    PreparedStatement prepared,
    ColumnMapping mapping,
  ) {
    final balanceColumn = mapping.balance;
    if (balanceColumn == null) return null;

    _DetectedBalance? selected;
    for (var index = 0; index < prepared.rows.length; index++) {
      final row = prepared.rows[index];
      final value = _amount(_cell(row, balanceColumn));
      if (value == null) continue;
      final date = _date(_cell(row, mapping.date));
      final candidate = _DetectedBalance(
        value: value,
        rowNumber: prepared.headerRowNumber + index + 1,
        date: date,
      );

      if (selected == null ||
          (candidate.date != null && selected.date == null) ||
          (candidate.date != null &&
              selected.date != null &&
              candidate.date!.isAfter(selected.date!)) ||
          (candidate.date == selected.date &&
              candidate.rowNumber > selected.rowNumber)) {
        selected = candidate;
      }
    }
    return selected;
  }

'''
    text = replace_once(
        text,
        "  List<List<dynamic>> _readXlsx(Uint8List bytes) {",
        helper + "  List<List<dynamic>> _readXlsx(Uint8List bytes) {",
        'balance helper insertion',
    )
    text += r'''

class _DetectedBalance {
  const _DetectedBalance({
    required this.value,
    required this.rowNumber,
    required this.date,
  });

  final double value;
  final int rowNumber;
  final DateTime? date;
}
'''
    path.write_text(text, encoding='utf-8')


def patch_mapping_screen() -> None:
    path = Path('lib/screens/column_mapping_screen.dart')
    text = path.read_text(encoding='utf-8')
    if 'int? _balance;' in text:
        return
    text = replace_once(
        text,
        "  int? _credit;\n  int? _description;",
        "  int? _credit;\n  int? _balance;\n  int? _description;",
        'mapping balance state',
    )
    text = replace_once(
        text,
        "    _credit = initial?.credit;\n    _description = initial?.description;",
        "    _credit = initial?.credit;\n    _balance = initial?.balance;\n    _description = initial?.description;",
        'mapping balance init',
    )
    card = """                    _mappingCard(\n                      'الرصيد',\n                      Icons.account_balance_wallet_outlined,\n                      _balance,\n                      false,\n                      (value) => setState(() => _balance = value),\n                      accent: const Color(0xFF8A5A00),\n                    ),\n"""
    text = replace_once(
        text,
        "                    _mappingCard(\n                      'المبلغ المباشر',",
        card + "                    _mappingCard(\n                      'المبلغ المباشر',",
        'balance mapping card',
    )
    text = replace_once(
        text,
        "        credit: _credit,\n        description: _description,",
        "        credit: _credit,\n        balance: _balance,\n        description: _description,",
        'mapping submit balance',
    )
    text = text.replace(
        'راجع الرؤوس والمعاينة، ثم عيّن التاريخ ومصدر المبلغ. اضغط على أي اسم عمود لعرضه كاملًا.',
        'راجع الرؤوس والمعاينة، ثم عيّن التاريخ ومصدر المبلغ وعمود الرصيد إن وجد. اضغط على أي اسم عمود لعرضه كاملًا.',
    )
    path.write_text(text, encoding='utf-8')


def patch_main() -> None:
    path = Path('lib/main.dart')
    text = path.read_text(encoding='utf-8')
    if 'this.firstDetectedBalance' in text:
        return
    text = replace_once(
        text,
        "          credit: mapping.credit,\n          description: mapping.description,",
        "          credit: mapping.credit,\n          balance: mapping.balance,\n          description: mapping.description,",
        'direct mapping balance',
    )
    text = replace_once(
        text,
        "              result: result,\n            ),",
        "              result: result,\n              firstDetectedBalance: _first!.detectedBalance,\n              secondDetectedBalance: _second!.detectedBalance,\n              firstBalanceRowNumber: _first!.balanceRowNumber,\n              secondBalanceRowNumber: _second!.balanceRowNumber,\n            ),",
        'pass balances to results',
    )
    text = replace_once(
        text,
        "    this.savedId,\n    this.savedName,",
        "    this.savedId,\n    this.savedName,\n    this.firstDetectedBalance,\n    this.secondDetectedBalance,\n    this.firstBalanceRowNumber,\n    this.secondBalanceRowNumber,",
        'ResultsScreen constructor balances',
    )
    text = replace_once(
        text,
        "  final String? savedId;\n  final String? savedName;",
        "  final String? savedId;\n  final String? savedName;\n  final double? firstDetectedBalance;\n  final double? secondDetectedBalance;\n  final int? firstBalanceRowNumber;\n  final int? secondBalanceRowNumber;",
        'ResultsScreen balance fields',
    )
    text = replace_once(
        text,
        "                                                result: widget.result,\n                                              ),",
        "                                                result: widget.result,\n                                                initialBookBalance:\n                                                    widget.firstDetectedBalance,\n                                                initialBankBalance:\n                                                    widget.secondDetectedBalance,\n                                                bookBalanceRowNumber:\n                                                    widget.firstBalanceRowNumber,\n                                                bankBalanceRowNumber:\n                                                    widget.secondBalanceRowNumber,\n                                              ),",
        'pass balances to bank screen',
    )
    text = replace_once(
        text,
        "        'تم استيراد ${imported.records.length} عملية من ${file.name}'\n        '${imported.skippedRows.isEmpty ? '' : '، وتجاهل ${imported.skippedRows.length} صف'}',",
        "        'تم استيراد ${imported.records.length} عملية من ${file.name}'\n        '${imported.detectedBalance == null ? '' : '، واكتشاف الرصيد ${NumberFormat('#,##0.00', 'en_US').format(imported.detectedBalance)} من الصف ${imported.balanceRowNumber}'}'\n        '${imported.skippedRows.isEmpty ? '' : '، وتجاهل ${imported.skippedRows.length} صف'}',",
        'import balance message',
    )
    path.write_text(text, encoding='utf-8')


def patch_bank_screen() -> None:
    path = Path('lib/screens/bank_reconciliation_screen.dart')
    text = path.read_text(encoding='utf-8')
    if 'this.initialBookBalance' in text:
        return
    text = replace_once(
        text,
        "    required this.result,\n  });",
        "    required this.result,\n    this.initialBookBalance,\n    this.initialBankBalance,\n    this.bookBalanceRowNumber,\n    this.bankBalanceRowNumber,\n  });",
        'bank screen constructor balance args',
    )
    text = replace_once(
        text,
        "  final ReconciliationResult result;",
        "  final ReconciliationResult result;\n  final double? initialBookBalance;\n  final double? initialBankBalance;\n  final int? bookBalanceRowNumber;\n  final int? bankBalanceRowNumber;",
        'bank screen balance fields',
    )
    text = replace_once(
        text,
        "    _accountController = TextEditingController(text: widget.secondName);",
        "    _accountController = TextEditingController(text: widget.secondName);\n    if (widget.initialBookBalance != null) {\n      _bookController.text = widget.initialBookBalance!.toStringAsFixed(2);\n    }\n    if (widget.initialBankBalance != null) {\n      _bankController.text = widget.initialBankBalance!.toStringAsFixed(2);\n    }",
        'prefill detected balances',
    )
    text = replace_once(
        text,
        "                  decoration: const InputDecoration(\n                    labelText: 'الرصيد حسب كشف البنك',\n                    prefixIcon: Icon(Icons.receipt_long_rounded),\n                  ),",
        "                  decoration: InputDecoration(\n                    labelText: 'الرصيد حسب كشف البنك',\n                    prefixIcon: const Icon(Icons.receipt_long_rounded),\n                    helperText: widget.initialBankBalance == null\n                        ? 'لم يُكتشف رصيد تلقائيًا؛ أدخله يدويًا.'\n                        : 'مكتشف تلقائيًا من الصف ${widget.bankBalanceRowNumber ?? '-'} ويمكن تعديله.',\n                    helperMaxLines: 2,\n                  ),",
        'bank balance helper',
    )
    text = replace_once(
        text,
        "                  decoration: const InputDecoration(\n                    labelText: 'الرصيد حسب دفاتر الشركة',\n                    prefixIcon: Icon(Icons.menu_book_rounded),\n                  ),",
        "                  decoration: InputDecoration(\n                    labelText: 'الرصيد حسب دفاتر الشركة',\n                    prefixIcon: const Icon(Icons.menu_book_rounded),\n                    helperText: widget.initialBookBalance == null\n                        ? 'لم يُكتشف رصيد تلقائيًا؛ أدخله يدويًا.'\n                        : 'مكتشف تلقائيًا من الصف ${widget.bookBalanceRowNumber ?? '-'} ويمكن تعديله.',\n                    helperMaxLines: 2,\n                  ),",
        'book balance helper',
    )
    path.write_text(text, encoding='utf-8')


def add_test() -> None:
    path = Path('test/balance_detection_test.dart')
    if path.exists():
        return
    path.write_text(r'''import 'dart:convert';
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
''', encoding='utf-8')


def main() -> None:
    patch_file_import()
    patch_mapping_screen()
    patch_main()
    patch_bank_screen()
    add_test()
    print('Balance auto-detection patch applied safely.')


if __name__ == '__main__':
    main()
