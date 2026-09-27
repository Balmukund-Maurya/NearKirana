file = 'lib/main.dart'
with open(file, 'r') as f:
    content = f.read()

if "import 'package:near_kirana/l10n/app_localizations.dart';" not in content:
    content = "import 'package:near_kirana/l10n/app_localizations.dart';\n" + content
    
with open(file, 'w') as f:
    f.write(content)
