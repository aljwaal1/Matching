import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'models/transaction_record.dart';
import 'services/archive_service.dart';
import 'services/export_service.dart';
import 'services/file_import_service.dart';
import 'services/reconciliation_engine.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MatchingApp());
}

class MatchingApp extends StatelessWidget {
  const MatchingApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'مطابقة الحسابات',
        locale: const Locale('ar'),
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B5B)),
          scaffoldBackgroundColor: const Color(0xFFF5F8F7),
          cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
        ),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: HomeScreen(),
        ),
      );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('مطابقة الحسابات'),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'الأرشيف',
              icon: const Icon(Icons.inventory_2_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const Directionality(
                    textDirection: TextDirection.rtl,
                    child: ArchiveHomeScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const _WelcomeCard(),
              const SizedBox(height: 22),
              _MatchingTypeCard(
                icon: Icons.people_alt_outlined,
                title: 'مطابقة العملاء والموردين',
                subtitle: 'مطابقة كشفين مهما اختلف ترتيب الأعمدة بينهما.',
                onTap: () => _openSetup(context, 'مطابقة العملاء والموردين'),
              ),
              const SizedBox(height: 14),
              _MatchingTypeCard(
                icon: Icons.account_balance_outlined,
                title: 'مطابقة كشف البنك',
                subtitle: 'مطابقة كشف البنك مع السجل المحاسبي بفارق تاريخ مسموح.',
                onTap: () => _openSetup(context, 'مطابقة كشف البنك'),
              ),
              const SizedBox(height: 22),
              const _PrivacyNotice(),
            ],
          ),
        ),
      );

  void _openSetup(BuildContext context, String title) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: ReconciliationSetupScreen(title: title),
      ),
    ));
  }
}

class ReconciliationSetupScreen extends StatefulWidget {
  const ReconciliationSetupScreen({super.key, required this.title});
  final String title;

  @override
  State<ReconciliationSetupScreen> createState() => _ReconciliationSetupScreenState();
}

class _ReconciliationSetupScreenState extends State<ReconciliationSetupScreen> {
  final _importer = FileImportService();
  ImportedStatement? _first;
  ImportedStatement? _second;
  int _allowedDays = 3;
  bool _busy = false;

  Future<void> _pickFile(bool first) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'xls', 'csv', 'tsv', 'txt', 'pdf'],
      withData: true,
    );
    if (result == null) return;
    final file = result.files.single;
    if (file.bytes == null) return _message('تعذر قراءة الملف من الجهاز.');

    setState(() => _busy = true);
    try {
      final imported = _importer.importBytes(fileName: file.name, bytes: file.bytes!);
      if (!mounted) return;
      setState(() => first ? _first = imported : _second = imported);
      _message('تم استيراد ${imported.records.length} عملية من ${file.name}.');
    } on FormatException catch (error) {
      _message(error.message.toString());
    } catch (_) {
      _message('حدث خطأ أثناء قراءة الملف. تأكد من سلامة الصيغة.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startMatching() {
    if (_first == null || _second == null) {
      return _message('اختر الملفين أولاً لبدء المطابقة.');
    }
    setState(() => _busy = true);
    final result = const ReconciliationEngine().reconcile(
      left: _first!.records,
      right: _second!.records,
      settings: ReconciliationSettings(allowedDateDifferenceDays: _allowedDays),
    );
    setState(() => _busy = false);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: ResultsScreen(
          title: widget.title,
          firstName: _first!.fileName,
          secondName: _second!.fileName,
          result: result,
        ),
      ),
    ));
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Stack(children: [
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _FileSlot(number: 1, label: 'كشف الطرف الأول', statement: _first, onTap: () => _pickFile(true)),
              const SizedBox(height: 12),
              _FileSlot(number: 2, label: 'كشف الطرف الثاني', statement: _second, onTap: () => _pickFile(false)),
              const SizedBox(height: 20),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('فارق التاريخ المسموح', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('حتى $_allowedDays أيام'),
                    Slider(
                      value: _allowedDays.toDouble(),
                      min: 0,
                      max: 3,
                      divisions: 3,
                      label: '$_allowedDays',
                      onChanged: (value) => setState(() => _allowedDays = value.round()),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _busy ? null : _startMatching,
                icon: const Icon(Icons.compare_arrows_rounded),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('بدء المطابقة'),
                ),
              ),
            ],
          ),
          if (_busy)
            const ColoredBox(
              color: Color(0x33000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ]),
      );
}

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({
    super.key,
    required this.title,
    required this.firstName,
    required this.secondName,
    required this.result,
    this.savedName,
  });
  final String title;
  final String firstName;
  final String secondName;
  final ReconciliationResult result;
  final String? savedName;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final _exporter = ExportService();
  final _archive = ArchiveService();
  bool _busy = false;
  String? _savedName;

  @override
  void initState() {
    super.initState();
    _savedName = widget.savedName;
  }

  Future<String?> _askName() async {
    final controller = TextEditingController(text: _savedName ?? 'مطابقة ${DateFormat('yyyy-MM-dd').format(DateTime.now())}');
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اسم نتيجة المطابقة'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'اكتب اسم النتيجة')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('حفظ')),
        ],
      ),
    );
    controller.dispose();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> _saveArchive() async {
    final name = await _askName();
    if (name == null) return;
    setState(() => _busy = true);
    try {
      await _archive.save(ArchivedReconciliation(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        type: widget.title.contains('البنك') ? 'bank' : 'parties',
        createdAt: DateTime.now(),
        firstName: widget.firstName,
        secondName: widget.secondName,
        result: widget.result,
      ));
      if (!mounted) return;
      setState(() => _savedName = name);
      _message('تم حفظ النتيجة في الأرشيف.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export(bool pdf) async {
    final name = _savedName ?? await _askName();
    if (name == null) return;
    setState(() => _busy = true);
    try {
      if (pdf) {
        await _exporter.exportPdf(name: name, firstName: widget.firstName, secondName: widget.secondName, result: widget.result);
      } else {
        await _exporter.exportExcel(name: name, firstName: widget.firstName, secondName: widget.secondName, result: widget.result);
      }
    } catch (_) {
      if (mounted) _message('تعذر إنشاء التقرير.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final rows = <_ResultRow>[
      ...widget.result.pairs.map((pair) => _ResultRow(pair.left, pair.right, pair.status, pair.reason)),
      ...widget.result.unmatchedRight.map((item) => _ResultRow(null, item, MatchStatus.unmatched, 'غير موجود في الكشف الأول')),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(_savedName ?? 'نتيجة المطابقة')),
      body: Stack(children: [
        Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Text(widget.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('${widget.firstName}  ↔  ${widget.secondName}', textAlign: TextAlign.center),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: _SummaryBox(label: 'متطابقة', value: widget.result.matchedCount, color: const Color(0xFFDCF5E8))),
                    const SizedBox(width: 10),
                    Expanded(child: _SummaryBox(label: 'غير متطابقة', value: widget.result.unmatchedCount, color: const Color(0xFFFFE1E1))),
                  ]),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                    OutlinedButton.icon(onPressed: _saveArchive, icon: const Icon(Icons.archive_outlined), label: const Text('حفظ بالأرشيف')),
                    OutlinedButton.icon(onPressed: () => _export(false), icon: const Icon(Icons.table_view_outlined), label: const Text('Excel')),
                    OutlinedButton.icon(onPressed: () => _export(true), icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('PDF')),
                  ]),
                ]),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, index) => _ResultCard(row: rows[index]),
            ),
          ),
        ]),
        if (_busy) const ColoredBox(color: Color(0x33000000), child: Center(child: CircularProgressIndicator())),
      ]),
    );
  }
}

class ArchiveHomeScreen extends StatelessWidget {
  const ArchiveHomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('أرشيف المطابقات')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          _MatchingTypeCard(
            icon: Icons.account_balance_outlined,
            title: 'أرشيف مطابقات البنك',
            subtitle: 'نتائج مطابقة كشوف البنك المحفوظة.',
            onTap: () => _open(context, 'bank', 'أرشيف مطابقات البنك'),
          ),
          const SizedBox(height: 14),
          _MatchingTypeCard(
            icon: Icons.people_alt_outlined,
            title: 'أرشيف العملاء والموردين',
            subtitle: 'نتائج مطابقات العملاء والموردين المحفوظة.',
            onTap: () => _open(context, 'parties', 'أرشيف العملاء والموردين'),
          ),
        ]),
      );

  void _open(BuildContext context, String type, String title) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: ArchiveListScreen(type: type, title: title),
      ),
    ));
  }
}

class ArchiveListScreen extends StatefulWidget {
  const ArchiveListScreen({super.key, required this.type, required this.title});
  final String type;
  final String title;

  @override
  State<ArchiveListScreen> createState() => _ArchiveListScreenState();
}

class _ArchiveListScreenState extends State<ArchiveListScreen> {
  final _service = ArchiveService();
  late Future<List<ArchivedReconciliation>> _items;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _items = _service.load(type: widget.type);

  Future<void> _delete(ArchivedReconciliation item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف النتيجة'),
        content: Text('هل تريد حذف «${item.name}»؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.delete(item.id);
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: FutureBuilder<List<ArchivedReconciliation>>(
          future: _items,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snapshot.data ?? const [];
            if (items.isEmpty) return const Center(child: Text('لا توجد نتائج محفوظة.'));
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${DateFormat('yyyy/MM/dd HH:mm').format(item.createdAt)}\nمتطابقة: ${item.result.matchedCount} — غير متطابقة: ${item.result.unmatchedCount}'),
                    isThreeLine: true,
                    trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(item)),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => Directionality(
                        textDirection: TextDirection.rtl,
                        child: ResultsScreen(
                          title: item.type == 'bank' ? 'مطابقة كشف البنك' : 'مطابقة العملاء والموردين',
                          firstName: item.firstName,
                          secondName: item.secondName,
                          result: item.result,
                          savedName: item.name,
                        ),
                      ),
                    )),
                  ),
                );
              },
            );
          },
        ),
      );
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.row});
  final _ResultRow row;

  @override
  Widget build(BuildContext context) {
    final matched = row.status == MatchStatus.matched;
    final color = matched ? const Color(0xFFDCF5E8) : const Color(0xFFFFE1E1);
    final item = row.left ?? row.right!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(matched ? Icons.check_circle_outline : Icons.error_outline),
          const SizedBox(width: 8),
          Expanded(child: Text(row.reason, style: const TextStyle(fontWeight: FontWeight.bold))),
          Text(item.amount.toStringAsFixed(2)),
        ]),
        const SizedBox(height: 8),
        Text('التاريخ: ${DateFormat('yyyy/MM/dd').format(item.date)}'),
        if ((item.documentNumber ?? '').isNotEmpty) Text('رقم المستند: ${item.documentNumber}'),
        if (item.description.isNotEmpty) Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

class _ResultRow {
  const _ResultRow(this.left, this.right, this.status, this.reason);
  final TransactionRecord? left;
  final TransactionRecord? right;
  final MatchStatus status;
  final String reason;
}

class _SummaryBox extends StatelessWidget {
  const _SummaryBox({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label),
        ]),
      );
}

class _FileSlot extends StatelessWidget {
  const _FileSlot({required this.number, required this.label, required this.statement, required this.onTap});
  final int number;
  final String label;
  final ImportedStatement? statement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = statement != null;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(child: selected ? const Icon(Icons.check) : Text('$number')),
        title: Text(selected ? statement!.fileName : label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(selected ? '${statement!.records.length} عملية جاهزة للمطابقة' : 'Excel أو CSV أو PDF'),
        trailing: const Icon(Icons.upload_file_outlined),
        onTap: onTap,
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [colors.primary, colors.primaryContainer]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.rule_folder_outlined, size: 38, color: Colors.white),
        SizedBox(height: 12),
        Text('مطابقة أسرع ونتائج أوضح', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 6),
        Text('استورد كشفين ثم ابدأ المطابقة حسب رقم المستند أو المبلغ والتاريخ.', style: TextStyle(color: Colors.white, height: 1.5)),
      ]),
    );
  }
}

class _MatchingTypeCard extends StatelessWidget {
  const _MatchingTypeCard({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(18)),
                child: Icon(icon, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45)),
              ])),
              const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ]),
          ),
        ),
      );
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context) => const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.lock_outline_rounded, size: 20),
        SizedBox(width: 8),
        Expanded(child: Text('تتم معالجة كشوفات الحساب داخل جهازك ولا تُرفع إلى الإنترنت.')),
      ]);
}
