import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../models/bank_reconciliation.dart';
import '../models/transaction_record.dart';
import '../services/bank_reconciliation_archive_service.dart';
import '../services/bank_reconciliation_export_service.dart';
import '../services/bank_reconciliation_service.dart';

class BankReconciliationScreen extends StatefulWidget {
  const BankReconciliationScreen({
    super.key,
    required this.firstName,
    required this.secondName,
    required this.result,
  });

  final String firstName;
  final String secondName;
  final ReconciliationResult result;

  @override
  State<BankReconciliationScreen> createState() =>
      _BankReconciliationScreenState();
}

class _BankReconciliationScreenState extends State<BankReconciliationScreen> {
  final _bookController = TextEditingController();
  final _bankController = TextEditingController();
  late final TextEditingController _accountController;
  final _exporter = BankReconciliationExportService();
  final _archive = BankReconciliationArchiveService();
  final _service = const BankReconciliationService();
  DateTime _period = DateTime(DateTime.now().year, DateTime.now().month);
  BankReconciliationStatement? _statement;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _accountController = TextEditingController(text: widget.secondName);
  }

  @override
  void dispose() {
    _bookController.dispose();
    _bankController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statement = _statement;
    return Scaffold(
      appBar: AppBar(
        title: const Text('التسوية البنكية'),
        actions: [
          IconButton(
            tooltip: 'أرشيف التسويات',
            onPressed: _busy ? null : _openArchive,
            icon: const Icon(Icons.inventory_2_outlined),
          ),
        ],
      ),
      floatingActionButton: statement == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _busy ? null : _addManualItem,
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة بند'),
            ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            children: [
              _hero(),
              const SizedBox(height: 12),
              _inputCard(),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _calculate,
                icon: const Icon(Icons.calculate_rounded),
                label: const Text('إعداد تقرير التسوية البنكية'),
              ),
              if (statement != null) ...[
                const SizedBox(height: 14),
                _actionButtons(statement),
                const SizedBox(height: 14),
                _standardReport(statement),
                const SizedBox(height: 16),
                Text(
                  'تفاصيل بنود التسوية (${statement.items.length})',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (statement.items.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'لا توجد بنود غير متطابقة. يمكنك إضافة بند يدوي عند الحاجة.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ...statement.items.map(_itemCard),
              ],
            ],
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x44000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _hero() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00B8D9), Color(0xFF6D4CFF)],
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تقرير التسوية البنكية المحاسبي',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.firstName} ↔ ${widget.secondName}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );

  Widget _inputCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final fields = <Widget>[
                TextField(
                  controller: _accountController,
                  decoration: const InputDecoration(
                    labelText: 'اسم البنك أو الحساب',
                    prefixIcon: Icon(Icons.account_balance_rounded),
                  ),
                ),
                _monthField(),
                TextField(
                  controller: _bankController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'الرصيد حسب كشف البنك',
                    prefixIcon: Icon(Icons.receipt_long_rounded),
                  ),
                ),
                TextField(
                  controller: _bookController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'الرصيد حسب دفاتر الشركة',
                    prefixIcon: Icon(Icons.menu_book_rounded),
                  ),
                ),
              ];
              if (constraints.maxWidth >= 760) {
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: fields
                      .map(
                        (field) => SizedBox(
                          width: (constraints.maxWidth - 10) / 2,
                          child: field,
                        ),
                      )
                      .toList(growable: false),
                );
              }
              return Column(
                children: fields
                    .map(
                      (field) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: field,
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ),
      );

  Widget _monthField() => InkWell(
        onTap: _pickPeriod,
        borderRadius: BorderRadius.circular(18),
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'شهر التسوية',
            prefixIcon: Icon(Icons.calendar_month_rounded),
          ),
          child: Text(DateFormat('yyyy/MM').format(_period)),
        ),
      );

  Widget _actionButtons(BankReconciliationStatement statement) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: _busy ? null : () => _save(statement),
            icon: const Icon(Icons.save_rounded),
            label: const Text('حفظ التسوية'),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _loadPreviousPending,
            icon: const Icon(Icons.redo_rounded),
            label: const Text('استدعاء المعلّق السابق'),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _export(statement),
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('تصدير PDF'),
          ),
        ],
      );

  Widget _standardReport(BankReconciliationStatement statement) {
    final bankItems = statement.items
        .where((item) => item.adjustBankBalance && !item.cleared)
        .toList(growable: false);
    final bookItems = statement.items
        .where((item) => !item.adjustBankBalance && !item.cleared)
        .toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'تقرير التسوية عن شهر ${DateFormat('yyyy/MM').format(statement.period)}',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            _reportSection(
              title: 'أولًا: تسوية رصيد كشف البنك',
              openingLabel: 'الرصيد حسب كشف البنك',
              openingBalance: statement.bankBalance,
              items: bankItems,
              closingLabel: 'الرصيد المعدل حسب كشف البنك',
              closingBalance: statement.adjustedBankBalance,
              color: const Color(0xFF00A9C8),
            ),
            const SizedBox(height: 14),
            _reportSection(
              title: 'ثانيًا: تسوية رصيد دفاتر الشركة',
              openingLabel: 'الرصيد حسب دفاتر الشركة',
              openingBalance: statement.bookBalance,
              items: bookItems,
              closingLabel: 'الرصيد المعدل حسب دفاتر الشركة',
              closingBalance: statement.adjustedBookBalance,
              color: const Color(0xFF6D4CFF),
            ),
            const SizedBox(height: 14),
            _finalResult(statement),
          ],
        ),
      ),
    );
  }

  Widget _reportSection({
    required String title,
    required String openingLabel,
    required double openingBalance,
    required List<BankAdjustmentItem> items,
    required String closingLabel,
    required double closingBalance,
    required Color color,
  }) =>
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
              ),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _reportRow(openingLabel, openingBalance, bold: true),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('لا توجد بنود تسوية في هذا القسم.'),
              )
            else
              ...items.map(
                (item) => _reportRow(
                  '${item.add ? 'يضاف' : 'يخصم'}: ${item.type.label}'
                  '${item.description.isEmpty ? '' : ' — ${item.description}'}',
                  item.add ? item.amount : -item.amount,
                ),
              ),
            _reportRow(
              closingLabel,
              closingBalance,
              bold: true,
              highlight: true,
            ),
          ],
        ),
      );

  Widget _reportRow(
    String label,
    double amount, {
    bool bold = false,
    bool highlight = false,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: highlight ? const Color(0xFFFFF3D6) : null,
          border: const Border(top: BorderSide(color: Color(0xFFE8E8EE))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              amount.toStringAsFixed(2),
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      );

  Widget _finalResult(BankReconciliationStatement statement) {
    final balanced = statement.isBalanced;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: balanced ? const Color(0xFFD9FFF6) : const Color(0xFFFFE4EC),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: balanced ? const Color(0xFF00A98F) : const Color(0xFFD52B61),
        ),
      ),
      child: Column(
        children: [
          Text(
            'الفرق النهائي: ${statement.difference.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            balanced ? 'التسوية متوازنة.' : 'التسوية غير متوازنة.',
          ),
        ],
      ),
    );
  }

  Widget _itemCard(BankAdjustmentItem item) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: item.adjustBankBalance
                        ? const Color(0xFFE1F8FC)
                        : const Color(0xFFECE6FF),
                    child: Icon(
                      item.add ? Icons.add_rounded : Icons.remove_rounded,
                      color: item.add
                          ? const Color(0xFF00A68F)
                          : const Color(0xFFFF5D8F),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.type.label,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(item.description.isEmpty ? 'بدون بيان' : item.description),
                        if (item.fromPreviousPeriod)
                          const Text(
                            'مرحّل من تسوية سابقة',
                            style: TextStyle(color: Color(0xFF6D4CFF)),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '${item.add ? '+' : '-'}${item.amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<BankDifferenceType>(
                value: item.type,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'تصنيف البند'),
                items: BankDifferenceType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) _updateItem(item, item.copyWith(type: value));
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<BankItemStatus>(
                value: item.status,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'حالة البند'),
                items: BankItemStatus.values
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) _updateItem(item, item.copyWith(status: value));
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _editItem(item),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('تعديل'),
                    ),
                  ),
                  if (item.manual) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _deleteManualItem(item),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('حذف'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      );

  void _updateItem(BankAdjustmentItem oldItem, BankAdjustmentItem newItem) {
    final statement = _statement;
    if (statement == null) return;
    setState(() {
      _statement = statement.copyWith(
        items: statement.items
            .map((item) => item.id == oldItem.id ? newItem : item)
            .toList(growable: false),
      );
    });
  }

  Future<void> _pickPeriod() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _period,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'اختر شهر التسوية',
    );
    if (picked != null) {
      setState(() => _period = DateTime(picked.year, picked.month));
    }
  }

  void _calculate() {
    final book = double.tryParse(_bookController.text.replaceAll(',', ''));
    final bank = double.tryParse(_bankController.text.replaceAll(',', ''));
    final account = _accountController.text.trim();
    if (account.isEmpty || book == null || bank == null) {
      _message('أدخل اسم الحساب والرصيدين بصورة صحيحة.');
      return;
    }
    setState(() {
      _statement = _service.build(
        accountName: account,
        period: _period,
        bookBalance: book,
        bankBalance: bank,
        matchingResult: widget.result,
      );
    });
  }

  Future<void> _save(BankReconciliationStatement statement) async {
    setState(() => _busy = true);
    try {
      final updated = statement.copyWith(
        accountName: _accountController.text.trim(),
        period: _period,
      );
      await _archive.save(updated);
      if (!mounted) return;
      setState(() => _statement = updated);
      _message('تم حفظ التسوية البنكية في الأرشيف.');
    } catch (error) {
      if (mounted) _message('تعذر حفظ التسوية: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadPreviousPending() async {
    final statement = _statement;
    if (statement == null) return;
    setState(() => _busy = true);
    try {
      final pending = await _archive.pendingFromPrevious(
        accountName: _accountController.text,
        beforePeriod: _period,
        currentItems: statement.items,
      );
      if (!mounted) return;
      if (pending.isEmpty) {
        _message('لا توجد بنود قابلة للترحيل من تسوية سابقة.');
      } else {
        setState(() {
          _statement = statement.copyWith(items: [...statement.items, ...pending]);
        });
        _message('تم استدعاء ${pending.length} بند معلق دون تكرار.');
      }
    } catch (error) {
      if (mounted) _message('تعذر استدعاء التسوية السابقة: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openArchive() async {
    final items = await _archive.loadAll();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.72,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'أرشيف التسويات البنكية',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: items.isEmpty
                      ? const Center(child: Text('لا توجد تسويات محفوظة.'))
                      : ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (_, index) {
                            final item = items[index];
                            return ListTile(
                              leading: Icon(
                                item.isBalanced
                                    ? Icons.check_circle_outline
                                    : Icons.warning_amber_rounded,
                              ),
                              title: Text(item.accountName),
                              subtitle: Text(
                                '${DateFormat('yyyy/MM').format(item.period)} — '
                                'الفرق ${item.difference.toStringAsFixed(2)}',
                              ),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                _loadArchived(item);
                              },
                              trailing: IconButton(
                                tooltip: 'حذف',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  await _archive.delete(
                                    accountName: item.accountName,
                                    period: item.period,
                                  );
                                  if (sheetContext.mounted) {
                                    Navigator.pop(sheetContext);
                                  }
                                  if (mounted) _openArchive();
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _loadArchived(BankReconciliationStatement item) {
    _accountController.text = item.accountName;
    _bankController.text = item.bankBalance.toStringAsFixed(2);
    _bookController.text = item.bookBalance.toStringAsFixed(2);
    setState(() {
      _period = item.period;
      _statement = item;
    });
  }

  Future<void> _addManualItem() async {
    final created = await _itemDialog();
    final statement = _statement;
    if (created == null || statement == null) return;
    try {
      setState(() {
        _statement = statement.copyWith(
          items: _service.addManualItem(statement.items, created),
        );
      });
    } on FormatException catch (error) {
      _message(error.message);
    }
  }

  Future<void> _editItem(BankAdjustmentItem item) async {
    final edited = await _itemDialog(initial: item);
    if (edited != null) _updateItem(item, edited);
  }

  Future<BankAdjustmentItem?> _itemDialog({BankAdjustmentItem? initial}) async {
    final description = TextEditingController(text: initial?.description ?? '');
    final amount = TextEditingController(
      text: initial == null ? '' : initial.amount.toStringAsFixed(2),
    );
    var type = initial?.type ?? BankDifferenceType.reviewRequired;
    var adjustBank = initial?.adjustBankBalance ?? true;
    var add = initial?.add ?? true;
    final result = await showDialog<BankAdjustmentItem>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(initial == null ? 'إضافة بند يدوي' : 'تعديل البند'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: description,
                  decoration: const InputDecoration(labelText: 'البيان'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'المبلغ'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<BankDifferenceType>(
                  value: type,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'التصنيف'),
                  items: BankDifferenceType.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) setLocal(() => type = value);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('يعدل رصيد كشف البنك'),
                  value: adjustBank,
                  onChanged: (value) => setLocal(() => adjustBank = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('البند يضاف إلى الرصيد'),
                  value: add,
                  onChanged: (value) => setLocal(() => add = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = double.tryParse(amount.text.replaceAll(',', ''));
                if (parsed == null || parsed == 0 || description.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  BankAdjustmentItem(
                    id: initial?.id ??
                        'manual-${DateTime.now().microsecondsSinceEpoch}',
                    description: description.text.trim(),
                    amount: parsed.abs(),
                    type: type,
                    adjustBankBalance: adjustBank,
                    add: add,
                    status: initial?.status ?? BankItemStatus.pending,
                    fromPreviousPeriod: initial?.fromPreviousPeriod ?? false,
                    manual: initial?.manual ?? true,
                  ),
                );
              },
              child: const Text('اعتماد'),
            ),
          ],
        ),
      ),
    );
    description.dispose();
    amount.dispose();
    return result;
  }

  Future<void> _deleteManualItem(BankAdjustmentItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف البند اليدوي'),
        content: const Text('هل أنت متأكد من حذف هذا البند؟'),
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
    if (confirmed != true || _statement == null) return;
    setState(() {
      _statement = _statement!.copyWith(
        items: _statement!.items
            .where((value) => value.id != item.id)
            .toList(growable: false),
      );
    });
  }

  Future<void> _export(BankReconciliationStatement statement) async {
    setState(() => _busy = true);
    try {
      await _exporter.exportPdf(
        companyName: widget.firstName,
        bankName: statement.accountName.isEmpty
            ? widget.secondName
            : statement.accountName,
        statement: statement,
      );
    } catch (error) {
      if (mounted) _message('تعذر إنشاء تقرير التسوية: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}