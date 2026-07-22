from pathlib import Path
import re

main_path = Path('lib/main.dart')
text = main_path.read_text(encoding='utf-8')
main_pattern = re.compile(
    r"[ \t]*if \(_busy\)\n"
    r"[ \t]*const ColoredBox\(\n"
    r"[ \t]*color: Color\(0x44000000\),\n"
    r"[ \t]*child: Center\(child: CircularProgressIndicator\(\)\),\n"
    r"[ \t]*\),"
)
main_normalized = '''          if (_busy)
            const ColoredBox(
              color: Color(0x44000000),
              child: Center(child: CircularProgressIndicator()),
            ),'''
text, count = main_pattern.subn(main_normalized, text)
if count != 2:
    raise SystemExit(f'Expected two main busy overlays, found {count}')
main_path.write_text(text, encoding='utf-8')

bank_path = Path('lib/screens/bank_reconciliation_screen.dart')
bank = bank_path.read_text(encoding='utf-8')
bank_pattern = re.compile(
    r"[ \t]*if \(_busy\)\n"
    r"[ \t]*const Positioned\.fill\(\n"
    r"[ \t]*child: ColoredBox\(\n"
    r"[ \t]*color: Color\(0x44000000\),\n"
    r"[ \t]*child: Center\(child: CircularProgressIndicator\(\)\),\n"
    r"[ \t]*\),\n"
    r"[ \t]*\),"
)
bank_normalized = '''          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x44000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),'''
bank, count = bank_pattern.subn(bank_normalized, bank)
if count != 1:
    raise SystemExit(f'Expected one bank busy overlay, found {count}')
bank_path.write_text(bank, encoding='utf-8')
print('Busy overlays normalized')
