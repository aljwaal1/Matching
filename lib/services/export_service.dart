import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/transaction_record.dart';

class ExportService {
  Future<File> exportExcel({required String name, required ReconciliationResult result}) async {
    final book = Excel.createExcel();
    final sheet = book['النتائج'];
    sheet.appendRow(['الحالة','السبب','تاريخ 1','رقم المستند 1','المبلغ 1','البيان 1','تاريخ 2','رقم المستند 2','المبلغ 2','البيان 2'].map(TextCellValue.new).toList());
    for (final p in result.pairs) {
      sheet.appendRow(_row(p).map(TextCellValue.new).toList());
    }
    for (final r in result.unmatchedRight) {
      sheet.appendRow(['غير متطابقة','غير موجودة في الطرف الأول','','','','',_date(r.date),r.documentNumber ?? '',r.amount.toStringAsFixed(2),r.description].map(TextCellValue.new).toList());
    }
    final summary = book['الملخص'];
    summary.appendRow(['متطابقة', '${result.matchedCount}'].map(TextCellValue.new).toList());
    summary.appendRow(['غير متطابقة', '${result.unmatchedCount}'].map(TextCellValue.new).toList());
    final bytes = book.encode();
    if (bytes == null) throw Exception('تعذر إنشاء ملف Excel.');
    final file = File('${(await getTemporaryDirectory()).path}/${_safe(name)}.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    return file;
  }

  Future<File> exportPdf({required String name, required ReconciliationResult result}) async {
    final doc = pw.Document();
    final rows = <List<String>>[
      ['الحالة','السبب','تاريخ 1','مستند 1','مبلغ 1','بيان 1','تاريخ 2','مستند 2','مبلغ 2','بيان 2'],
      ...result.pairs.map(_row),
      ...result.unmatchedRight.map((r) => ['غير متطابقة','غير موجودة في الطرف الأول','','','','',_date(r.date),r.documentNumber ?? '',r.amount.toStringAsFixed(2),r.description]),
    ];
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      build: (_) => [
        pw.Text(name, textDirection: pw.TextDirection.rtl),
        pw.SizedBox(height: 8),
        pw.Text('متطابقة: ${result.matchedCount} | غير متطابقة: ${result.unmatchedCount}', textDirection: pw.TextDirection.rtl),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(data: rows, headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold), cellStyle: const pw.TextStyle(fontSize: 7)),
      ],
    ));
    final file = File('${(await getTemporaryDirectory()).path}/${_safe(name)}.pdf');
    await file.writeAsBytes(await doc.save(), flush: true);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    return file;
  }

  List<String> _row(MatchPair p) => [
    p.status == MatchStatus.matched ? 'متطابقة' : 'غير متطابقة',
    p.reason,
    _date(p.left.date), p.left.documentNumber ?? '', p.left.amount.toStringAsFixed(2), p.left.description,
    p.right == null ? '' : _date(p.right!.date), p.right?.documentNumber ?? '', p.right?.amount.toStringAsFixed(2) ?? '', p.right?.description ?? '',
  ];
  String _date(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  String _safe(String s) => s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}
