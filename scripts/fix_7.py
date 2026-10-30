import os
import re

# cart_screen.dart
with open('lib/cart_screen.dart', 'r') as f:
    content = f.read()

# Any remaining .translate('foo') with newlines
content = re.sub(r'([a-zA-Z0-9_]+)\s*\.\s*translate\s*\(\s*[\'"]([a-zA-Z0-9_]+)[\'"]\s*,?\s*\)', r'AppLocalizations.of(context)!.\2', content, flags=re.DOTALL)
content = re.sub(r'Provider\.of\s*<\s*LanguageProvider\s*>\s*\([^)]*\)\s*\.\s*translate\s*\(\s*[\'"]([a-zA-Z0-9_]+)[\'"]\s*,?\s*\)', r'AppLocalizations.of(context)!.\1', content, flags=re.DOTALL)

with open('lib/cart_screen.dart', 'w') as f:
    f.write(content)

# customer_shop_tab.dart
with open('lib/customer_shop_tab.dart', 'r') as f:
    content = f.read()

content = re.sub(r'([a-zA-Z0-9_]+)\s*\.\s*translate\s*\(\s*[\'"]([a-zA-Z0-9_]+)[\'"]\s*,?\s*\)', r'AppLocalizations.of(context)!.\2', content, flags=re.DOTALL)
content = re.sub(r'Provider\.of\s*<\s*LanguageProvider\s*>\s*\([^)]*\)\s*\.\s*translate\s*\(\s*[\'"]([a-zA-Z0-9_]+)[\'"]\s*,?\s*\)', r'AppLocalizations.of(context)!.\1', content, flags=re.DOTALL)

with open('lib/customer_shop_tab.dart', 'w') as f:
    f.write(content)

print("Done")
