import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/bank_reconciliation.dart';
import '../models/transaction_record.dart';
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
  State<BankReconciliationScreen> createState() => _BankReconciliationScreenState();
}

class _BankReconciliationScreenState extends State<BankReconciliationScreen> {
  final _bookController = TextEditingController();
  final _bankController = TextEditingController();
  DateTime _period = DateTime(DateTime.now().year, DateTime.now().month);
  BankReconciliationStatement? _statement;

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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
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
                const Text('إعداد تسوية الشهر',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('${widget.firstName} ↔ ${widget.secondName}',
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 620;
                  final fields = [
                    _monthField(),
                    TextField(
                      controller: _bookController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: const InputDecoration(
                        labelText: 'رصيد دفاتر الشركة قبل التسوية',
                        prefixIcon: Icon(Icons.menu_book_rounded),
                      ),
                    ),
                    TextField(
                      controller: _bankController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: const InputDecoration(
                        labelText: 'رصيد كشف البنك قبل التسوية',
                        prefixIcon: Icon(Icons.account_balance_rounded),
                      ),
                    ),
                  ];
                  return wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: fields
                              .map((field) => Expanded(child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 5),
                                    child: field,
                                  )))
                              .toList(growable: false),
                        )
                      : Column(
                          children: fields
                              .map((field) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: field,
                                  ))
                              .toList(growable: false),
                        );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _calculate,
            icon: const Icon(Icons.calculate_rounded),
            label: const Text('إعداد التسوية وعرض البنود'),
          ),
          if (statement != null) ...[
            const SizedBox(height: 16),
            _summary(statement),
            const SizedBox(height: 14),
            Text('بنود التسوية (${statement.items.length})',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...statement.items.map(_itemCard),
          ],
        ],
      ),
    );
  }

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

  Widget _summary(BankReconciliationStatement statement) {
    final balanced = statement.isBalanced;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _valueChip('رصيد البنك المعدل', statement.adjustedBankBalance, const Color(0xFF00B8D9)),
                _valueChip('رصيد الدفاتر المعدل', statement.adjustedBookBalance, const Color(0xFF6D4CFF)),
                _valueChip('الفرق النهائي', statement.difference, balanced ? const Color(0xFF00C2A8) : const Color(0xFFFF5D8F)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: balanced ? const Color(0xFFD9FFF6) : const Color(0xFFFFE4EC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                balanced ? 'التسوية متوازنة وجاهزة للحفظ.' : 'التسوية غير متوازنة وتحتاج مراجعة البنود أو الأرصدة.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: balanced ? const Color(0xFF007D6C) : const Color(0xFFC41E58),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _valueChip(String label, double value, Color color) => Container(
        constraints: const BoxConstraints(minWidth: 170),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(value.toStringAsFixed(2), style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      );

  Widget _itemCard(BankAdjustmentItem item) => Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: item.adjustBankBalance
                ? const Color(0xFFE1F8FC)
                : const Color(0xFFECE6FF),
            child: Icon(
              item.add ? Icons.add_rounded : Icons.remove_rounded,
              color: item.add ? const Color(0xFF00A68F) : const Color(0xFFFF5D8F),
            ),
          ),
          title: Text(item.type.label),
          subtitle: Text(item.description.isEmpty ? 'بدون بيان' : item.description),
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
    if (picked != null) setState(() => _period = DateTime(picked.year, picked.month));
  }

  void _calculate() {
    final book = double.tryParse(_bookController.text.replaceAll(',', ''));
    final bank = double.tryParse(_bankController.text.replaceAll(',', ''));
    if (book == null || bank == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل رصيد الدفاتر ورصيد كشف البنك بصورة صحيحة.')),
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
}
