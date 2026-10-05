import os

filepath = 'lib/cart_screen.dart'
with open(filepath, 'r') as f:
    content = f.read()

# Replace the delivery button's logic
target = """                            _showCheckoutForm(
                              context,
                              'Delivery',
                              finalTotal,
                              deliveryFee,
                              cartProvider,
                            );"""
replacement = "                            setState(() { _isCheckout = true; });"
content = content.replace(target, replacement)

# Replace pickup button's logic
target2 = """                        _showCheckoutForm(
                          context,
                          'Pickup',
                          subtotal,
                          0.0,
                          cartProvider,
                        );"""
replacement2 = "                        setState(() { _isCheckout = true; });"
content = content.replace(target2, replacement2)

with open(filepath, 'w') as f:
    f.write(content)
print("Wired buttons!")
