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
    this.directAmountSide = EntrySide.unknown,
  });

  final int date;
  final int? document;
  final int? amount;
  final int? debit;
  final int? credit;
  final int? description;
  final EntrySide directAmountSide;

  bool get hasAmountSource =>
      amount != null || debit != null || credit != null;
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
  static const _dateNames = [
    'التاريخ',
    'تاريخ العملية',
    'تاريخ القيد',
    'date',
    'posting date',
    'transaction date',
    'value date',
  ];

  static const _documentNames = [
    'رقم المستند',
    'رقم السند',
    'رقم القيد',
    'رقم المرجع',
    'المرجع',
    'document number',
    'document no',
    'document',
    'doc no',
    'doc',
    'reference',
    'ref',
    'voucher',
  ];

  static const _amountNames = [
    'المبلغ',
    'قيمة الحركة',
    'مبلغ الحركة',
    'القيمة',
    'صافي المبلغ',
    'transaction amount',
    'net amount',
    'amount',
  ];

  static const _debitNames = [
    'المبلغ المدين',
    'مدين مبلغ',
    'debit amount',
    'مدين',
    'debit',
  ];

  static const _creditNames = [
    'المبلغ الدائن',
    'دائن مبلغ',
    'credit amount',
    'دائن',
    'credit',
  ];

  static const _balanceNames = [
    'الرصيد',
    'الرصيد الجاري',
    'running balance',
    'balance',
  ];

  static const _descriptionNames = [
    'البيان',
    'الوصف',
    'التفاصيل',
    'تفاصيل',
    'شرح',
    'description',
    'details',
    'narration',
    'memo',
  ];

  ImportedStatement importBytes({
    required String fileName,
    required Uint8List bytes,
  }) {
    final prepared = prepareBytes(fileName: fileName, bytes: bytes);
    final mapping = prepared.suggestedMapping;
    if (mapping == null) throw ColumnDetectionException(prepared);
    return buildStatement(prepared, mapping);
  }

  PreparedStatement prepareBytes({
    required String fileName,
    required Uint8List bytes,
  }) {
    if (bytes.isEmpty) throw const FormatException('الملف فارغ.');

    final extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    final table = switch (extension) {
      'xlsx' => _readXlsx(bytes),
      'csv' || 'txt' || 'tsv' =>
        _readDelimited(bytes, extension == 'tsv' ? '\t' : null),
      'pdf' => _readPdf(bytes),
      'xls' => throw const FormatException(
          'صيغة XLS القديمة غير مدعومة. احفظ الملف بصيغة XLSX.',
        ),
      _ => throw FormatException('صيغة الملف .$extension غير مدعومة.'),
    };

    if (table.length < 2) {
      throw const FormatException('الملف لا يحتوي على صف عناوين وبيانات.');
    }

    final headerIndex = _findHeader(table);
    final headers =
        table[headerIndex].map(_clean).toList(growable: false);
    final rows = table
        .skip(headerIndex + 1)
        .where((row) => row.any((value) => _clean(value).isNotEmpty))
        .toList(growable: false);

    if (rows.isEmpty) {
      throw const FormatException('الملف لا يحتوي على صفوف بيانات.');
    }

    final date = _findBest(headers, _dateNames) ??
        _guessDate(rows, headers.length);
    final debit = _findBest(headers, _debitNames);
    final credit = _findBest(headers, _creditNames);
    final balance = _findBest(headers, _balanceNames);
    final amount = _findDirectAmount(
      headers,
      excluded: {date, debit, credit, balance}.whereType<int>().toSet(),
    );

    final mapping =
        date != null && (amount != null || debit != null || credit != null)
            ? ColumnMapping(
                date: date,
                document: _findBest(headers, _documentNames),
                amount: amount,
                debit: debit,
                credit: credit,
                description: _findBest(headers, _descriptionNames),
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

  ImportedStatement buildStatement(
    PreparedStatement prepared,
    ColumnMapping mapping,
  ) {
    if (!mapping.hasAmountSource) {
      throw const FormatException('اختر عمود مبلغ أو مدين أو دائن.');
    }

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

        double? movementAmount;
        var side = EntrySide.unknown;

        if (direct != null && direct != 0) {
          movementAmount = direct.abs();
          side = mapping.directAmountSide;
        } else if (debit != 0 && credit == 0) {
          movementAmount = debit.abs();
          side = EntrySide.debit;
        } else if (credit != 0 && debit == 0) {
          movementAmount = credit.abs();
          side = EntrySide.credit;
        } else if (debit != 0 && credit != 0) {
          skipped.add(
            SkippedRow(rowNumber, 'الصف يحتوي مديناً ودائناً معاً'),
          );
          continue;
        }

        if (date == null || movementAmount == null || movementAmount == 0) {
          skipped.add(
            SkippedRow(
              rowNumber,
              date == null ? 'تعذر فهم التاريخ' : 'تعذر فهم المبلغ',
            ),
          );
          continue;
        }

        records.add(
          TransactionRecord(
            id: '${prepared.fingerprint}-$rowNumber',
            date: date,
            amount: movementAmount,
            documentNumber: _nullable(_cell(row, mapping.document)),
            description: _clean(_cell(row, mapping.description)),
            sourceRow: rowNumber,
            side: side,
          ),
        );
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
      fileName: prepared.fileName,
      fingerprint: prepared.fingerprint,
      records: List.unmodifiable(records),
      skippedRows: List.unmodifiable(skipped),
    );
  }

  List<List<dynamic>> _readXlsx(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      final sharedStrings = <String>[];
      final sharedFile = archive.files.cast<ArchiveFile?>().firstWhere(
            (file) =>
                file != null &&
                file.isFile &&
                file.name.replaceAll('\\', '/') == 'xl/sharedStrings.xml',
            orElse: () => null,
          );

      if (sharedFile != null) {
        final document = XmlDocument.parse(
          utf8.decode(_archiveBytes(sharedFile)),
        );
        final items = document.descendants
            .whereType<XmlElement>()
            .where((element) => element.name.local == 'si');
        for (final item in items) {
          sharedStrings.add(
            item.descendants
                .whereType<XmlElement>()
                .where((element) => element.name.local == 't')
                .map((element) => element.innerText)
                .join(),
          );
        }
      }

      final sheetFiles = archive.files.where((file) {
        if (!file.isFile) return false;
        final normalizedName = file.name.replaceAll('\\', '/');
        return normalizedName.startsWith('xl/worksheets/') &&
            normalizedName.endsWith('.xml');
      }).toList(growable: false);

      List<List<dynamic>> bestSheet = const [];
      var bestCellCount = 0;

      for (final file in sheetFiles) {
        final document = XmlDocument.parse(
          utf8.decode(_archiveBytes(file)),
        );
        final rowElements = document.descendants
            .whereType<XmlElement>()
            .where((element) => element.name.local == 'row');
        final rows = <List<dynamic>>[];
        var cellCount = 0;

        for (final rowElement in rowElements) {
          final cells = <int, dynamic>{};
          var maximumColumn = -1;
          final cellElements = rowElement.children
              .whereType<XmlElement>()
              .where((element) => element.name.local == 'c');

          for (final cell in cellElements) {
            final column = _columnIndex(cell.getAttribute('r') ?? '');
            if (column < 0) continue;

            final type = cell.getAttribute('t');
            dynamic value;
            if (type == 'inlineStr') {
              value = cell.descendants
                  .whereType<XmlElement>()
                  .where((element) => element.name.local == 't')
                  .map((element) => element.innerText)
                  .join();
            } else {
              final valueElements = cell.children
                  .whereType<XmlElement>()
                  .where((element) => element.name.local == 'v')
                  .toList(growable: false);
              final raw = valueElements.isEmpty
                  ? ''
                  : valueElements.first.innerText;
              if (type == 's') {
                final sharedIndex = int.tryParse(raw);
                value = sharedIndex != null &&
                        sharedIndex >= 0 &&
                        sharedIndex < sharedStrings.length
                    ? sharedStrings[sharedIndex]
                    : raw;
              } else if (type == 'b') {
                value = raw == '1';
              } else {
                value = num.tryParse(raw) ?? raw;
              }
            }

            cells[column] = value;
            if (_clean(value).isNotEmpty) cellCount++;
            if (column > maximumColumn) maximumColumn = column;
          }

          if (maximumColumn >= 0) {
            final row = List<dynamic>.generate(
              maximumColumn + 1,
              (column) => cells[column],
            );
            if (row.any((value) => _clean(value).isNotEmpty)) {
              rows.add(row);
            }
          }
        }

        if (rows.length >= 2 &&
            (cellCount > bestCellCount || bestSheet.isEmpty)) {
          bestSheet = rows;
          bestCellCount = cellCount;
        }
      }

      if (bestSheet.isEmpty) {
        throw FormatException(
          'ملف XLSX لا يحتوي على ورقة بيانات صالحة. '
          'تم فحص ${sheetFiles.length} ورقة.',
        );
      }
      return bestSheet;
    } catch (error) {
      if (error is FormatException) rethrow;
      throw FormatException('تعذر فك ملف XLSX: $error');
    }
  }

  List<int> _archiveBytes(ArchiveFile file) {
    final content = file.content;
    if (content is List<int>) return content;
    throw const FormatException('محتوى XLSX الداخلي غير صالح.');
  }

  int _columnIndex(String reference) {
    final letters = RegExp(r'^[A-Za-z]+').stringMatch(reference);
    if (letters == null) return -1;

    var result = 0;
    for (final code in letters.toUpperCase().codeUnits) {
      result = result * 26 + code - 64;
    }
    return result - 1;
  }

  List<List<dynamic>> _readDelimited(
    Uint8List bytes,
    String? forcedDelimiter,
  ) {
    final text = utf8
        .decode(bytes, allowMalformed: true)
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final firstLine = text.split('\n').first;
    final candidates = [',', ';', '\t']
      ..sort(
        (a, b) => b
            .allMatches(firstLine)
            .length
            .compareTo(a.allMatches(firstLine).length),
      );

    return CsvToListConverter(
      fieldDelimiter: forcedDelimiter ?? candidates.first,
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(text);
  }

  List<List<dynamic>> _readPdf(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      final text = PdfTextExtractor(document).extractText();
      if (text.trim().isEmpty) {
        throw const FormatException('PDF لا يحتوي نصاً قابلاً للاستخراج.');
      }

      final rows = <List<dynamic>>[
        ['Date', 'Doc No', 'Description', 'Debit', 'Credit', 'Amount'],
      ];
      final normalized =
          text.replaceAll('\u00a0', ' ').replaceAll('\r', '\n');
      final datePattern = RegExp(
        r'\b(\d{4}[-/.]\d{1,2}[-/.]\d{1,2}|'
        r'\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4})\b',
      );
      final amountPattern = RegExp(
        r'(?<![A-Za-z])[-(]?[0-9][0-9,]*(?:\.\d+)?\)?',
      );
      final documentPattern = RegExp(
        r'\b(?=[A-Za-z0-9_-]*[A-Za-z])'
        r'(?=[A-Za-z0-9_-]*\d)[A-Za-z0-9_-]+\b',
      );
      final dates = datePattern.allMatches(normalized).toList();

      for (var index = 0; index < dates.length; index++) {
        final dateMatch = dates[index];
        final end = index + 1 < dates.length
            ? dates[index + 1].start
            : normalized.length;
        var chunk = normalized
            .substring(dateMatch.end, end)
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

        final documentMatch = documentPattern.firstMatch(chunk);
        final documentNumber = documentMatch?.group(0) ?? '';
        if (documentMatch != null) {
          chunk = '${chunk.substring(0, documentMatch.start)} '
                  '${chunk.substring(documentMatch.end)}'
              .trim();
        }

        final amounts = amountPattern.allMatches(chunk).toList();
        if (amounts.isEmpty) continue;

        final movementMatch = amounts.first;
        final description = chunk.substring(0, movementMatch.start).trim();
        final value = movementMatch.group(0) ?? '';
        final lower = description.toLowerCase();
        final creditLike =
            lower.contains('receipt') ||
            lower.contains('payment') ||
            lower.contains('قبض') ||
            lower.contains('دفعة') ||
            lower.contains('سداد');
        final debitLike =
            lower.contains('invoice') ||
            lower.contains('sale') ||
            lower.contains('فاتورة') ||
            lower.contains('مبيعات');

        rows.add([
          dateMatch.group(0) ?? '',
          documentNumber,
          description,
          debitLike ? value : '',
          creditLike ? value : '',
          !debitLike && !creditLike ? value : '',
        ]);
      }

      if (rows.length < 2) {
        throw const FormatException(
          'تم فتح PDF لكن لم يتم التعرف على عمليات محاسبية.',
        );
      }
      return rows;
    } finally {
      document.dispose();
    }
  }

  int _findHeader(List<List<dynamic>> table) {
    var bestIndex = 0;
    var bestScore = -1;

    for (var index = 0; index < table.length && index < 20; index++) {
      final headers = table[index].map(_clean).toList(growable: false);
      var score = 0;
      for (final header in headers) {
        score += _bestHeaderScore(header, _allNames) > 0 ? 1 : 0;
      }
      if (score > bestScore) {
        bestScore = score;
        bestIndex = index;
      }
    }
    return bestIndex;
  }

  List<String> get _allNames => [
        ..._dateNames,
        ..._documentNames,
        ..._amountNames,
        ..._debitNames,
        ..._creditNames,
        ..._balanceNames,
        ..._descriptionNames,
      ];

  int? _findBest(List<String> headers, List<String> names) {
    int? bestIndex;
    var bestScore = 0;

    for (var index = 0; index < headers.length; index++) {
      final score = _bestHeaderScore(headers[index], names);
      if (score > bestScore) {
        bestScore = score;
        bestIndex = index;
      }
    }
    return bestIndex;
  }

  int? _findDirectAmount(
    List<String> headers, {
    required Set<int> excluded,
  }) {
    int? bestIndex;
    var bestScore = 0;

    for (var index = 0; index < headers.length; index++) {
      if (excluded.contains(index)) continue;
      final score = _bestHeaderScore(headers[index], _amountNames);
      if (score > bestScore) {
        bestScore = score;
        bestIndex = index;
      }
    }
    return bestIndex;
  }

  int _bestHeaderScore(String header, List<String> names) {
    final normalizedHeader = _normalize(header);
    if (normalizedHeader.isEmpty) return 0;

    var best = 0;
    for (final name in names) {
      final normalizedName = _normalize(name);
      if (normalizedName.isEmpty) continue;

      int score;
      if (normalizedHeader == normalizedName) {
        score = 10000 + normalizedName.length;
      } else if (normalizedHeader.contains(normalizedName)) {
        score = 1000 + normalizedName.length;
      } else {
        score = 0;
      }
      if (score > best) best = score;
    }
    return best;
  }

  int? _guessDate(List<List<dynamic>> rows, int columnCount) {
    var bestScore = 0;
    int? bestColumn;

    for (var column = 0; column < columnCount; column++) {
      final score = rows
          .take(40)
          .where((row) => _date(_cell(row, column)) != null)
          .length;
      if (score > bestScore) {
        bestScore = score;
        bestColumn = column;
      }
    }
    return bestScore >= 2 ? bestColumn : null;
  }

  dynamic _cell(List<dynamic> row, int? index) =>
      index == null || index < 0 || index >= row.length ? null : row[index];

  String _clean(dynamic value) => value?.toString().trim() ?? '';

  String? _nullable(dynamic value) {
    final text = _clean(value);
    return text.isEmpty ? null : text;
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'[\s_\-]+'), ' ')
      .trim();

  DateTime? _date(dynamic value) {
    if (value is DateTime) {
      return DateTime(value.year, value.month, value.day);
    }
    if (value is num && value > 20000 && value < 80000) {
      return DateTime(1899, 12, 30).add(Duration(days: value.round()));
    }

    final text = _clean(value);
    if (text.isEmpty) return null;

    final iso = DateTime.tryParse(text);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);

    final rawParts =
        text.replaceAll('.', '/').replaceAll('-', '/').split('/');
    if (rawParts.length != 3) return null;
    final parts = rawParts.map(int.tryParse).toList();
    if (parts.any((part) => part == null)) return null;

    final first = parts[0]!;
    final second = parts[1]!;
    final third = parts[2]!;
    final year = first > 1900 ? first : (third < 100 ? 2000 + third : third);
    final month = second;
    final day = first > 1900 ? third : first;
    final result = DateTime(year, month, day);

    return result.year == year && result.month == month && result.day == day
        ? result
        : null;
  }

  double? _amount(dynamic value) {
    if (value is num) return value.toDouble();

    var text = _clean(value);
    if (text.isEmpty) return null;
    final negative = text.startsWith('(') && text.endsWith(')');
    text = text.replaceAll(RegExp(r'[^0-9,.\-]'), '').replaceAll(',', '');
    final number = double.tryParse(text);
    if (number == null) return null;
    return negative ? -number : number;
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
