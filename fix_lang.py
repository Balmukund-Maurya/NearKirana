import os
import re

files = [
    "lib/customer_shop_tab.dart",
    "lib/customer_profile_tab.dart",
    "lib/my_orders_screen.dart",
    "lib/cart_screen.dart"
]

for filepath in files:
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
        
    # Replace Provider.of<LanguageProvider>(context).translate('key')
    content = re.sub(r'Provider\.of<LanguageProvider>\(context(?:,\s*listen:\s*false)?\)\.translate\([\'"]([a-zA-Z0-9_]+)[\'"]\)', r'AppLocalizations.of(context)!.\1', content)
    
    # Replace langProvider.translate('key')
    content = re.sub(r'langProvider\.translate\([\'"]([a-zA-Z0-9_]+)[\'"]\)', r'AppLocalizations.of(context)!.\1', content)
    
    # Replace lang.translate('key') 
    content = re.sub(r'lang\.translate\([\'"]([a-zA-Z0-9_]+)[\'"]\)', r'AppLocalizations.of(context)!.\1', content)

    # Add import if missing
    if "import 'package:near_kirana/l10n/app_localizations.dart';" not in content:
        content = "import 'package:near_kirana/l10n/app_localizations.dart';\n" + content
        
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

print("Fixed language references in tab/screen files.")
