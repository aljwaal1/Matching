import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

import '../models/transaction_record.dart';

class ImportedStatement {
  const ImportedStatement({
    required this.fileName,
    required this.headers,
    required this.rows,
    required this.records,
  });

  final String fileName;
  final List<String> headers;
  final List<List<dynamic>> rows;
  final List<TransactionRecord> records;
}

class FileImportService {
  static const _documentNames = <String>[
    'رقم المستند', 'رقم السند', 'رقم القيد', 'رقم المرجع', 'المرجع',
    'document', 'document no', 'doc no', 'reference', 'ref', 'voucher',
  ];
  static const _dateNames = <String>[
    'التاريخ', 'تاريخ العملية', 'تاريخ القيد', 'date', 'transaction date',
    'posting date', 'value date',
  ];
  static const _amountNames = <String>[
    'المبلغ', 'القيمة', 'صافي المبلغ', 'amount', 'value', 'net amount',
  ];
  static const _debitNames = <String>['مدين', 'مدين مبلغ', 'debit', 'debit amount'];
  static const _creditNames = <String>['دائن', 'دائن مبلغ', 'credit', 'credit amount'];
  static const _descriptionNames = <String>[
    'البيان', 'الوصف', 'تفاصيل', 'شرح', 'description', 'details', 'narration', 'memo',
  ];

  ImportedStatement importBytes({
    required String fileName,
    required Uint8List bytes,
  }) {
    final extension = fileName.split('.').last.toLowerCase();
    late final List<List<dynamic>> table;

    if (extension == 'xlsx') {
      table = _readExcel(bytes);
    } else if (extension == 'csv' || extension == 'txt' || extension == 'tsv') {
      table = _readDelimited(bytes, extension == 'tsv' ? '\t' : null);
    } else if (extension == 'xls') {
      throw const FormatException('صيغة XLS القديمة غير مدعومة حالياً. احفظ الملف بصيغة XLSX.');
    } else if (extension == 'pdf') {
      throw const FormatException('تم اختيار ملف PDF، وسيتم ربط قراءة جداول PDF في المرحلة التالية.');
    } else {
      throw FormatException('صيغة الملف .$extension غير مدعومة.');
    }

    if (table.length < 2) {
      throw const FormatException('الملف لا يحتوي على بيانات كافية.');
    }

    final headerIndex = _findHeaderRow(table);
    final headers = table[headerIndex].map((value) => _clean(value)).toList();
    final dataRows = table.skip(headerIndex + 1).where(_hasUsefulData).toList();
    final columns = _detectColumns(headers, dataRows);
    final records = <TransactionRecord>[];

    for (var index = 0; index < dataRows.length; index++) {
      final row = dataRows[index];
      final date = _parseDate(_cell(row, columns.date));
      final amount = _extractAmount(row, columns);
      if (date == null || amount == null) continue;

      records.add(TransactionRecord(
        id: '${fileName}_$index',
        date: date,
        amount: amount.abs(),
        documentNumber: _nullableText(_cell(row, columns.document)),
        description: _clean(_cell(row, columns.description)),
        sourceRow: headerIndex + index + 2,
      ));
    }

    if (records.isEmpty) {
      throw const FormatException('لم يتم العثور على صفوف تحتوي على تاريخ ومبلغ صالحين.');
    }

    return ImportedStatement(
      fileName: fileName,
      headers: headers,
      rows: dataRows,
      records: records,
    );
  }

  List<List<dynamic>> _readExcel(Uint8List bytes) {
    final workbook = Excel.decodeBytes(bytes);
    if (workbook.tables.isEmpty) return const [];
    final sheet = workbook.tables.values.first;
    if (sheet == null) return const [];
    return sheet.rows
        .map((row) => row.map((cell) => cell?.value).toList(growable: false))
        .toList(growable: false);
  }

  List<List<dynamic>> _readDelimited(Uint8List bytes, String? forcedDelimiter) {
    final text = utf8.decode(bytes, allowMalformed: true).replaceAll('\r\n', '\n');
    final delimiter = forcedDelimiter ?? _detectDelimiter(text);
    return CsvToListConverter(fieldDelimiter: delimiter, shouldParseNumbers: false)
        .convert(text);
  }

  String _detectDelimiter(String text) {
    final firstLine = text.split('\n').first;
    final candidates = <String>[',', ';', '\t'];
    candidates.sort((a, b) => b.allMatches(firstLine).length.compareTo(a.allMatches(firstLine).length));
    return candidates.first;
  }

  int _findHeaderRow(List<List<dynamic>> table) {
    var bestIndex = 0;
    var bestScore = -1;
    for (var i = 0; i < table.length && i < 15; i++) {
      final row = table[i];
      final score = row.where((cell) => _knownHeader(_clean(cell))).length;
      if (score > bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  bool _knownHeader(String value) =>
      _matches(value, _documentNames) ||
      _matches(value, _dateNames) ||
      _matches(value, _amountNames) ||
      _matches(value, _debitNames) ||
      _matches(value, _creditNames) ||
      _matches(value, _descriptionNames);

  _DetectedColumns _detectColumns(List<String> headers, List<List<dynamic>> rows) {
    int? find(List<String> names) {
      for (var i = 0; i < headers.length; i++) {
        if (_matches(headers[i], names)) return i;
      }
      return null;
    }

    var date = find(_dateNames);
    var amount = find(_amountNames);
    final debit = find(_debitNames);
    final credit = find(_creditNames);

    date ??= _guessDateColumn(rows, headers.length);
    if (amount == null && debit == null && credit == null) {
      amount = _guessAmountColumn(rows, headers.length, exclude: date);
    }

    if (date == null || (amount == null && debit == null && credit == null)) {
      throw const FormatException('تعذر تحديد عمود التاريخ أو المبلغ تلقائياً.');
    }

    return _DetectedColumns(
      document: find(_documentNames),
      date: date,
      amount: amount,
      debit: debit,
      credit: credit,
      description: find(_descriptionNames),
    );
  }

  int? _guessDateColumn(List<List<dynamic>> rows, int count) {
    var best = 0;
    int? bestColumn;
    for (var column = 0; column < count; column++) {
      final score = rows.take(25).where((row) => _parseDate(_cell(row, column)) != null).length;
      if (score > best) { best = score; bestColumn = column; }
    }
    return best >= 2 ? bestColumn : null;
  }

  int? _guessAmountColumn(List<List<dynamic>> rows, int count, {int? exclude}) {
    var best = 0;
    int? bestColumn;
    for (var column = 0; column < count; column++) {
      if (column == exclude) continue;
      final score = rows.take(25).where((row) => _parseAmount(_cell(row, column)) != null).length;
      if (score > best) { best = score; bestColumn = column; }
    }
    return best >= 2 ? bestColumn : null;
  }

  double? _extractAmount(List<dynamic> row, _DetectedColumns columns) {
    final direct = _parseAmount(_cell(row, columns.amount));
    if (direct != null) return direct;
    final debit = _parseAmount(_cell(row, columns.debit)) ?? 0;
    final credit = _parseAmount(_cell(row, columns.credit)) ?? 0;
    final value = debit != 0 ? debit : credit;
    return value == 0 ? null : value;
  }

  DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return DateTime(value.year, value.month, value.day);
    if (value is DateCellValue) {
      final date = value.asDateTimeLocal();
      return DateTime(date.year, date.month, date.day);
    }
    if (value is num && value > 20000 && value < 80000) {
      return DateTime(1899, 12, 30).add(Duration(days: value.round()));
    }
    final text = _clean(value);
    if (text.isEmpty) return null;
    final normalized = text.replaceAll(RegExp(r'[.\\]'), '/').replaceAll('-', '/');
    final parts = normalized.split('/').map((part) => int.tryParse(part.trim())).toList();
    if (parts.length == 3 && parts.every((part) => part != null)) {
      var a = parts[0]!; var b = parts[1]!; var c = parts[2]!;
      if (a > 1900) return _safeDate(a, b, c);
      if (c < 100) c += 2000;
      return _safeDate(c, b, a);
    }
    return DateTime.tryParse(text);
  }

  DateTime? _safeDate(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day ? date : null;
  }

  double? _parseAmount(dynamic value) {
    if (value is num) return value.toDouble();
    final text = _clean(value);
    if (text.isEmpty) return null;
    final negative = text.startsWith('(') && text.endsWith(')');
    var normalized = text
        .replaceAll(RegExp(r'[^0-9.,\-]'), '')
        .replaceAll(',', '');
    final parsed = double.tryParse(normalized);
    return parsed == null ? null : (negative ? -parsed.abs() : parsed);
  }

  dynamic _cell(List<dynamic> row, int? index) =>
      index == null || index < 0 || index >= row.length ? null : row[index];

  bool _hasUsefulData(List<dynamic> row) => row.any((value) => _clean(value).isNotEmpty);

  bool _matches(String header, List<String> names) {
    final normalized = _normalize(header);
    return names.any((name) {
      final target = _normalize(name);
      return normalized == target || normalized.contains(target);
    });
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'[_\-\s]+'), ' ')
      .trim();

  String _clean(dynamic value) => value?.toString().trim() ?? '';
  String? _nullableText(dynamic value) {
    final text = _clean(value);
    return text.isEmpty ? null : text;
  }
}

class _DetectedColumns {
  const _DetectedColumns({
    required this.document,
    required this.date,
    required this.amount,
    required this.debit,
    required this.credit,
    required this.description,
  });

  final int? document;
  final int date;
  final int? amount;
  final int? debit;
  final int? credit;
  final int? description;
}
