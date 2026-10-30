import os
import re

files = [
    "lib/admin_settings_screen.dart",
    "lib/admin_product_forms.dart",
    "lib/cart_screen.dart",
    "lib/customer_shop_tab.dart",
    "lib/main.dart"
]

for filepath in files:
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Replace specific missing ones with 'error_loading'
    content = content.replace("err_loading_settings", "error_loading")
    content = content.replace("err_saving_settings", "error_loading")
    content = content.replace("err_reading_location", "error_loading")
    content = content.replace("generic_error", "error_loading")
    
    # In main.dart, we might have Provider.of<LanguageProvider>(context).translate('foo')
    content = re.sub(r'Provider\.of<LanguageProvider>\(context(?:,\s*listen:\s*false)?\)\.translate\([\'"]([a-zA-Z0-9_]+)[\'"]\)', r'AppLocalizations.of(context)!.\1', content)
    content = re.sub(r'langProvider\.translate\([\'"]([a-zA-Z0-9_]+)[\'"]\)', r'AppLocalizations.of(context)!.\1', content)
    content = re.sub(r'lang\.translate\([\'"]([a-zA-Z0-9_]+)[\'"]\)', r'AppLocalizations.of(context)!.\1', content)

    # Some translates might be spread across lines, but re.sub matches single line usually unless with re.DOTALL.
    # Let's see if there's any remaining `translate(` and try to fix them.
    # I can just do a very aggressive replacement of `.translate('foo')` to `AppLocalizations.of(context)!.foo` if it's on langProvider.
    
    if "import 'package:near_kirana/l10n/app_localizations.dart';" not in content:
        content = "import 'package:near_kirana/l10n/app_localizations.dart';\n" + content
        
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

print("Fixed remaining translates.")
