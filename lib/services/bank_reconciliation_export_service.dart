import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/bank_reconciliation.dart';
import 'export_service.dart';

class BankReconciliationExportService {
  Future<File> exportPdf({
    required String companyName,
    required String bankName,
    required BankReconciliationStatement statement,
  }) async {
    final fonts = await loadArabicPdfFonts();
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
    );

    final bankItems = statement.items
        .where((item) => item.adjustBankBalance && !item.cleared)
        .toList(growable: false);
    final bookItems = statement.items
        .where((item) => !item.adjustBankBalance && !item.cleared)
        .toList(growable: false);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(30, 26, 30, 28),
        textDirection: pw.TextDirection.rtl,
        build: (_) => [
          _header(companyName, bankName, statement),
          pw.SizedBox(height: 16),
          _reconciliationSection(
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
            title: 'ثانيًا: تسوية رصيد دفاتر الشركة',
            openingLabel: 'الرصيد حسب دفاتر الشركة',
            openingBalance: statement.bookBalance,
            items: bookItems,
            closingLabel: 'الرصيد المعدل حسب دفاتر الشركة',
            closingBalance: statement.adjustedBookBalance,
            color: PdfColor.fromHex('#6D4CFF'),
          ),
          pw.SizedBox(height: 18),
          _finalResult(statement),
          pw.SizedBox(height: 16),
          pw.Text(
            'ملاحظة: البنود غير المسوّاة تُراجع وتُرحّل إلى التسوية التالية عند بقائها معلقة.',
            textDirection: pw.TextDirection.rtl,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );

    final period = DateFormat('yyyy-MM').format(statement.period);
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
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'تقرير التسوية البنكية',
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#4B2FCC'),
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              'الشركة: $companyName',
              textDirection: pw.TextDirection.rtl,
            ),
            pw.Text(
              'البنك / الكشف: $bankName',
              textDirection: pw.TextDirection.rtl,
            ),
            pw.Text(
              'عن الشهر المنتهي في ${DateFormat('yyyy/MM').format(statement.period)}',
              textDirection: pw.TextDirection.rtl,
            ),
          ],
        ),
      );

  pw.Widget _reconciliationSection({
    required String title,
    required String openingLabel,
    required double openingBalance,
    required List<BankAdjustmentItem> items,
    required String closingLabel,
    required double closingBalance,
    required PdfColor color,
  }) {
    final rows = <pw.TableRow>[
      _row(openingLabel, openingBalance, bold: true),
      ...items.map(
        (item) => _row(
          '${item.add ? 'يضاف' : 'يخصم'}: ${item.type.label}'
          '${item.description.isEmpty ? '' : ' — ${item.description}'}',
          item.add ? item.amount : -item.amount,
        ),
      ),
      _row(closingLabel, closingBalance, bold: true, highlight: true),
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: pw.BoxDecoration(
            color: color,
            borderRadius: const pw.BorderRadius.only(
              topLeft: pw.Radius.circular(7),
              topRight: pw.Radius.circular(7),
            ),
          ),
          child: pw.Text(
            title,
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(4.5),
            1: pw.FlexColumnWidth(1.5),
          },
          children: rows,
        ),
      ],
    );
  }

  pw.TableRow _row(
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
          pw.Padding(
            padding: const pw.EdgeInsets.all(7),
            child: pw.Text(
              label,
              textDirection: pw.TextDirection.rtl,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(7),
            child: pw.Text(
              amount.toStringAsFixed(2),
              textAlign: pw.TextAlign.left,
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
        ],
      );

  pw.Widget _finalResult(BankReconciliationStatement statement) {
    final balanced = statement.isBalanced;
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(13),
      decoration: pw.BoxDecoration(
        color: balanced
            ? PdfColor.fromHex('#DFFFF7')
            : PdfColor.fromHex('#FFE5EC'),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(
          color: balanced
              ? PdfColor.fromHex('#00A98F')
              : PdfColor.fromHex('#D52B61'),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            'الفرق بين الرصيدين المعدلين: ${statement.difference.toStringAsFixed(2)}',
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 12,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            balanced
                ? 'النتيجة: التسوية البنكية متوازنة.'
                : 'النتيجة: التسوية غير متوازنة وتحتاج إلى مراجعة البنود أو الأرصدة.',
            textDirection: pw.TextDirection.rtl,
          ),
        ],
      ),
    );
  }
}
