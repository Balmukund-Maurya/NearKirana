import os

lib_dir = "lib"

for root, _, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            new_content = content.replace(
                "import 'package:flutter_gen/gen_l10n/app_localizations.dart';",
                "import 'package:near_kirana/l10n/app_localizations.dart';"
            )
            
            if new_content != content:
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(new_content)

print("Imports fixed.")
