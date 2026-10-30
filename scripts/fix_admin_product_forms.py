import re

with open('lib/admin_product_forms.dart', 'r') as f:
    content = f.read()

# Replace ScaffoldMessenger...showSnackBar with _showTopSnackBar where we didn't before.

# Line 500: ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Item updated successfully!'), backgroundColor: Colors.green));
content = re.sub(
    r"ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*SnackBar\(\s*content:\s*Text\('Item updated successfully!'\),\s*backgroundColor:\s*Colors\.green,?\s*\),?\s*\);",
    r"_showTopSnackBar(context, 'Item updated successfully!');",
    content
)

# Line 522: ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating item: $e'), backgroundColor: Colors.red));
content = re.sub(
    r"ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*SnackBar\(\s*content:\s*Text\('Error updating item: \$e'\),\s*backgroundColor:\s*Colors\.red,?\s*\),?\s*\);",
    r"_showTopSnackBar(context, 'Error updating item: $e', isError: true);",
    content
)

# Line 661: ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Barcode field cannot be empty!'), backgroundColor: Colors.red));
content = re.sub(
    r"ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*SnackBar\(\s*content:\s*Text\('Barcode field cannot be empty!'\),\s*backgroundColor:\s*Colors\.red,?\s*\),?\s*\);",
    r"_showTopSnackBar(context, 'Barcode field cannot be empty!', isError: true);",
    content
)

# Line 698: ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Product details fetched!'), backgroundColor: Colors.green));
content = re.sub(
    r"ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*SnackBar\(\s*content:\s*Text\('Product details fetched!'\),\s*backgroundColor:\s*Colors\.green,?\s*\),?\s*\);",
    r"_showTopSnackBar(context, 'Product details fetched!');",
    content
)

# Line 705: ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Product with this barcode already exists!'), backgroundColor: Colors.red));
content = re.sub(
    r"ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*SnackBar\(\s*content:\s*Text\('Product with this barcode already exists!'\),\s*backgroundColor:\s*Colors\.red,?\s*\),?\s*\);",
    r"_showTopSnackBar(context, 'Product with this barcode already exists!', isError: true);",
    content
)

# Line 795: ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching barcode details: $e'), backgroundColor: Colors.red));
content = re.sub(
    r"ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*SnackBar\(\s*content:\s*Text\('Error fetching barcode details: \$e'\),\s*backgroundColor:\s*Colors\.red,?\s*\),?\s*\);",
    r"_showTopSnackBar(context, 'Error fetching barcode details: $e', isError: true);",
    content
)

# Line 827: ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: Price must be > 0 and Stock must be >= 0'), backgroundColor: Colors.red));
content = re.sub(
    r"ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*SnackBar\(\s*content:\s*Text\('Error: Price must be > 0 and Stock must be >= 0'\),\s*backgroundColor:\s*Colors\.red,?\s*\),?\s*\);",
    r"_showTopSnackBar(context, 'Error: Price must be > 0 and Stock must be >= 0', isError: true);",
    content
)

# Line 848: ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Item added successfully!'), backgroundColor: Colors.green));
content = re.sub(
    r"ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*SnackBar\(\s*content:\s*Text\('Item added successfully!'\),\s*backgroundColor:\s*Colors\.green,?\s*\),?\s*\);",
    r"_showTopSnackBar(context, 'Item added successfully!');",
    content
)

# Line 858: ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding item: $e'), backgroundColor: Colors.red));
content = re.sub(
    r"ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*SnackBar\(\s*content:\s*Text\('Error adding item: \$e'\),\s*backgroundColor:\s*Colors\.red,?\s*\),?\s*\);",
    r"_showTopSnackBar(context, 'Error adding item: $e', isError: true);",
    content
)

# Line 969: ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Barcode not found in database. Please enter manually.'), backgroundColor: Colors.orange));
content = re.sub(
    r"ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*SnackBar\(\s*content:\s*Text\('Barcode not found in database\. Please enter manually\.'\),\s*backgroundColor:\s*Colors\.orange,?\s*\),?\s*\);",
    r"_showTopSnackBar(context, 'Barcode not found in database. Please enter manually.', isError: true);",
    content
)


with open('lib/admin_product_forms.dart', 'w') as f:
    f.write(content)

