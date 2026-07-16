from pathlib import Path

path = Path('lib/main.dart')
source = path.read_text(encoding='utf-8')

import_marker = "import 'services/reconciliation_engine.dart';\n"
imports = "import 'screens/bank_reconciliation_screen.dart';\nimport 'screens/column_mapping_screen.dart';\n"
if imports not in source:
    source = source.replace(import_marker, import_marker + imports, 1)

start = source.index('  Future<ColumnMapping?> _askMapping(')
end = source.index('  Future<void> _match()', start)
replacement = '''  Future<ColumnMapping?> _askMapping(
    PreparedStatement prepared, {
    ColumnMapping? initial,
    required String statementLabel,
  }) =>
      Navigator.push<ColumnMapping>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => Directionality(
            textDirection: TextDirection.rtl,
            child: ColumnMappingScreen(
              prepared: prepared,
              initial: initial,
              statementLabel: statementLabel,
            ),
          ),
        ),
      );

'''
source = source[:start] + replacement + source[end:]

wrap_marker = '''                            FilterChip(
                              label: const Text('غير المتطابقة'),
                              selected: _showUnmatched,
                              onSelected: (value) =>
                                  setState(() => _showUnmatched = value),
                            ),
'''
bank_button = wrap_marker + '''                            if (widget.mode == ReconciliationMode.bank)
                              FilledButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => Directionality(
                                              textDirection: TextDirection.rtl,
                                              child: BankReconciliationScreen(
                                                firstName: widget.firstName,
                                                secondName: widget.secondName,
                                                result: widget.result,
                                              ),
                                            ),
                                          ),
                                        ),
                                icon: const Icon(Icons.account_balance_wallet_rounded),
                                label: const Text('إعداد التسوية البنكية'),
                              ),
'''
if bank_button not in source:
    if wrap_marker not in source:
        raise SystemExit('Results actions marker not found')
    source = source.replace(wrap_marker, bank_button, 1)

path.write_text(source, encoding='utf-8')
print('Integrated responsive column mapping and bank reconciliation')
