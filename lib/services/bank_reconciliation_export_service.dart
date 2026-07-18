import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/bank_reconciliation.dart';
import 'arabic_pdf_support.dart';

class BankReconciliationExportService {
  Future<File> exportPdf({
    required String companyName,
    required String bankName,
    required BankReconciliationStatement statement,
  }) async {
    final fonts = await loadArabicPdfFonts();
    final document = pw.Document(theme: arabicPdfTheme(fonts));

    final bankItems = statement.items
        .where((item) => item.adjustBankBalance && !item.cleared)
        .toList(growable: false);
    final bookItems = statement.items
        .where((item) => !item.adjustBankBalance && !item.cleared)
        .toList(growable: false);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 30),
        textDirection: pw.TextDirection.rtl,
        theme: arabicPdfTheme(fonts),
        maxPages: 100,
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: arabicPdfText(
            'الصفحة ${context.pageNumber} من ${context.pagesCount}',
            fonts,
            fontSize: 8,
            color: PdfColors.grey700,
            textAlign: pw.TextAlign.center,
          ),
        ),
        build: (_) => [
          _header(fonts, companyName, bankName, statement),
          pw.SizedBox(height: 16),
          _reconciliationSection(
            fonts: fonts,
            title: 'أولًا: تسوية رصيد كشف البنك',
            openingLabel: 'الرصيد حسب كشف البنك',
            openingBalance: statement.bankBalance,
            items: bankItems,
            closingLabel: 'الرصيد المعدل حسب كشف البنك',
            closingBalance: statement.adjustedBankBalance,
            color: PdfColor.fromHex('#00A9C8'),
          ),
          pw.SizedBox(height: 18),
          _reconciliationSection(
            fonts: fonts,
            title: 'ثانيًا: تسوية رصيد دفاتر الشركة',
            openingLabel: 'الرصيد حسب دفاتر الشركة',
            openingBalance: statement.bookBalance,
            items: bookItems,
            closingLabel: 'الرصيد المعدل حسب دفاتر الشركة',
            closingBalance: statement.adjustedBookBalance,
            color: PdfColor.fromHex('#6D4CFF'),
          ),
          pw.SizedBox(height: 18),
          _finalResult(fonts, statement),
          pw.SizedBox(height: 14),
          _statusSummary(fonts, statement),
          pw.SizedBox(height: 12),
          arabicPdfText(
            'ملاحظة: البنود التي لم تتم تسويتها تبقى قيد المراجعة، ويجوز ترحيلها إلى الشهر التالي حسب اختيار المستخدم.',
            fonts,
            fontSize: 9,
            color: PdfColors.grey700,
          ),
        ],
      ),
    );

    final period = DateFormat('yyyy-MM', 'en_US').format(statement.period);
    final file = File(
      '${(await getTemporaryDirectory()).path}/تسوية_بنكية_$period.pdf',
    );
    await file.writeAsBytes(await document.save(), flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'تقرير التسوية البنكية $period',
      ),
    );
    return file;
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
            arabicPdfText(
              'الشركة: $companyName',
              fonts,
              fontSize: 10,
            ),
            arabicPdfText(
              'البنك أو الحساب: $bankName',
              fonts,
              fontSize: 10,
            ),
            arabicPdfText(
              'شهر التسوية: ${DateFormat('yyyy/MM', 'en_US').format(statement.period)}',
              fonts,
              fontSize: 10,
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

  pw.Widget _reconciliationSection({
    required ArabicPdfFonts fonts,
    required String title,
    required String openingLabel,
    required double openingBalance,
    required List<BankAdjustmentItem> items,
    required String closingLabel,
    required double closingBalance,
    required PdfColor color,
  }) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        repeat: true,
        decoration: pw.BoxDecoration(color: color),
        verticalAlignment: pw.TableCellVerticalAlignment.middle,
        children: [
          _sectionHeaderCell(fonts, title),
          _sectionHeaderCell(fonts, 'المبلغ'),
        ],
      ),
      _row(
        fonts,
        openingLabel,
        openingBalance,
        bold: true,
      ),
      ...items.map(
        (item) => _row(
          fonts,
          '${item.add ? 'يضاف' : 'يخصم'}: ${item.type.label}'
          '${item.description.isEmpty ? '' : '\nالبيان: ${item.description}'}'
          '\nالحالة: ${item.status.label}',
          item.add ? item.amount : -item.amount,
        ),
      ),
      _row(
        fonts,
        closingLabel,
        closingBalance,
        bold: true,
        highlight: true,
      ),
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(4.8),
        1: pw.FlexColumnWidth(1.5),
      },
      children: rows,
    );
  }

  pw.Widget _sectionHeaderCell(
    ArabicPdfFonts fonts,
    String text,
  ) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        child: arabicPdfText(
          text,
          fonts,
          fontSize: 11,
          bold: true,
          color: PdfColors.white,
          textAlign: pw.TextAlign.center,
        ),
      );

  pw.TableRow _row(
    ArabicPdfFonts fonts,
    String label,
    double amount, {
    bool bold = false,
    bool highlight = false,
  }) =>
      pw.TableRow(
        verticalAlignment: pw.TableCellVerticalAlignment.middle,
        decoration: highlight
            ? pw.BoxDecoration(color: PdfColor.fromHex('#FFF3D6'))
            : null,
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(7),
            child: arabicPdfText(
              label,
              fonts,
              fontSize: 9.5,
              bold: bold,
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(7),
            child: arabicPdfText(
              _money(amount),
              fonts,
              fontSize: 9.5,
              bold: bold,
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      );

  pw.Widget _finalResult(
    ArabicPdfFonts fonts,
    BankReconciliationStatement statement,
  ) {
    final balanced = statement.isBalanced;
    final color = balanced
        ? PdfColor.fromHex('#007D69')
        : PdfColor.fromHex('#B51F50');
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(13),
      decoration: pw.BoxDecoration(
        color: balanced
            ? PdfColor.fromHex('#DFFFF7')
            : PdfColor.fromHex('#FFE5EC'),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: color),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          arabicPdfText(
            'الفرق بين الرصيدين المعدلين: ${_money(statement.difference)}',
            fonts,
            fontSize: 12,
            bold: true,
            color: color,
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 5),
          arabicPdfText(
            balanced
                ? 'النتيجة: التسوية البنكية متوازنة.'
                : 'النتيجة: التسوية غير متوازنة وتحتاج إلى مراجعة البنود أو الأرصدة.',
            fonts,
            fontSize: 10,
            bold: true,
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  pw.Widget _statusSummary(
    ArabicPdfFonts fonts,
    BankReconciliationStatement statement,
  ) {
    final cleared = statement.items.where((item) => item.cleared).length;
    final pending = statement.items
        .where((item) => item.status == BankItemStatus.pending)
        .length;
    final carried = statement.items
        .where((item) => item.status == BankItemStatus.carryForward)
        .length;

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(11),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F7F7FA'),
        borderRadius: pw.BorderRadius.circular(7),
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: arabicPdfText(
              'تمت تسويتها: $cleared',
              fonts,
              fontSize: 9,
              bold: true,
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.Expanded(
            child: arabicPdfText(
              'معلقة: $pending',
              fonts,
              fontSize: 9,
              bold: true,
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.Expanded(
            child: arabicPdfText(
              'مرحلة للشهر القادم: $carried',
              fonts,
              fontSize: 9,
              bold: true,
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  String _money(double value) {
    final formatted = NumberFormat('#,##0.00', 'en_US').format(value.abs());
    return value < 0 ? '-$formatted' : formatted;
  }
}
