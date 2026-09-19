import re

files = ['lib/cart_screen.dart', 'lib/my_orders_screen.dart']

for file in files:
    with open(file, 'r') as f:
        content = f.read()

    # Remove const before SnackBar if it contains langProvider
    content = re.sub(r'const\s+(SnackBar\([^)]*langProvider[^)]*\))', r'\1', content)

    with open(file, 'w') as f:
        f.write(content)
