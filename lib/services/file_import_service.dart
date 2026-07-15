import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/transaction_record.dart';

class SkippedRow {
  const SkippedRow(this.rowNumber, this.reason);
  final int rowNumber;
  final String reason;
}

class ImportedStatement {
  const ImportedStatement({required this.fileName, required this.records, required this.skippedRows});
  final String fileName;
  final List<TransactionRecord> records;
  final List<SkippedRow> skippedRows;
}

class FileImportService {
  static const _dateNames = ['التاريخ','تاريخ العملية','تاريخ القيد','date','posting date','value date'];
  static const _docNames = ['رقم المستند','رقم السند','رقم القيد','رقم المرجع','المرجع','document','document no','doc no','reference','ref','voucher'];
  static const _amountNames = ['المبلغ','القيمة','صافي المبلغ','amount','value','net amount'];
  static const _debitNames = ['مدين','مدين مبلغ','debit','debit amount'];
  static const _creditNames = ['دائن','دائن مبلغ','credit','credit amount'];
  static const _descNames = ['البيان','الوصف','تفاصيل','شرح','description','details','narration','memo'];

  ImportedStatement importBytes({required String fileName, required Uint8List bytes}) {
    if (bytes.isEmpty) throw const FormatException('الملف فارغ.');
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    final table = switch (ext) {
      'xlsx' => _readExcel(bytes),
      'csv' || 'txt' || 'tsv' => _readDelimited(bytes, ext == 'tsv' ? '\t' : null),
      'pdf' => _readPdf(bytes),
      'xls' => throw const FormatException('صيغة XLS القديمة غير مدعومة. احفظ الملف بصيغة XLSX.'),
      _ => throw FormatException('صيغة الملف .$ext غير مدعومة.'),
    };
    if (table.length < 2) throw const FormatException('الملف لا يحتوي على صف عناوين وبيانات.');

    final headerIndex = _findHeader(table);
    final headers = table[headerIndex].map(_clean).toList();
    final rows = table.skip(headerIndex + 1).where((r) => r.any((v) => _clean(v).isNotEmpty)).toList();
    final dateCol = _find(headers, _dateNames) ?? _guessDate(rows, headers.length);
    final amountCol = _find(headers, _amountNames);
    final debitCol = _find(headers, _debitNames);
    final creditCol = _find(headers, _creditNames);
    final docCol = _find(headers, _docNames);
    final descCol = _find(headers, _descNames);
    if (dateCol == null || (amountCol == null && debitCol == null && creditCol == null)) {
      throw const FormatException('تعذر تحديد عمود التاريخ أو المبلغ/المدين/الدائن تلقائياً.');
    }

    final records = <TransactionRecord>[];
    final skipped = <SkippedRow>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final date = _date(_cell(row, dateCol));
      final direct = _amount(_cell(row, amountCol));
      final debit = _amount(_cell(row, debitCol)) ?? 0;
      final credit = _amount(_cell(row, creditCol)) ?? 0;
      final amount = direct ?? (debit != 0 ? debit : (credit != 0 ? credit : null));
      if (date == null || amount == null || amount == 0) {
        skipped.add(SkippedRow(headerIndex + i + 2, date == null ? 'تاريخ غير صالح' : 'مبلغ غير صالح'));
        continue;
      }
      records.add(TransactionRecord(
        id: '$fileName-${headerIndex + i + 2}',
        date: date,
        amount: amount.abs(),
        documentNumber: _nullable(_cell(row, docCol)),
        description: _clean(_cell(row, descCol)),
        sourceRow: headerIndex + i + 2,
      ));
    }
    if (records.isEmpty) throw FormatException('لم يتم العثور على عمليات صالحة. تم تجاهل ${skipped.length} صف.');
    return ImportedStatement(fileName: fileName, records: List.unmodifiable(records), skippedRows: List.unmodifiable(skipped));
  }

  List<List<dynamic>> _readExcel(Uint8List bytes) {
    final book = Excel.decodeBytes(bytes);
    List<List<dynamic>> best = const [];
    for (final sheet in book.tables.values) {
      if (sheet == null) continue;
      final rows = sheet.rows.map((r) => r.map((c) => c?.value).toList()).toList();
      if (rows.length > best.length) best = rows;
    }
    return best;
  }

  List<List<dynamic>> _readDelimited(Uint8List bytes, String? forced) {
    final text = utf8.decode(bytes, allowMalformed: true).replaceAll('\r\n','\n').replaceAll('\r','\n');
    final first = text.split('\n').first;
    final delimiter = forced ?? ([',',';','\t']..sort((a,b)=>b.allMatches(first).length.compareTo(a.allMatches(first).length))).first;
    return CsvToListConverter(fieldDelimiter: delimiter, eol: '\n', shouldParseNumbers: false).convert(text);
  }

  List<List<dynamic>> _readPdf(Uint8List bytes) {
    final doc = PdfDocument(inputBytes: bytes);
    try {
      final text = PdfTextExtractor(doc).extractText();
      if (text.trim().isEmpty) throw const FormatException('ملف PDF لا يحتوي نصاً قابلاً للاستخراج.');
      return const LineSplitter().convert(text).map((line) => line.trim()).where((line) => line.isNotEmpty).map((line) => line.split(RegExp(r'\t+|\s{2,}'))).toList();
    } finally { doc.dispose(); }
  }

  int _findHeader(List<List<dynamic>> table) {
    var best = 0, score = -1;
    for (var i=0; i<table.length && i<20; i++) {
      final s = table[i].map(_clean).where((h) => _allNames.any((n) => _norm(h)==_norm(n))).length;
      if (s > score) { score = s; best = i; }
    }
    return best;
  }

  List<String> get _allNames => [..._dateNames,..._docNames,..._amountNames,..._debitNames,..._creditNames,..._descNames];
  int? _find(List<String> headers, List<String> names) { for (var i=0;i<headers.length;i++) { if (names.any((n)=>_norm(headers[i])==_norm(n))) return i; } return null; }
  int? _guessDate(List<List<dynamic>> rows, int count) { var best=0; int? col; for(var c=0;c<count;c++){final s=rows.take(40).where((r)=>_date(_cell(r,c))!=null).length;if(s>best){best=s;col=c;}} return best>=2?col:null; }
  dynamic _cell(List<dynamic> row, int? i) => i==null || i<0 || i>=row.length ? null : row[i];
  String _clean(dynamic v) => v?.toString().trim() ?? '';
  String _norm(String v) => v.toLowerCase().replaceAll(RegExp(r'[\s_\-]+'),' ').trim();
  String? _nullable(dynamic v) { final s=_clean(v); return s.isEmpty?null:s; }

  DateTime? _date(dynamic value) {
    if (value is DateTime) return DateTime(value.year,value.month,value.day);
    if (value is DateCellValue) { final d=value.asDateTimeLocal(); return DateTime(d.year,d.month,d.day); }
    if (value is num && value>20000 && value<80000) return DateTime(1899,12,30).add(Duration(days:value.round()));
    final s=_clean(value); if(s.isEmpty) return null;
    final p=s.replaceAll('.','/').replaceAll('-','/').split('/').map(int.tryParse).toList();
    if(p.length==3 && p.every((e)=>e!=null)){var a=p[0]!,b=p[1]!,c=p[2]!;int y,m,d;if(a>1900){y=a;m=b;d=c;}else{d=a;m=b;y=c<100?2000+c:c;}try{return DateTime(y,m,d);}catch(_){}}
    return DateTime.tryParse(s);
  }

  double? _amount(dynamic value) {
    if (value is num) return value.toDouble();
    var s=_clean(value); if(s.isEmpty) return null;
    final negative=s.startsWith('(')&&s.endsWith(')');
    s=s.replaceAll(RegExp(r'[^0-9,\.\-]'),'').replaceAll(',','');
    final n=double.tryParse(s); return n==null?null:(negative?-n:n);
  }
}
