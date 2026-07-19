import 'package:excel/excel.dart';

class ExcelReportStyle {
  const ExcelReportStyle._();

  static final _thinBorder = Border(
    borderStyle: BorderStyle.Thin,
    borderColorHex: ExcelColor.fromHexString('#FFB7BCC7'),
  );

  static final title = CellStyle(
    bold: true,
    fontSize: 16,
    fontColorHex: ExcelColor.white,
    backgroundColorHex: ExcelColor.fromHexString('#FF5B3FD1'),
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    textWrapping: TextWrapping.WrapText,
    leftBorder: _thinBorder,
    rightBorder: _thinBorder,
    topBorder: _thinBorder,
    bottomBorder: _thinBorder,
  );

  static final header = CellStyle(
    bold: true,
    fontSize: 11,
    fontColorHex: ExcelColor.white,
    backgroundColorHex: ExcelColor.fromHexString('#FF00A9C8'),
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    textWrapping: TextWrapping.WrapText,
    leftBorder: _thinBorder,
    rightBorder: _thinBorder,
    topBorder: _thinBorder,
    bottomBorder: _thinBorder,
  );

  static final body = CellStyle(
    horizontalAlign: HorizontalAlign.Right,
    verticalAlign: VerticalAlign.Center,
    textWrapping: TextWrapping.WrapText,
    leftBorder: _thinBorder,
    rightBorder: _thinBorder,
    topBorder: _thinBorder,
    bottomBorder: _thinBorder,
  );

  static final bodyCenter = CellStyle(
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    textWrapping: TextWrapping.WrapText,
    leftBorder: _thinBorder,
    rightBorder: _thinBorder,
    topBorder: _thinBorder,
    bottomBorder: _thinBorder,
  );

  static final money = CellStyle(
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    numberFormat: CustomNumericNumFormat('#,##0.00;[Red]-#,##0.00'),
    leftBorder: _thinBorder,
    rightBorder: _thinBorder,
    topBorder: _thinBorder,
    bottomBorder: _thinBorder,
  );

  static final total = CellStyle(
    bold: true,
    backgroundColorHex: ExcelColor.fromHexString('#FFFFF1C9'),
    horizontalAlign: HorizontalAlign.Right,
    verticalAlign: VerticalAlign.Center,
    textWrapping: TextWrapping.WrapText,
    leftBorder: _thinBorder,
    rightBorder: _thinBorder,
    topBorder: _thinBorder,
    bottomBorder: _thinBorder,
  );

  static final totalMoney = CellStyle(
    bold: true,
    backgroundColorHex: ExcelColor.fromHexString('#FFFFF1C9'),
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    numberFormat: CustomNumericNumFormat('#,##0.00;[Red]-#,##0.00'),
    leftBorder: _thinBorder,
    rightBorder: _thinBorder,
    topBorder: _thinBorder,
    bottomBorder: _thinBorder,
  );

  static void styleTable(
    Sheet sheet, {
    required int headerRow,
    required int lastRow,
    required int columnCount,
    Set<int> moneyColumns = const {},
    Set<int> centeredColumns = const {},
    List<double> widths = const [],
  }) {
    for (var column = 0; column < columnCount; column++) {
      sheet
          .cell(CellIndex.indexByColumnRow(
            columnIndex: column,
            rowIndex: headerRow,
          ))
          .cellStyle = header;
      if (column < widths.length) sheet.setColumnWidth(column, widths[column]);
    }

    for (var row = headerRow + 1; row <= lastRow; row++) {
      for (var column = 0; column < columnCount; column++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(
          columnIndex: column,
          rowIndex: row,
        ));
        cell.cellStyle = moneyColumns.contains(column)
            ? money
            : centeredColumns.contains(column)
                ? bodyCenter
                : body;
      }
    }
  }

  static void styleSummary(
    Sheet sheet, {
    required int rows,
    double labelWidth = 30,
    double valueWidth = 36,
    Set<int> moneyRows = const {},
    Set<int> totalRows = const {},
  }) {
    sheet.setColumnWidth(0, labelWidth);
    sheet.setColumnWidth(1, valueWidth);
    for (var row = 0; row < rows; row++) {
      final label = sheet.cell(CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: row,
      ));
      final value = sheet.cell(CellIndex.indexByColumnRow(
        columnIndex: 1,
        rowIndex: row,
      ));
      if (row == 0) {
        label.cellStyle = title;
        value.cellStyle = title;
      } else if (totalRows.contains(row)) {
        label.cellStyle = total;
        value.cellStyle = moneyRows.contains(row) ? totalMoney : total;
      } else {
        label.cellStyle = body;
        value.cellStyle = moneyRows.contains(row) ? money : body;
      }
    }
  }
}
