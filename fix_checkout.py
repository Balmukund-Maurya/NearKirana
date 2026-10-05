import os

filepath = 'lib/desktop_checkout_view.dart'
with open(filepath, 'r') as f:
    content = f.read()

content = content.replace("item.shopId", "")
content = content.replace("import 'firebase_utils.dart';", "import 'firebase_utils.dart';\nimport 'shop_provider.dart';")
content = content.replace("String shopId = cartProvider.itemsList.first.shopId;", "String shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId ?? '';")
content = content.replace("'shop_id': ,", "")

with open(filepath, 'w') as f:
    f.write(content)
print("Updated desktop_checkout_view.dart")
