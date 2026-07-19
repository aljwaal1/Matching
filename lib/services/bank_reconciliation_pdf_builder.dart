import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/bank_reconciliation.dart';
import 'arabic_pdf_support.dart';

class BankReconciliationPdfBuilder {
  const BankReconciliationPdfBuilder();

  Future<Uint8List> build({
    required String companyName,
    required String bankName,
    required BankReconciliationStatement statement,
  }) async {
    final fonts = await loadArabicPdfFonts();
    final document = pw.Document(theme: arabicPdfTheme(fonts));

    final activeBankItems = statement.items
        .where((item) => item.adjustBankBalance && !item.cleared)
        .toList(growable: false);
    final activeBookItems = statement.items
        .where((item) => !item.adjustBankBalance && !item.cleared)
        .toList(growable: false);
    final bankPending = activeBankItems
        .where((item) => item.status == BankItemStatus.pending)
        .toList(growable: false);
    final bookPending = activeBookItems
        .where((item) => item.status == BankItemStatus.pending)
        .toList(growable: false);
    final carried = statement.items
        .where((item) => item.status == BankItemStatus.carryForward)
        .toList(growable: false);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(24, 22, 24, 28),
        textDirection: pw.TextDirection.rtl,
        theme: arabicPdfTheme(fonts),
        maxPages: 100,
        footer: (context) => arabicPdfText(
          'الصفحة ${context.pageNumber} من ${context.pagesCount}',
          fonts,
          fontSize: 8,
          color: PdfColors.grey700,
          textAlign: pw.TextAlign.center,
        ),
        build: (_) => [
          _header(fonts, companyName, bankName, statement),
          pw.SizedBox(height: 14),
          _summarySection(
            fonts: fonts,
            title: 'أولًا: ملخص تسوية رصيد كشف البنك',
            openingLabel: 'الرصيد حسب كشف البنك',
            openingBalance: statement.bankBalance,
            items: activeBankItems,
            closingLabel: 'الرصيد المعدل حسب كشف البنك',
            closingBalance: statement.adjustedBankBalance,
            color: PdfColor.fromHex('#00A9C8'),
          ),
          pw.SizedBox(height: 14),
          _summarySection(
            fonts: fonts,
            title: 'ثانيًا: ملخص تسوية رصيد دفاتر الشركة',
            openingLabel: 'الرصيد حسب دفاتر الشركة',
            openingBalance: statement.bookBalance,
            items: activeBookItems,
            closingLabel: 'الرصيد المعدل حسب دفاتر الشركة',
            closingBalance: statement.adjustedBookBalance,
            color: PdfColor.fromHex('#6D4CFF'),
          ),
          pw.SizedBox(height: 14),
          _finalResult(fonts, statement),
          pw.NewPage(),
          _detailSection(
            fonts: fonts,
            title: 'معلقات كشف البنك',
            items: bankPending,
            color: PdfColor.fromHex('#00A9C8'),
          ),
          pw.SizedBox(height: 16),
          _detailSection(
            fonts: fonts,
            title: 'معلقات دفاتر الشركة',
            items: bookPending,
            color: PdfColor.fromHex('#6D4CFF'),
          ),
          if (carried.isNotEmpty) ...[
            pw.NewPage(),
            _detailSection(
              fonts: fonts,
              title: 'البنود المرحلة للشهر القادم',
              items: carried,
              color: PdfColor.fromHex('#D97706'),
              includeSide: true,
            ),
          ],
        ],
      ),
    );

    return document.save();
  }

  pw.Widget _header(
    ArabicPdfFonts fonts,
    String companyName,
    String bankName,
    BankReconciliationStatement statement,
  ) =>
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#F2EEFF'),
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: PdfColor.fromHex('#CFC4FF')),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            arabicPdfText(
              'تقرير التسوية البنكية',
              fonts,
              fontSize: 18,
              bold: true,
              color: PdfColor.fromHex('#4B2FCC'),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 7),
            arabicPdfText('الشركة: $companyName', fonts),
            arabicPdfText('البنك أو الحساب: $bankName', fonts),
            arabicPdfText(
              'شهر التسوية: ${DateFormat('yyyy/MM', 'en_US').format(statement.period)}',
              fonts,
              bold: true,
            ),
            arabicPdfText(
              'تاريخ إعداد التقرير: ${DateFormat('yyyy/MM/dd HH:mm', 'en_US').format(DateTime.now())}',
              fonts,
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ],
        ),
      );

  pw.Widget _summarySection({
    required ArabicPdfFonts fonts,
    required String title,
    required String openingLabel,
    required double openingBalance,
    required List<BankAdjustmentItem> items,
    required String closingLabel,
    required double closingBalance,
    required PdfColor color,
  }) {
    final lines = _aggregate(items);
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(4.8),
        1: pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          repeat: true,
          decoration: pw.BoxDecoration(color: color),
          children: [
            _cell(fonts, title, bold: true, color: PdfColors.white, center: true),
            _cell(fonts, 'المبلغ', bold: true, color: PdfColors.white, center: true),
          ],
        ),
        _amountRow(fonts, openingLabel, openingBalance, bold: true),
        ...lines.map((line) => _amountRow(fonts, line.label, line.amount)),
        _amountRow(
          fonts,
          closingLabel,
          closingBalance,
          bold: true,
          highlight: true,
        ),
      ],
    );
  }

  pw.Widget _detailSection({
    required ArabicPdfFonts fonts,
    required String title,
    required List<BankAdjustmentItem> items,
    required PdfColor color,
    bool includeSide = false,
  }) {
    final headers = <String>[
      'التاريخ',
      'رقم المرجع',
      'البيان',
      'التصنيف',
      if (includeSide) 'الجهة',
      'المبلغ',
      'الحالة',
    ];
    final amountColumn = headers.indexOf('المبلغ');
    final widths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(1.1),
      1: const pw.FlexColumnWidth(1.3),
      2: const pw.FlexColumnWidth(2.8),
      3: const pw.FlexColumnWidth(1.8),
      if (includeSide) 4: const pw.FlexColumnWidth(1.3),
      amountColumn: const pw.FlexColumnWidth(1.2),
      headers.length - 1: const pw.FlexColumnWidth(1.3),
    };

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(9),
          color: color,
          child: arabicPdfText(
            title,
            fonts,
            bold: true,
            color: PdfColors.white,
            textAlign: pw.TextAlign.center,
          ),
        ),
        if (items.isEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
            ),
            child: arabicPdfText(
              'لا توجد بنود في هذا القسم.',
              fonts,
              textAlign: pw.TextAlign.center,
            ),
          )
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.45),
            columnWidths: widths,
            children: [
              pw.TableRow(
                repeat: true,
                decoration: pw.BoxDecoration(color: PdfColor.fromHex('#E8EAF0')),
                children: headers
                    .map(
                      (value) => _cell(
                        fonts,
                        value,
                        bold: true,
                        center: true,
                      ),
                    )
                    .toList(growable: false),
              ),
              ...items.map((item) {
                final transaction = item.transaction;
                final document = transaction?.documentNumber?.trim();
                return pw.TableRow(
                  children: [
                    _cell(
                      fonts,
                      transaction == null ? '-' : _date(transaction.date),
                      center: true,
                    ),
                    _cell(
                      fonts,
                      document == null || document.isEmpty ? '-' : document,
                      center: true,
                    ),
                    _cell(fonts, item.description),
                    _cell(fonts, item.type.label),
                    if (includeSide)
                      _cell(
                        fonts,
                        item.adjustBankBalance
                            ? 'كشف البنك'
                            : 'دفاتر الشركة',
                        center: true,
                      ),
                    _cell(
                      fonts,
                      _money(item.add ? item.amount : -item.amount),
                      center: true,
                    ),
                    _cell(fonts, item.status.label, center: true),
                  ],
                );
              }),
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColor.fromHex('#FFF3D6')),
                children: List<pw.Widget>.generate(
                  headers.length,
                  (index) => _cell(
                    fonts,
                    index == 2
                        ? 'الإجمالي'
                        : index == amountColumn
                            ? _money(
                                items.fold<double>(
                                  0,
                                  (sum, item) =>
                                      sum + (item.add ? item.amount : -item.amount),
                                ),
                              )
                            : '',
                    bold: true,
                    center: index == amountColumn,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  List<_SummaryLine> _aggregate(List<BankAdjustmentItem> items) {
    final totals = <BankDifferenceType, double>{};
    for (final item in items) {
      totals.update(
        item.type,
        (value) => value + (item.add ? item.amount : -item.amount),
        ifAbsent: () => item.add ? item.amount : -item.amount,
      );
    }
    return totals.entries
        .where((entry) => entry.value.abs() > 0.0001)
        .map(
          (entry) => _SummaryLine(
            label: '${entry.value >= 0 ? 'يضاف' : 'يخصم'}: إجمالي ${entry.key.label}',
            amount: entry.value,
          ),
        )
        .toList(growable: false);
  }

  pw.TableRow _amountRow(
    ArabicPdfFonts fonts,
    String label,
    double amount, {
    bool bold = false,
    bool highlight = false,
  }) =>
      pw.TableRow(
        decoration: highlight
            ? pw.BoxDecoration(color: PdfColor.fromHex('#FFF3D6'))
            : null,
        children: [
          _cell(fonts, label, bold: bold),
          _cell(fonts, _money(amount), bold: bold, center: true),
        ],
      );

  pw.Widget _cell(
    ArabicPdfFonts fonts,
    String text, {
    bool bold = false,
    PdfColor? color,
    bool center = false,
  }) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: arabicPdfText(
          text.trim().isEmpty ? '-' : text,
          fonts,
          fontSize: 8.6,
          bold: bold,
          color: color,
          textAlign: center ? pw.TextAlign.center : pw.TextAlign.right,
        ),
      );

  pw.Widget _finalResult(
    ArabicPdfFonts fonts,
    BankReconciliationStatement statement,
  ) =>
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(13),
        decoration: pw.BoxDecoration(
          color: statement.isBalanced
              ? PdfColor.fromHex('#DFFFF7')
              : PdfColor.fromHex('#FFE5EC'),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          children: [
            arabicPdfText(
              'الفرق بين الرصيدين المعدلين: ${_money(statement.difference)}',
              fonts,
              fontSize: 12,
              bold: true,
              textAlign: pw.TextAlign.center,
            ),
            arabicPdfText(
              statement.isBalanced
                  ? 'النتيجة: التسوية البنكية متوازنة.'
                  : 'النتيجة: التسوية غير متوازنة وتحتاج إلى مراجعة.',
              fonts,
              bold: true,
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      );

  String _date(DateTime date) =>
      DateFormat('yyyy-MM-dd', 'en_US').format(date);

  String _money(double value) {
    final formatted = NumberFormat('#,##0.00', 'en_US').format(value.abs());
    return value < 0 ? '-$formatted' : formatted;
  }
}

class _SummaryLine {
  const _SummaryLine({required this.label, required this.amount});

  final String label;
  final double amount;
}
