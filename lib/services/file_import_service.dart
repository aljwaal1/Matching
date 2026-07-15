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
  const ImportedStatement({
    required this.fileName,
    required this.records,
    required this.skippedRows,
  });

  final String fileName;
  final List<TransactionRecord> records;
  final List<SkippedRow> skippedRows;
}

class FileImportService {
  static const _dateNames = [
    'التاريخ', 'تاريخ العملية', 'تاريخ القيد', 'date', 'posting date', 'value date',
  ];
  static const _docNames = [
    'رقم المستند', 'رقم السند', 'رقم القيد', 'رقم المرجع', 'المرجع',
    'document', 'document no', 'doc', 'doc no', 'reference', 'ref', 'voucher',
  ];
  static const _amountNames = [
    'المبلغ', 'القيمة', 'صافي المبلغ', 'amount', 'value', 'net amount',
  ];
  static const _debitNames = ['مدين', 'مدين مبلغ', 'debit', 'debit amount'];
  static const _creditNames = ['دائن', 'دائن مبلغ', 'credit', 'credit amount'];
  static const _descNames = [
    'البيان', 'الوصف', 'تفاصيل', 'شرح', 'description', 'details', 'narration', 'memo',
  ];

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
    if (table.length < 2) {
      throw const FormatException('الملف لا يحتوي على صف عناوين وبيانات.');
    }

    final headerIndex = _findHeader(table);
    final headers = table[headerIndex].map(_clean).toList();
    final rows = table
        .skip(headerIndex + 1)
        .where((row) => row.any((value) => _clean(value).isNotEmpty))
        .toList();

    final dateCol = _find(headers, _dateNames) ?? _guessDate(rows, headers.length);
    final amountCol = _find(headers, _amountNames);
    final debitCol = _find(headers, _debitNames);
    final creditCol = _find(headers, _creditNames);
    final docCol = _find(headers, _docNames);
    final descCol = _find(headers, _descNames);

    if (dateCol == null || (amountCol == null && debitCol == null && creditCol == null)) {
      throw const FormatException(
        'تعذر تحديد عمود التاريخ أو المبلغ/المدين/الدائن تلقائياً.',
      );
    }

    final records = <TransactionRecord>[];
    final skipped = <SkippedRow>[];
    for (var i = 0; i < rows.length; i++) {
      final rowNumber = headerIndex + i + 2;
      try {
        final row = rows[i];
        final date = _date(_cell(row, dateCol));
        final direct = _amount(_cell(row, amountCol));
        final debit = _amount(_cell(row, debitCol)) ?? 0;
        final credit = _amount(_cell(row, creditCol)) ?? 0;
        final amount = direct ?? (debit != 0 ? debit : (credit != 0 ? credit : null));

        if (date == null || amount == null || amount == 0) {
          skipped.add(SkippedRow(
            rowNumber,
            date == null ? 'تعذر فهم التاريخ' : 'تعذر فهم المبلغ',
          ));
          continue;
        }

        records.add(TransactionRecord(
          id: '$fileName-$rowNumber',
          date: date,
          amount: amount.abs(),
          documentNumber: _nullable(_cell(row, docCol)),
          description: _clean(_cell(row, descCol)),
          sourceRow: rowNumber,
        ));
      } catch (error) {
        skipped.add(SkippedRow(rowNumber, 'تعذر قراءة الصف: $error'));
      }
    }

    if (records.isEmpty) {
      throw FormatException(
        'لم يتم العثور على عمليات صالحة. تم تجاهل ${skipped.length} صف.',
      );
    }
    return ImportedStatement(
      fileName: fileName,
      records: List.unmodifiable(records),
      skippedRows: List.unmodifiable(skipped),
    );
  }

  List<List<dynamic>> _readExcel(Uint8List bytes) {
    final book = Excel.decodeBytes(bytes);
    List<List<dynamic>> best = const [];
    for (final sheet in book.tables.values) {
      final rows = sheet.rows
          .map((row) => row.map(_safeExcelCellValue).toList(growable: false))
          .toList(growable: false);
      if (rows.length > best.length) best = rows;
    }
    return best;
  }

  dynamic _safeExcelCellValue(Data? cell) {
    if (cell == null) return null;
    try {
      return cell.value;
    } catch (_) {
      try {
        return cell.toString();
      } catch (_) {
        return null;
      }
    }
  }

  List<List<dynamic>> _readDelimited(Uint8List bytes, String? forced) {
    final text = utf8
        .decode(bytes, allowMalformed: true)
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final first = text.split('\n').first;
    final delimiter = forced ??
        ([',', ';', '\t']
              ..sort((a, b) => b.allMatches(first).length.compareTo(a.allMatches(first).length)))
            .first;
    return CsvToListConverter(
      fieldDelimiter: delimiter,
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(text);
  }

  List<List<dynamic>> _readPdf(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      final text = PdfTextExtractor(document).extractText();
      if (text.trim().isEmpty) {
        throw const FormatException('ملف PDF لا يحتوي نصاً قابلاً للاستخراج.');
      }
      final parsed = _parseStatementPdf(text);
      if (parsed.length >= 2) return parsed;
      return const LineSplitter()
          .convert(text)
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .map((line) => line.split(RegExp(r'\t+|\s{2,}')))
          .toList();
    } finally {
      document.dispose();
    }
  }

  List<List<dynamic>> _parseStatementPdf(String text) {
    final rows = <List<dynamic>>[
      ['Date', 'Doc No', 'Description', 'Amount'],
    ];
    final dateAtStart = RegExp(r'^\s*(\d{4}[-/.]\d{1,2}[-/.]\d{1,2}|\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4})\s+(.+)$');
    final number = RegExp(r'[-(]?[0-9][0-9,]*(?:\.\d+)?\)?');

    for (final rawLine in const LineSplitter().convert(text)) {
      final line = rawLine.trim();
      final match = dateAtStart.firstMatch(line);
      if (match == null) continue;

      final date = match.group(1)!;
      final rest = match.group(2)!.trim();
      final numbers = number.allMatches(rest).toList();
      if (numbers.length < 2) continue;

      final transactionAmount = numbers[numbers.length - 2];
      final amountText = transactionAmount.group(0)!;
      final beforeAmount = rest.substring(0, transactionAmount.start).trim();
      final tokens = beforeAmount.split(RegExp(r'\s+'));

      String documentNumber = '';
      var descriptionStart = 0;
      if (tokens.isNotEmpty && RegExp(r'^(?=.*\d)[A-Za-z0-9_-]+$').hasMatch(tokens.first)) {
        documentNumber = tokens.first;
        descriptionStart = 1;
      }
      final description = tokens.skip(descriptionStart).join(' ').trim();
      rows.add([date, documentNumber, description, amountText]);
    }
    return rows;
  }

  int _findHeader(List<List<dynamic>> table) {
    var best = 0;
    var score = -1;
    for (var i = 0; i < table.length && i < 20; i++) {
      final current = table[i]
          .map(_clean)
          .where((header) => _allNames.any((name) => _norm(header) == _norm(name)))
          .length;
      if (current > score) {
        score = current;
        best = i;
      }
    }
    return best;
  }

  List<String> get _allNames => [
        ..._dateNames,
        ..._docNames,
        ..._amountNames,
        ..._debitNames,
        ..._creditNames,
        ..._descNames,
      ];

  int? _find(List<String> headers, List<String> names) {
    for (var i = 0; i < headers.length; i++) {
      if (names.any((name) => _norm(headers[i]) == _norm(name))) return i;
    }
    return null;
  }

  int? _guessDate(List<List<dynamic>> rows, int count) {
    var best = 0;
    int? column;
    for (var c = 0; c < count; c++) {
      final score = rows.take(40).where((row) => _date(_cell(row, c)) != null).length;
      if (score > best) {
        best = score;
        column = c;
      }
    }
    return best >= 2 ? column : null;
  }

  dynamic _cell(List<dynamic> row, int? index) =>
      index == null || index < 0 || index >= row.length ? null : row[index];

  String _clean(dynamic value) => value?.toString().trim() ?? '';

  String _norm(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[\s_\-]+'), ' ')
      .trim();

  String? _nullable(dynamic value) {
    final text = _clean(value);
    return text.isEmpty ? null : text;
  }

  DateTime? _date(dynamic value) {
    if (value is DateTime) return DateTime(value.year, value.month, value.day);
    if (value is num && value > 20000 && value < 80000) {
      return DateTime(1899, 12, 30).add(Duration(days: value.round()));
    }

    final text = _clean(value);
    if (text.isEmpty) return null;
    final iso = DateTime.tryParse(text);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);

    final parts = text
        .replaceAll('.', '/')
        .replaceAll('-', '/')
        .split('/')
        .map(int.tryParse)
        .toList();
    if (parts.length != 3 || parts.any((part) => part == null)) return null;

    final a = parts[0]!;
    final b = parts[1]!;
    final c = parts[2]!;
    final year = a > 1900 ? a : (c < 100 ? 2000 + c : c);
    final month = b;
    final day = a > 1900 ? c : a;
    final result = DateTime(year, month, day);
    if (result.year != year || result.month != month || result.day != day) return null;
    return result;
  }

  double? _amount(dynamic value) {
    if (value is num) return value.toDouble();
    var text = _clean(value);
    if (text.isEmpty) return null;
    final negative = text.startsWith('(') && text.endsWith(')');
    text = text.replaceAll(RegExp(r'[^0-9,.\-]'), '').replaceAll(',', '');
    final number = double.tryParse(text);
    return number == null ? null : (negative ? -number : number);
  }
}
