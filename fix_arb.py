import json

with open("lib/l10n/app_en.arb", "r", encoding="utf-8") as f:
    en = json.load(f)

for k, v in en.items():
    if isinstance(v, str) and not k.startswith("@"):
        en[k] = v.replace("'", "''")

with open("lib/l10n/app_en.arb", "w", encoding="utf-8") as f:
    json.dump(en, f, indent=2)

with open("lib/l10n/app_hi.arb", "r", encoding="utf-8") as f:
    hi = json.load(f)

for k, v in hi.items():
    if isinstance(v, str) and not k.startswith("@"):
        hi[k] = v.replace("'", "''")

with open("lib/l10n/app_hi.arb", "w", encoding="utf-8") as f:
    json.dump(hi, f, ensure_ascii=False, indent=2)

print("Fixed!")
