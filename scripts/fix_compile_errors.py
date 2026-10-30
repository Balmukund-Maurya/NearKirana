import os
import re

# 1. Fix cart_screen.dart:
file = "lib/cart_screen.dart"
with open(file, 'r', encoding='utf-8') as f: content = f.read()
content = re.sub(r'langProvider\.translate\([\'"]([a-zA-Z0-9_]+)[\'"]\)', r'langProvider.\1', content)
content = re.sub(r'l10n\.translate\([\'"]([a-zA-Z0-9_]+)[\'"]\)', r'l10n.\1', content)
with open(file, 'w', encoding='utf-8') as f: f.write(content)

# 2. Fix customer_profile_tab.dart
file = "lib/customer_profile_tab.dart"
with open(file, 'r', encoding='utf-8') as f: content = f.read()
# We need to revert AppLocalizations langProvider back to LanguageProvider langProvider
content = content.replace("AppLocalizations langProvider", "LanguageProvider langProvider")
content = content.replace("import 'package:near_kirana/l10n/app_localizations.dart';", "import 'package:near_kirana/l10n/app_localizations.dart';\nimport 'package:near_kirana/language_provider.dart';")
with open(file, 'w', encoding='utf-8') as f: f.write(content)

# 3. Fix customer_shop_tab.dart
file = "lib/customer_shop_tab.dart"
with open(file, 'r', encoding='utf-8') as f: content = f.read()
content = re.sub(r'langProvider\.translate\([\'"]([a-zA-Z0-9_]+)[\'"]\)', r'langProvider.\1', content)
# Also revert the LanguageProvider if it was changed
content = content.replace("AppLocalizations langProvider", "LanguageProvider langProvider")
content = content.replace("final AppLocalizations langProvider;", "final LanguageProvider langProvider;")
if "import 'package:near_kirana/language_provider.dart';" not in content:
    content = "import 'package:near_kirana/language_provider.dart';\n" + content
with open(file, 'w', encoding='utf-8') as f: f.write(content)

# 4. Fix khata_screen.dart
file = "lib/khata_screen.dart"
with open(file, 'r', encoding='utf-8') as f: content = f.read()
content = content.replace("generic_error", "error_loading")
content = re.sub(r'Provider\.of<LanguageProvider>\(context,\s*listen:\s*false\)\.translate\((.*?)\)', r'AppLocalizations.of(context)!.\1', content)
content = re.sub(r'Provider\.of<LanguageProvider>\(context\)\.translate\((.*?)\)', r'AppLocalizations.of(context)!.\1', content)
# It has a ternary: Provider.of<LanguageProvider>(context, listen: false).translate(isBanned ? 'customer_unblocked' : 'customer_blocked')
# This cannot be evaluated directly as a property! We have to replace it manually.
# For ternary: AppLocalizations.of(context)!.customer_unblocked or AppLocalizations.of(context)!.customer_blocked
# Let's just fix it specifically:
content = content.replace(
    r"AppLocalizations.of(context)!.(isBanned ? 'customer_unblocked' : 'customer_blocked')",
    r"isBanned ? AppLocalizations.of(context)!.customer_unblocked : AppLocalizations.of(context)!.customer_blocked"
)
with open(file, 'w', encoding='utf-8') as f: f.write(content)

# 5. Fix khata_statement_screen.dart
file = "lib/khata_statement_screen.dart"
with open(file, 'r', encoding='utf-8') as f: content = f.read()
content = content.replace("generic_error", "error_loading")
content = re.sub(r'Provider\.of<LanguageProvider>\(context,\s*listen:\s*false\)\.translate\((.*?)\)', r'AppLocalizations.of(context)!.\1', content)
content = content.replace(
    r"AppLocalizations.of(context)!.(isCredit ? 'udhaar_added' : 'payment_received_short')",
    r"isCredit ? AppLocalizations.of(context)!.udhaar_added : AppLocalizations.of(context)!.payment_received_short"
)
with open(file, 'w', encoding='utf-8') as f: f.write(content)

# 6. Fix main.dart
file = "lib/main.dart"
with open(file, 'r', encoding='utf-8') as f: content = f.read()
content = content.replace("AppLocalizations langProvider", "LanguageProvider langProvider")
if "import 'package:near_kirana/language_provider.dart';" not in content:
    content = "import 'package:near_kirana/language_provider.dart';\n" + content
with open(file, 'w', encoding='utf-8') as f: f.write(content)

# 7. admin_more_tab.dart
file = "lib/admin_more_tab.dart"
with open(file, 'r', encoding='utf-8') as f: content = f.read()
content = content.replace("AppLocalizations langProvider", "LanguageProvider langProvider")
if "import 'package:near_kirana/language_provider.dart';" not in content:
    content = "import 'package:near_kirana/language_provider.dart';\n" + content
with open(file, 'w', encoding='utf-8') as f: f.write(content)

# 8. my_orders_screen.dart
file = "lib/my_orders_screen.dart"
with open(file, 'r', encoding='utf-8') as f: content = f.read()
content = content.replace("AppLocalizations langProvider", "LanguageProvider langProvider")
if "import 'package:near_kirana/language_provider.dart';" not in content:
    content = "import 'package:near_kirana/language_provider.dart';\n" + content
with open(file, 'w', encoding='utf-8') as f: f.write(content)
