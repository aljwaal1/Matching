from pathlib import Path

path = Path('lib/services/file_import_service.dart')
source = path.read_text(encoding='utf-8')
start_marker = '  List<List<dynamic>> _readXlsx(Uint8List bytes) {'
end_marker = '  List<int> _archiveBytes(ArchiveFile file) {'
start = source.index(start_marker)
end = source.index(end_marker, start)
replacement = r'''  List<List<dynamic>> _readXlsx(Uint8List bytes) {
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

'''
path.write_text(source[:start] + replacement + source[end:], encoding='utf-8')
print('XLSX reader patched')
