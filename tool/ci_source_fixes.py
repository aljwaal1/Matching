from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file_path = Path(path)
    content = file_path.read_text(encoding="utf-8")
    if old not in content:
        raise SystemExit(f"Expected source pattern was not found in {path}")
    file_path.write_text(content.replace(old, new, 1), encoding="utf-8")


replace_once(
    "lib/main.dart",
    "import 'package:intl/intl.dart';",
    "import 'package:intl/intl.dart' hide TextDirection;",
)

replace_once(
    "lib/services/export_service.dart",
    """      for (final row in grid.rows) {
        for (final cell in row.cells) {
          cell.stringFormat = PdfStringFormat(
            textDirection: PdfTextDirection.rightToLeft,
            alignment: PdfTextAlignment.center,
          );
        }
      }
      for (final cell in header.cells) {
        cell.style.font = font;
        cell.stringFormat = PdfStringFormat(
          textDirection: PdfTextDirection.rightToLeft,
          alignment: PdfTextAlignment.center,
        );
      }
""",
    """      for (var rowIndex = 0; rowIndex < grid.rows.count; rowIndex++) {
        final row = grid.rows[rowIndex];
        for (var cellIndex = 0; cellIndex < row.cells.count; cellIndex++) {
          final cell = row.cells[cellIndex];
          cell.stringFormat = PdfStringFormat(
            textDirection: PdfTextDirection.rightToLeft,
            alignment: PdfTextAlignment.center,
          );
        }
      }
      for (var cellIndex = 0; cellIndex < header.cells.count; cellIndex++) {
        final cell = header.cells[cellIndex];
        cell.style.font = font;
        cell.stringFormat = PdfStringFormat(
          textDirection: PdfTextDirection.rightToLeft,
          alignment: PdfTextAlignment.center,
        );
      }
""",
)
