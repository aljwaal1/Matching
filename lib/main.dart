import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'models/transaction_record.dart';
import 'services/file_import_service.dart';
import 'services/reconciliation_engine.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MatchingApp());
}

class MatchingApp extends StatelessWidget {
  const MatchingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مطابقة الحسابات'), centerTitle: true),
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
  }

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
    if (file.bytes == null) {
      _message('تعذر قراءة الملف من الجهاز.');
      return;
    }

    setState(() => _busy = true);
    try {
      final imported = _importer.importBytes(fileName: file.name, bytes: file.bytes!);
      if (!mounted) return;
      setState(() {
        if (first) {
          _first = imported;
        } else {
          _second = imported;
        }
      });
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
      _message('اختر الملفين أولاً لبدء المطابقة.');
      return;
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

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _FileSlot(
                number: 1,
                label: 'كشف الطرف الأول',
                statement: _first,
                onTap: () => _pickFile(true),
              ),
              const SizedBox(height: 12),
              _FileSlot(
                number: 2,
                label: 'كشف الطرف الثاني',
                statement: _second,
                onTap: () => _pickFile(false),
              ),
              const SizedBox(height: 20),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                    ],
                  ),
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
        ],
      ),
    );
  }
}

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({
    super.key,
    required this.title,
    required this.firstName,
    required this.secondName,
    required this.result,
  });

  final String title;
  final String firstName;
  final String secondName;
  final ReconciliationResult result;

  @override
  Widget build(BuildContext context) {
    final rows = <_ResultRow>[
      ...result.pairs.map((pair) => _ResultRow(pair.left, pair.right, pair.status, pair.reason)),
      ...result.unmatchedRight.map((item) => _ResultRow(null, item, MatchStatus.unmatched, 'غير موجود في الكشف الأول')),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('نتيجة المطابقة')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('$firstName  ↔  $secondName', textAlign: TextAlign.center),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: _SummaryBox(label: 'متطابقة', value: result.matchedCount, color: const Color(0xFFDCF5E8))),
                        const SizedBox(width: 10),
                        Expanded(child: _SummaryBox(label: 'غير متطابقة', value: result.unmatchedCount, color: const Color(0xFFFFE1E1))),
                      ],
                    ),
                  ],
                ),
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
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.row});
  final _ResultRow row;

  @override
  Widget build(BuildContext context) {
    final matched = row.status == MatchStatus.matched;
    final color = matched ? const Color(0xFFDCF5E8) : const Color(0xFFFFE1E1);
    final item = row.left ?? row.right!;
    final date = DateFormat('yyyy/MM/dd').format(item.date);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(matched ? Icons.check_circle_outline : Icons.error_outline),
              const SizedBox(width: 8),
              Expanded(child: Text(row.reason, style: const TextStyle(fontWeight: FontWeight.bold))),
              Text(item.amount.toStringAsFixed(2)),
            ],
          ),
          const SizedBox(height: 8),
          Text('التاريخ: $date'),
          if ((item.documentNumber ?? '').isNotEmpty) Text('رقم المستند: ${item.documentNumber}'),
          if (item.description.isNotEmpty) Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label),
        ],
      ),
    );
  }
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.rule_folder_outlined, size: 38, color: Colors.white),
          SizedBox(height: 12),
          Text('مطابقة أسرع ونتائج أوضح', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text('استورد كشفين ثم ابدأ المطابقة حسب رقم المستند أو المبلغ والتاريخ.', style: TextStyle(color: Colors.white, height: 1.5)),
        ],
      ),
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
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(18)),
                child: Icon(icon, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline_rounded, size: 20),
        SizedBox(width: 8),
        Expanded(child: Text('تتم معالجة كشوفات الحساب داخل جهازك ولا تُرفع إلى الإنترنت.')),
      ],
    );
  }
}
