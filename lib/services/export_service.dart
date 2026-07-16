import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
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
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
    );
    final rows = <List<String>>[
      _headers,
      ...result.pairs.map(
        (pair) => _row(pair.left, pair.right, pair.status, pair.reason),
      ),
      ...result.unmatchedRight.map(
        (record) => _row(
          null,
          record,
          MatchStatus.unmatched,
          'غير موجودة في الطرف الأول',
        ),
      ),
    ];

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a3.landscape,
        margin: const pw.EdgeInsets.all(18),
        textDirection: pw.TextDirection.rtl,
        build: (_) => [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F1ECFF'),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  name,
                  textDirection: pw.TextDirection.rtl,
                  style: pw.TextStyle(
                    fontSize: 17,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  '$firstName  ↔  $secondName',
                  textDirection: pw.TextDirection.rtl,
                ),
                pw.Text(
                  'متطابقة: ${result.matchedCount}   |   غير متطابقة: ${result.unmatchedCount}',
                  textDirection: pw.TextDirection.rtl,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            data: rows,
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 7,
            ),
            cellStyle: const pw.TextStyle(fontSize: 6.3),
            headerDecoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#DCD2FF'),
            ),
            border: pw.TableBorder.all(
              color: PdfColors.grey600,
              width: 0.4,
            ),
            cellAlignment: pw.Alignment.centerRight,
            headerAlignment: pw.Alignment.centerRight,
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 3,
              vertical: 4,
            ),
          ),
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

  String _date(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
  String _safe(String value) => value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}

class ArabicPdfFonts {
  const ArabicPdfFonts({required this.regular, required this.bold});

  final pw.Font regular;
  final pw.Font bold;
}

Future<ArabicPdfFonts> loadArabicPdfFonts() async {
  final regularData = await rootBundle.load(
    'assets/fonts/NotoNaskhArabic-Regular.ttf',
  );
  final boldData = await rootBundle.load(
    'assets/fonts/NotoNaskhArabic-Bold.ttf',
  );

  return ArabicPdfFonts(
    regular: pw.Font.ttf(ByteData.sublistView(regularData)),
    bold: pw.Font.ttf(ByteData.sublistView(boldData)),
  );
}
