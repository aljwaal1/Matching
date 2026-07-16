from pathlib import Path

path = Path('lib/main.dart')
source = path.read_text(encoding='utf-8')

old_theme = '''        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF175C52),
            primary: const Color(0xFF175C52),
            secondary: const Color(0xFFD79A24),
            surface: Colors.white,
          ),
          scaffoldBackgroundColor: const Color(0xFFF1F6F5),
          cardTheme: CardThemeData(
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(22)),
              side: BorderSide(color: Color(0xFFE0EBE8)),
            ),
          ),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            backgroundColor: Color(0xFFF1F6F5),
            foregroundColor: Color(0xFF163D37),
            elevation: 0,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFD8E5E2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFD8E5E2)),
            ),
          ),
        ),'''
new_theme = '''        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6D4CFF),
            primary: const Color(0xFF6D4CFF),
            secondary: const Color(0xFFFF7A00),
            tertiary: const Color(0xFF00C2A8),
            surface: Colors.white,
          ),
          scaffoldBackgroundColor: const Color(0xFFF7F4FF),
          cardTheme: CardThemeData(
            elevation: 3,
            shadowColor: const Color(0x336D4CFF),
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(24)),
              side: BorderSide(color: Color(0xFFD9D0FF), width: 1.2),
            ),
          ),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            backgroundColor: Color(0xFF6D4CFF),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF7A00),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            labelStyle: const TextStyle(color: Color(0xFF5137CC)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFFCFC4FF)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFFCFC4FF)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFF00B8D9), width: 2),
            ),
          ),
        ),'''
if old_theme not in source:
    raise SystemExit('Theme marker not found')
source = source.replace(old_theme, new_theme, 1)

old_mapping_flow = '''      var mapping = prepared.suggestedMapping ?? await _askMapping(prepared);
      if (mapping == null) return;'''
new_mapping_flow = '''      var mapping = await _askMapping(
        prepared,
        initial: prepared.suggestedMapping,
        statementLabel: first ? 'الكشف الأول' : 'الكشف الثاني',
      );
      if (mapping == null) return;'''
if old_mapping_flow not in source:
    raise SystemExit('Mapping flow marker not found')
source = source.replace(old_mapping_flow, new_mapping_flow, 1)

old_signature = '''  Future<ColumnMapping?> _askMapping(PreparedStatement prepared) async {
    int? date;
    int? document;
    int? amount;
    int? debit;
    int? credit;
    int? description;
    var directAmountRule = DirectAmountRule.unknown;'''
new_signature = '''  Future<ColumnMapping?> _askMapping(
    PreparedStatement prepared, {
    ColumnMapping? initial,
    required String statementLabel,
  }) async {
    int? date = initial?.date;
    int? document = initial?.document;
    int? amount = initial?.amount;
    int? debit = initial?.debit;
    int? credit = initial?.credit;
    int? description = initial?.description;
    var directAmountRule =
        initial?.directAmountRule ?? DirectAmountRule.unknown;'''
if old_signature not in source:
    raise SystemExit('Mapping signature marker not found')
source = source.replace(old_signature, new_signature, 1)

old_title = "            title: const Text('تحديد الأعمدة يدويًا'),"
new_title = '''            title: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFE8E2FF),
                  child: Icon(Icons.view_column_rounded, color: Color(0xFF6D4CFF)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('مراجعة أعمدة $statementLabel')),
              ],
            ),'''
if old_title not in source:
    raise SystemExit('Mapping title marker not found')
source = source.replace(old_title, new_title, 1)

old_content = '''            content: SingleChildScrollView(
              child: Column(
                children: ['''
new_content = '''            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0E3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFB36B)),
                    ),
                    child: const Text(
                      'راجع الاختيارات المقترحة وعدّل أي عمود قبل اعتماد الكشف.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 14),'''
if old_content not in source:
    raise SystemExit('Mapping content marker not found')
source = source.replace(old_content, new_content, 1)

source = source.replace(
    "child: const Text('اعتماد'),",
    "child: const Text('اعتماد أعمدة الكشف'),",
    1,
)

path.write_text(source, encoding='utf-8')
print('Applied vivid UI and dual mapping review')
