import os

filepath = 'lib/cart_screen.dart'
with open(filepath, 'r') as f:
    content = f.read()

# First, let's find the start of the existing _buildDesktopCart method
start_idx = content.find("Widget _buildDesktopCart(BuildContext context, CartProvider cartProvider) {")
if start_idx == -1:
    print("Method not found!")
    exit(1)

# Find the matching closing brace for this method
brace_count = 0
end_idx = -1
in_method = False

for i in range(start_idx, len(content)):
    if content[i] == '{':
        brace_count += 1
        in_method = True
    elif content[i] == '}':
        brace_count -= 1
        if in_method and brace_count == 0:
            end_idx = i + 1
            break

if end_idx == -1:
    print("Could not find end of method!")
    exit(1)

new_method = """  Widget _buildDesktopCart(BuildContext context, CartProvider cartProvider) {
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
          // HEADER ROW
          Row(
            children: [
              const Icon(Icons.shopping_cart_outlined, size: 36, color: Color(0xFF111827)),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('My Cart', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  Text('Review your items and proceed to checkout', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                ],
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => cartProvider.clearCart(),
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                label: const Text('Clear Cart', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  side: BorderSide(color: Colors.red.shade100, width: 1.5),
                  backgroundColor: Colors.red.shade50.withValues(alpha: 0.3),
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
                child: Column(
                  children: [
                    // CART ITEMS LIST
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Cart Items (${cartItems.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                              TextButton(onPressed: () {}, child: const Text('Continue Shopping →', style: TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.w600))),
                            ],
                          ),
                          const Divider(height: 32),
                          if (cartItems.isEmpty)
                            const Padding(padding: EdgeInsets.all(32), child: Center(child: Text("Cart is empty")))
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: cartItems.length,
                              separatorBuilder: (_, __) => const Divider(height: 32, color: Color(0xFFF3F4F6)),
                              itemBuilder: (ctx, i) {
                                final item = cartItems[i];
                                final hasDiscount = i % 2 == 0;
                                final originalPrice = hasDiscount ? item.price * 1.1 : item.price;
                                
                                return Row(
                                  children: [
                                    Container(
                                      width: 20, height: 20,
                                      decoration: BoxDecoration(color: const Color(0xFF047857), borderRadius: BorderRadius.circular(4)),
                                      child: const Icon(Icons.check, color: Colors.white, size: 14),
                                    ),
                                    const SizedBox(width: 16),
                                    Container(
                                      width: 64, height: 64,
                                      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
                                      child: const Icon(Icons.image, color: Colors.grey),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827))),
                                          const SizedBox(height: 4),
                                          Text(item.isLoose ? '1 kg' : '1 pc', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                          const SizedBox(height: 2),
                                          Text('Sharma Kirana Store', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    if (hasDiscount)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                                        child: const Text('10% OFF', style: TextStyle(color: Color(0xFF166534), fontSize: 10, fontWeight: FontWeight.bold)),
                                      )
                                    else const SizedBox(width: 50),
                                    const SizedBox(width: 24),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('₹${item.price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                                        if (hasDiscount)
                                          Text('₹${originalPrice.toStringAsFixed(0)}', style: TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey.shade400, fontSize: 12)),
                                      ],
                                    ),
                                    const SizedBox(width: 24),
                                    Container(
                                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                                      child: Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove, size: 16), 
                                            onPressed: () {
                                              if (item.quantity > 1) {
                                                cartProvider.updateQuantity(item.id, item.quantity - 1);
                                              } else {
                                                cartProvider.removeItem(item.id);
                                              }
                                            },
                                            padding: const EdgeInsets.all(8), constraints: const BoxConstraints(),
                                          ),
                                          Text(item.quantity.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold)),
                                          IconButton(
                                            icon: const Icon(Icons.add, size: 16), 
                                            onPressed: () => cartProvider.updateQuantity(item.id, item.quantity + 1),
                                            padding: const EdgeInsets.all(8), constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    InkWell(
                                      onTap: () => cartProvider.removeItem(item.id),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                                        child: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                      ),
                                    )
                                  ],
                                );
                              },
                            )
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // SAVED FOR LATER SECTION
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Saved for Later (2)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                              TextButton(onPressed: () {}, child: const Text('View All →', style: TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.w600))),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildSavedItemCard("Aashirvaad Atta", "5 kg", "Sharma Kirana Store", "₹210", "₹230", "9% OFF")),
                              const SizedBox(width: 16),
                              Expanded(child: _buildSavedItemCard("Dettol Soap", "125 g", "Verma Store", "₹45", "", "")),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              
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
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Order Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Subtotal (${cartItems.length} items)', style: TextStyle(color: Colors.grey.shade500)),
                              Text('₹${subtotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text('Delivery Charges ', style: TextStyle(color: Colors.grey.shade500)),
                                  Icon(Icons.info_outline, size: 14, color: Colors.grey.shade400),
                                ],
                              ),
                              Text('₹${deliveryFee.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF111827))),
                                Text('₹${finalTotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF111827))),
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
                                backgroundColor: const Color(0xFF047857),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text('Proceed to Checkout', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward, size: 16, color: Colors.white),
                                ],
                              ),
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
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Delivery Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on, color: Color(0xFF047857), size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Deliver to', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                    const Text('Shivaji Nagar, Bhopal - 462001', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Color(0xFF111827))),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                                child: const Text('Change', style: TextStyle(color: Color(0xFF166534), fontSize: 12, fontWeight: FontWeight.bold)),
                              )
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              children: [
                                const Icon(Icons.local_shipping, color: Colors.blue, size: 20),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Estimated Delivery Time', style: TextStyle(color: Colors.blue, fontSize: 11)),
                                    Text('30 - 45 minutes', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // AVAILABLE OFFERS
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Available Offers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                              TextButton(
                                onPressed: () {}, 
                                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                child: const Text('See All →', style: TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.w600, fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildOfferCard(Icons.local_offer, const Color(0xFFDCFCE7), const Color(0xFF166534), "Get 10% OFF", "On orders above ₹500", const Color(0xFFDCFCE7), const Color(0xFF166534)),
                          const Divider(height: 24),
                          _buildOfferCard(Icons.local_shipping, const Color(0xFFFFEDD5), const Color(0xFFC2410C), "Free Delivery", "On orders above ₹700", const Color(0xFFFFEDD5), const Color(0xFFC2410C)),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    // YOU MIGHT ALSO LIKE
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('You Might Also Like', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                              TextButton(
                                onPressed: () {}, 
                                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                child: const Text('See All →', style: TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.w600, fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildSmallProductCard("Surf Excel", "1 kg", "₹180")),
                              const SizedBox(width: 12),
                              Expanded(child: _buildSmallProductCard("Brooke Bond Tea", "500 g", "₹260")),
                              const SizedBox(width: 12),
                              Expanded(child: _buildSmallProductCard("Colgate Toothpaste", "200 g", "₹105")),
                            ],
                          ),
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

  Widget _buildSavedItemCard(String title, String weight, String shop, String price, String oldPrice, String discount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.grey.shade100, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.image, color: Colors.grey)),
              const Spacer(),
              const Icon(Icons.favorite_border, color: Colors.grey, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827))),
          const SizedBox(height: 2),
          Text(weight, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          const SizedBox(height: 2),
          Text(shop, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(price, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF111827))),
              if (oldPrice.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(oldPrice, style: TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey.shade400, fontSize: 12)),
              ],
              if (discount.isNotEmpty) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                  child: Text(discount, style: const TextStyle(color: Color(0xFF166534), fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ]
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF047857),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text('Move to Cart', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          )
        ],
      ),
    );
  }
  
  Widget _buildOfferCard(IconData icon, Color iconBg, Color iconColor, String title, String subtitle, Color btnBg, Color btnColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827))),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: btnBg, borderRadius: BorderRadius.circular(6)),
          child: Text('Apply', style: TextStyle(color: btnColor, fontWeight: FontWeight.bold, fontSize: 12)),
        )
      ],
    );
  }

  Widget _buildSmallProductCard(String title, String weight, String price) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(alignment: Alignment.topRight, child: const Icon(Icons.favorite_border, color: Colors.grey, size: 14)),
          Center(
            child: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.grey.shade100, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.image, color: Colors.grey, size: 16)),
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF111827)), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(weight, style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(price, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF111827))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF047857), borderRadius: BorderRadius.circular(4)),
                child: const Text('Add', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ],
      ),
    );
  }
"""

content = content[:start_idx] + new_method + content[end_idx:]

with open(filepath, 'w') as f:
    f.write(content)
print("Updated desktop cart view!")
