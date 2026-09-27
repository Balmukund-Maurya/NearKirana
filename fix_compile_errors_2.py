import os
import re

def replace_in_file(filepath, replacements):
    with open(filepath, 'r') as f:
        content = f.read()
    
    for old, new in replacements:
        content = content.replace(old, new)
        
    with open(filepath, 'w') as f:
        f.write(content)

# main.dart
replace_in_file('lib/main.dart', [
    ('AppLocalizations langProvider', 'LanguageProvider langProvider'),
    ('AppLocalizations.of(context)!.currentLanguage', 'Provider.of<LanguageProvider>(context, listen: false).currentLanguage'),
    ('AppLocalizations.of(context)!.setLanguage', 'Provider.of<LanguageProvider>(context, listen: false).setLanguage'),
    ('langProvider: l10n,', 'langProvider: langProvider,')
])

# customer_profile_tab.dart
replace_in_file('lib/customer_profile_tab.dart', [
    ('AppLocalizations langProvider', 'LanguageProvider langProvider'),
    ('AppLocalizations.of(context)!.currentLanguage', 'Provider.of<LanguageProvider>(context, listen: false).currentLanguage'),
    ('AppLocalizations.of(context)!.setLanguage', 'Provider.of<LanguageProvider>(context, listen: false).setLanguage'),
    ('langProvider: AppLocalizations.of(context)!', 'langProvider: langProvider'),
])

# customer_shop_tab.dart
replace_in_file('lib/customer_shop_tab.dart', [
    ('LanguageProvider langProvider', 'AppLocalizations l10n'),
    ('final LanguageProvider langProvider', 'final AppLocalizations l10n'),
    ('langProvider:', 'l10n:'),
    ('langProvider.', 'l10n.'),
    ('l10n.translate', 'l10n.')  # fixes left over translates
])
# Because customer_shop_tab calls some functions that used to take LanguageProvider, I changed the signature to take AppLocalizations instead. But I should make sure there are no remaining 'LanguageProvider langProvider' inside it.
# Wait! In customer_shop_tab.dart I just replaced LanguageProvider langProvider with AppLocalizations l10n!

# my_orders_screen.dart
replace_in_file('lib/my_orders_screen.dart', [
    ('LanguageProvider langProvider', 'AppLocalizations l10n'),
    ('langProvider:', 'l10n:'),
    ('langProvider.', 'l10n.')
])
# but wait! my_orders_screen.dart had AppLocalizations langProvider, so it needs to be:
replace_in_file('lib/my_orders_screen.dart', [
    ('AppLocalizations langProvider', 'AppLocalizations l10n'),
    ('langProvider:', 'l10n:'),
    ('langProvider.', 'l10n.')
])

# cart_screen.dart
replace_in_file('lib/cart_screen.dart', [
    ('langProvider.translate', 'l10n.'),
    ('l10n.translate', 'l10n.')
])

# khata_screen.dart
replace_in_file('lib/khata_screen.dart', [
    ('isBanned ? AppLocalizations.of(context)!.customer_unblocked : AppLocalizations.of(context)!.customer_blocked',
     'AppLocalizations.of(context)!.(isBanned ? \'customer_unblocked\' : \'customer_blocked\')'), # Wait, the first one was wrong because of string literals
])
# Wait, for ternary, I need to do: isBanned ? AppLocalizations.of(context)!.customer_unblocked : AppLocalizations.of(context)!.customer_blocked
# If it says 'isBanned' isn't defined for AppLocalizations, it means it parsed as AppLocalizations.of(context)!.isBanned !
# Ah! AppLocalizations.of(context)!.isBanned ? ... because I probably replaced `.translate(isBanned ? ... )` with `.(isBanned ? ...)` !
# Let's fix this with regex.
import glob
for file in glob.glob('lib/**/*.dart', recursive=True):
    with open(file, 'r') as f: content = f.read()
    
    # Fix AppLocalizations.of(context)!.(isBanned ? ... )
    content = re.sub(
        r'AppLocalizations\.of\(context\)!.\(isBanned\s*\?\s*\'(.*?)\'\s*:\s*\'(.*?)\'\)',
        r'isBanned ? AppLocalizations.of(context)!.\1 : AppLocalizations.of(context)!.\2',
        content
    )
    
    # Fix AppLocalizations.of(context)!.(isCredit ? ... )
    content = re.sub(
        r'AppLocalizations\.of\(context\)!.\(isCredit\s*\?\s*\'(.*?)\'\s*:\s*\'(.*?)\'\)',
        r'isCredit ? AppLocalizations.of(context)!.\1 : AppLocalizations.of(context)!.\2',
        content
    )
    
    # Remove duplicate imports
    lines = content.split('\n')
    unique_lines = []
    seen_imports = set()
    for line in lines:
        if line.startswith('import '):
            if line in seen_imports:
                continue
            seen_imports.add(line)
        unique_lines.append(line)
        
    with open(file, 'w') as f:
        f.write('\n'.join(unique_lines))
