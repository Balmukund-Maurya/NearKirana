import os
import re
import glob

def fix_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original = content
    
    # admin_home_tab.dart
    content = content.replace("langProvider.product_found", "AppLocalizations.of(context)!.product_found")
    content = content.replace("langProvider.price", "AppLocalizations.of(context)!.price")
    content = content.replace("langProvider.stock", "AppLocalizations.of(context)!.stock")
    content = content.replace("langProvider.edit", "AppLocalizations.of(context)!.edit")
    content = content.replace("langProvider.ok_btn", "AppLocalizations.of(context)!.ok_btn")
    
    # admin_more_tab.dart
    content = content.replace("langProvider: AppLocalizations.of(context)!", "langProvider: langProvider")
    content = content.replace("langProvider.select_language", "AppLocalizations.of(context)!.select_language")

    # ANY remaining langProvider.translate('foo')
    content = re.sub(r'langProvider\.translate\([\'"]([a-zA-Z0-9_]+)[\'"]\)', r'AppLocalizations.of(context)!.\1', content)
    
    # ANY remaining l10n.translate('foo')
    content = re.sub(r'l10n\.translate\([\'"]([a-zA-Z0-9_]+)[\'"]\)', r'AppLocalizations.of(context)!.\1', content)

    # In customer_shop_tab.dart line 1492: AppLocalizations isn't defined for type ProductGrid.
    # It probably says `AppLocalizations.no_product` instead of `AppLocalizations.of(context)!.no_product`.
    content = content.replace("AppLocalizations.no_product", "AppLocalizations.of(context)!.no_product")
    
    # Also in customer_shop_tab.dart line 1492, there might be Text(AppLocalizations.of(context)!.no_product). Wait, the error is `The getter 'AppLocalizations' isn't defined for the type 'ProductGrid'`. This means I probably wrote `AppLocalizations.of(context)...` but AppLocalizations isn't imported in customer_shop_tab.dart maybe? No, it's imported. Wait, if it says getter not defined, maybe it was `AppLocalizations.of...` but missing parentheses? Let's fix that.
    content = content.replace("Text(AppLocalizations.no_product", "Text(AppLocalizations.of(context)!.no_product")

    # ensure AppLocalizations is imported
    if content != original and "import 'package:near_kirana/l10n/app_localizations.dart';" not in content:
        content = "import 'package:near_kirana/l10n/app_localizations.dart';\n" + content
        
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

for file in glob.glob('lib/**/*.dart', recursive=True):
    fix_file(file)

print("Fixed errors.")
