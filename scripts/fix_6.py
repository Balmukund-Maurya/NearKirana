import os
import re

# admin_more_tab.dart
with open('lib/admin_more_tab.dart', 'r') as f:
    content = f.read()
    
# Change _showLanguageDialog(context, langProvider); to _showLanguageDialog(context);
content = content.replace('_showLanguageDialog(context, langProvider);', '_showLanguageDialog(context);')
# Change void _showLanguageDialog(BuildContext context, LanguageProvider langProvider) to void _showLanguageDialog(BuildContext context)
content = content.replace('void _showLanguageDialog(\n    BuildContext context,\n    LanguageProvider langProvider,\n  )', 'void _showLanguageDialog(BuildContext context)')
content = content.replace('void _showLanguageDialog(\n    BuildContext context,\n    LanguageProvider langProvider)', 'void _showLanguageDialog(BuildContext context)')

# Inside _showLanguageDialog, it uses langProvider for _buildLanguageOption. Let's change _buildLanguageOption to take LanguageProvider lang.
content = content.replace('_buildLanguageOption(sheetContext, langProvider, ', "_buildLanguageOption(sheetContext, Provider.of<LanguageProvider>(context, listen: false), ")

with open('lib/admin_more_tab.dart', 'w') as f:
    f.write(content)

# cart_screen.dart
with open('lib/cart_screen.dart', 'r') as f:
    content = f.read()

# Any remaining Provider.of<LanguageProvider>(context...).translate('x') across ANY space
content = re.sub(r'Provider\.of<LanguageProvider>\([^)]*\)\s*\.\s*translate\s*\(\s*[\'"]([a-zA-Z0-9_]+)[\'"]\s*\)', r'AppLocalizations.of(context)!.\1', content)

# Also check for langProvider.translate('foo')
content = re.sub(r'[a-zA-Z0-9_]+\s*\.\s*translate\s*\(\s*[\'"]([a-zA-Z0-9_]+)[\'"]\s*\)', r'AppLocalizations.of(context)!.\1', content)

with open('lib/cart_screen.dart', 'w') as f:
    f.write(content)

# customer_shop_tab.dart
with open('lib/customer_shop_tab.dart', 'r') as f:
    content = f.read()

content = re.sub(r'Provider\.of<LanguageProvider>\([^)]*\)\s*\.\s*translate\s*\(\s*[\'"]([a-zA-Z0-9_]+)[\'"]\s*\)', r'AppLocalizations.of(context)!.\1', content)
content = re.sub(r'[a-zA-Z0-9_]+\s*\.\s*translate\s*\(\s*[\'"]([a-zA-Z0-9_]+)[\'"]\s*\)', r'AppLocalizations.of(context)!.\1', content)

with open('lib/customer_shop_tab.dart', 'w') as f:
    f.write(content)

print("Done")
