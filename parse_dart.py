import re
import json

with open('lib/language_provider.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Find the dictionary: 'or_divider': { 'hi': '...', 'en': '...' }, ...
# Start from "final translations = {" and end at "};"
start = content.find("final translations = {")
end = content.find("};\n", start)
dict_content = content[start:end+1]

# Instead of parsing dart, let's just use a simple regex that matches:
# 'key': { 'hi': '...', 'en': '...' }
# We have to be careful with quotes and newlines.
# Dart strings might be using single quotes or double quotes.
# This regex matches: 'key' or "key"
# then : {
# then 'hi' or "hi" : 'val' or "val"
# then 'en' or "en" : 'val' or "val"

# Let's extract all key-value pairs of the form:
# '([a-zA-Z0-9_]+)'\s*:\s*\{([^}]+)\}
pattern = re.compile(r"['\"]([a-zA-Z0-9_]+)['\"]\s*:\s*\{([^}]+)\}")
matches = pattern.findall(dict_content)

en_arb = {}
hi_arb = {}

# Inside the inner block, we match 'hi': 'value' and 'en': 'value'
inner_pattern = re.compile(r"['\"](hi|en)['\"]\s*:\s*(['\"])(.*?)(?<!\\)\2", re.DOTALL)

for key, inner_text in matches:
    inner_matches = inner_pattern.findall(inner_text)
    for lang, quote, text in inner_matches:
        # replace escaped quotes
        text = text.replace("\\'", "'").replace('\\"', '"').replace('\\n', '\n')
        if lang == 'en':
            en_arb[key] = text
        else:
            hi_arb[key] = text

def process_placeholders(arb_dict):
    new_arb = {}
    for k, v in arb_dict.items():
        new_arb[k] = v
        placeholders = re.findall(r'\{([a-zA-Z0-9_]+)\}', v)
        if placeholders:
            ph_dict = {}
            for p in placeholders:
                ph_dict[p] = {"type": "String"}
            new_arb["@" + k] = {"placeholders": ph_dict}
    return new_arb

en_arb = process_placeholders(en_arb)
hi_arb = process_placeholders(hi_arb)

import os
os.makedirs("lib/l10n", exist_ok=True)
with open("lib/l10n/app_en.arb", "w", encoding='utf-8') as f:
    json.dump(en_arb, f, ensure_ascii=False, indent=2)
with open("lib/l10n/app_hi.arb", "w", encoding='utf-8') as f:
    json.dump(hi_arb, f, ensure_ascii=False, indent=2)

print("Parsed", len(en_arb.keys())//2, "keys") # dividing by 2 because of metadata
