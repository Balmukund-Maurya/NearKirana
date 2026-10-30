import os
import re

lib_dir = "lib"

# Matches different variations of getting LanguageProvider
# We will just replace .translate('some_key') with AppLocalizations.of(context)!.some_key

for root, _, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Step 1: Replace Provider.of<LanguageProvider>(context).translate('key')
            # with AppLocalizations.of(context)!.key
            # and context.read<LanguageProvider>().translate('key') etc.
            
            # Let's just find anything matching `.translate('key')` or `.translate("key")`
            # Wait, `lang.translate('key')` means we need to make sure we have `AppLocalizations.of(context)!`
            # If we don't have context, it's hard. But Flutter widget builds usually have context.
            
            # Since this is a massive change, doing it with regex might be dangerous if we don't have context.
            # Usually `final lang = Provider.of<LanguageProvider>(context);` is used.
            # We can replace that with `final l10n = AppLocalizations.of(context)!;`
            # and then `lang.translate('key')` with `l10n.key`.
            
            content = re.sub(
                r'final\s+(\w+)\s*=\s*Provider\.of<LanguageProvider>\(context(.*?)?\);',
                r'final \1 = AppLocalizations.of(context)!;',
                content
            )
            content = re.sub(
                r'final\s+(\w+)\s*=\s*context\.watch<LanguageProvider>\(\);',
                r'final \1 = AppLocalizations.of(context)!;',
                content
            )
            content = re.sub(
                r'final\s+(\w+)\s*=\s*context\.read<LanguageProvider>\(\);',
                r'final \1 = AppLocalizations.of(context)!;',
                content
            )
            
            # Now replace `langVar.translate('some_key')` with `langVar.some_key`
            # E.g. lang.translate('hello') -> lang.hello
            content = re.sub(r'(\w+)\.translate\([\'"]([a-zA-Z0-9_]+)[\'"]\)', r'\1.\2', content)
            
            # Replace inline Provider.of...translate('key')
            content = re.sub(
                r'Provider\.of<LanguageProvider>\(context(.*?)?\)\.translate\([\'"]([a-zA-Z0-9_]+)[\'"]\)',
                r'AppLocalizations.of(context)!.\2',
                content
            )
            
            # Now add import for app_localizations if it was used
            if 'AppLocalizations' in content and 'flutter_gen/gen_l10n/app_localizations.dart' not in content:
                # Add import at top
                content = "import 'package:flutter_gen/gen_l10n/app_localizations.dart';\n" + content

            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
print("Replacement script executed.")
