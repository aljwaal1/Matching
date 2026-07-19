from pathlib import Path

source_path = Path('tool/apply_balance_detection_patch.py')
source = source_path.read_text(encoding='utf-8')
source = source.replace(
    "    path.write_text(r'''import 'dart:convert';",
    "    path.write_text(r\"\"\"import 'dart:convert';",
    1,
)
source = source.replace(
    "}\n''', encoding='utf-8')\n\n\ndef main()",
    "}\n\"\"\", encoding='utf-8')\n\n\ndef main()",
    1,
)
namespace = {'__name__': 'balance_patch_module'}
exec(compile(source, str(source_path), 'exec'), namespace)
namespace['main']()
