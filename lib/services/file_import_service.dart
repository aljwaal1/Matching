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
    'التاريخ', 'تاريخ العملية', 'تاريخ القيد', 'date', 'posting date',
    'transaction date', 'value date',
  ];
  static const _docNames = [
    'رقم المستند', 'رقم السند', 'رقم القيد', 'رقم المرجع', 'المرجع',
    'document', 'document no', 'doc', 'doc no', 'reference', 'ref', 'voucher',
  ];
  static const _amountNames = [
    'المبلغ', 'قيمة الحركة', 'مبلغ الحركة', 'القيمة', 'صافي المبلغ',
    'amount', 'transaction amount', 'value', 'net amount',
  ];
  static const _debitNames = [
    'مدين', 'المبلغ المدين', 'مدين مبلغ', 'debit', 'debit amount',
  ];
  static const _creditNames = [
    'دائن', 'المبلغ الدائن', 'دائن مبلغ', 'credit', 'credit amount',
  ];
  static const _balanceNames = ['الرصيد', 'balance', 'running balance'];
  static const _descNames = [
    'البيان', 'الوصف', 'تفاصيل', 'شرح', 'description', 'details',
    'narration', 'memo',
  ];

  ImportedStatement importBytes({
    required String fileName,
    required Uint8List bytes,
  }) {
    if (bytes.isEmpty) throw const FormatException('الملف فارغ.');
    final extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';

    final table = switch (extension) {
      'xlsx' => _readXlsxDirect(bytes),
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
    final headers = table[headerIndex].map(_clean).toList(growable: false);
    final rows = table
        .skip(headerIndex + 1)
        .where((row) => row.any((value) => _clean(value).isNotEmpty))
        .toList(growable: false);

    final dateCol = _find(headers, _dateNames) ?? _guessDate(rows, headers.length);
    final amountCol = _find(headers, _amountNames);
    final debitCol = _find(headers, _debitNames);
    final creditCol = _find(headers, _creditNames);
    final balanceCol = _find(headers, _balanceNames);
    final docCol = _find(headers, _docNames);
    final descCol = _find(headers, _descNames);

    if (dateCol == null ||
        (amountCol == null && debitCol == null && creditCol == null)) {
      throw FormatException(
        'تعذر تحديد عمود التاريخ أو مبلغ الحركة تلقائياً. '
        'الأعمدة المقروءة: ${headers.join(' | ')}',
      );
    }

    final records = <TransactionRecord>[];
    final skipped = <SkippedRow>[];

    for (var index = 0; index < rows.length; index++) {
      final rowNumber = headerIndex + index + 2;
      try {
        final row = rows[index];
        final date = _date(_cell(row, dateCol));
        final direct = _amount(_cell(row, amountCol));
        final debit = _amount(_cell(row, debitCol)) ?? 0;
        final credit = _amount(_cell(row, creditCol)) ?? 0;

        double? amount;
        EntrySide side = EntrySide.unknown;
        if (direct != null && direct != 0) {
          amount = direct.abs();
        } else if (debit != 0 && credit == 0) {
          amount = debit.abs();
          side = EntrySide.debit;
        } else if (credit != 0 && debit == 0) {
          amount = credit.abs();
          side = EntrySide.credit;
        } else if (debit != 0 && credit != 0) {
          skipped.add(SkippedRow(
            rowNumber,
            'الصف يحتوي على مبلغ مدين ودائن معاً ويحتاج مراجعة',
          ));
          continue;
        }

        if (date == null || amount == null || amount == 0) {
          final balance = _amount(_cell(row, balanceCol));
          skipped.add(SkippedRow(
            rowNumber,
            date == null
                ? 'تعذر فهم التاريخ'
                : 'تعذر فهم المدين أو الدائن'
                    '${balance == null ? '' : ' (الرصيد $balance ليس مبلغ حركة)'}',
          ));
          continue;
        }

        records.add(TransactionRecord(
          id: '$fileName-$rowNumber',
          date: date,
          amount: amount,
          documentNumber: _nullable(_cell(row, docCol)),
          description: _clean(_cell(row, descCol)),
          sourceRow: rowNumber,
          side: side,
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

  List<List<dynamic>> _readXlsxDirect(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      final sharedStrings = <String>[];
      final sharedFile = archive.findFile('xl/sharedStrings.xml');
      if (sharedFile != null) {
        final document = XmlDocument.parse(
          utf8.decode(_archiveBytes(sharedFile)),
        );
        for (final item in document.findAllElements('si')) {
          sharedStrings.add(
            item.findAllElements('t').map((element) => element.innerText).join(),
          );
        }
      }

      final worksheets = archive.files
          .where((file) =>
              file.isFile &&
              RegExp(r'^xl/worksheets/sheet\d+\.xml$').hasMatch(file.name))
          .toList(growable: false);
      if (worksheets.isEmpty) {
        throw const FormatException(
          'ملف XLSX لا يحتوي على ورقة بيانات قابلة للقراءة.',
        );
      }

      List<List<dynamic>> best = const [];
      for (final file in worksheets) {
        final document = XmlDocument.parse(
          utf8.decode(_archiveBytes(file)),
        );
        final rows = <List<dynamic>>[];
        for (final rowElement in document.findAllElements('row')) {
          final cells = <int, dynamic>{};
          var maxColumn = -1;
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
            if (column > maxColumn) maxColumn = column;
          }
          if (maxColumn >= 0) {
            rows.add(
              List<dynamic>.generate(maxColumn + 1, (column) => cells[column]),
            );
          }
        }
        if (rows.length > best.length) best = rows;
      }
      return best;
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('تعذر فك ملف XLSX: $error');
    }
  }

  List<int> _archiveBytes(ArchiveFile file) {
    final content = file.content;
    if (content is List<int>) return content;
    throw const FormatException('محتوى ملف XLSX الداخلي غير صالح.');
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

  List<List<dynamic>> _readDelimited(Uint8List bytes, String? forced) {
    final text = utf8
        .decode(bytes, allowMalformed: true)
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final first = text.split('\n').first;
    final candidates = [',', ';', '\t'];
    candidates.sort(
      (a, b) => b.allMatches(first).length.compareTo(a.allMatches(first).length),
    );
    return CsvToListConverter(
      fieldDelimiter: forced ?? candidates.first,
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
      if (parsed.length < 2) {
        throw const FormatException(
          'تم فتح PDF، لكن لم يتم العثور على عمليات تبدأ بتاريخ ويتبعها مبلغ حركة.',
        );
      }
      return parsed;
    } finally {
      document.dispose();
    }
  }

  List<List<dynamic>> _parseStatementPdf(String text) {
    final rows = <List<dynamic>>[
      ['Date', 'Doc No', 'Description', 'Debit', 'Credit', 'Balance'],
    ];
    final normalized = text
        .replaceAll('\u00a0', ' ')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final datePattern = RegExp(
      r'\b(\d{4}[-/.]\d{1,2}[-/.]\d{1,2}|\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4})\b',
    );
    final dates = datePattern.allMatches(normalized).toList(growable: false);
    final amountPattern = RegExp(r'(?<![A-Za-z])[-(]?[0-9][0-9,]*(?:\.\d+)?\)?');
    final documentPattern = RegExp(
      r'\b(?=[A-Za-z0-9_-]*[A-Za-z])(?=[A-Za-z0-9_-]*\d)[A-Za-z0-9_-]+\b',
    );

    for (var index = 0; index < dates.length; index++) {
      final dateMatch = dates[index];
      final end = index + 1 < dates.length
          ? dates[index + 1].start
          : normalized.length;
      var chunk = normalized
          .substring(dateMatch.end, end)
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (chunk.isEmpty) continue;

      var documentNumber = '';
      final documentMatch = documentPattern.firstMatch(chunk);
      if (documentMatch != null) {
        documentNumber = documentMatch.group(0) ?? '';
        chunk = '${chunk.substring(0, documentMatch.start)} '
            '${chunk.substring(documentMatch.end)}'
            .trim();
      }

      final amounts = amountPattern.allMatches(chunk).toList(growable: false);
      if (amounts.isEmpty) continue;
      final transactionAmount = amounts.first;
      final amountText = transactionAmount.group(0) ?? '';
      final balanceText = amounts.length > 1 ? amounts.last.group(0) ?? '' : '';
      final description = chunk.substring(0, transactionAmount.start).trim();
      final side = _sideFromPdfDescription(description);

      rows.add([
        dateMatch.group(0) ?? '',
        documentNumber,
        description,
        side == EntrySide.debit ? amountText : '',
        side == EntrySide.credit ? amountText : '',
        balanceText,
      ]);
    }
    return rows;
  }

  EntrySide _sideFromPdfDescription(String description) {
    final value = _norm(description);
    const creditWords = [
      'receipt', 'payment received', 'cash receipt', 'collection',
      'قبض', 'تحصيل', 'سداد', 'دفعة مستلمة',
    ];
    const debitWords = [
      'invoice', 'sales invoice', 'service fee', 'charge',
      'فاتورة', 'رسوم', 'تحميل',
    ];
    if (creditWords.any(value.contains)) return EntrySide.credit;
    if (debitWords.any(value.contains)) return EntrySide.debit;
    return EntrySide.unknown;
  }

  int _findHeader(List<List<dynamic>> table) {
    var best = 0;
    var bestScore = -1;
    for (var index = 0; index < table.length && index < 20; index++) {
      final score = table[index]
          .map(_clean)
          .where((header) => _allNames.any((name) => _headerMatches(header, name)))
          .length;
      if (score > bestScore) {
        bestScore = score;
        best = index;
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
        ..._balanceNames,
        ..._descNames,
      ];

  int? _find(List<String> headers, List<String> names) {
    for (var index = 0; index < headers.length; index++) {
      if (names.any((name) => _headerMatches(headers[index], name))) {
        return index;
      }
    }
    return null;
  }

  bool _headerMatches(String header, String name) {
    final normalizedHeader = _norm(header);
    final normalizedName = _norm(name);
    if (normalizedHeader.isEmpty || normalizedName.isEmpty) return false;
    return normalizedHeader == normalizedName ||
        normalizedHeader.contains(normalizedName) ||
        normalizedName.contains(normalizedHeader);
  }

  int? _guessDate(List<List<dynamic>> rows, int count) {
    var best = 0;
    int? column;
    for (var current = 0; current < count; current++) {
      final score = rows
          .take(40)
          .where((row) => _date(_cell(row, current)) != null)
          .length;
      if (score > best) {
        best = score;
        column = current;
      }
    }
    return best >= 2 ? column : null;
  }

  dynamic _cell(List<dynamic> row, int? index) =>
      index == null || index < 0 || index >= row.length ? null : row[index];

  String _clean(dynamic value) => value?.toString().trim() ?? '';

  String _norm(String value) => value
      .toLowerCase()
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
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
        .toList(growable: false);
    if (parts.length != 3 || parts.any((part) => part == null)) return null;
    final a = parts[0]!;
    final b = parts[1]!;
    final c = parts[2]!;
    final year = a > 1900 ? a : (c < 100 ? 2000 + c : c);
    final month = b;
    final day = a > 1900 ? c : a;
    final result = DateTime(year, month, day);
    if (result.year != year || result.month != month || result.day != day) {
      return null;
    }
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
