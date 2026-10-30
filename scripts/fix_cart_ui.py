import os

filepath = 'lib/cart_screen.dart'
with open(filepath, 'r') as f:
    content = f.read()

# Remove the incorrectly placed method
wrong_start = "  Widget _buildDesktopCart(BuildContext context, CartProvider cartProvider) {"
if wrong_start in content:
    idx = content.find(wrong_start)
    content = content[:idx].rstrip() + "\n"

# Add it before the final closing brace of _CartScreenState
# The class _CartScreenState ends at the very last brace of the file? No, it might not be the very last brace if there are other classes.
# Wait, CartScreen has only CartScreen and _CartScreenState. The last brace IS the end of the class.
# Wait, my regex found the last brace, but the method was outside? No, the last brace was probably the end of the class.

desktop_cart_code = """
  Widget _buildDesktopCart(BuildContext context, CartProvider cartProvider) {
    final cartItems = cartProvider.itemsList;
    final userProvider = Provider.of<UserProvider>(context);
    final double subtotal = cartProvider.cartTotal;
    final double deliveryFee = (subtotal >= _minOrder && subtotal < _freeDeliveryThreshold) ? _deliveryFeeAmount : 0.0;
    final double finalTotal = subtotal + ((subtotal >= _minOrder) ? deliveryFee : 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_cart_outlined, size: 32),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('My Cart', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  Text('Review your items and proceed to checkout', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () {
                  cartProvider.clearCart();
                },
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                label: const Text('Clear Cart', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red.shade100),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT COL
              Expanded(
                flex: 7,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Cart Items (${cartItems.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          TextButton(onPressed: () {}, child: const Text('Continue Shopping →', style: TextStyle(color: AppColors.primaryDark))),
                        ],
                      ),
                      const Divider(),
                      if (cartItems.isEmpty)
                        const Padding(padding: EdgeInsets.all(32), child: Center(child: Text("Cart is empty")))
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: cartItems.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (ctx, i) {
                            final item = cartItems[i];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_box, color: AppColors.primaryDark),
                                  const SizedBox(width: 16),
                                  Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8))),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Text(item.isLoose ? '1 kg' : '1 pc', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Text('₹${item.price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 24),
                                  Container(
                                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                                    child: Row(
                                      children: [
                                        IconButton(icon: const Icon(Icons.remove, size: 16), onPressed: () {
                                            if (item.quantity > 1) {
                                              cartProvider.updateQuantity(item.id, item.quantity - 1);
                                            } else {
                                              cartProvider.removeItem(item.id);
                                            }
                                        }),
                                        Text(item.quantity.toStringAsFixed(0)),
                                        IconButton(icon: const Icon(Icons.add, size: 16), onPressed: () {
                                            cartProvider.updateQuantity(item.id, item.quantity + 1);
                                        }),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  IconButton(
                                    icon: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                                      child: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                    ),
                                    onPressed: () => cartProvider.removeItem(item.id),
                                  )
                                ],
                              ),
                            );
                          },
                        )
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // RIGHT COL
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    // ORDER SUMMARY
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Order Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Subtotal (${cartItems.length} items)', style: TextStyle(color: Colors.grey.shade600)),
                              Text('₹${subtotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Delivery Charges', style: TextStyle(color: Colors.grey.shade600)),
                              Text('₹${deliveryFee.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text('₹${finalTotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: cartItems.isEmpty ? null : () {
                                setState(() { _isCheckout = true; });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF166534),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Proceed to Checkout →', style: TextStyle(color: Colors.white, fontSize: 16)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // DELIVERY INFO
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Delivery Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on, color: AppColors.primaryDark),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Deliver to', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                    Text(userProvider.deliveryAddress.isNotEmpty ? userProvider.deliveryAddress : 'Please select delivery address', style: const TextStyle(fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                              TextButton(onPressed: () {}, child: const Text('Change', style: TextStyle(color: AppColors.primaryDark)))
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              children: [
                                const Icon(Icons.local_shipping, color: Colors.blue),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Estimated Delivery Time', style: TextStyle(color: Colors.blue, fontSize: 11)),
                                    Text('30 - 45 minutes', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
"""

last_brace = content.rfind("}")
content = content[:last_brace] + desktop_cart_code + "\n}\n"

with open(filepath, 'w') as f:
    f.write(content)
print("Fixed cart screen!")
