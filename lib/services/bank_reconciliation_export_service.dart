import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/bank_reconciliation.dart';
import 'arabic_pdf_support.dart';
import 'file_save_service.dart';

class BankReconciliationExportService {
  const BankReconciliationExportService({
    this.fileSaver = const FileSaveService(),
  });

  final FileSaveService fileSaver;

  Future<SavedReport?> exportPdf({
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
        footer: (context) => arabicPdfText(
          'الصفحة ${context.pageNumber} من ${context.pagesCount}',
          fonts,
          fontSize: 8,
          color: PdfColors.grey700,
          textAlign: pw.TextAlign.center,
        ),
        build: (_) => [
          _header(fonts, companyName, bankName, statement),
          pw.SizedBox(height: 16),
          _section(
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
          _section(
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
          pw.SizedBox(height: 12),
          _statusSummary(fonts, statement),
        ],
      ),
    );

    final period = DateFormat('yyyy-MM', 'en_US').format(statement.period);
    final baseName = _safe('تسوية_${bankName}_$period');
    final pdfResult = await fileSaver.saveBytes(
      bytes: Uint8List.fromList(await document.save()),
      fileName: baseName,
      extension: 'pdf',
      dialogTitle: 'حفظ التسوية البنكية بصيغة PDF',
    );

    if (pdfResult != null) {
      await exportExcel(
        companyName: companyName,
        bankName: bankName,
        statement: statement,
        suggestedName: baseName,
      );
    }
    return pdfResult;
  }

  Future<SavedReport?> exportExcel({
    required String companyName,
    required String bankName,
    required BankReconciliationStatement statement,
    String? suggestedName,
  }) async {
    final workbook = Excel.createExcel();
    workbook.delete('Sheet1');

    final summary = workbook['ملخص التسوية'];
    final summaryRows = <List<String>>[
      ['الشركة', companyName],
      ['البنك أو الحساب', bankName],
      ['شهر التسوية', DateFormat('yyyy/MM', 'en_US').format(statement.period)],
      ['رصيد كشف البنك', _money(statement.bankBalance)],
      ['الرصيد المعدل حسب البنك', _money(statement.adjustedBankBalance)],
      ['رصيد دفاتر الشركة', _money(statement.bookBalance)],
      ['الرصيد المعدل حسب الدفاتر', _money(statement.adjustedBookBalance)],
      ['الفرق النهائي', _money(statement.difference)],
      ['حالة التسوية', statement.isBalanced ? 'متوازنة' : 'غير متوازنة'],
    ];
    for (final row in summaryRows) {
      summary.appendRow(row.map(TextCellValue.new).toList());
    }

    final items = workbook['بنود التسوية'];
    const headers = [
      'البيان',
      'التصنيف',
      'المبلغ',
      'الجانب المعدل',
      'المعالجة',
      'الحالة',
      'مرحّل من شهر سابق',
      'بند يدوي',
    ];
    items.appendRow(headers.map(TextCellValue.new).toList());
    for (final item in statement.items) {
      items.appendRow(
        [
          item.description,
          item.type.label,
          _money(item.amount),
          item.adjustBankBalance ? 'كشف البنك' : 'دفاتر الشركة',
          item.add ? 'إضافة' : 'خصم',
          item.status.label,
          item.fromPreviousPeriod ? 'نعم' : 'لا',
          item.manual ? 'نعم' : 'لا',
        ].map(TextCellValue.new).toList(),
      );
    }

    final encoded = workbook.encode();
    if (encoded == null) throw Exception('تعذر إنشاء ملف Excel للتسوية.');
    final period = DateFormat('yyyy-MM', 'en_US').format(statement.period);
    return fileSaver.saveBytes(
      bytes: Uint8List.fromList(encoded),
      fileName: suggestedName ?? _safe('تسوية_${bankName}_$period'),
      extension: 'xlsx',
      dialogTitle: 'حفظ التسوية البنكية بصيغة Excel',
    );
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
          ],
        ),
      );

  pw.Widget _section({
    required ArabicPdfFonts fonts,
    required String title,
    required String openingLabel,
    required double openingBalance,
    required List<BankAdjustmentItem> items,
    required String closingLabel,
    required double closingBalance,
    required PdfColor color,
  }) =>
      pw.Table(
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
          ...items.map(
            (item) => _amountRow(
              fonts,
              '${item.add ? 'يضاف' : 'يخصم'}: ${item.type.label}'
              '${item.description.isEmpty ? '' : '\n${item.description}'}'
              '\nالحالة: ${item.status.label}',
              item.add ? item.amount : -item.amount,
            ),
          ),
          _amountRow(
            fonts,
            closingLabel,
            closingBalance,
            bold: true,
            highlight: true,
          ),
        ],
      );

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
        padding: const pw.EdgeInsets.all(7),
        child: arabicPdfText(
          text,
          fonts,
          fontSize: 9.5,
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
    return arabicPdfText(
      'تمت تسويتها: $cleared | معلقة: $pending | مرحلة للشهر القادم: $carried',
      fonts,
      fontSize: 9,
      bold: true,
      textAlign: pw.TextAlign.center,
    );
  }

  String _money(double value) {
    final formatted = NumberFormat('#,##0.00', 'en_US').format(value.abs());
    return value < 0 ? '-$formatted' : formatted;
  }

  String _safe(String value) => value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}
