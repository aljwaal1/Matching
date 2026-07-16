from pathlib import Path

service_path = Path('lib/services/file_import_service.dart')
service = service_path.read_text(encoding='utf-8')

service = service.replace(
    "    this.description,\n  });",
    "    this.description,\n    this.directAmountSide = EntrySide.unknown,\n  });",
    1,
)
service = service.replace(
    "  final int? description;\n\n  bool get hasAmountSource",
    "  final int? description;\n  final EntrySide directAmountSide;\n\n  bool get hasAmountSource",
    1,
)
service = service.replace(
    "        if (direct != null && direct != 0) {\n          movementAmount = direct.abs();",
    "        if (direct != null && direct != 0) {\n          movementAmount = direct.abs();\n          side = mapping.directAmountSide;",
    1,
)
service_path.write_text(service, encoding='utf-8')

main_path = Path('lib/main.dart')
main = main_path.read_text(encoding='utf-8')

old_import = """      ImportedStatement imported;
      try {
        imported = _importer.importBytes(
          fileName: file.name,
          bytes: bytes,
        );
      } on ColumnDetectionException catch (error) {
        final mapping = await _askMapping(error.prepared);
        if (mapping == null) return;
        imported = _importer.buildStatement(error.prepared, mapping);
      }
"""
new_import = """      final prepared = _importer.prepareBytes(
        fileName: file.name,
        bytes: bytes,
      );
      var mapping = prepared.suggestedMapping ?? await _askMapping(prepared);
      if (mapping == null) return;

      final usesDirectAmount = mapping.amount != null &&
          mapping.debit == null &&
          mapping.credit == null;
      if (widget.mode == ReconciliationMode.parties && usesDirectAmount) {
        final selectedSide = await _askDirectAmountSide(file.name);
        if (selectedSide == null) return;
        mapping = ColumnMapping(
          date: mapping.date,
          document: mapping.document,
          amount: mapping.amount,
          debit: mapping.debit,
          credit: mapping.credit,
          description: mapping.description,
          directAmountSide: selectedSide,
        );
      }

      final imported = _importer.buildStatement(prepared, mapping);
"""
if old_import not in main:
    raise SystemExit('Import flow marker not found')
main = main.replace(old_import, new_import, 1)

marker = "  Future<ColumnMapping?> _askMapping(PreparedStatement prepared) async {"
method = """  Future<EntrySide?> _askDirectAmountSide(String fileName) =>
      showDialog<EntrySide>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('تحديد جهة عمود المبلغ'),
          content: Text(
            'لم يحتوي ملف «$fileName» على عمودين منفصلين للمدين والدائن. '
            'حدد جهة عمود المبلغ في هذا الكشف.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, EntrySide.debit),
              child: const Text('المبلغ مدين'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, EntrySide.credit),
              child: const Text('المبلغ دائن'),
            ),
          ],
        ),
      );

"""
if marker not in main:
    raise SystemExit('Mapping dialog marker not found')
main = main.replace(marker, method + marker, 1)

main = main.replace(
    "    int? description;\n\n    return showDialog<ColumnMapping>(",
    "    int? description;\n    var directAmountSide = EntrySide.unknown;\n\n    return showDialog<ColumnMapping>(",
    1,
)

amount_field = """                  field(
                    'المبلغ المباشر',
                    amount,
                    (value) => setLocal(() => amount = value),
                  ),
"""
amount_with_side = amount_field + """                  DropdownButtonFormField<EntrySide>(
                    initialValue: directAmountSide,
                    decoration: const InputDecoration(
                      labelText: 'جهة عمود المبلغ المباشر',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: EntrySide.unknown,
                        child: Text('غير محدد'),
                      ),
                      DropdownMenuItem(
                        value: EntrySide.debit,
                        child: Text('مدين'),
                      ),
                      DropdownMenuItem(
                        value: EntrySide.credit,
                        child: Text('دائن'),
                      ),
                    ],
                    onChanged: (value) => setLocal(
                      () => directAmountSide = value ?? EntrySide.unknown,
                    ),
                  ),
"""
if amount_field not in main:
    raise SystemExit('Amount field marker not found')
main = main.replace(amount_field, amount_with_side, 1)

main = main.replace(
    "                            description: description,\n                          ),",
    "                            description: description,\n                            directAmountSide: directAmountSide,\n                          ),",
    1,
)

main_path.write_text(main, encoding='utf-8')
print('Applied direct amount side support')
