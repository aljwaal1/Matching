from pathlib import Path

service_path = Path('lib/services/file_import_service.dart')
service = service_path.read_text(encoding='utf-8')

if 'enum DirectAmountRule' not in service:
    service = service.replace(
        'class ColumnMapping {',
        '''enum DirectAmountRule {\n  unknown,\n  allDebit,\n  allCredit,\n  positiveDebitNegativeCredit,\n  positiveCreditNegativeDebit,\n}\n\nclass ColumnMapping {''',
        1,
    )

service = service.replace(
    '    this.directAmountSide = EntrySide.unknown,',
    '    this.directAmountRule = DirectAmountRule.unknown,',
    1,
)
service = service.replace(
    '  final EntrySide directAmountSide;',
    '  final DirectAmountRule directAmountRule;',
    1,
)
service = service.replace(
    '''        if (direct != null && direct != 0) {\n          movementAmount = direct.abs();\n          side = mapping.directAmountSide;''',
    '''        if (direct != null && direct != 0) {\n          movementAmount = direct.abs();\n          side = switch (mapping.directAmountRule) {\n            DirectAmountRule.allDebit => EntrySide.debit,\n            DirectAmountRule.allCredit => EntrySide.credit,\n            DirectAmountRule.positiveDebitNegativeCredit =>\n              direct > 0 ? EntrySide.debit : EntrySide.credit,\n            DirectAmountRule.positiveCreditNegativeDebit =>\n              direct > 0 ? EntrySide.credit : EntrySide.debit,\n            DirectAmountRule.unknown => EntrySide.unknown,\n          };''',
    1,
)
service_path.write_text(service, encoding='utf-8')

main_path = Path('lib/main.dart')
main = main_path.read_text(encoding='utf-8')

main = main.replace(
    '''        theme: ThemeData(\n          useMaterial3: true,\n          colorScheme: ColorScheme.fromSeed(\n            seedColor: const Color(0xFF176B5B),\n          ),\n          scaffoldBackgroundColor: const Color(0xFFF5F8F7),\n        ),''',
    '''        theme: ThemeData(\n          useMaterial3: true,\n          colorScheme: ColorScheme.fromSeed(\n            seedColor: const Color(0xFF175C52),\n            primary: const Color(0xFF175C52),\n            secondary: const Color(0xFFD79A24),\n            surface: Colors.white,\n          ),\n          scaffoldBackgroundColor: const Color(0xFFF1F6F5),\n          cardTheme: CardThemeData(\n            elevation: 0,\n            margin: EdgeInsets.zero,\n            shape: RoundedRectangleBorder(\n              borderRadius: BorderRadius.all(Radius.circular(22)),\n              side: BorderSide(color: Color(0xFFE0EBE8)),\n            ),\n          ),\n          appBarTheme: const AppBarTheme(\n            centerTitle: true,\n            backgroundColor: Color(0xFFF1F6F5),\n            foregroundColor: Color(0xFF163D37),\n            elevation: 0,\n          ),\n          inputDecorationTheme: InputDecorationTheme(\n            filled: true,\n            fillColor: Colors.white,\n            border: OutlineInputBorder(\n              borderRadius: BorderRadius.circular(16),\n              borderSide: const BorderSide(color: Color(0xFFD8E5E2)),\n            ),\n            enabledBorder: OutlineInputBorder(\n              borderRadius: BorderRadius.circular(16),\n              borderSide: const BorderSide(color: Color(0xFFD8E5E2)),\n            ),\n          ),\n        ),''',
    1,
)

main = main.replace(
    '        final selectedSide = await _askDirectAmountSide(file.name);',
    '        final selectedSide = await _askDirectAmountRule(file.name, prepared, mapping);',
    1,
)
main = main.replace(
    '          directAmountSide: selectedSide,',
    '          directAmountRule: selectedSide,',
    1,
)

start = main.index('  Future<EntrySide?> _askDirectAmountSide')
end = main.index('  Future<ColumnMapping?> _askMapping', start)
new_method = '''  Future<DirectAmountRule?> _askDirectAmountRule(\n    String fileName,\n    PreparedStatement prepared,\n    ColumnMapping mapping,\n  ) {\n    final values = prepared.rows\n        .map((row) => mapping.amount == null || mapping.amount! >= row.length\n            ? null\n            : row[mapping.amount!])\n        .where((value) => value != null && value.toString().trim().isNotEmpty)\n        .take(5)\n        .toList(growable: false);\n    final numeric = values\n        .map((value) => double.tryParse(\n              value.toString().replaceAll(',', '').replaceAll('(', '-').replaceAll(')', ''),\n            ))\n        .whereType<double>()\n        .toList(growable: false);\n    final hasPositive = numeric.any((value) => value > 0);\n    final hasNegative = numeric.any((value) => value < 0);\n\n    return showDialog<DirectAmountRule>(\n      context: context,\n      barrierDismissible: false,\n      builder: (context) => AlertDialog(\n        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),\n        title: Row(\n          children: const [\n            CircleAvatar(\n              backgroundColor: Color(0xFFE0F2EE),\n              child: Icon(Icons.rule_folder_outlined, color: Color(0xFF175C52)),\n            ),\n            SizedBox(width: 12),\n            Expanded(child: Text('تأكيد جهة المبالغ')),\n          ],\n        ),\n        content: SizedBox(\n          width: 440,\n          child: SingleChildScrollView(\n            child: Column(\n              crossAxisAlignment: CrossAxisAlignment.stretch,\n              children: [\n                Text(\n                  'ملف «$fileName» يحتوي عمود مبلغ واحد. راجع أول القيم ثم اختر القاعدة المحاسبية الصحيحة.',\n                ),\n                const SizedBox(height: 14),\n                Container(\n                  padding: const EdgeInsets.all(14),\n                  decoration: BoxDecoration(\n                    color: const Color(0xFFF3F8F7),\n                    borderRadius: BorderRadius.circular(18),\n                  ),\n                  child: Column(\n                    crossAxisAlignment: CrossAxisAlignment.start,\n                    children: [\n                      const Text('معاينة أول القيم', style: TextStyle(fontWeight: FontWeight.bold)),\n                      const SizedBox(height: 8),\n                      ...values.asMap().entries.map(\n                        (entry) => Padding(\n                          padding: const EdgeInsets.symmetric(vertical: 3),\n                          child: Text('${entry.key + 1}. ${entry.value}'),\n                        ),\n                      ),\n                    ],\n                  ),\n                ),\n                const SizedBox(height: 16),\n                if (hasPositive && hasNegative) ...[\n                  _RuleChoice(\n                    icon: Icons.north_east,\n                    title: 'الموجب مدين — السالب دائن',\n                    subtitle: 'تتحول القيمة إلى مبلغ موجب وتحفظ جهة كل صف حسب الإشارة.',\n                    onTap: () => Navigator.pop(\n                      context,\n                      DirectAmountRule.positiveDebitNegativeCredit,\n                    ),\n                  ),\n                  const SizedBox(height: 10),\n                  _RuleChoice(\n                    icon: Icons.south_west,\n                    title: 'الموجب دائن — السالب مدين',\n                    subtitle: 'استخدم هذا الخيار إذا كان نظام الكشف يعكس دلالة الإشارة.',\n                    onTap: () => Navigator.pop(\n                      context,\n                      DirectAmountRule.positiveCreditNegativeDebit,\n                    ),\n                  ),\n                ] else ...[\n                  _RuleChoice(\n                    icon: Icons.trending_up,\n                    title: 'كل المبالغ مدين',\n                    subtitle: 'استخدمه عندما يمثل هذا العمود حركات مدينة فقط.',\n                    onTap: () => Navigator.pop(context, DirectAmountRule.allDebit),\n                  ),\n                  const SizedBox(height: 10),\n                  _RuleChoice(\n                    icon: Icons.trending_down,\n                    title: 'كل المبالغ دائن',\n                    subtitle: 'استخدمه عندما يمثل هذا العمود حركات دائنة فقط.',\n                    onTap: () => Navigator.pop(context, DirectAmountRule.allCredit),\n                  ),\n                ],\n              ],\n            ),\n          ),\n        ),\n        actions: [\n          TextButton(\n            onPressed: () => Navigator.pop(context),\n            child: const Text('إلغاء'),\n          ),\n        ],\n      ),\n    );\n  }\n\n'''
main = main[:start] + new_method + main[end:]

main = main.replace(
    '    var directAmountSide = EntrySide.unknown;',
    '    var directAmountRule = DirectAmountRule.unknown;',
    1,
)
main = main.replace(
    'DropdownButtonFormField<EntrySide>(',
    'DropdownButtonFormField<DirectAmountRule>(',
    1,
)
main = main.replace('initialValue: directAmountSide,', 'initialValue: directAmountRule,', 1)
main = main.replace('value: EntrySide.unknown,', 'value: DirectAmountRule.unknown,', 1)
main = main.replace('value: EntrySide.debit,', 'value: DirectAmountRule.allDebit,', 1)
main = main.replace('value: EntrySide.credit,', 'value: DirectAmountRule.allCredit,', 1)
main = main.replace(
    '() => directAmountSide = value ?? EntrySide.unknown,',
    '() => directAmountRule = value ?? DirectAmountRule.unknown,',
    1,
)
main = main.replace('directAmountSide: directAmountSide,', 'directAmountRule: directAmountRule,', 1)

insert_at = main.index('class _TypeCard extends StatelessWidget')
rule_widget = '''class _RuleChoice extends StatelessWidget {\n  const _RuleChoice({\n    required this.icon,\n    required this.title,\n    required this.subtitle,\n    required this.onTap,\n  });\n\n  final IconData icon;\n  final String title;\n  final String subtitle;\n  final VoidCallback onTap;\n\n  @override\n  Widget build(BuildContext context) => Material(\n        color: const Color(0xFFFFFFFF),\n        borderRadius: BorderRadius.circular(18),\n        child: InkWell(\n          borderRadius: BorderRadius.circular(18),\n          onTap: onTap,\n          child: Container(\n            padding: const EdgeInsets.all(14),\n            decoration: BoxDecoration(\n              borderRadius: BorderRadius.circular(18),\n              border: Border.all(color: const Color(0xFFDCE8E5)),\n            ),\n            child: Row(\n              children: [\n                CircleAvatar(\n                  backgroundColor: const Color(0xFFFFF2D7),\n                  child: Icon(icon, color: const Color(0xFF9A6500)),\n                ),\n                const SizedBox(width: 12),\n                Expanded(\n                  child: Column(\n                    crossAxisAlignment: CrossAxisAlignment.start,\n                    children: [\n                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),\n                      const SizedBox(height: 3),\n                      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),\n                    ],\n                  ),\n                ),\n                const Icon(Icons.arrow_back_ios_new, size: 16),\n              ],\n            ),\n          ),\n        ),\n      );\n}\n\n'''
main = main[:insert_at] + rule_widget + main[insert_at:]

main_path.write_text(main, encoding='utf-8')
print('Applied signed amount rules and professional UI')
