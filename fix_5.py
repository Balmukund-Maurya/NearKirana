import os
import re
import glob

for file in glob.glob('lib/**/*.dart', recursive=True):
    with open(file, 'r') as f: content = f.read()
    orig = content
    
    # Matches Provider.of<LanguageProvider>(...) .translate('key') across lines
    # Pattern: Provider\.of\s*<\s*LanguageProvider\s*>\s*\([^)]*\)\s*\.\s*translate\s*\(\s*['"]([^'"]+)['"]\s*\)
    pattern = r'Provider\.of\s*<\s*LanguageProvider\s*>\s*\([^)]*\)\s*\.\s*translate\s*\(\s*[\'"]([a-zA-Z0-9_]+)[\'"]\s*\)'
    content = re.sub(pattern, r'AppLocalizations.of(context)!.\1', content)

    # Any remaining `.translate('key')` that I missed (e.g. if there are other variable names)
    # wait, if it's `foo.translate('key')`, we can just replace the whole `foo.translate('key')` with `AppLocalizations.of(context)!.key`.
    # Let's see if there are any others.
    pattern2 = r'[a-zA-Z0-9_]+\s*\.\s*translate\s*\(\s*[\'"]([a-zA-Z0-9_]+)[\'"]\s*\)'
    content = re.sub(pattern2, r'AppLocalizations.of(context)!.\1', content)

    if orig != content:
        with open(file, 'w') as f: f.write(content)

print("Done")
