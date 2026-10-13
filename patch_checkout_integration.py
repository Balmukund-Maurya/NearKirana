import os
import re

filepath = 'lib/cart_screen.dart'
with open(filepath, 'r') as f:
    content = f.read()

# Add import if missing
if "import 'desktop_checkout_view.dart';" not in content:
    content = content.replace("import 'package:near_kirana/firebase_utils.dart';", "import 'package:near_kirana/firebase_utils.dart';\nimport 'desktop_checkout_view.dart';")

# Add state variable
state_start = "class _CartScreenState extends State<CartScreen> {"
if "bool _isCheckout = false;" not in content:
    content = content.replace(state_start, state_start + "\n  bool _isCheckout = false;\n")

# Modify build method to check for _isCheckout
build_start = "  @override\n  Widget build(BuildContext context) {"
if "if (_isCheckout) {" not in content:
    new_build_start = """  @override
  Widget build(BuildContext context) {
    if (_isCheckout) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: DesktopCheckoutView(
          onBackToCart: () => setState(() => _isCheckout = false),
          onOrderPlaced: () {
            setState(() => _isCheckout = false);
          },
        ),
      );
    }
"""
    content = content.replace(build_start, new_build_start)

# Modify button to trigger checkout
old_btn_regex = r"onPressed:\s*cartProvider\.itemsList\.isEmpty\s*\?\s*null\s*:\s*\(\)\s*\{\s*if\s*\(canDeliver\s*&&\s*userProvider\.isServiceable\)\s*\{\s*_showCheckoutForm\(context,\s*'Delivery',\s*finalTotal,\s*deliveryFee,\s*cartProvider\);\s*\}\s*else\s*if\s*\(userProvider\.isPickupAllowed\)\s*\{\s*_showCheckoutForm\(context,\s*'Pickup',\s*subtotal,\s*0\.0,\s*cartProvider\);\s*\}\s*else\s*\{\s*ScaffoldMessenger\.of\(context\)\.showSnackBar\(const\s*SnackBar\(content:\s*Text\(\"Cannot checkout\"\),\s*backgroundColor:\s*AppColors\.error\)\);\s*\}\s*\},"
new_btn = """onPressed: cartProvider.itemsList.isEmpty ? null : () {
                           setState(() { _isCheckout = true; });
                       },"""
content = re.sub(old_btn_regex, new_btn, content)

with open(filepath, 'w') as f:
    f.write(content)
print("Patched cart_screen.dart to render Checkout view")
