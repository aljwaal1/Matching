import 'package:flutter/material.dart';

import '../services/file_import_service.dart';

class ColumnMappingScreen extends StatefulWidget {
  const ColumnMappingScreen({
    super.key,
    required this.prepared,
    required this.statementLabel,
    this.initial,
  });

  final PreparedStatement prepared;
  final String statementLabel;
  final ColumnMapping? initial;

  @override
  State<ColumnMappingScreen> createState() => _ColumnMappingScreenState();
}

class _ColumnMappingScreenState extends State<ColumnMappingScreen> {
  int? _date;
  int? _document;
  int? _amount;
  int? _debit;
  int? _credit;
  int? _balance;
  int? _description;
  DirectAmountRule _directAmountRule = DirectAmountRule.unknown;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _date = initial?.date;
    _document = initial?.document;
    _amount = initial?.amount;
    _debit = initial?.debit;
    _credit = initial?.credit;
    _balance = initial?.balance;
    _description = initial?.description;
    _directAmountRule = initial?.directAmountRule ?? DirectAmountRule.unknown;
  }

  bool get _canSubmit =>
      _date != null && (_amount != null || _debit != null || _credit != null);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'مراجعة أعمدة ${widget.statementLabel}',
          maxLines: 2,
          overflow: TextOverflow.visible,
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: _canSubmit ? _submit : null,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text(
              'اعتماد أعمدة الكشف',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth < 380 ? 10.0 : 16.0;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  12,
                  horizontalPadding,
                  8,
                ),
                sliver: SliverToBoxAdapter(child: _introCard()),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 6,
                ),
                sliver: SliverToBoxAdapter(
                  child: _PreviewList(prepared: widget.prepared),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  6,
                  horizontalPadding,
                  12,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate.fixed([
                    _mappingCard(
                      'التاريخ',
                      Icons.calendar_month,
                      _date,
                      true,
                      (value) => setState(() => _date = value),
                    ),
                    _mappingCard(
                      'رقم المستند',
                      Icons.receipt_long,
                      _document,
                      false,
                      (value) => setState(() => _document = value),
                    ),
                    _mappingCard(
                      'البيان',
                      Icons.notes_rounded,
                      _description,
                      false,
                      (value) => setState(() => _description = value),
                    ),
                    _mappingCard(
                      'الرصيد',
                      Icons.account_balance_wallet_outlined,
                      _balance,
                      false,
                      (value) => setState(() => _balance = value),
                      accent: const Color(0xFF8A5A00),
                    ),
                    _mappingCard(
                      'المبلغ المباشر',
                      Icons.payments_rounded,
                      _amount,
                      false,
                      (value) => setState(() {
                        _amount = value;
                        if (value == null) {
                          _directAmountRule = DirectAmountRule.unknown;
                        }
                      }),
                    ),
                    _mappingCard(
                      'المدين',
                      Icons.arrow_upward_rounded,
                      _debit,
                      false,
                      (value) => setState(() => _debit = value),
                      accent: const Color(0xFFFF5D8F),
                    ),
                    _mappingCard(
                      'الدائن',
                      Icons.arrow_downward_rounded,
                      _credit,
                      false,
                      (value) => setState(() => _credit = value),
                      accent: const Color(0xFF00C2A8),
                    ),
                    if (_amount != null && _debit == null && _credit == null)
                      _amountRuleCard(),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _introCard() => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6D4CFF), Color(0xFF00B8D9)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x286D4CFF),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.table_chart_rounded, color: Color(0xFF6D4CFF)),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'راجع الرؤوس والمعاينة، ثم عيّن التاريخ ومصدر المبلغ وعمود الرصيد إن وجد. اضغط على أي اسم عمود لعرضه كاملًا.',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _mappingCard(
    String label,
    IconData icon,
    int? value,
    bool required,
    ValueChanged<int?> onChanged, {
    Color accent = const Color(0xFF6D4CFF),
  }) {
    final selectedName =
        value == null ? 'غير مستخدم' : widget.prepared.headers[value];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: accent.withValues(alpha: 0.12),
                  child: Icon(icon, size: 20, color: accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    required ? '$label *' : label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (value != null)
                  IconButton(
                    tooltip: 'عرض اسم العمود كاملًا',
                    onPressed: () => _showFullText(selectedName),
                    icon: const Icon(Icons.info_outline_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              value: value,
              isExpanded: true,
              menuMaxHeight: 380,
              decoration: InputDecoration(
                hintText: 'اختر العمود',
                helperText: selectedName,
                helperMaxLines: 3,
              ),
              selectedItemBuilder: (_) => [
                if (!required)
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text('غير مستخدم'),
                  ),
                ...widget.prepared.headers.map(
                  (header) => Align(
                    alignment: Alignment.centerRight,
                    child: Text(header, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              items: [
                if (!required)
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('غير مستخدم'),
                  ),
                ...List.generate(
                  widget.prepared.headers.length,
                  (index) => DropdownMenuItem<int?>(
                    value: index,
                    child: Tooltip(
                      message: widget.prepared.headers[index],
                      child: Text(
                        '${index + 1} — ${widget.prepared.headers[index]}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountRuleCard() {
    final samples = widget.prepared.rows
        .map((row) => _amount! < row.length ? '${row[_amount!] ?? ''}'.trim() : '')
        .where((value) => value.isNotEmpty)
        .take(5)
        .toList(growable: false);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'قاعدة عمود المبلغ الواحد',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (samples.isNotEmpty) ...[
              const Text('أول 5 قيم من العمود المختار:'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: samples
                    .map((value) => Chip(label: Text(value)))
                    .toList(growable: false),
              ),
              const SizedBox(height: 10),
            ],
            DropdownButtonFormField<DirectAmountRule>(
              value: _directAmountRule,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'طريقة تحديد المدين والدائن',
              ),
              items: const [
                DropdownMenuItem(
                  value: DirectAmountRule.unknown,
                  child: Text('اختر قاعدة الإشارة'),
                ),
                DropdownMenuItem(
                  value: DirectAmountRule.allDebit,
                  child: Text('كل القيم مدين'),
                ),
                DropdownMenuItem(
                  value: DirectAmountRule.allCredit,
                  child: Text('كل القيم دائن'),
                ),
                DropdownMenuItem(
                  value: DirectAmountRule.positiveDebitNegativeCredit,
                  child: Text('الموجب مدين — السالب دائن'),
                ),
                DropdownMenuItem(
                  value: DirectAmountRule.positiveCreditNegativeDebit,
                  child: Text('الموجب دائن — السالب مدين'),
                ),
              ],
              onChanged: (value) => setState(
                () => _directAmountRule = value ?? DirectAmountRule.unknown,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFullText(String text) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('اسم العمود الكامل'),
          content: SelectableText(text, textAlign: TextAlign.right),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      );

  void _submit() {
    Navigator.pop(
      context,
      ColumnMapping(
        date: _date!,
        document: _document,
        amount: _amount,
        debit: _debit,
        credit: _credit,
        balance: _balance,
        description: _description,
        directAmountRule: _directAmountRule,
      ),
    );
  }
}

class _PreviewList extends StatelessWidget {
  const _PreviewList({required this.prepared});

  final PreparedStatement prepared;

  @override
  Widget build(BuildContext context) {
    final previewRows = prepared.rows.take(10).toList(growable: false);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'معاينة أول 10 صفوف',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 5),
            Text(
              'صف العناوين المكتشف: ${prepared.headerRowNumber}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            if (previewRows.isEmpty)
              const Text('لا توجد صفوف متاحة للمعاينة.')
            else
              ...List.generate(previewRows.length, (rowIndex) {
                final row = previewRows[rowIndex];
                return ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title: Text(
                    'الصف ${prepared.headerRowNumber + rowIndex + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    _rowSummary(row),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  children: List.generate(prepared.headers.length, (index) {
                    final value = index < row.length ? '${row[index] ?? ''}' : '';
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: InkWell(
                        onTap: () => _showValue(context, prepared.headers[index]),
                        child: Text(
                          prepared.headers[index],
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      subtitle: Text(
                        value.isEmpty ? '—' : value,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                );
              }),
          ],
        ),
      ),
    );
  }

  String _rowSummary(List<dynamic> row) => row
      .map((value) => '${value ?? ''}'.trim())
      .where((value) => value.isNotEmpty)
      .take(3)
      .join(' • ');

  Future<void> _showValue(BuildContext context, String value) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('اسم العمود الكامل'),
          content: SelectableText(value, textAlign: TextAlign.right),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      );
}
