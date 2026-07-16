import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/transaction_record.dart';

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
      sheet.appendRow(_row(pair.left, pair.right, pair.status, pair.reason)
          .map(TextCellValue.new)
          .toList());
    }
    for (final record in result.unmatchedRight) {
      sheet.appendRow(_row(null, record, MatchStatus.unmatched, 'غير موجودة في الطرف الأول')
          .map(TextCellValue.new)
          .toList());
    }

    final summary = book['الملخص'];
    summary.appendRow(['اسم المطابقة', name].map(TextCellValue.new).toList());
    summary.appendRow(['الطرف الأول', firstName].map(TextCellValue.new).toList());
    summary.appendRow(['الطرف الثاني', secondName].map(TextCellValue.new).toList());
    summary.appendRow(['متطابقة', '${result.matchedCount}'].map(TextCellValue.new).toList());
    summary.appendRow(['غير متطابقة', '${result.unmatchedCount}'].map(TextCellValue.new).toList());

    final bytes = book.encode();
    if (bytes == null) throw Exception('تعذر إنشاء ملف Excel.');
    final file = File('${(await getTemporaryDirectory()).path}/${_safe(name)}.xlsx');
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
    final font = await _loadArabicFont();
    final document = pw.Document(theme: pw.ThemeData.withFont(base: font, bold: font));
    final rows = <List<String>>[
      _headers,
      ...result.pairs.map((pair) => _row(pair.left, pair.right, pair.status, pair.reason)),
      ...result.unmatchedRight.map(
        (record) => _row(null, record, MatchStatus.unmatched, 'غير موجودة في الطرف الأول'),
      ),
    ];
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a3.landscape,
        margin: const pw.EdgeInsets.all(18),
        textDirection: pw.TextDirection.rtl,
        build: (_) => [
          pw.Text(name, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text('$firstName  ↔  $secondName'),
          pw.Text('متطابقة: ${result.matchedCount}   |   غير متطابقة: ${result.unmatchedCount}'),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            data: rows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
            cellStyle: const pw.TextStyle(fontSize: 6.3),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.4),
            cellAlignment: pw.Alignment.centerRight,
            headerAlignment: pw.Alignment.centerRight,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
          ),
        ],
      ),
    );
    final file = File('${(await getTemporaryDirectory()).path}/${_safe(name)}.pdf');
    await file.writeAsBytes(await document.save(), flush: true);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    return file;
  }

  static const _headers = [
    'الحالة','السبب',
    'تاريخ الطرف الأول','رقم مستند الطرف الأول','جهة الطرف الأول','مبلغ الطرف الأول','بيان الطرف الأول',
    'تاريخ الطرف الثاني','رقم مستند الطرف الثاني','جهة الطرف الثاني','مبلغ الطرف الثاني','بيان الطرف الثاني',
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

  Future<pw.Font> _loadArabicFont() async {
    const candidates = [
      '/system/fonts/NotoNaskhArabic-Regular.ttf',
      '/system/fonts/NotoSansArabic-Regular.ttf',
      '/system/fonts/NotoSansArabic.ttf',
      '/system/fonts/DroidSansFallback.ttf',
    ];
    for (final path in candidates) {
      final file = File(path);
      if (!await file.exists()) continue;
      try {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) return pw.Font.ttf(ByteData.sublistView(Uint8List.fromList(bytes)));
      } catch (_) {}
    }
    throw const FileSystemException(
      'لا يوجد خط عربي مناسب على هذا الجهاز. استخدم تصدير Excel بدل PDF.',
    );
  }

  String _date(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
  String _safe(String value) => value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}
