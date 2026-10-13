import os
import re

filepath = 'lib/cart_screen.dart'
with open(filepath, 'r') as f:
    content = f.read()

if "import 'desktop_checkout_view.dart';" not in content:
    content = content.replace("import 'package:near_kirana/firebase_utils.dart';", "import 'package:near_kirana/firebase_utils.dart';\nimport 'desktop_checkout_view.dart';")

state_start = "class _CartScreenState extends State<CartScreen> {"
if "bool _isCheckout = false;" not in content:
    content = content.replace(state_start, state_start + "\n  bool _isCheckout = false;\n")

desktop_layout_regex = r"Widget _buildDesktopLayout\(BuildContext context, CartProvider cartProvider\) \{.*?return SingleChildScrollView\("
new_desktop_layout = """Widget _buildDesktopLayout(BuildContext context, CartProvider cartProvider) {
    if (_isCheckout) {
      return DesktopCheckoutView(
        onBackToCart: () => setState(() => _isCheckout = false),
        onOrderPlaced: () {
          setState(() => _isCheckout = false);
          // could pop to home or just clear cart and stay
        },
      );
    }
    final cartItems = cartProvider.itemsList;
    return SingleChildScrollView("""
content = re.sub(desktop_layout_regex, new_desktop_layout, content, flags=re.DOTALL)

old_btn = """                     child: ElevatedButton(
                       onPressed: cartProvider.itemsList.isEmpty ? null : () {
                           if (canDeliver && userProvider.isServiceable) {
                               _showCheckoutForm(context, 'Delivery', finalTotal, deliveryFee, cartProvider);
                           } else if (userProvider.isPickupAllowed) {
                               _showCheckoutForm(context, 'Pickup', subtotal, 0.0, cartProvider);
                           } else {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot checkout"), backgroundColor: AppColors.error));
                           }
                       },"""
new_btn = """                     child: ElevatedButton(
                       onPressed: cartProvider.itemsList.isEmpty ? null : () {
                           setState(() { _isCheckout = true; });
                       },"""
if old_btn in content:
    content = content.replace(old_btn, new_btn)

with open(filepath, 'w') as f:
    f.write(content)
print("Updated cart_screen.dart")
