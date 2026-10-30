import os
path = '/Users/macbook/Desktop/Kirana_Store_Builder/lib/admin_product_forms.dart'
with open(path, 'r') as f:
    content = f.read()

import re

# Match .collection('settings').doc('app_config') with any indentation
content = re.sub(
    r"\.collection\('settings'\)\s*\.doc\('app_config'\)",
    r".collection('shops').doc(Provider.of<ShopProvider>(context, listen: false).currentShopId ?? 'app_config')",
    content
)

with open(path, 'w') as f:
    f.write(content)

