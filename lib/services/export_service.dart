import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/transaction_record.dart';
import 'arabic_pdf_support.dart';

class ExportService {
  Future<File> exportExcel({
    required String name,
    required String firstName,
    required String secondName,
    required ReconciliationResult result,
  }) async {
    final book = Excel.createExcel();
    final sheet = book['النتائج'];
    book.delete('Sheet1');
    sheet.appendRow(_headers.map(TextCellValue.new).toList());
    for (final pair in result.pairs) {
      sheet.appendRow(
        _row(pair.left, pair.right, pair.status, pair.reason)
            .map(TextCellValue.new)
            .toList(),
      );
    }
    for (final record in result.unmatchedRight) {
      sheet.appendRow(
        _row(
          null,
          record,
          MatchStatus.unmatched,
          'غير موجودة في الطرف الأول',
        ).map(TextCellValue.new).toList(),
      );
    }

    final summary = book['الملخص'];
    summary.appendRow(['اسم المطابقة', name].map(TextCellValue.new).toList());
    summary.appendRow(['الطرف الأول', firstName].map(TextCellValue.new).toList());
    summary.appendRow(['الطرف الثاني', secondName].map(TextCellValue.new).toList());
    summary.appendRow(['متطابقة', '${result.matchedCount}'].map(TextCellValue.new).toList());
    summary.appendRow(['غير متطابقة', '${result.unmatchedCount}'].map(TextCellValue.new).toList());

    final bytes = book.encode();
    if (bytes == null) throw Exception('تعذر إنشاء ملف Excel.');
    final file = File(
      '${(await getTemporaryDirectory()).path}/${_safe(name)}.xlsx',
    );
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    return file;
  }

  Future<File> exportPdf({
    required String name,
    required String firstName,
    required String secondName,
    required ReconciliationResult result,
  }) async {
    final fonts = await loadArabicPdfFonts();
    final document = pw.Document(theme: arabicPdfTheme(fonts));
    final displayRows = <_PdfResultRow>[
      ...result.pairs.map(
        (pair) => _PdfResultRow(
          left: pair.left,
          right: pair.right,
          status: pair.status,
          reason: pair.reason,
        ),
      ),
      ...result.unmatchedRight.map(
        (record) => _PdfResultRow(
          left: null,
          right: record,
          status: MatchStatus.unmatched,
          reason: 'غير موجودة في الطرف الأول',
        ),
      ),
    ];

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(20, 18, 20, 24),
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
          _pdfHeader(
            fonts: fonts,
            name: name,
            firstName: firstName,
            secondName: secondName,
            result: result,
          ),
          pw.SizedBox(height: 12),
          _summaryCards(fonts, result),
          pw.SizedBox(height: 14),
          if (displayRows.isEmpty)
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(18),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F7F7FA'),
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.grey400),
              ),
              child: arabicPdfText(
                'لا توجد عمليات لعرضها في تقرير المطابقة.',
                fonts,
                bold: true,
                textAlign: pw.TextAlign.center,
              ),
            )
          else
            _resultsTable(fonts, displayRows),
        ],
      ),
    );

    final file = File(
      '${(await getTemporaryDirectory()).path}/${_safe(name)}.pdf',
    );
    await file.writeAsBytes(await document.save(), flush: true);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    return file;
  }

  pw.Widget _pdfHeader({
    required ArabicPdfFonts fonts,
    required String name,
    required String firstName,
    required String secondName,
    required ReconciliationResult result,
  }) =>
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#F1ECFF'),
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: PdfColor.fromHex('#CFC4FF')),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            arabicPdfText(
              name,
              fonts,
              fontSize: 18,
              bold: true,
              color: PdfColor.fromHex('#4B2FCC'),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 5),
            arabicPdfText(
              'الطرف الأول: $firstName',
              fonts,
              fontSize: 10,
            ),
            arabicPdfText(
              'الطرف الثاني: $secondName',
              fonts,
              fontSize: 10,
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

  pw.Widget _summaryCards(
    ArabicPdfFonts fonts,
    ReconciliationResult result,
  ) =>
      pw.Row(
        children: [
          pw.Expanded(
            child: _summaryCard(
              fonts,
              label: 'إجمالي العمليات',
              value: '${result.matchedCount + result.unmatchedCount}',
              color: PdfColor.fromHex('#6D4CFF'),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: _summaryCard(
              fonts,
              label: 'العمليات المتطابقة',
              value: '${result.matchedCount}',
              color: PdfColor.fromHex('#009B83'),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: _summaryCard(
              fonts,
              label: 'العمليات غير المتطابقة',
              value: '${result.unmatchedCount}',
              color: PdfColor.fromHex('#C82E60'),
            ),
          ),
        ],
      );

  pw.Widget _summaryCard(
    ArabicPdfFonts fonts, {
    required String label,
    required String value,
    required PdfColor color,
  }) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#FAFAFC'),
          borderRadius: pw.BorderRadius.circular(7),
          border: pw.Border.all(color: color, width: 0.8),
        ),
        child: pw.Column(
          children: [
            arabicPdfText(
              label,
              fonts,
              fontSize: 9,
              bold: true,
              color: color,
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 3),
            arabicPdfText(
              value,
              fonts,
              fontSize: 15,
              bold: true,
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      );

  pw.Widget _resultsTable(
    ArabicPdfFonts fonts,
    List<_PdfResultRow> rows,
  ) =>
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.45),
        columnWidths: const {
          0: pw.FlexColumnWidth(1.1),
          1: pw.FlexColumnWidth(1.7),
          2: pw.FlexColumnWidth(3.6),
          3: pw.FlexColumnWidth(3.6),
        },
        children: [
          pw.TableRow(
            repeat: true,
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#DCD2FF'),
            ),
            verticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
              _headerCell(fonts, 'الحالة'),
              _headerCell(fonts, 'سبب النتيجة'),
              _headerCell(fonts, 'تفاصيل الطرف الأول'),
              _headerCell(fonts, 'تفاصيل الطرف الثاني'),
            ],
          ),
          ...rows.map((row) => _resultTableRow(fonts, row)),
        ],
      );

  pw.TableRow _resultTableRow(
    ArabicPdfFonts fonts,
    _PdfResultRow row,
  ) {
    final matched = row.status == MatchStatus.matched;
    return pw.TableRow(
      verticalAlignment: pw.TableCellVerticalAlignment.middle,
      decoration: pw.BoxDecoration(
        color: matched
            ? PdfColor.fromHex('#F2FFFB')
            : PdfColor.fromHex('#FFF6F8'),
      ),
      children: [
        _bodyCell(
          fonts,
          matched ? 'متطابقة' : 'غير متطابقة',
          bold: true,
          color: matched
              ? PdfColor.fromHex('#007D69')
              : PdfColor.fromHex('#B51F50'),
          textAlign: pw.TextAlign.center,
        ),
        _bodyCell(fonts, row.reason),
        _transactionCell(fonts, row.left),
        _transactionCell(fonts, row.right),
      ],
    );
  }

  pw.Widget _headerCell(ArabicPdfFonts fonts, String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 7),
        child: arabicPdfText(
          text,
          fonts,
          fontSize: 8.5,
          bold: true,
          textAlign: pw.TextAlign.center,
        ),
      );

  pw.Widget _bodyCell(
    ArabicPdfFonts fonts,
    String text, {
    bool bold = false,
    PdfColor? color,
    pw.TextAlign textAlign = pw.TextAlign.right,
  }) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
        child: arabicPdfText(
          text.isEmpty ? '-' : text,
          fonts,
          fontSize: 7.5,
          bold: bold,
          color: color,
          textAlign: textAlign,
        ),
      );

  pw.Widget _transactionCell(
    ArabicPdfFonts fonts,
    TransactionRecord? record,
  ) {
    if (record == null) {
      return _bodyCell(
        fonts,
        'لا توجد عملية مقابلة',
        textAlign: pw.TextAlign.center,
      );
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          arabicPdfText(
            'التاريخ: ${_date(record.date)}',
            fonts,
            fontSize: 7.4,
          ),
          arabicPdfText(
            'رقم المستند: ${record.documentNumber?.trim().isEmpty ?? true ? '-' : record.documentNumber}',
            fonts,
            fontSize: 7.4,
          ),
          arabicPdfText(
            'الجهة: ${record.sideLabel}',
            fonts,
            fontSize: 7.4,
          ),
          arabicPdfText(
            'المبلغ: ${_money(record.amount)}',
            fonts,
            fontSize: 7.6,
            bold: true,
          ),
          arabicPdfText(
            'البيان: ${record.description.trim().isEmpty ? '-' : record.description}',
            fonts,
            fontSize: 7.4,
          ),
        ],
      ),
    );
  }

  static const _headers = [
    'الحالة',
    'السبب',
    'تاريخ الطرف الأول',
    'رقم مستند الطرف الأول',
    'جهة الطرف الأول',
    'مبلغ الطرف الأول',
    'بيان الطرف الأول',
    'تاريخ الطرف الثاني',
    'رقم مستند الطرف الثاني',
    'جهة الطرف الثاني',
    'مبلغ الطرف الثاني',
    'بيان الطرف الثاني',
  ];

  List<String> _row(
    TransactionRecord? left,
    TransactionRecord? right,
    MatchStatus status,
    String reason,
  ) => [
        status == MatchStatus.matched ? 'متطابقة' : 'غير متطابقة',
        reason,
        left == null ? '' : _date(left.date),
        left?.documentNumber ?? '',
        left?.sideLabel ?? '',
        left?.amount.toStringAsFixed(2) ?? '',
        left?.description ?? '',
        right == null ? '' : _date(right.date),
        right?.documentNumber ?? '',
        right?.sideLabel ?? '',
        right?.amount.toStringAsFixed(2) ?? '',
        right?.description ?? '',
      ];

  String _date(DateTime date) => DateFormat('yyyy-MM-dd', 'en_US').format(date);
  String _money(double value) =>
      NumberFormat('#,##0.00', 'en_US').format(value.abs());
  String _safe(String value) => value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}

class _PdfResultRow {
  const _PdfResultRow({
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
