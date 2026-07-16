import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/bank_reconciliation.dart';
import '../models/transaction_record.dart';
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
  final _exporter = BankReconciliationExportService();
  DateTime _period = DateTime(DateTime.now().year, DateTime.now().month);
  BankReconciliationStatement? _statement;
  bool _busy = false;

  @override
  void dispose() {
    _bookController.dispose();
    _bankController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statement = _statement;
    return Scaffold(
      appBar: AppBar(title: const Text('التسوية البنكية')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _hero(),
              const SizedBox(height: 14),
              _inputCard(),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _calculate,
                icon: const Icon(Icons.calculate_rounded),
                label: const Text('إعداد تقرير التسوية البنكية'),
              ),
              if (statement != null) ...[
                const SizedBox(height: 18),
                _standardReport(statement),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _export(statement),
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('تصدير تقرير التسوية PDF'),
                ),
                const SizedBox(height: 18),
                Text(
                  'تفاصيل بنود التسوية (${statement.items.length})',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...statement.items.map(_itemCard),
              ],
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

  Widget _hero() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00B8D9), Color(0xFF6D4CFF)],
          ),
          borderRadius: BorderRadius.circular(24),
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
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 620;
              final fields = [
                _monthField(),
                TextField(
                  controller: _bankController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'الرصيد حسب كشف البنك',
                    prefixIcon: Icon(Icons.account_balance_rounded),
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
              return wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: fields
                          .map(
                            (field) => Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 5),
                                child: field,
                              ),
                            ),
                          )
                          .toList(growable: false),
                    )
                  : Column(
                      children: fields
                          .map(
                            (field) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
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

  Widget _standardReport(BankReconciliationStatement statement) {
    final bankItems = statement.items
        .where((item) => item.adjustBankBalance && !item.cleared)
        .toList(growable: false);
    final bookItems = statement.items
        .where((item) => !item.adjustBankBalance && !item.cleared)
        .toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 16),
            _reportSection(
              title: 'أولًا: تسوية رصيد كشف البنك',
              openingLabel: 'الرصيد حسب كشف البنك',
              openingBalance: statement.bankBalance,
              items: bankItems,
              closingLabel: 'الرصيد المعدل حسب كشف البنك',
              closingBalance: statement.adjustedBankBalance,
              color: const Color(0xFF00A9C8),
            ),
            const SizedBox(height: 16),
            _reportSection(
              title: 'ثانيًا: تسوية رصيد دفاتر الشركة',
              openingLabel: 'الرصيد حسب دفاتر الشركة',
              openingBalance: statement.bookBalance,
              items: bookItems,
              closingLabel: 'الرصيد المعدل حسب دفاتر الشركة',
              closingBalance: statement.adjustedBookBalance,
              color: const Color(0xFF6D4CFF),
            ),
            const SizedBox(height: 16),
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
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(17),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: highlight ? const Color(0xFFFFF3D6) : null,
          border: const Border(
            top: BorderSide(color: Color(0xFFE8E8EE)),
          ),
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
            const SizedBox(width: 10),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: balanced ? const Color(0xFFD9FFF6) : const Color(0xFFFFE4EC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: balanced ? const Color(0xFF00A98F) : const Color(0xFFD52B61),
        ),
      ),
      child: Column(
        children: [
          Text(
            'الفرق بين الرصيدين المعدلين: ${statement.difference.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 5),
          Text(
            balanced
                ? 'التسوية البنكية متوازنة.'
                : 'التسوية غير متوازنة وتحتاج مراجعة البنود أو الأرصدة.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _itemCard(BankAdjustmentItem item) => Card(
        child: ListTile(
          leading: CircleAvatar(
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
          title: Text(item.type.label),
          subtitle: Text(
            item.description.isEmpty ? 'بدون بيان' : item.description,
          ),
          trailing: Text(
            '${item.add ? '+' : '-'}${item.amount.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );

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
    if (book == null || bank == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أدخل رصيد الدفاتر ورصيد كشف البنك بصورة صحيحة.'),
        ),
      );
      return;
    }
    setState(() {
      _statement = const BankReconciliationService().build(
        period: _period,
        bookBalance: book,
        bankBalance: bank,
        matchingResult: widget.result,
      );
    });
  }

  Future<void> _export(BankReconciliationStatement statement) async {
    setState(() => _busy = true);
    try {
      await _exporter.exportPdf(
        companyName: widget.firstName,
        bankName: widget.secondName,
        statement: statement,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إنشاء تقرير التسوية: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
