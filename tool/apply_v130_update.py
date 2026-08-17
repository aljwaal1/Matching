from pathlib import Path

path = Path('lib/main.dart')
text = path.read_text(encoding='utf-8')
original = text

# The validated 1.3.0 source is committed back to the branch after a successful
# build. Future builds must therefore treat an already-applied update as valid
# instead of failing because the original replacement anchors no longer exist.
if "const MatchingApp({super.key, this.home = const LaunchGate()});" in text:
    print('Matching 1.3.0 UI update already present; skipping patch.')
    raise SystemExit(0)


def replace_once(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, found {count}')
    text = text.replace(old, new, 1)


replace_once(
    "import 'package:intl/intl.dart' hide TextDirection;\n",
    "import 'package:intl/intl.dart' hide TextDirection;\nimport 'package:shared_preferences/shared_preferences.dart';\n",
    'shared_preferences import',
)
replace_once(
    "import 'services/bank_reconciliation_resume_service.dart';\n",
    "import 'services/bank_reconciliation_resume_service.dart';\nimport 'services/sample_bank_files_service.dart';\n",
    'sample service import',
)
replace_once(
    "import 'screens/support_screen.dart';\n",
    "import 'screens/support_screen.dart';\nimport 'screens/onboarding_screen.dart';\n",
    'onboarding import',
)
replace_once(
    "const MatchingApp({super.key, this.home = const HomeScreen()});",
    "const MatchingApp({super.key, this.home = const LaunchGate()});",
    'default launch gate',
)

launch_gate = r'''
class LaunchGate extends StatefulWidget {
  const LaunchGate({super.key});

  @override
  State<LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<LaunchGate> {
  static const _onboardingKey = 'onboarding_v1_completed';
  bool? _completed;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _completed = preferences.getBool(_onboardingKey) ?? false);
  }

  Future<void> _finishOnboarding() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_onboardingKey, true);
    if (!mounted) return;
    setState(() => _completed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_completed == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_completed == false) {
      return OnboardingScreen(onFinished: _finishOnboarding);
    }
    return const HomeScreen();
  }
}

'''
replace_once(
    'class HomeScreen extends StatefulWidget {',
    launch_gate + 'class HomeScreen extends StatefulWidget {',
    'launch gate insertion',
)

help_action = r'''            IconButton(
              tooltip: 'كيف يعمل التطبيق؟',
              icon: const Icon(Icons.help_outline),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Directionality(
                    textDirection: TextDirection.rtl,
                    child: OnboardingScreen(
                      allowSkip: false,
                      onFinished: () async => Navigator.pop(context),
                    ),
                  ),
                ),
              ),
            ),
'''
replace_once(
    "          actions: [\n            IconButton(\n              tooltip: 'سياسة الخصوصية',",
    "          actions: [\n" + help_action + "            IconButton(\n              tooltip: 'سياسة الخصوصية',",
    'help action',
)

parties_card = r'''            _TypeCard(
              icon: Icons.people_alt_outlined,
              title: 'مطابقة العملاء والموردين',
              subtitle: 'يشترط أن يقابل المدين الدائن والعكس.',
              onTap: () => _open(context, ReconciliationMode.parties),
            ),
            const SizedBox(height: 14),
'''
replace_once(parties_card, '', 'remove parties card')

replace_once(
    "class _SetupScreenState extends State<SetupScreen> {\n  final _importer = FileImportService();",
    "class _SetupScreenState extends State<SetupScreen> {\n  final _importer = FileImportService();\n  final _sampleFiles = const SampleBankFilesService();",
    'sample service field',
)

sample_methods = r'''
  Future<void> _loadSample() async {
    setState(() {
      _busy = true;
      _busyMessage = 'جاري تجهيز المثال التجريبي...';
    });
    try {
      final sample = await _sampleFiles.loadExample();
      if (!mounted) return;
      setState(() {
        _first = sample.books;
        _second = sample.bank;
      });
      _message('تم تحميل المثال التجريبي. يمكنك متابعة التسوية الآن.');
    } catch (error) {
      if (mounted) {
        await showOperationError(
          context,
          title: 'تعذر تحميل المثال',
          error: error,
          message: 'يمكنك الاستمرار باختيار ملفاتك يدويًا.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadSamples() async {
    setState(() {
      _busy = true;
      _busyMessage = 'جاري تجهيز الملفين التجريبيين...';
    });
    try {
      final saved = await _sampleFiles.downloadExamples();
      if (!mounted) return;
      final savedCount = saved.whereType<Object>().length;
      _message(savedCount == 2
          ? 'تم حفظ الملفين التجريبيين.'
          : 'تم حفظ $savedCount من الملفين التجريبيين.');
    } catch (error) {
      if (mounted) {
        await showOperationError(
          context,
          title: 'تعذر حفظ الملفات التجريبية',
          error: error,
          message: 'تحقق من مساحة التخزين ثم أعد المحاولة.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

'''
replace_once(
    '  Future<void> _pick(bool first) async {',
    sample_methods + '  Future<void> _pick(bool first) async {',
    'sample methods',
)

sample_card = r'''                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.science_outlined, color: Color(0xFF6D4CFF)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'جرّب قبل أن تبدأ',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'استخدم مثالًا جاهزًا داخل التطبيق أو نزّل الملفين التجريبيين لمشاهدة شكل البيانات المطلوبة.',
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: _busy ? null : _loadSample,
                          icon: const Icon(Icons.play_circle_outline),
                          label: const Text('تجربة مثال جاهز'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _downloadSamples,
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('تحميل الملفين التجريبيين'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
'''
replace_once(
    "              children: [\n                _FileCard(\n                  number: 1,\n                  label: firstStatementLabel,",
    "              children: [\n" + sample_card + "                _FileCard(\n                  number: 1,\n                  label: firstStatementLabel,",
    'sample card',
)

if text == original:
    raise SystemExit('No changes were applied')
path.write_text(text, encoding='utf-8')
print('Applied Matching 1.3.0 UI update to lib/main.dart')
