import re
import glob

for file in glob.glob('lib/**/*.dart', recursive=True):
    with open(file, 'r') as f: content = f.read()
    orig = content
    
    # cart_screen.dart and customer_shop_tab.dart
    content = re.sub(r'langProvider\.translate\([\'"]([a-zA-Z0-9_]+)[\'"]\)', r'AppLocalizations.of(context)!.\1', content)
    
    # admin_home_tab.dart
    content = content.replace("langProvider.product_found", "AppLocalizations.of(context)!.product_found")
    content = content.replace("langProvider.price", "AppLocalizations.of(context)!.price")
    content = content.replace("langProvider.stock", "AppLocalizations.of(context)!.stock")
    content = content.replace("langProvider.edit", "AppLocalizations.of(context)!.edit")
    content = content.replace("langProvider.ok_btn", "AppLocalizations.of(context)!.ok_btn")

    # admin_more_tab.dart
    content = content.replace("langProvider: AppLocalizations.of(context)!", "langProvider: langProvider")
    
    if orig != content:
        with open(file, 'w') as f: f.write(content)

print("Done")
