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
    required ReconciliationResult result,
  }) async {
    final book = Excel.createExcel();
    final sheet = book['النتائج'];
    sheet.appendRow([
      'الحالة', 'السبب',
      'تاريخ الطرف الأول', 'رقم مستند الطرف الأول', 'مبلغ الطرف الأول', 'بيان الطرف الأول',
      'تاريخ الطرف الثاني', 'رقم مستند الطرف الثاني', 'مبلغ الطرف الثاني', 'بيان الطرف الثاني',
    ].map(TextCellValue.new).toList());
    for (final pair in result.pairs) {
      sheet.appendRow(_row(pair).map(TextCellValue.new).toList());
    }
    for (final record in result.unmatchedRight) {
      sheet.appendRow([
        'غير متطابقة', 'غير موجودة في الطرف الأول', '', '', '', '',
        _date(record.date), record.documentNumber ?? '',
        record.amount.toStringAsFixed(2), record.description,
      ].map(TextCellValue.new).toList());
    }

    final summary = book['الملخص'];
    summary.appendRow(['النتيجة', 'العدد'].map(TextCellValue.new).toList());
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
    required ReconciliationResult result,
  }) async {
    final arabicFont = await _loadArabicFont();
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFont),
    );
    final rows = <List<String>>[
      [
        'الحالة', 'السبب',
        'تاريخ 1', 'مستند 1', 'مبلغ 1', 'بيان 1',
        'تاريخ 2', 'مستند 2', 'مبلغ 2', 'بيان 2',
      ],
      ...result.pairs.map(_row),
      ...result.unmatchedRight.map((record) => [
            'غير متطابقة', 'غير موجودة في الطرف الأول', '', '', '', '',
            _date(record.date), record.documentNumber ?? '',
            record.amount.toStringAsFixed(2), record.description,
          ]),
    ];

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(18),
        textDirection: pw.TextDirection.rtl,
        build: (_) => [
          pw.Text(
            name,
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'متطابقة: ${result.matchedCount}   |   غير متطابقة: ${result.unmatchedCount}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            data: rows,
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 7,
            ),
            cellStyle: const pw.TextStyle(fontSize: 6.5),
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

  Future<pw.Font> _loadArabicFont() async {
    const candidates = [
      '/system/fonts/NotoNaskhArabic-Regular.ttf',
      '/system/fonts/NotoSansArabic-Regular.ttf',
      '/system/fonts/NotoSansArabic.ttf',
      '/system/fonts/DroidSansFallback.ttf',
      '/system/fonts/NotoSans-Regular.ttf',
    ];
    for (final path in candidates) {
      final file = File(path);
      if (!await file.exists()) continue;
      try {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          return pw.Font.ttf(ByteData.sublistView(Uint8List.fromList(bytes)));
        }
      } catch (_) {
        // نجرب الخط التالي المتوفر على الجهاز.
      }
    }
    return pw.Font.helvetica();
  }

  List<String> _row(MatchPair pair) => [
        pair.status == MatchStatus.matched ? 'متطابقة' : 'غير متطابقة',
        pair.reason,
        _date(pair.left.date),
        pair.left.documentNumber ?? '',
        pair.left.amount.toStringAsFixed(2),
        pair.left.description,
        pair.right == null ? '' : _date(pair.right!.date),
        pair.right?.documentNumber ?? '',
        pair.right?.amount.toStringAsFixed(2) ?? '',
        pair.right?.description ?? '',
      ];

  String _date(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  String _safe(String value) => value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}
