import os
import re

lib_dir = "lib"

for root, _, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Replace `LanguageProvider langProvider` with `AppLocalizations langProvider` in function signatures
            content = re.sub(r'LanguageProvider (\w+)', r'AppLocalizations \1', content)
            
            # Now wait, we might have cases where `langProvider` was initialized with Provider.of... but since it was in parameter,
            # what about `AppLocalizations` import? We need to make sure `package:near_kirana/l10n/app_localizations.dart` is imported.
            if 'AppLocalizations' in content and 'package:near_kirana/l10n/app_localizations.dart' not in content:
                content = "import 'package:near_kirana/l10n/app_localizations.dart';\n" + content
                
            # Replace `langProvider.translate('foo')` with `langProvider.foo`
            content = re.sub(r'(\w+)\.translate\([\'"]([a-zA-Z0-9_]+)[\'"]\)', r'\1.\2', content)

            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)

print("Fixed leftover LanguageProvider references.")
