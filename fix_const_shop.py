import re

with open('lib/customer_shop_tab.dart', 'r') as f:
    content = f.read()

content = content.replace("const Text(langProvider.translate('fix_btn')", "Text(langProvider.translate('fix_btn')")

with open('lib/customer_shop_tab.dart', 'w') as f:
    f.write(content)
