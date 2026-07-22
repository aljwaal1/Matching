import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/transaction_record.dart';
import 'arabic_pdf_support.dart';
import 'excel_report_style.dart';
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
    summary.appendRow([
      TextCellValue('ملخص نتائج المطابقة'),
      TextCellValue(''),
    ]);
    summary.appendRow([TextCellValue('اسم المطابقة'), TextCellValue(name)]);
    summary.appendRow([TextCellValue('كشف حساب الشركة'), TextCellValue(firstName)]);
    summary.appendRow([TextCellValue('كشف حساب العميل أو المورد'), TextCellValue(secondName)]);
    summary.appendRow([
      TextCellValue('عدد العمليات المتطابقة'),
      IntCellValue(result.matchedCount),
    ]);
    summary.appendRow([
      TextCellValue('عدد العمليات المعلقة'),
      IntCellValue(result.pendingCount),
    ]);
    summary.appendRow([
      TextCellValue('عدد العمليات غير المتطابقة'),
      IntCellValue(result.unmatchedCount),
    ]);
    summary.appendRow([
      TextCellValue('تاريخ إنشاء الملف'),
      TextCellValue(
        DateFormat('yyyy/MM/dd HH:mm', 'en_US').format(DateTime.now()),
      ),
    ]);
    ExcelReportStyle.styleSummary(summary, rows: summary.maxRows);

    final matched = workbook['العمليات المتطابقة'];
    matched.appendRow(_headers.map(TextCellValue.new).toList());
    for (final pair
        in result.pairs.where((item) => item.status == MatchStatus.matched)) {
      matched.appendRow(
        _excelRow(
          left: pair.left,
          right: pair.right,
          status: pair.status,
          reason: pair.reason,
          score: pair.score,
        ),
      );
    }
    _styleResultSheet(matched);

    final pending = workbook['العمليات المعلقة'];
    pending.appendRow(_headers.map(TextCellValue.new).toList());
    for (final pair
        in result.pairs.where((item) => item.status == MatchStatus.pending)) {
      pending.appendRow(
        _excelRow(
          left: pair.left,
          right: pair.right,
          status: pair.status,
          reason: pair.reason,
          score: pair.score,
        ),
      );
    }
    _styleResultSheet(pending);

    final unmatched = workbook['العمليات غير المتطابقة'];
    unmatched.appendRow(_headers.map(TextCellValue.new).toList());
    for (final pair
        in result.pairs.where((item) => item.status == MatchStatus.unmatched)) {
      unmatched.appendRow(
        _excelRow(
          left: pair.left,
          right: pair.right,
          status: pair.status,
          reason: pair.reason,
          score: pair.score,
        ),
      );
    }
    for (final record in result.unmatchedRight) {
      unmatched.appendRow(
        _excelRow(
          left: null,
          right: record,
          status: MatchStatus.unmatched,
          reason: 'غير موجودة في كشف حساب الشركة',
          score: null,
        ),
      );
    }
    _styleResultSheet(unmatched);

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
          score: pair.score,
        ),
      ),
      ...result.unmatchedRight.map(
        (record) => _PdfResultRow(
          left: null,
          right: record,
          status: MatchStatus.unmatched,
          reason: 'غير موجودة في كشف حساب الشركة',
          score: null,
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

  void _styleResultSheet(Sheet sheet) {
    ExcelReportStyle.styleTable(
      sheet,
      headerRow: 0,
      lastRow: sheet.maxRows - 1,
      columnCount: _headers.length,
      moneyColumns: const {6, 11},
      centeredColumns: const {0, 1, 3, 4, 5, 8, 9, 10},
      widths: const [16, 15, 34, 15, 19, 13, 18, 38, 15, 19, 13, 18, 38],
    );
  }

  List<CellValue> _excelRow({
    required TransactionRecord? left,
    required TransactionRecord? right,
    required MatchStatus status,
    required String reason,
    required double? score,
  }) =>
      [
        TextCellValue(
          _status(status),
        ),
        TextCellValue(score == null ? '-' : '${score.toStringAsFixed(1)}%'),
        TextCellValue(reason),
        TextCellValue(left == null ? '' : _date(left.date)),
        TextCellValue(left?.documentNumber?.trim() ?? ''),
        TextCellValue(left?.sideLabel ?? ''),
        left == null ? TextCellValue('') : DoubleCellValue(left.amount),
        TextCellValue(left?.description ?? ''),
        TextCellValue(right == null ? '' : _date(right.date)),
        TextCellValue(right?.documentNumber?.trim() ?? ''),
        TextCellValue(right?.sideLabel ?? ''),
        right == null ? TextCellValue('') : DoubleCellValue(right.amount),
        TextCellValue(right?.description ?? ''),
      ];

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
            arabicPdfText('كشف حساب الشركة: $firstName', fonts),
            arabicPdfText('كشف حساب العميل أو المورد: $secondName', fonts),
            arabicPdfText(
              'تاريخ التقرير: ${DateFormat('yyyy/MM/dd HH:mm', 'en_US').format(DateTime.now())}',
              fonts,
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ],
        ),
      );

  pw.Widget _summary(ArabicPdfFonts fonts, ReconciliationResult result) =>
      pw.Row(
        children: [
          _summaryBox(
            fonts,
            'إجمالي العمليات',
            result.matchedCount + result.pendingCount + result.unmatchedCount,
          ),
          pw.SizedBox(width: 8),
          _summaryBox(fonts, 'المتطابقة', result.matchedCount),
          pw.SizedBox(width: 8),
          _summaryBox(fonts, 'المعلقة', result.pendingCount),
          pw.SizedBox(width: 8),
          _summaryBox(fonts, 'غير المتطابقة', result.unmatchedCount),
        ],
      );

  pw.Widget _summaryBox(
    ArabicPdfFonts fonts,
    String label,
    int value,
  ) =>
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(9),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#FAFAFC'),
            borderRadius: pw.BorderRadius.circular(7),
            border: pw.Border.all(color: PdfColors.grey400),
          ),
          child: pw.Column(
            children: [
              arabicPdfText(
                label,
                fonts,
                bold: true,
                textAlign: pw.TextAlign.center,
              ),
              arabicPdfText(
                '$value',
                fonts,
                fontSize: 15,
                bold: true,
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),
      );

  pw.Widget _table(ArabicPdfFonts fonts, List<_PdfResultRow> rows) =>
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.45),
        columnWidths: const {
          0: pw.FlexColumnWidth(1.1),
          1: pw.FlexColumnWidth(2.0),
          2: pw.FlexColumnWidth(3.6),
          3: pw.FlexColumnWidth(3.6),
        },
        children: [
          pw.TableRow(
            repeat: true,
            decoration: pw.BoxDecoration(color: PdfColor.fromHex('#DCD2FF')),
            children: [
              _cell(fonts, 'الحالة', bold: true, center: true),
              _cell(fonts, 'سبب ودرجة المطابقة', bold: true, center: true),
              _cell(fonts, 'تفاصيل كشف حساب الشركة', bold: true, center: true),
              _cell(fonts, 'تفاصيل كشف حساب العميل أو المورد', bold: true, center: true),
            ],
          ),
          ...rows.map(
            (row) => pw.TableRow(
              decoration: pw.BoxDecoration(
                color: row.status == MatchStatus.matched
                    ? PdfColor.fromHex('#F2FFFB')
                    : row.status == MatchStatus.pending
                        ? PdfColor.fromHex('#FFF9E8')
                        : PdfColor.fromHex('#FFF6F8'),
              ),
              children: [
                _cell(
                  fonts,
                  _status(row.status),
                  bold: true,
                  center: true,
                ),
                _cell(
                  fonts,
                  '${row.reason}${row.score == null ? '' : '\nدرجة المطابقة: ${row.score!.toStringAsFixed(1)}%'}',
                ),
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
    if (record == null) {
      return _cell(fonts, 'لا توجد عملية مقابلة', center: true);
    }
    final document = record.documentNumber?.trim();
    return _cell(
      fonts,
      'التاريخ: ${_date(record.date)}\n'
      'رقم المرجع أو المستند: ${document == null || document.isEmpty ? '-' : document}\n'
      'الجهة: ${record.sideLabel}\n'
      'المبلغ: ${_money(record.amount)}\n'
      'البيان: ${record.description.trim().isEmpty ? '-' : record.description}',
    );
  }

  static const _headers = [
    'الحالة',
    'درجة المطابقة',
    'السبب',
    'تاريخ كشف حساب الشركة',
    'رقم مرجع أو مستند كشف حساب الشركة',
    'جهة كشف حساب الشركة',
    'مبلغ كشف حساب الشركة',
    'بيان كشف حساب الشركة',
    'تاريخ كشف حساب العميل أو المورد',
    'رقم مرجع أو مستند كشف حساب العميل أو المورد',
    'جهة كشف حساب العميل أو المورد',
    'مبلغ كشف حساب العميل أو المورد',
    'بيان كشف حساب العميل أو المورد',
  ];

  String _date(DateTime date) =>
      DateFormat('yyyy-MM-dd', 'en_US').format(date);

  String _money(double value) =>
      NumberFormat('#,##0.00', 'en_US').format(value.abs());

  String _status(MatchStatus status) => switch (status) {
        MatchStatus.matched => 'متطابقة',
        MatchStatus.pending => 'معلقة للمراجعة',
        MatchStatus.unmatched => 'غير متطابقة',
      };

  String _safe(String value) =>
      value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}

class _PdfResultRow {
  const _PdfResultRow({
    required this.left,
    required this.right,
    required this.status,
    required this.reason,
    required this.score,
  });

  final TransactionRecord? left;
  final TransactionRecord? right;
  final MatchStatus status;
  final String reason;
  final double? score;
}
