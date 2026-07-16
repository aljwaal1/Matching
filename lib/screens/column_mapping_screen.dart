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
    _description = initial?.description;
    _directAmountRule = initial?.directAmountRule ?? DirectAmountRule.unknown;
  }

  bool get _canSubmit =>
      _date != null && (_amount != null || _debit != null || _credit != null);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 900 ? 3 : width >= 600 ? 2 : 1;

    return Scaffold(
      appBar: AppBar(title: Text('مراجعة أعمدة ${widget.statementLabel}')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: FilledButton.icon(
          onPressed: _canSubmit ? _submit : null,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('اعتماد أعمدة الكشف'),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6D4CFF), Color(0xFF00B8D9)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x336D4CFF),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.table_chart_rounded, color: Color(0xFF6D4CFF)),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'راجع أسماء الرؤوس كاملة، ثم تأكد من تعيين التاريخ والمبالغ قبل المتابعة.',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverToBoxAdapter(
              child: _PreviewTable(prepared: widget.prepared),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: columns == 1 ? 2.9 : 2.5,
              ),
              delegate: SliverChildListDelegate([
                _mappingCard('التاريخ', Icons.calendar_month, _date, true,
                    (value) => setState(() => _date = value)),
                _mappingCard('رقم المستند', Icons.receipt_long, _document, false,
                    (value) => setState(() => _document = value)),
                _mappingCard('البيان', Icons.notes_rounded, _description, false,
                    (value) => setState(() => _description = value)),
                _mappingCard('المبلغ المباشر', Icons.payments_rounded, _amount, false,
                    (value) => setState(() => _amount = value)),
                _mappingCard('المدين', Icons.arrow_upward_rounded, _debit, false,
                    (value) => setState(() => _debit = value), accent: const Color(0xFFFF5D8F)),
                _mappingCard('الدائن', Icons.arrow_downward_rounded, _credit, false,
                    (value) => setState(() => _credit = value), accent: const Color(0xFF00C2A8)),
              ]),
            ),
          ),
          if (_amount != null && _debit == null && _credit == null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverToBoxAdapter(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('قاعدة عمود المبلغ الواحد',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<DirectAmountRule>(
                          value: _directAmountRule,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'طريقة تحديد المدين والدائن'),
                          items: const [
                            DropdownMenuItem(value: DirectAmountRule.unknown, child: Text('تحديد لاحقًا بعد معاينة الإشارات')),
                            DropdownMenuItem(value: DirectAmountRule.allDebit, child: Text('كل القيم مدين')),
                            DropdownMenuItem(value: DirectAmountRule.allCredit, child: Text('كل القيم دائن')),
                            DropdownMenuItem(value: DirectAmountRule.positiveDebitNegativeCredit, child: Text('الموجب مدين — السالب دائن')),
                            DropdownMenuItem(value: DirectAmountRule.positiveCreditNegativeDebit, child: Text('الموجب دائن — السالب مدين')),
                          ],
                          onChanged: (value) => setState(
                            () => _directAmountRule = value ?? DirectAmountRule.unknown,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _mappingCard(
    String label,
    IconData icon,
    int? value,
    bool required,
    ValueChanged<int?> onChanged, {
    Color accent = const Color(0xFF6D4CFF),
  }) {
    final selectedName = value == null ? 'غير مستخدم' : widget.prepared.headers[value];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: accent.withValues(alpha: 0.12),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<int?>(
                value: value,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: required ? '$label *' : label,
                  helperText: selectedName,
                  helperMaxLines: 2,
                ),
                selectedItemBuilder: (_) => [
                  if (!required) const Text('غير مستخدم', overflow: TextOverflow.ellipsis),
                  ...widget.prepared.headers.map(
                    (header) => Text(header, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ],
                items: [
                  if (!required)
                    const DropdownMenuItem<int?>(value: null, child: Text('غير مستخدم')),
                  ...List.generate(
                    widget.prepared.headers.length,
                    (index) => DropdownMenuItem<int?>(
                      value: index,
                      child: Tooltip(
                        message: widget.prepared.headers[index],
                        child: Text(
                          '${index + 1} — ${widget.prepared.headers[index]}',
                          maxLines: 3,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                    ),
                  ),
                ],
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    Navigator.pop(
      context,
      ColumnMapping(
        date: _date!,
        document: _document,
        amount: _amount,
        debit: _debit,
        credit: _credit,
        description: _description,
        directAmountRule: _directAmountRule,
      ),
    );
  }
}

class _PreviewTable extends StatelessWidget {
  const _PreviewTable({required this.prepared});

  final PreparedStatement prepared;

  @override
  Widget build(BuildContext context) {
    final previewRows = prepared.rows.take(5).toList(growable: false);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('معاينة الرؤوس وأول 5 صفوف',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFEDE8FF)),
                columns: prepared.headers
                    .map((header) => DataColumn(label: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 180),
                          child: Text(header, maxLines: 3, overflow: TextOverflow.visible),
                        )))
                    .toList(growable: false),
                rows: previewRows
                    .map((row) => DataRow(
                          cells: List.generate(
                            prepared.headers.length,
                            (index) => DataCell(ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 180),
                              child: Text(index < row.length ? '${row[index] ?? ''}' : '', maxLines: 3),
                            )),
                          ),
                        ))
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
