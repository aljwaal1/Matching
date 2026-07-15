import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'models/transaction_record.dart';
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
    ),
    home: const Directionality(textDirection: TextDirection.rtl, child: HomeScreen()),
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('مطابقة الحسابات'), centerTitle: true),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('اختر نوع المطابقة ثم ارفع كشفين بصيغة Excel أو CSV أو PDF نصي.', textAlign: TextAlign.center))),
        const SizedBox(height: 18),
        _TypeCard(
          icon: Icons.people_alt_outlined,
          title: 'مطابقة العملاء والموردين',
          subtitle: 'مطابقة كشف العميل مع كشف المورد مهما اختلف ترتيب الأعمدة.',
          onTap: () => _open(context, 'مطابقة العملاء والموردين'),
        ),
        const SizedBox(height: 14),
        _TypeCard(
          icon: Icons.account_balance_outlined,
          title: 'مطابقة كشف البنك',
          subtitle: 'مطابقة كشف البنك مع السجل المحاسبي بفارق تاريخ مسموح.',
          onTap: () => _open(context, 'مطابقة كشف البنك'),
        ),
      ],
    ),
  );

  void _open(BuildContext context, String title) => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => Directionality(textDirection: TextDirection.rtl, child: SetupScreen(title: title))),
  );
}

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.title});
  final String title;
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _importer = FileImportService();
  ImportedStatement? _first;
  ImportedStatement? _second;
  bool _busy = false;
  int _days = 3;

  Future<void> _pick(bool first) async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx','xls','csv','tsv','txt','pdf'],
        allowMultiple: false,
        withData: true,
      );
    } catch (e) {
      _message('تعذر فتح مدير الملفات: $e');
      return;
    }
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final fileName = file.name;
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';

    setState(() => _busy = true);
    try {
      Uint8List? bytes = file.bytes;
      if ((bytes == null || bytes.isEmpty) && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) {
        throw Exception('تعذر الوصول إلى بيانات الملف من الجهاز. انقل الملف إلى ذاكرة الهاتف الداخلية ثم أعد المحاولة.');
      }
      final imported = _importer.importBytes(fileName: fileName, bytes: bytes);
      if (!mounted) return;
      setState(() => first ? _first = imported : _second = imported);
      final skipped = imported.skippedRows.isEmpty ? '' : '، وتم تجاهل ${imported.skippedRows.length} صف';
      _message('تم استيراد ${imported.records.length} عملية من $fileName$skipped.');
    } on FormatException catch (e) {
      _message('فشل قراءة "$fileName" (نوع: $ext): ${e.message}');
    } catch (e) {
      _message('فشل قراءة "$fileName" (نوع: $ext). تفاصيل الخطأ: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _match() {
    if (_first == null || _second == null) {
      _message('اختر الملفين أولاً.');
      return;
    }
    final result = const ReconciliationEngine().reconcile(
      left: _first!.records,
      right: _second!.records,
      settings: ReconciliationSettings(allowedDateDifferenceDays: _days),
    );
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: ResultsScreen(title: widget.title, firstName: _first!.fileName, secondName: _second!.fileName, result: result),
      ),
    ));
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 5)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _FileCard(number: 1, label: 'كشف الطرف الأول', statement: _first, onTap: () => _pick(true)),
            const SizedBox(height: 12),
            _FileCard(number: 2, label: 'كشف الطرف الثاني', statement: _second, onTap: () => _pick(false)),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('فرق التاريخ المسموح', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('حتى $_days أيام'),
                  Slider(value: _days.toDouble(), min: 0, max: 3, divisions: 3, label: '$_days', onChanged: (v) => setState(() => _days = v.round())),
                ]),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(onPressed: _busy ? null : _match, icon: const Icon(Icons.compare_arrows), label: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('بدء المطابقة'))),
          ],
        ),
        if (_busy) const ColoredBox(color: Color(0x44000000), child: Center(child: CircularProgressIndicator())),
      ],
    ),
  );
}

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key, required this.title, required this.firstName, required this.secondName, required this.result});
  final String title;
  final String firstName;
  final String secondName;
  final ReconciliationResult result;
  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final _export = ExportService();
  bool _busy = false;

  Future<void> _doExport(bool pdf) async {
    setState(() => _busy = true);
    try {
      final name = '${widget.title} ${DateFormat('yyyy-MM-dd HH-mm').format(DateTime.now())}';
      if (pdf) {
        await _export.exportPdf(name: name, result: widget.result);
      } else {
        await _export.exportExcel(name: name, result: widget.result);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر التصدير: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = <MatchPair>[
      ...widget.result.pairs,
      ...widget.result.unmatchedRight.map((r) => MatchPair(left: r, right: null, status: MatchStatus.unmatched, reason: 'غير موجودة في الطرف الأول', score: 0)),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('نتيجة المطابقة')),
      body: Stack(children: [
        Column(children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  Text('${widget.firstName} ↔ ${widget.secondName}', textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _CountBox(label: 'متطابقة', value: widget.result.matchedCount, color: const Color(0xFFDCF5E8))),
                    const SizedBox(width: 8),
                    Expanded(child: _CountBox(label: 'غير متطابقة', value: widget.result.unmatchedCount, color: const Color(0xFFFFE1E1))),
                  ]),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, children: [
                    OutlinedButton.icon(onPressed: () => _doExport(false), icon: const Icon(Icons.table_view), label: const Text('Excel')),
                    OutlinedButton.icon(onPressed: () => _doExport(true), icon: const Icon(Icons.picture_as_pdf), label: const Text('PDF')),
                  ]),
                ]),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(14,0,14,20),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _ResultCard(pair: rows[i]),
            ),
          ),
        ]),
        if (_busy) const ColoredBox(color: Color(0x44000000), child: Center(child: CircularProgressIndicator())),
      ]),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon; final String title; final String subtitle; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(child: ListTile(contentPadding: const EdgeInsets.all(16), leading: CircleAvatar(child: Icon(icon)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Padding(padding: const EdgeInsets.only(top: 6), child: Text(subtitle)), trailing: const Icon(Icons.arrow_back_ios_new), onTap: onTap));
}

class _FileCard extends StatelessWidget {
  const _FileCard({required this.number, required this.label, required this.statement, required this.onTap});
  final int number; final String label; final ImportedStatement? statement; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(child: ListTile(contentPadding: const EdgeInsets.all(14), leading: CircleAvatar(child: Text('$number')), title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(statement == null ? 'اضغط لاختيار الملف' : '${statement!.fileName}\n${statement!.records.length} عملية'), isThreeLine: statement != null, trailing: const Icon(Icons.upload_file), onTap: onTap));
}

class _CountBox extends StatelessWidget {
  const _CountBox({required this.label, required this.value, required this.color});
  final String label; final int value; final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)), child: Column(children: [Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), Text(label)]));
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.pair});
  final MatchPair pair;
  @override
  Widget build(BuildContext context) {
    final matched = pair.status == MatchStatus.matched;
    return Card(
      color: matched ? const Color(0xFFECF8F1) : const Color(0xFFFFEEEE),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(matched ? 'متطابقة' : 'غير متطابقة', style: TextStyle(fontWeight: FontWeight.bold, color: matched ? Colors.green.shade800 : Colors.red.shade800)),
          Text(pair.reason),
          const Divider(),
          Text('الطرف الأول: ${DateFormat('yyyy-MM-dd').format(pair.left.date)} | ${pair.left.amount.toStringAsFixed(2)} | ${pair.left.documentNumber ?? '-'}'),
          if (pair.right != null) Text('الطرف الثاني: ${DateFormat('yyyy-MM-dd').format(pair.right!.date)} | ${pair.right!.amount.toStringAsFixed(2)} | ${pair.right!.documentNumber ?? '-'}'),
        ]),
      ),
    );
  }
}
