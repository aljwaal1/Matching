import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

import '../models/transaction_record.dart';

class SkippedRow {
  const SkippedRow(this.rowNumber, this.reason);
  final int rowNumber;
  final String reason;
}

class ColumnMapping {
  const ColumnMapping({
    required this.date,
    this.document,
    this.amount,
    this.debit,
    this.credit,
    this.description,
  });
  final int date;
  final int? document;
  final int? amount;
  final int? debit;
  final int? credit;
  final int? description;

  bool get hasAmountSource => amount != null || debit != null || credit != null;
}

class PreparedStatement {
  const PreparedStatement({
    required this.fileName,
    required this.fingerprint,
    required this.headers,
    required this.rows,
    required this.headerRowNumber,
    required this.suggestedMapping,
  });
  final String fileName;
  final String fingerprint;
  final List<String> headers;
  final List<List<dynamic>> rows;
  final int headerRowNumber;
  final ColumnMapping? suggestedMapping;
}

class ColumnDetectionException implements Exception {
  const ColumnDetectionException(this.prepared);
  final PreparedStatement prepared;
  @override
  String toString() => 'تعذر تحديد الأعمدة تلقائياً.';
}

class ImportedStatement {
  const ImportedStatement({
    required this.fileName,
    required this.fingerprint,
    required this.records,
    required this.skippedRows,
  });
  final String fileName;
  final String fingerprint;
  final List<TransactionRecord> records;
  final List<SkippedRow> skippedRows;
}

class FileImportService {
  static const _dateNames = ['التاريخ','تاريخ العملية','تاريخ القيد','date','posting date','transaction date','value date'];
  static const _docNames = ['رقم المستند','رقم السند','رقم القيد','رقم المرجع','المرجع','document','document no','doc','doc no','reference','ref','voucher'];
  static const _amountNames = ['المبلغ','قيمة الحركة','مبلغ الحركة','القيمة','صافي المبلغ','amount','transaction amount','value','net amount'];
  static const _debitNames = ['مدين','المبلغ المدين','مدين مبلغ','debit','debit amount'];
  static const _creditNames = ['دائن','المبلغ الدائن','دائن مبلغ','credit','credit amount'];
  static const _balanceNames = ['الرصيد','balance','running balance'];
  static const _descNames = ['البيان','الوصف','تفاصيل','شرح','description','details','narration','memo'];

  ImportedStatement importBytes({required String fileName, required Uint8List bytes}) {
    final prepared = prepareBytes(fileName: fileName, bytes: bytes);
    final mapping = prepared.suggestedMapping;
    if (mapping == null) throw ColumnDetectionException(prepared);
    return buildStatement(prepared, mapping);
  }

  PreparedStatement prepareBytes({required String fileName, required Uint8List bytes}) {
    if (bytes.isEmpty) throw const FormatException('الملف فارغ.');
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    final table = switch (ext) {
      'xlsx' => _readXlsxDirect(bytes),
      'csv' || 'txt' || 'tsv' => _readDelimited(bytes, ext == 'tsv' ? '\t' : null),
      'pdf' => _readPdf(bytes),
      'xls' => throw const FormatException('صيغة XLS القديمة غير مدعومة. احفظ الملف بصيغة XLSX.'),
      _ => throw FormatException('صيغة الملف .$ext غير مدعومة.'),
    };
    if (table.length < 2) throw const FormatException('الملف لا يحتوي على صف عناوين وبيانات.');

    final headerIndex = _findHeader(table);
    final headers = table[headerIndex].map(_clean).toList(growable: false);
    final rows = table.skip(headerIndex + 1).where((row) => row.any((v) => _clean(v).isNotEmpty)).toList(growable: false);
    final date = _find(headers, _dateNames) ?? _guessDate(rows, headers.length);
    final amount = _find(headers, _amountNames);
    final debit = _find(headers, _debitNames);
    final credit = _find(headers, _creditNames);
    final mapping = date != null && (amount != null || debit != null || credit != null)
        ? ColumnMapping(
            date: date,
            document: _find(headers, _docNames),
            amount: amount,
            debit: debit,
            credit: credit,
            description: _find(headers, _descNames),
          )
        : null;
    return PreparedStatement(
      fileName: fileName,
      fingerprint: _fingerprint(bytes),
      headers: headers,
      rows: rows,
      headerRowNumber: headerIndex + 1,
      suggestedMapping: mapping,
    );
  }

  ImportedStatement buildStatement(PreparedStatement prepared, ColumnMapping mapping) {
    if (!mapping.hasAmountSource) throw const FormatException('اختر عمود مبلغ أو مدين أو دائن.');
    final records = <TransactionRecord>[];
    final skipped = <SkippedRow>[];
    for (var index = 0; index < prepared.rows.length; index++) {
      final rowNumber = prepared.headerRowNumber + index + 1;
      final row = prepared.rows[index];
      try {
        final date = _date(_cell(row, mapping.date));
        final direct = _amount(_cell(row, mapping.amount));
        final debit = _amount(_cell(row, mapping.debit)) ?? 0;
        final credit = _amount(_cell(row, mapping.credit)) ?? 0;
        double? amount;
        var side = EntrySide.unknown;
        if (direct != null && direct != 0) {
          amount = direct.abs();
        } else if (debit != 0 && credit == 0) {
          amount = debit.abs();
          side = EntrySide.debit;
        } else if (credit != 0 && debit == 0) {
          amount = credit.abs();
          side = EntrySide.credit;
        } else if (debit != 0 && credit != 0) {
          skipped.add(SkippedRow(rowNumber, 'الصف يحتوي مديناً ودائناً معاً'));
          continue;
        }
        if (date == null || amount == null || amount == 0) {
          skipped.add(SkippedRow(rowNumber, date == null ? 'تعذر فهم التاريخ' : 'تعذر فهم المبلغ'));
          continue;
        }
        records.add(TransactionRecord(
          id: '${prepared.fingerprint}-$rowNumber',
          date: date,
          amount: amount,
          documentNumber: _nullable(_cell(row, mapping.document)),
          description: _clean(_cell(row, mapping.description)),
          sourceRow: rowNumber,
          side: side,
        ));
      } catch (error) {
        skipped.add(SkippedRow(rowNumber, 'تعذر قراءة الصف: $error'));
      }
    }
    if (records.isEmpty) throw FormatException('لم يتم العثور على عمليات صالحة. تم تجاهل ${skipped.length} صف.');
    return ImportedStatement(
      fileName: prepared.fileName,
      fingerprint: prepared.fingerprint,
      records: List.unmodifiable(records),
      skippedRows: List.unmodifiable(skipped),
    );
  }

  List<List<dynamic>> _readXlsxDirect(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      final shared = <String>[];
      final sharedFile = archive.findFile('xl/sharedStrings.xml');
      if (sharedFile != null) {
        final xml = XmlDocument.parse(utf8.decode(_archiveBytes(sharedFile)));
        for (final item in xml.findAllElements('si')) {
          shared.add(item.findAllElements('t').map((e) => e.innerText).join());
        }
      }
      final sheets = archive.files.where((f) => f.isFile && RegExp(r'^xl/worksheets/sheet\d+\.xml$').hasMatch(f.name));
      List<List<dynamic>> best = const [];
      for (final file in sheets) {
        final xml = XmlDocument.parse(utf8.decode(_archiveBytes(file)));
        final rows = <List<dynamic>>[];
        for (final rowElement in xml.findAllElements('row')) {
          final cells = <int, dynamic>{};
          var max = -1;
          for (final cell in rowElement.findElements('c')) {
            final column = _columnIndex(cell.getAttribute('r') ?? '');
            if (column < 0) continue;
            final type = cell.getAttribute('t');
            dynamic value;
            if (type == 'inlineStr') {
              value = cell.findAllElements('t').map((e) => e.innerText).join();
            } else {
              final values = cell.findElements('v');
              final raw = values.isEmpty ? '' : values.first.innerText;
              if (type == 's') {
                final i = int.tryParse(raw);
                value = i != null && i >= 0 && i < shared.length ? shared[i] : raw;
              } else {
                value = num.tryParse(raw) ?? raw;
              }
            }
            cells[column] = value;
            if (column > max) max = column;
          }
          if (max >= 0) rows.add(List<dynamic>.generate(max + 1, (i) => cells[i]));
        }
        if (rows.length > best.length) best = rows;
      }
      return best;
    } catch (error) {
      throw FormatException('تعذر فك ملف XLSX: $error');
    }
  }

  List<int> _archiveBytes(ArchiveFile file) {
    final content = file.content;
    if (content is List<int>) return content;
    throw const FormatException('محتوى XLSX الداخلي غير صالح.');
  }

  int _columnIndex(String ref) {
    final letters = RegExp(r'^[A-Za-z]+').stringMatch(ref);
    if (letters == null) return -1;
    var result = 0;
    for (final code in letters.toUpperCase().codeUnits) result = result * 26 + code - 64;
    return result - 1;
  }

  List<List<dynamic>> _readDelimited(Uint8List bytes, String? forced) {
    final text = utf8.decode(bytes, allowMalformed: true).replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final first = text.split('\n').first;
    final candidates = [',',';','\t']..sort((a,b) => b.allMatches(first).length.compareTo(a.allMatches(first).length));
    return CsvToListConverter(fieldDelimiter: forced ?? candidates.first, eol: '\n', shouldParseNumbers: false).convert(text);
  }

  List<List<dynamic>> _readPdf(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      final text = PdfTextExtractor(document).extractText();
      if (text.trim().isEmpty) throw const FormatException('PDF لا يحتوي نصاً قابلاً للاستخراج.');
      final rows = <List<dynamic>>[['Date','Doc No','Description','Debit','Credit','Amount']];
      final normalized = text.replaceAll('\u00a0',' ').replaceAll('\r','\n');
      final datePattern = RegExp(r'\b(\d{4}[-/.]\d{1,2}[-/.]\d{1,2}|\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4})\b');
      final dates = datePattern.allMatches(normalized).toList();
      final amountPattern = RegExp(r'(?<![A-Za-z])[-(]?[0-9][0-9,]*(?:\.\d+)?\)?');
      final docPattern = RegExp(r'\b(?=[A-Za-z0-9_-]*[A-Za-z])(?=[A-Za-z0-9_-]*\d)[A-Za-z0-9_-]+\b');
      for (var i = 0; i < dates.length; i++) {
        final d = dates[i];
        final end = i + 1 < dates.length ? dates[i + 1].start : normalized.length;
        var chunk = normalized.substring(d.end, end).replaceAll(RegExp(r'\s+'),' ').trim();
        final doc = docPattern.firstMatch(chunk);
        final docNo = doc?.group(0) ?? '';
        if (doc != null) chunk = '${chunk.substring(0, doc.start)} ${chunk.substring(doc.end)}'.trim();
        final amounts = amountPattern.allMatches(chunk).toList();
        if (amounts.isEmpty) continue;
        final movement = amounts.first;
        final description = chunk.substring(0, movement.start).trim();
        final value = movement.group(0) ?? '';
        final lower = description.toLowerCase();
        final creditLike = lower.contains('receipt') || lower.contains('payment') || lower.contains('قبض') || lower.contains('دفعة') || lower.contains('سداد');
        final debitLike = lower.contains('invoice') || lower.contains('sale') || lower.contains('فاتورة') || lower.contains('مبيعات');
        rows.add([d.group(0) ?? '', docNo, description, debitLike ? value : '', creditLike ? value : '', (!debitLike && !creditLike) ? value : '']);
      }
      if (rows.length < 2) throw const FormatException('تم فتح PDF لكن لم يتم التعرف على عمليات محاسبية.');
      return rows;
    } finally {
      document.dispose();
    }
  }

  int _findHeader(List<List<dynamic>> table) {
    var best = 0, score = -1;
    for (var i = 0; i < table.length && i < 20; i++) {
      final current = table[i].map(_clean).where((h) => _allNames.any((n) => _headerMatches(h,n))).length;
      if (current > score) { score = current; best = i; }
    }
    return best;
  }

  List<String> get _allNames => [..._dateNames,..._docNames,..._amountNames,..._debitNames,..._creditNames,..._balanceNames,..._descNames];

  int? _find(List<String> headers, List<String> names) {
    for (var i = 0; i < headers.length; i++) if (names.any((n) => _headerMatches(headers[i],n))) return i;
    return null;
  }

  bool _headerMatches(String header, String name) {
    final h = _norm(header), n = _norm(name);
    return h == n || h.contains(n) || n.contains(h);
  }

  int? _guessDate(List<List<dynamic>> rows, int count) {
    var best = 0; int? column;
    for (var c = 0; c < count; c++) {
      final score = rows.take(40).where((r) => _date(_cell(r,c)) != null).length;
      if (score > best) { best = score; column = c; }
    }
    return best >= 2 ? column : null;
  }

  dynamic _cell(List<dynamic> row, int? index) => index == null || index < 0 || index >= row.length ? null : row[index];
  String _clean(dynamic value) => value?.toString().trim() ?? '';
  String? _nullable(dynamic value) { final t = _clean(value); return t.isEmpty ? null : t; }
  String _norm(String v) => v.toLowerCase().replaceAll('أ','ا').replaceAll('إ','ا').replaceAll('آ','ا').replaceAll('ة','ه').replaceAll(RegExp(r'[\s_\-]+'),' ').trim();

  DateTime? _date(dynamic value) {
    if (value is DateTime) return DateTime(value.year,value.month,value.day);
    if (value is num && value > 20000 && value < 80000) return DateTime(1899,12,30).add(Duration(days:value.round()));
    final text = _clean(value); if (text.isEmpty) return null;
    final iso = DateTime.tryParse(text); if (iso != null) return DateTime(iso.year,iso.month,iso.day);
    final parts = text.replaceAll('.','/').replaceAll('-','/').split('/').map(int.tryParse).toList();
    if (parts.length != 3 || parts.any((p) => p == null)) return null;
    final a=parts[0]!, b=parts[1]!, c=parts[2]!;
    final year=a>1900?a:(c<100?2000+c:c), month=b, day=a>1900?c:a;
    final result=DateTime(year,month,day);
    return result.year==year&&result.month==month&&result.day==day?result:null;
  }

  double? _amount(dynamic value) {
    if (value is num) return value.toDouble();
    var text=_clean(value); if(text.isEmpty)return null;
    final negative=text.startsWith('(')&&text.endsWith(')');
    text=text.replaceAll(RegExp(r'[^0-9,.\-]'),'').replaceAll(',','');
    final number=double.tryParse(text); return number==null?null:(negative?-number:number);
  }

  String _fingerprint(Uint8List bytes) {
    var hash = 0xcbf29ce484222325;
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
    }
    return hash.toRadixString(16);
  }
}
