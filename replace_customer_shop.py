with open('lib/customer_shop_tab.dart', 'r') as f:
    content = f.read()

replacements = {
    "Text('Requested quantity exceeds available stock.')": "Text(langProvider.translate('qty_exceeds'))",
    "Text('Maximum stock reached!')": "Text(langProvider.translate('max_stock'))",
    "label: Text(category)": "label: Text(langProvider.translate('cat_' + category.toLowerCase()) == 'cat_' + category.toLowerCase() ? category : langProvider.translate('cat_' + category.toLowerCase()))",
    "Text('Fix',": "Text(langProvider.translate('fix_btn'),",
}

for old, new_str in replacements.items():
    content = content.replace(old, new_str)

with open('lib/customer_shop_tab.dart', 'w') as f:
    f.write(content)
