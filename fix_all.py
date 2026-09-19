import re

# Fix customer_shop_tab.dart const SnackBar
with open('lib/customer_shop_tab.dart', 'r') as f:
    content = f.read()

content = re.sub(r'const\s+(SnackBar\([^)]*langProvider[^)]*\))', r'\1', content)

with open('lib/customer_shop_tab.dart', 'w') as f:
    f.write(content)

# Fix cart_screen.dart langProvider scope
with open('lib/cart_screen.dart', 'r') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if "langProvider.translate('qty_exceeds')" in line and "const SnackBar" in line:
        lines[i] = line.replace("const SnackBar", "SnackBar").replace("langProvider", "Provider.of<LanguageProvider>(context, listen: false)")
    elif "langProvider.translate('qty_exceeds')" in line:
        lines[i] = line.replace("langProvider", "Provider.of<LanguageProvider>(context, listen: false)")

with open('lib/cart_screen.dart', 'w') as f:
    f.writelines(lines)
