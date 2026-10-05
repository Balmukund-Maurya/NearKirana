import os
import re

filepath = '/Users/macbook/Desktop/Kirana_Store_Builder/lib/shop_stock_screen.dart'
with open(filepath, 'r') as f:
    content = f.read()

# 1. Add import
if "import 'admin_product_details_screen.dart';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'admin_product_details_screen.dart';")

# 2. Add state variables
if "String? _selectedProductBarcode;" not in content:
    content = content.replace(
        "class _ShopStockScreenState extends State<ShopStockScreen> {",
        "class _ShopStockScreenState extends State<ShopStockScreen> {\n  String? _selectedProductBarcode;\n  String? _selectedProductName;\n"
    )

# 3. Update build method
build_method = """  @override
  Widget build(BuildContext context) {
    if (_selectedProductBarcode != null) {
      return AdminProductDetailsScreen(
        barcode: _selectedProductBarcode!,
        productName: _selectedProductName ?? 'Product',
        onBack: () => setState(() {
          _selectedProductBarcode = null;
          _selectedProductName = null;
        }),
      );
    }"""
if "_selectedProductBarcode != null" not in content:
    content = content.replace("  @override\n  Widget build(BuildContext context) {", build_method)

# 4. Update Desktop row onTap
desktop_row = """                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedProductBarcode = barcode;
                      _selectedProductName = name;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),"""
content = content.replace(
    """                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),""",
    desktop_row
)

# Replace the end of the return statement for the list item builder
content = content.replace(
    """                  ),
                );
              },
            ),""",
    """                  ),
                ),
                );
              },
            ),"""
)

# 5. Update mobile onTap
mobile_ontap = """                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _selectedProductBarcode = product.id;
                                _selectedProductName = product['name'];
                              });
                            },"""
content = re.sub(
    r"onTap:\s*\(\)\s*\{\s*HapticFeedback\.lightImpact\(\);\s*AdminProductForms\.showEditProductDialog\(\s*context,\s*product\.id,\s*\);\s*\},",
    mobile_ontap,
    content
)

with open(filepath, 'w') as f:
    f.write(content)
print("Updated shop_stock_screen.dart")
