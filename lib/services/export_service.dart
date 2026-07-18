import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/transaction_record.dart';
import 'arabic_pdf_support.dart';
import 'file_save_service.dart';

class ExportService {
  const ExportService({this.fileSaver = const FileSaveService()});

  final FileSaveService fileSaver;

  Future<SavedReport?> exportExcel({
    required String name,
    required String firstName,
    required String secondName,
    required ReconciliationResult result,
  }) async {
    final workbook = Excel.createExcel();
    workbook.delete('Sheet1');

    final summary = workbook['الملخص'];
    summary.appendRow(['اسم المطابقة', name].map(TextCellValue.new).toList());
    summary.appendRow(['الطرف الأول', firstName].map(TextCellValue.new).toList());
    summary.appendRow(['الطرف الثاني', secondName].map(TextCellValue.new).toList());
    summary.appendRow(['عدد المتطابق', '${result.matchedCount}'].map(TextCellValue.new).toList());
    summary.appendRow(['عدد غير المتطابق', '${result.unmatchedCount}'].map(TextCellValue.new).toList());
    summary.appendRow([
      'تاريخ إنشاء الملف',
      DateFormat('yyyy/MM/dd HH:mm', 'en_US').format(DateTime.now()),
    ].map(TextCellValue.new).toList());

    final matched = workbook['العمليات المتطابقة'];
    matched.appendRow(_headers.map(TextCellValue.new).toList());
    for (final pair in result.pairs.where((item) => item.status == MatchStatus.matched)) {
      matched.appendRow(
        _row(pair.left, pair.right, pair.status, pair.reason)
            .map(TextCellValue.new)
            .toList(),
      );
    }

    final unmatched = workbook['العمليات غير المتطابقة'];
    unmatched.appendRow(_headers.map(TextCellValue.new).toList());
    for (final pair in result.pairs.where((item) => item.status == MatchStatus.unmatched)) {
      unmatched.appendRow(
        _row(pair.left, pair.right, pair.status, pair.reason)
            .map(TextCellValue.new)
            .toList(),
      );
    }
    for (final record in result.unmatchedRight) {
      unmatched.appendRow(
        _row(
          null,
          record,
          MatchStatus.unmatched,
          'غير موجودة في الطرف الأول',
        ).map(TextCellValue.new).toList(),
      );
    }

    final encoded = workbook.encode();
    if (encoded == null) throw Exception('تعذر إنشاء ملف Excel.');
    return fileSaver.saveBytes(
      bytes: Uint8List.fromList(encoded),
      fileName: _safe(name),
      extension: 'xlsx',
      dialogTitle: 'حفظ نتائج المطابقة بصيغة Excel',
    );
  }

  Future<SavedReport?> exportPdf({
    required String name,
    required String firstName,
    required String secondName,
    required ReconciliationResult result,
  }) async {
    final fonts = await loadArabicPdfFonts();
    final document = pw.Document(theme: arabicPdfTheme(fonts));
    final rows = <_PdfResultRow>[
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
        footer: (context) => arabicPdfText(
          'الصفحة ${context.pageNumber} من ${context.pagesCount}',
          fonts,
          fontSize: 8,
          color: PdfColors.grey700,
          textAlign: pw.TextAlign.center,
        ),
        build: (_) => [
          _header(fonts, name, firstName, secondName),
          pw.SizedBox(height: 12),
          _summary(fonts, result),
          pw.SizedBox(height: 14),
          if (rows.isEmpty)
            arabicPdfText(
              'لا توجد عمليات لعرضها في تقرير المطابقة.',
              fonts,
              bold: true,
              textAlign: pw.TextAlign.center,
            )
          else
            _table(fonts, rows),
        ],
      ),
    );

    return fileSaver.saveBytes(
      bytes: Uint8List.fromList(await document.save()),
      fileName: _safe(name),
      extension: 'pdf',
      dialogTitle: 'حفظ نتائج المطابقة بصيغة PDF',
    );
  }

  pw.Widget _header(
    ArabicPdfFonts fonts,
    String name,
    String firstName,
    String secondName,
  ) =>
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
            arabicPdfText('الطرف الأول: $firstName', fonts),
            arabicPdfText('الطرف الثاني: $secondName', fonts),
            arabicPdfText(
              'تاريخ التقرير: ${DateFormat('yyyy/MM/dd HH:mm', 'en_US').format(DateTime.now())}',
              fonts,
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ],
        ),
      );

  pw.Widget _summary(ArabicPdfFonts fonts, ReconciliationResult result) => pw.Row(
        children: [
          _summaryBox(fonts, 'إجمالي العمليات', result.matchedCount + result.unmatchedCount),
          pw.SizedBox(width: 8),
          _summaryBox(fonts, 'المتطابقة', result.matchedCount),
          pw.SizedBox(width: 8),
          _summaryBox(fonts, 'غير المتطابقة', result.unmatchedCount),
        ],
      );

  pw.Widget _summaryBox(ArabicPdfFonts fonts, String label, int value) => pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(9),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#FAFAFC'),
            borderRadius: pw.BorderRadius.circular(7),
            border: pw.Border.all(color: PdfColors.grey400),
          ),
          child: pw.Column(
            children: [
              arabicPdfText(label, fonts, bold: true, textAlign: pw.TextAlign.center),
              arabicPdfText('$value', fonts, fontSize: 15, bold: true, textAlign: pw.TextAlign.center),
            ],
          ),
        ),
      );

  pw.Widget _table(ArabicPdfFonts fonts, List<_PdfResultRow> rows) => pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.45),
        columnWidths: const {
          0: pw.FlexColumnWidth(1.1),
          1: pw.FlexColumnWidth(1.8),
          2: pw.FlexColumnWidth(3.6),
          3: pw.FlexColumnWidth(3.6),
        },
        children: [
          pw.TableRow(
            repeat: true,
            decoration: pw.BoxDecoration(color: PdfColor.fromHex('#DCD2FF')),
            children: [
              _cell(fonts, 'الحالة', bold: true, center: true),
              _cell(fonts, 'سبب النتيجة', bold: true, center: true),
              _cell(fonts, 'تفاصيل الطرف الأول', bold: true, center: true),
              _cell(fonts, 'تفاصيل الطرف الثاني', bold: true, center: true),
            ],
          ),
          ...rows.map(
            (row) => pw.TableRow(
              decoration: pw.BoxDecoration(
                color: row.status == MatchStatus.matched
                    ? PdfColor.fromHex('#F2FFFB')
                    : PdfColor.fromHex('#FFF6F8'),
              ),
              children: [
                _cell(
                  fonts,
                  row.status == MatchStatus.matched ? 'متطابقة' : 'غير متطابقة',
                  bold: true,
                  center: true,
                ),
                _cell(fonts, row.reason),
                _transaction(fonts, row.left),
                _transaction(fonts, row.right),
              ],
            ),
          ),
        ],
      );

  pw.Widget _cell(
    ArabicPdfFonts fonts,
    String value, {
    bool bold = false,
    bool center = false,
  }) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
        child: arabicPdfText(
          value.trim().isEmpty ? '-' : value,
          fonts,
          fontSize: 7.5,
          bold: bold,
          textAlign: center ? pw.TextAlign.center : pw.TextAlign.right,
        ),
      );

  pw.Widget _transaction(ArabicPdfFonts fonts, TransactionRecord? record) {
    if (record == null) return _cell(fonts, 'لا توجد عملية مقابلة', center: true);
    final document = record.documentNumber?.trim();
    return _cell(
      fonts,
      'التاريخ: ${_date(record.date)}\n'
      'المستند: ${document == null || document.isEmpty ? '-' : document}\n'
      'الجهة: ${record.sideLabel}\n'
      'المبلغ: ${_money(record.amount)}\n'
      'البيان: ${record.description.trim().isEmpty ? '-' : record.description}',
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
  ) =>
      [
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
  String _money(double value) => NumberFormat('#,##0.00', 'en_US').format(value.abs());
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
