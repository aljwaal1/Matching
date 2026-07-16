import 'dart:io';
import 'dart:typed_data';

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
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF176B5B),
          ),
          scaffoldBackgroundColor: const Color(0xFFF5F8F7),
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
              onPressed: () => Navigator.push(
                context,
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
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'ارفع كشفين بصيغة XLSX أو CSV أو PDF نصي. عند تعذر التعرف على الأعمدة سيطلب منك التطبيق تحديدها.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 18),
            _TypeCard(
              icon: Icons.people_alt_outlined,
              title: 'مطابقة العملاء والموردين',
              subtitle: 'يشترط أن يقابل المدين الدائن والعكس.',
              onTap: () => _open(context, ReconciliationMode.parties),
            ),
            const SizedBox(height: 14),
            _TypeCard(
              icon: Icons.account_balance_outlined,
              title: 'مطابقة كشف البنك',
              subtitle:
                  'مطابقة كشف البنك مع السجل المحاسبي حسب المستند أو المبلغ والتاريخ.',
              onTap: () => _open(context, ReconciliationMode.bank),
            ),
          ],
        ),
      );

  void _open(BuildContext context, ReconciliationMode mode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: SetupScreen(mode: mode),
        ),
      ),
    );
  }
}

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.mode});

  final ReconciliationMode mode;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _importer = FileImportService();
  ImportedStatement? _first;
  ImportedStatement? _second;
  bool _busy = false;
  int _days = 3;

  String get title => widget.mode == ReconciliationMode.bank
      ? 'مطابقة كشف البنك'
      : 'مطابقة العملاء والموردين';

  Future<void> _pick(bool first) async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'csv', 'tsv', 'txt', 'pdf'],
        allowMultiple: false,
        withData: true,
      );
    } catch (error) {
      _message('تعذر فتح مدير الملفات: $error');
      return;
    }
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    setState(() => _busy = true);
    try {
      Uint8List? bytes = file.bytes;
      if ((bytes == null || bytes.isEmpty) && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) {
        throw const FormatException(
          'تعذر الوصول إلى بيانات الملف من الجهاز.',
        );
      }

      final prepared = _importer.prepareBytes(
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

      if (!mounted) return;
      setState(() => first ? _first = imported : _second = imported);
      _message(
        'تم استيراد ${imported.records.length} عملية من ${file.name}'
        '${imported.skippedRows.isEmpty ? '' : '، وتجاهل ${imported.skippedRows.length} صف'}',
      );
    } on FormatException catch (error) {
      _message(error.message.toString());
    } catch (error) {
      _message('تعذر قراءة الملف: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<EntrySide?> _askDirectAmountSide(String fileName) =>
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

  Future<ColumnMapping?> _askMapping(PreparedStatement prepared) async {
    int? date;
    int? document;
    int? amount;
    int? debit;
    int? credit;
    int? description;
    var directAmountSide = EntrySide.unknown;

    return showDialog<ColumnMapping>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          DropdownButtonFormField<int?> field(
            String label,
            int? value,
            ValueChanged<int?> onChanged, {
            bool isRequired = false,
          }) =>
              DropdownButtonFormField<int?>(
                initialValue: value,
                decoration: InputDecoration(labelText: label),
                items: [
                  if (!isRequired)
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('غير مستخدم'),
                    ),
                  ...List.generate(
                    prepared.headers.length,
                    (index) => DropdownMenuItem<int?>(
                      value: index,
                      child: Text(
                        '${index + 1} - ${prepared.headers[index]}',
                      ),
                    ),
                  ),
                ],
                onChanged: onChanged,
              );

          return AlertDialog(
            title: const Text('تحديد الأعمدة يدويًا'),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  field(
                    'عمود التاريخ',
                    date,
                    (value) => setLocal(() => date = value),
                    isRequired: true,
                  ),
                  field(
                    'رقم المستند',
                    document,
                    (value) => setLocal(() => document = value),
                  ),
                  field(
                    'المبلغ المباشر',
                    amount,
                    (value) => setLocal(() => amount = value),
                  ),
                  DropdownButtonFormField<EntrySide>(
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
                  field(
                    'المدين',
                    debit,
                    (value) => setLocal(() => debit = value),
                  ),
                  field(
                    'الدائن',
                    credit,
                    (value) => setLocal(() => credit = value),
                  ),
                  field(
                    'البيان',
                    description,
                    (value) => setLocal(() => description = value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: date == null ||
                        (amount == null && debit == null && credit == null)
                    ? null
                    : () => Navigator.pop(
                          context,
                          ColumnMapping(
                            date: date!,
                            document: document,
                            amount: amount,
                            debit: debit,
                            credit: credit,
                            description: description,
                            directAmountSide: directAmountSide,
                          ),
                        ),
                child: const Text('اعتماد'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _match() async {
    if (_first == null || _second == null) {
      _message('اختر الملفين أولاً.');
      return;
    }

    setState(() => _busy = true);
    try {
      final left = _first!.records;
      final right = _second!.records;
      final settings = ReconciliationSettings(
        allowedDateDifferenceDays: _days,
        mode: widget.mode,
      );
      final result = const ReconciliationEngine().reconcile(
        left: left,
        right: right,
        settings: settings,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Directionality(
            textDirection: TextDirection.rtl,
            child: ResultsScreen(
              mode: widget.mode,
              firstName: _first!.fileName,
              secondName: _second!.fileName,
              result: result,
            ),
          ),
        ),
      );
    } catch (error) {
      _message('تعذر إكمال المطابقة: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _FileCard(
                  number: 1,
                  label: 'كشف الطرف الأول',
                  statement: _first,
                  onTap: () => _pick(true),
                ),
                const SizedBox(height: 12),
                _FileCard(
                  number: 2,
                  label: 'كشف الطرف الثاني',
                  statement: _second,
                  onTap: () => _pick(false),
                ),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'فرق التاريخ المسموح',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('حتى $_days أيام'),
                        Slider(
                          value: _days.toDouble(),
                          min: 0,
                          max: 3,
                          divisions: 3,
                          onChanged: (value) =>
                              setState(() => _days = value.round()),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _busy ? null : _match,
                  icon: const Icon(Icons.compare_arrows),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('بدء المطابقة'),
                  ),
                ),
              ],
            ),
            if (_busy)
              const ColoredBox(
                color: Color(0x44000000),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      );
}

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({
    super.key,
    required this.mode,
    required this.firstName,
    required this.secondName,
    required this.result,
    this.savedId,
    this.savedName,
  });

  final ReconciliationMode mode;
  final String firstName;
  final String secondName;
  final ReconciliationResult result;
  final String? savedId;
  final String? savedName;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final _export = ExportService();
  final _archive = ArchiveService();
  bool _busy = false;
  String? _savedId;
  String? _savedName;
  bool _showMatched = true;
  bool _showUnmatched = true;

  @override
  void initState() {
    super.initState();
    _savedId = widget.savedId;
    _savedName = widget.savedName;
  }

  Future<String?> _askName() async {
    final controller = TextEditingController(
      text: _savedName ??
          'مطابقة ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اسم النتيجة'),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim()),
            child: const Text('اعتماد'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result == null || result.isEmpty ? null : result;
  }

  Future<void> _save() async {
    final name = await _askName();
    if (name == null) return;

    setState(() => _busy = true);
    try {
      final id = _savedId ?? '${DateTime.now().microsecondsSinceEpoch}';
      await _archive.save(
        ArchivedReconciliation(
          id: id,
          name: name,
          type: widget.mode.name,
          createdAt: DateTime.now(),
          firstName: widget.firstName,
          secondName: widget.secondName,
          result: widget.result,
        ),
      );
      if (!mounted) return;
      setState(() {
        _savedId = id;
        _savedName = name;
      });
      _message('تم حفظ النتيجة في الأرشيف.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _doExport(bool pdf) async {
    final name = _savedName ?? await _askName();
    if (name == null) return;

    setState(() => _busy = true);
    try {
      if (pdf) {
        await _export.exportPdf(
          name: name,
          firstName: widget.firstName,
          secondName: widget.secondName,
          result: widget.result,
        );
      } else {
        await _export.exportExcel(
          name: name,
          firstName: widget.firstName,
          secondName: widget.secondName,
          result: widget.result,
        );
      }
    } catch (error) {
      _message('تعذر التصدير: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final allRows = <_DisplayRow>[
      ...widget.result.pairs.map(
        (pair) => _DisplayRow(
          left: pair.left,
          right: pair.right,
          status: pair.status,
          reason: pair.reason,
        ),
      ),
      ...widget.result.unmatchedRight.map(
        (item) => _DisplayRow(
          left: null,
          right: item,
          status: MatchStatus.unmatched,
          reason: 'غير موجودة في الطرف الأول',
        ),
      ),
    ];
    final rows = allRows
        .where(
          (row) =>
              (row.status == MatchStatus.matched && _showMatched) ||
              (row.status == MatchStatus.unmatched && _showUnmatched),
        )
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: Text(_savedName ?? 'نتيجة المطابقة')),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Text(
                          '${widget.firstName} ↔ ${widget.secondName}',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'متطابقة: ${widget.result.matchedCount} — '
                          'غير متطابقة: ${widget.result.unmatchedCount}',
                        ),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilterChip(
                              label: const Text('المتطابقة'),
                              selected: _showMatched,
                              onSelected: (value) =>
                                  setState(() => _showMatched = value),
                            ),
                            FilterChip(
                              label: const Text('غير المتطابقة'),
                              selected: _showUnmatched,
                              onSelected: (value) =>
                                  setState(() => _showUnmatched = value),
                            ),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _save,
                              icon: const Icon(Icons.archive_outlined),
                              label: Text(
                                _savedId == null
                                    ? 'حفظ بالأرشيف'
                                    : 'تعديل الاسم',
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : () => _doExport(false),
                              icon: const Icon(Icons.table_view),
                              label: const Text('Excel'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : () => _doExport(true),
                              icon: const Icon(Icons.picture_as_pdf),
                              label: const Text('PDF'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, index) => _ResultCard(row: rows[index]),
                ),
              ),
            ],
          ),
          if (_busy)
            const ColoredBox(
              color: Color(0x44000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class ArchiveHomeScreen extends StatelessWidget {
  const ArchiveHomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('أرشيف المطابقات')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _TypeCard(
              icon: Icons.account_balance_outlined,
              title: 'أرشيف مطابقات البنك',
              subtitle: 'النتائج المحفوظة لمطابقات البنك.',
              onTap: () => _open(context, ReconciliationMode.bank),
            ),
            const SizedBox(height: 14),
            _TypeCard(
              icon: Icons.people_alt_outlined,
              title: 'أرشيف العملاء والموردين',
              subtitle: 'النتائج المحفوظة لمطابقات العملاء والموردين.',
              onTap: () => _open(context, ReconciliationMode.parties),
            ),
          ],
        ),
      );

  void _open(BuildContext context, ReconciliationMode mode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: ArchiveListScreen(mode: mode),
        ),
      ),
    );
  }
}

class ArchiveListScreen extends StatefulWidget {
  const ArchiveListScreen({super.key, required this.mode});

  final ReconciliationMode mode;

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

  void _reload() => _items = _service.load(type: widget.mode.name);

  Future<void> _delete(ArchivedReconciliation item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف النتيجة'),
        content: Text('هل تريد حذف «${item.name}»؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.delete(item.id);
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('النتائج المحفوظة')),
        body: FutureBuilder<List<ArchivedReconciliation>>(
          future: _items,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('تعذر فتح الأرشيف: ${snapshot.error}'));
            }
            final items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return const Center(child: Text('لا توجد نتائج محفوظة.'));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  child: ListTile(
                    title: Text(item.name),
                    subtitle: Text(
                      '${DateFormat('yyyy/MM/dd HH:mm').format(item.createdAt)}\n'
                      'متطابقة: ${item.result.matchedCount} — '
                      'غير متطابقة: ${item.result.unmatchedCount}',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(item),
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Directionality(
                            textDirection: TextDirection.rtl,
                            child: ResultsScreen(
                              mode: widget.mode,
                              firstName: item.firstName,
                              secondName: item.secondName,
                              result: item.result,
                              savedId: item.id,
                              savedName: item.name,
                            ),
                          ),
                        ),
                      );
                      if (mounted) setState(_reload);
                    },
                  ),
                );
              },
            );
          },
        ),
      );
}

class _DisplayRow {
  const _DisplayRow({
    required this.left,
    required this.right,
    required this.status,
    required this.reason,
  });

  final TransactionRecord? left;
  final TransactionRecord? right;
  final MatchStatus status;
  final String reason;
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.row});

  final _DisplayRow row;

  @override
  Widget build(BuildContext context) {
    final matched = row.status == MatchStatus.matched;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: matched
            ? const Color(0xFFDCF5E8)
            : const Color(0xFFFFE1E1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.reason,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const Divider(),
          if (row.left != null) _record('الطرف الأول', row.left!),
          if (row.left != null && row.right != null)
            const SizedBox(height: 8),
          if (row.right != null) _record('الطرف الثاني', row.right!),
        ],
      ),
    );
  }

  Widget _record(String label, TransactionRecord item) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(
            '${DateFormat('yyyy/MM/dd').format(item.date)} — '
            '${item.amount.toStringAsFixed(2)} — ${item.sideLabel}',
          ),
          if ((item.documentNumber ?? '').isNotEmpty)
            Text('المستند: ${item.documentNumber}'),
          if (item.description.isNotEmpty) Text(item.description),
        ],
      );
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(child: Icon(icon)),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.arrow_back_ios_new),
          onTap: onTap,
        ),
      );
}

class _FileCard extends StatelessWidget {
  const _FileCard({
    required this.number,
    required this.label,
    required this.statement,
    required this.onTap,
  });

  final int number;
  final String label;
  final ImportedStatement? statement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(14),
          leading: CircleAvatar(
            child: statement == null ? Text('$number') : const Icon(Icons.check),
          ),
          title: Text(statement?.fileName ?? label),
          subtitle: Text(
            statement == null
                ? 'اضغط لاختيار الملف'
                : '${statement!.records.length} عملية',
          ),
          trailing: const Icon(Icons.upload_file),
          onTap: onTap,
        ),
      );
}
