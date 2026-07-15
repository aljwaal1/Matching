import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/transaction_record.dart';

class ExportService {
  Future<void> exportExcel({
    required String name,
    required String firstName,
    required String secondName,
    required ReconciliationResult result,
  }) async {
    final workbook = Excel.createExcel();
    final sheet = workbook['نتيجة المطابقة'];
    workbook.delete('Sheet1');

    sheet.appendRow([
      TextCellValue('الحالة'),
      TextCellValue('السبب'),
      TextCellValue('تاريخ الطرف الأول'),
      TextCellValue('رقم مستند الطرف الأول'),
      TextCellValue('مبلغ الطرف الأول'),
      TextCellValue('بيان الطرف الأول'),
      TextCellValue('تاريخ الطرف الثاني'),
      TextCellValue('رقم مستند الطرف الثاني'),
      TextCellValue('مبلغ الطرف الثاني'),
      TextCellValue('بيان الطرف الثاني'),
    ]);

    for (final pair in result.pairs) {
      _appendExcelRow(sheet, pair.left, pair.right, pair.status, pair.reason);
    }
    for (final item in result.unmatchedRight) {
      _appendExcelRow(
        sheet,
        null,
        item,
        MatchStatus.unmatched,
        'غير موجود في الكشف الأول',
      );
    }

    final summary = workbook['الملخص'];
    summary.appendRow([TextCellValue('اسم المطابقة'), TextCellValue(name)]);
    summary.appendRow([TextCellValue('الطرف الأول'), TextCellValue(firstName)]);
    summary.appendRow([TextCellValue('الطرف الثاني'), TextCellValue(secondName)]);
    summary.appendRow([
      TextCellValue('العمليات المتطابقة'),
      IntCellValue(result.matchedCount),
    ]);
    summary.appendRow([
      TextCellValue('العمليات غير المتطابقة'),
      IntCellValue(result.unmatchedCount),
    ]);

    final bytes = workbook.save();
    if (bytes == null) throw Exception('تعذر إنشاء ملف Excel.');
    final file = await _writeFile(_safeName(name), 'xlsx', Uint8List.fromList(bytes));
    await SharePlus.instance.share(
      ShareParams(
        text: 'نتيجة مطابقة الحسابات',
        files: [XFile(file.path)],
      ),
    );
  }

  void _appendExcelRow(
    Sheet sheet,
    TransactionRecord? left,
    TransactionRecord? right,
    MatchStatus status,
    String reason,
  ) {
    final format = DateFormat('yyyy/MM/dd');
    sheet.appendRow([
      TextCellValue(status == MatchStatus.matched ? 'متطابقة' : 'غير متطابقة'),
      TextCellValue(reason),
      TextCellValue(left == null ? '' : format.format(left.date)),
      TextCellValue(left?.documentNumber ?? ''),
      DoubleCellValue(left?.amount ?? 0),
      TextCellValue(left?.description ?? ''),
      TextCellValue(right == null ? '' : format.format(right.date)),
      TextCellValue(right?.documentNumber ?? ''),
      DoubleCellValue(right?.amount ?? 0),
      TextCellValue(right?.description ?? ''),
    ]);
  }

  Future<void> exportPdf({
    required String name,
    required String firstName,
    required String secondName,
    required ReconciliationResult result,
  }) async {
    final document = PdfDocument();
    document.pageSettings.orientation = PdfPageOrientation.landscape;
    document.pageSettings.size = PdfPageSize.a3;
    document.pageSettings.margins.all = 24;

    try {
      final font = await _arabicFont(9);
      final titleFont = await _arabicFont(17);
      final page = document.pages.add();
      page.graphics.drawString(
        name,
        titleFont,
        bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, 30),
        format: PdfStringFormat(
          textDirection: PdfTextDirection.rightToLeft,
          alignment: PdfTextAlignment.center,
        ),
      );
      page.graphics.drawString(
        '$firstName  -  $secondName',
        font,
        bounds: Rect.fromLTWH(0, 34, page.getClientSize().width, 22),
        format: PdfStringFormat(
          textDirection: PdfTextDirection.rightToLeft,
          alignment: PdfTextAlignment.center,
        ),
      );
      page.graphics.drawString(
        'المتطابقة: ${result.matchedCount}     غير المتطابقة: ${result.unmatchedCount}',
        font,
        bounds: Rect.fromLTWH(0, 58, page.getClientSize().width, 22),
        format: PdfStringFormat(
          textDirection: PdfTextDirection.rightToLeft,
          alignment: PdfTextAlignment.center,
        ),
      );

      final grid = PdfGrid();
      grid.columns.add(count: 10);
      final header = grid.headers.add(1)[0];
      final headers = [
        'الحالة',
        'السبب',
        'تاريخ الطرف الأول',
        'رقم مستند الطرف الأول',
        'مبلغ الطرف الأول',
        'بيان الطرف الأول',
        'تاريخ الطرف الثاني',
        'رقم مستند الطرف الثاني',
        'مبلغ الطرف الثاني',
        'بيان الطرف الثاني',
      ];
      for (var i = 0; i < headers.length; i++) {
        header.cells[i].value = headers[i];
      }

      final rows = <({TransactionRecord? left, TransactionRecord? right, MatchStatus status, String reason})>[
        ...result.pairs.map((pair) => (
              left: pair.left,
              right: pair.right,
              status: pair.status,
              reason: pair.reason,
            )),
        ...result.unmatchedRight.map((item) => (
              left: null,
              right: item,
              status: MatchStatus.unmatched,
              reason: 'غير موجود في الكشف الأول',
            )),
      ];
      final date = DateFormat('yyyy/MM/dd');
      for (final item in rows) {
        final row = grid.rows.add();
        row.cells[0].value = item.status == MatchStatus.matched ? 'متطابقة' : 'غير متطابقة';
        row.cells[1].value = item.reason;
        row.cells[2].value = item.left == null ? '' : date.format(item.left!.date);
        row.cells[3].value = item.left?.documentNumber ?? '';
        row.cells[4].value = item.left?.amount.toStringAsFixed(2) ?? '';
        row.cells[5].value = item.left?.description ?? '';
        row.cells[6].value = item.right == null ? '' : date.format(item.right!.date);
        row.cells[7].value = item.right?.documentNumber ?? '';
        row.cells[8].value = item.right?.amount.toStringAsFixed(2) ?? '';
        row.cells[9].value = item.right?.description ?? '';
      }

      grid.style = PdfGridStyle(
        font: font,
        cellPadding: PdfPaddings(left: 3, right: 3, top: 3, bottom: 3),
      );
      for (var rowIndex = 0; rowIndex < grid.rows.count; rowIndex++) {
        final row = grid.rows[rowIndex];
        for (var cellIndex = 0; cellIndex < row.cells.count; cellIndex++) {
          final cell = row.cells[cellIndex];
          cell.stringFormat = PdfStringFormat(
            textDirection: PdfTextDirection.rightToLeft,
            alignment: PdfTextAlignment.center,
            lineAlignment: PdfVerticalAlignment.middle,
          );
        }
      }
      for (var cellIndex = 0; cellIndex < header.cells.count; cellIndex++) {
        final cell = header.cells[cellIndex];
        cell.style.font = font;
        cell.stringFormat = PdfStringFormat(
          textDirection: PdfTextDirection.rightToLeft,
          alignment: PdfTextAlignment.center,
          lineAlignment: PdfVerticalAlignment.middle,
        );
      }
      grid.draw(page: page, bounds: Rect.fromLTWH(0, 90, 0, 0));

      final bytes = await document.save();
      final file = await _writeFile(_safeName(name), 'pdf', Uint8List.fromList(bytes));
      await SharePlus.instance.share(
        ShareParams(
          text: 'نتيجة مطابقة الحسابات',
          files: [XFile(file.path)],
        ),
      );
    } finally {
      document.dispose();
    }
  }

  Future<PdfFont> _arabicFont(double size) async {
    const paths = [
      '/system/fonts/NotoNaskhArabic-Regular.ttf',
      '/system/fonts/NotoSansArabic-Regular.ttf',
      '/system/fonts/NotoSansArabicUI-Regular.ttf',
      '/system/fonts/DroidNaskh-Regular-SystemUI.ttf',
      '/system/fonts/DroidSansArabic.ttf',
      '/system/fonts/DroidSansFallback.ttf',
    ];
    for (final path in paths) {
      final file = File(path);
      if (await file.exists()) {
        return PdfTrueTypeFont(await file.readAsBytes(), size);
      }
    }
    throw const FileSystemException(
      'تعذر إنشاء PDF عربي لأن الجهاز لا يحتوي على خط عربي مدعوم. استخدم تصدير Excel على هذا الجهاز.',
    );
  }

  Future<File> _writeFile(String name, String extension, Uint8List bytes) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$name.$extension');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  String _safeName(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_');
    return cleaned.isEmpty ? 'نتيجة_المطابقة' : cleaned;
  }
}
