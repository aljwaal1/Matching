from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"Expected one match in {path}, found {count}: {old[:80]!r}")
    file.write_text(text.replace(old, new, 1), encoding="utf-8")


# Load font bytes on the root isolate, then construct PDF fonts anywhere.
replace_once(
    "lib/services/arabic_pdf_support.dart",
    "import 'package:flutter/services.dart';\n",
    "import 'dart:typed_data';\n\nimport 'package:flutter/services.dart';\n",
)
replace_once(
    "lib/services/arabic_pdf_support.dart",
    """Future<ArabicPdfFonts> loadArabicPdfFonts() async {
  final regularData = await rootBundle.load(
    'assets/fonts/NotoNaskhArabic-Regular.ttf',
  );
  final boldData = await rootBundle.load(
    'assets/fonts/NotoNaskhArabic-Bold.ttf',
  );

  return ArabicPdfFonts(
    regular: pw.Font.ttf(ByteData.sublistView(regularData)),
    bold: pw.Font.ttf(ByteData.sublistView(boldData)),
  );
}
""",
    """class ArabicPdfFontData {
  const ArabicPdfFontData({required this.regular, required this.bold});

  final Uint8List regular;
  final Uint8List bold;
}

Future<ArabicPdfFontData> loadArabicPdfFontData() async {
  final regularData = await rootBundle.load(
    'assets/fonts/NotoNaskhArabic-Regular.ttf',
  );
  final boldData = await rootBundle.load(
    'assets/fonts/NotoNaskhArabic-Bold.ttf',
  );

  return ArabicPdfFontData(
    regular: Uint8List.sublistView(regularData),
    bold: Uint8List.sublistView(boldData),
  );
}

ArabicPdfFonts arabicPdfFontsFromData(ArabicPdfFontData data) => ArabicPdfFonts(
      regular: pw.Font.ttf(ByteData.sublistView(data.regular)),
      bold: pw.Font.ttf(ByteData.sublistView(data.bold)),
    );

Future<ArabicPdfFonts> loadArabicPdfFonts() async =>
    arabicPdfFontsFromData(await loadArabicPdfFontData());
""",
)

# The PDF builder must not dereference nullable archived fields.
replace_once(
    "lib/services/bank_reconciliation_pdf_builder.dart",
    """    required String bankName,
    required BankReconciliationStatement statement,
  }) async {
    final fonts = await loadArabicPdfFonts();
""",
    """    required String bankName,
    required BankReconciliationStatement statement,
    ArabicPdfFontData? fontData,
  }) async {
    final fonts = fontData == null
        ? await loadArabicPdfFonts()
        : arabicPdfFontsFromData(fontData);
""",
)
replace_once(
    "lib/services/bank_reconciliation_pdf_builder.dart",
    """    final carried = statement.items
        .where((item) => item.status == BankItemStatus.carryForward)
        .toList(growable: false);

    document.addPage(
""",
    """    final carried = statement.items
        .where((item) => item.status == BankItemStatus.carryForward)
        .toList(growable: false);
    final matchingResult = statement.matchingResult;

    document.addPage(
""",
)
replace_once(
    "lib/services/bank_reconciliation_pdf_builder.dart",
    """          if (statement.matchingResult != null) ...[
            pw.NewPage(),
            _matchingAnalysis(fonts, statement.matchingResult!),
          ],
""",
    """          if (matchingResult != null) ...[
            pw.NewPage(),
            _matchingAnalysis(fonts, matchingResult),
          ],
""",
)
replace_once(
    "lib/services/bank_reconciliation_pdf_builder.dart",
    """    final document = item.documentNumber?.trim();
    return 'التاريخ: ${_date(item.date)}\\n'
        'المستند: ${document == null || document.isEmpty ? '-' : document}\\n'
        'البيان: ${item.description.trim().isEmpty ? '-' : item.description}\\n'
        'المدين: ${item.side == EntrySide.debit ? _money(item.amount) : '0.00'}\\n'
        'الدائن: ${item.side == EntrySide.credit ? _money(item.amount) : '0.00'}\\n'
        'الرصيد: ${item.balance == null ? '-' : _money(item.balance!)}';
""",
    """    final document = item.documentNumber?.trim();
    final balance = item.balance;
    return 'التاريخ: ${_date(item.date)}\\n'
        'المستند: ${document == null || document.isEmpty ? '-' : document}\\n'
        'البيان: ${item.description.trim().isEmpty ? '-' : item.description}\\n'
        'المدين: ${item.side == EntrySide.debit ? _money(item.amount) : '0.00'}\\n'
        'الدائن: ${item.side == EntrySide.credit ? _money(item.amount) : '0.00'}\\n'
        'الرصيد: ${balance == null ? '-' : _money(balance)}';
""",
)

# Never call Flutter platform channels from the PDF worker isolate.
replace_once(
    "lib/services/bank_reconciliation_export_service.dart",
    "import 'package:flutter/foundation.dart';\nimport 'package:flutter/services.dart';\n",
    "import 'package:flutter/foundation.dart';\n",
)
replace_once(
    "lib/services/bank_reconciliation_export_service.dart",
    "import 'bank_reconciliation_excel_builder.dart';\n",
    "import 'arabic_pdf_support.dart';\nimport 'bank_reconciliation_excel_builder.dart';\n",
)
replace_once(
    "lib/services/bank_reconciliation_export_service.dart",
    """  Future<Uint8List> _buildPdfWithoutBlockingUi({
    required String companyName,
    required String bankName,
    required BankReconciliationStatement statement,
  }) async {
    final rootToken = RootIsolateToken.instance;
    if (kIsWeb ||
        rootToken == null ||
        pdfBuilder.runtimeType != BankReconciliationPdfBuilder) {
      return pdfBuilder.build(
        companyName: companyName,
        bankName: bankName,
        statement: statement,
      );
    }

    final statementJson = statement.toJson();
    return Isolate.run<Uint8List>(() async {
      BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);
      return const BankReconciliationPdfBuilder().build(
        companyName: companyName,
        bankName: bankName,
        statement: BankReconciliationStatement.fromJson(
          Map<String, dynamic>.from(statementJson),
        ),
      );
    });
  }
""",
    """  Future<Uint8List> _buildPdfWithoutBlockingUi({
    required String companyName,
    required String bankName,
    required BankReconciliationStatement statement,
  }) async {
    if (kIsWeb || pdfBuilder.runtimeType != BankReconciliationPdfBuilder) {
      return pdfBuilder.build(
        companyName: companyName,
        bankName: bankName,
        statement: statement,
      );
    }

    // rootBundle must stay on the root isolate. Only raw bytes and plain JSON
    // are passed to the worker, avoiding BackgroundIsolateBinaryMessenger null
    // failures seen after restoring an archived reconciliation.
    final fontData = await loadArabicPdfFontData();
    final regularFont = TransferableTypedData.fromList([fontData.regular]);
    final boldFont = TransferableTypedData.fromList([fontData.bold]);
    final statementJson = statement.toJson();

    return Isolate.run<Uint8List>(() async {
      final isolatedFonts = ArabicPdfFontData(
        regular: regularFont.materialize().asUint8List(),
        bold: boldFont.materialize().asUint8List(),
      );
      return const BankReconciliationPdfBuilder().build(
        companyName: companyName,
        bankName: bankName,
        statement: BankReconciliationStatement.fromJson(
          Map<String, dynamic>.from(statementJson),
        ),
        fontData: isolatedFonts,
      );
    });
  }
""",
)

# Persist an in-progress export so an older Android device can recover the same
# screen if the activity/process is recreated while the document picker is open.
Path("lib/services/bank_reconciliation_resume_service.dart").write_text(
    """import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/bank_reconciliation.dart';

class BankReconciliationResumeData {
  const BankReconciliationResumeData({
    required this.firstName,
    required this.secondName,
    required this.statement,
  });

  final String firstName;
  final String secondName;
  final BankReconciliationStatement statement;
}

class BankReconciliationResumeService {
  const BankReconciliationResumeService();

  static const _key = 'bank_reconciliation_export_resume_v1';

  Future<void> save({
    required String firstName,
    required String secondName,
    required BankReconciliationStatement statement,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _key,
      jsonEncode({
        'firstName': firstName,
        'secondName': secondName,
        'statement': statement.toJson(),
      }),
    );
    if (!saved) {
      throw StateError('تعذر حفظ حالة شاشة التسوية مؤقتًا.');
    }
  }

  Future<BankReconciliationResumeData?> take() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null) return null;
    await preferences.remove(_key);

    try {
      final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return BankReconciliationResumeData(
        firstName: json['firstName'] as String? ?? 'دفاتر الشركة',
        secondName: json['secondName'] as String? ?? 'كشف البنك',
        statement: BankReconciliationStatement.fromJson(
          Map<String, dynamic>.from(json['statement'] as Map),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key);
  }
}
""",
    encoding="utf-8",
)

replace_once(
    "lib/screens/bank_reconciliation_screen.dart",
    "import '../services/bank_reconciliation_export_service.dart';\n",
    "import '../services/bank_reconciliation_export_service.dart';\nimport '../services/bank_reconciliation_resume_service.dart';\n",
)
replace_once(
    "lib/screens/bank_reconciliation_screen.dart",
    """  final _exporter = BankReconciliationExportService();
  final _archive = BankReconciliationArchiveService();
""",
    """  final _exporter = BankReconciliationExportService();
  final _archive = BankReconciliationArchiveService();
  final _resumeService = const BankReconciliationResumeService();
""",
)
replace_once(
    "lib/screens/bank_reconciliation_screen.dart",
    """    try {
      final companyName = statement.bookSourceName.isEmpty
""",
    """    try {
      await _resumeService.save(
        firstName: widget.firstName,
        secondName: widget.secondName,
        statement: statement,
      );
      final companyName = statement.bookSourceName.isEmpty
""",
)
replace_once(
    "lib/screens/bank_reconciliation_screen.dart",
    """    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) {
""",
    """    } finally {
      // If this State still exists, Android returned to the same screen and the
      // recovery marker is no longer needed. If the route/process disappeared,
      // keep it so HomeScreen can reopen this exact reconciliation.
      if (mounted) {
        await _resumeService.clear();
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  void _message(String text) {
""",
)

# Resume an interrupted export only when HomeScreen is actually the visible route.
replace_once(
    "lib/main.dart",
    "import 'services/reconciliation_engine.dart';\n",
    "import 'services/reconciliation_engine.dart';\nimport 'services/bank_reconciliation_resume_service.dart';\n",
)
replace_once(
    "lib/main.dart",
    "class _HomeScreenState extends State<HomeScreen> {\n",
    "class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {\n",
)
replace_once(
    "lib/main.dart",
    """  BannerAd? _banner;
  bool _bannerLoaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.enableAds) _initializeBanner();
  }

  Future<void> _initializeBanner() async {
""",
    """  BannerAd? _banner;
  bool _bannerLoaded = false;
  bool _checkingResume = false;
  final _resumeService = const BankReconciliationResumeService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resumeInterruptedBankExport();
    });
    if (widget.enableAds) _initializeBanner();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resumeInterruptedBankExport();
      });
    }
  }

  Future<void> _resumeInterruptedBankExport() async {
    if (_checkingResume || !mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;

    _checkingResume = true;
    try {
      final data = await _resumeService.take();
      if (!mounted || data == null || ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      final result = data.statement.matchingResult ??
          const ReconciliationResult(pairs: [], unmatchedRight: []);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Directionality(
            textDirection: TextDirection.rtl,
            child: BankReconciliationScreen(
              firstName: data.firstName,
              secondName: data.secondName,
              result: result,
              documentMismatchRule: data.statement.documentMismatchRule,
              initialStatement: data.statement,
            ),
          ),
        ),
      );
    } finally {
      _checkingResume = false;
    }
  }

  Future<void> _initializeBanner() async {
""",
)
replace_once(
    "lib/main.dart",
    """  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }
""",
    """  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _banner?.dispose();
    super.dispose();
  }
""",
)

# A regression test for the exact archived-statement case reported from the phone.
Path("test/bank_reconciliation_archived_pdf_test.dart").write_text(
    """import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:matching/models/bank_reconciliation.dart';
import 'package:matching/services/bank_reconciliation_pdf_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('creates PDF from archived reconciliation without matching result', () async {
    final original = BankReconciliationStatement(
      accountName: 'الحساب البنكي',
      period: DateTime(2026, 7),
      bookBalance: 48088325.92,
      bankBalance: 40277467.62,
      items: const [],
      bookSourceName: 'دفاتر الشركة',
      bankSourceName: 'كشف البنك',
      matchingResult: null,
    );
    final archived = BankReconciliationStatement.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(jsonEncode(original.toJson())) as Map,
      ),
    );

    expect(archived.matchingResult, isNull);
    final bytes = await const BankReconciliationPdfBuilder().build(
      companyName: 'دفاتر الشركة',
      bankName: 'الحساب البنكي',
      statement: archived,
    );

    expect(bytes.length, greaterThan(100));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
""",
    encoding="utf-8",
)

replace_once(
    "pubspec.yaml",
    "version: 1.2.1+6\n",
    "version: 1.2.2+7\n",
)

# Remove this one-shot patch machinery from the resulting branch.
Path(".github/scripts/apply_archive_pdf_resume_fix.py").unlink(missing_ok=True)
Path(".github/workflows/apply-archive-pdf-resume-fix.yml").unlink(missing_ok=True)
