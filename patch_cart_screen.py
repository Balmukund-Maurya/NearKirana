import os

filepath = '/Users/macbook/Desktop/Kirana_Store_Builder/lib/cart_screen.dart'
with open(filepath, 'r') as f:
    content = f.read()

# Replace the build method
old_build_start = "  @override\n  Widget build(BuildContext context) {"
old_build_end = "  Widget _buildCartItem({"

build_body_regex = r"  @override\n  Widget build\(BuildContext context\) \{.*?  Widget _buildCartItem\(\{"
import re

new_build_method = """  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 800) {
          return Scaffold(
             backgroundColor: const Color(0xFFF8F9FA),
             body: Consumer<CartProvider>(
                builder: (context, cartProvider, child) {
                   return _buildDesktopLayout(context, cartProvider);
                },
             ),
          );
        }
        
        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            automaticallyImplyLeading: !widget.isTab,
            title: Text(AppLocalizations.of(context)!.cart_title),
          ),
          body: Consumer<CartProvider>(
            builder: (context, cartProvider, child) {
              final cartItems = cartProvider.itemsList;

              if (cartItems.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Lottie.asset(
                        'assets/lottie/empty_cart.json',
                        width: 250,
                        height: 250,
                        repeat: true,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        AppLocalizations.of(context)!.cart_empty,
                        style: AppTextStyles.heading2(color: AppColors.textMid),
                      ),
                    ],
                  ).animate(onPlay: (c) => c.repeat(reverse: true))
                   .fadeIn(duration: 400.ms)
                   .slideY(begin: 0.1, end: 0)
                   .scaleXY(begin: 1.0, end: 1.05, duration: 1500.ms, curve: Curves.easeInOut),
                );
              }

              return Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: cartItems.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = cartItems[index];
                        return _buildCartItem(
                          id: item.id,
                          name: item.name,
                          price:
                              '₹${item.price} x ${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1)}',
                          quantity: item.quantity,
                          isLoose: item.isLoose,
                          cartProvider: cartProvider,
                          context: context,
                        );
                      },
                    ),
                  ),
                  _buildCheckoutBottomBar(context, cartProvider),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDesktopLayout(BuildContext context, CartProvider cartProvider) {
    final cartItems = cartProvider.itemsList;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
              // Page Header
              Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                    Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                          Text("My Cart", style: AppTextStyles.heading1(color: AppColors.textDark).copyWith(fontSize: 28)),
                          const SizedBox(height: 4),
                          Text("Review your items and proceed to checkout", style: AppTextStyles.bodyMedium(color: AppColors.textMid)),
                       ],
                    ),
                    if (cartItems.isNotEmpty)
                      OutlinedButton.icon(
                         onPressed: () => cartProvider.clearCart(),
                         icon: const Icon(Icons.delete_outline, color: Colors.red),
                         label: const Text("Clear Cart", style: TextStyle(color: Colors.red)),
                         style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFEE2E2)),
                            backgroundColor: const Color(0xFFFEF2F2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                         ),
                      ),
                 ],
              ),
              const SizedBox(height: 32),
              Row(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                    // LEFT: Cart Items
                    Expanded(
                       flex: 7,
                       child: _buildDesktopCartItemsColumn(context, cartProvider),
                    ),
                    const SizedBox(width: 32),
                    // RIGHT: Order Summary
                    SizedBox(
                       width: 360,
                       child: _buildDesktopOrderSummaryColumn(context, cartProvider),
                    ),
                 ],
              ),
           ],
        ),
      ),
    );
  }

  Widget _buildDesktopCartItemsColumn(BuildContext context, CartProvider cartProvider) {
    final cartItems = cartProvider.itemsList;
    return Container(
       padding: const EdgeInsets.all(24),
       decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
             BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
          ],
          border: Border.all(color: Colors.grey.shade200),
       ),
       child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text("Cart Items (${cartItems.length})", style: AppTextStyles.heading2(color: AppColors.textDark)),
                   InkWell(
                      onTap: () {
                         // Fallback logic to go to browse. Since it's tab based on desktop, 
                         // it would require calling the parent callback.
                      },
                      child: Row(
                         children: const [
                            Text("Continue Shopping ", style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold, fontSize: 14)),
                            Icon(Icons.arrow_forward, color: AppColors.primaryDark, size: 16),
                         ],
                      ),
                   ),
                ],
             ),
             const SizedBox(height: 24),
             if (cartItems.isEmpty)
                Center(
                   child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Text("Cart is empty", style: AppTextStyles.bodyMedium(color: AppColors.textMid)),
                   ),
                )
             else
                ListView.separated(
                   shrinkWrap: true,
                   physics: const NeverScrollableScrollPhysics(),
                   itemCount: cartItems.length,
                   separatorBuilder: (context, index) => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(height: 1, color: Color(0xFFF3F4F6)),
                   ),
                   itemBuilder: (context, index) {
                      return _buildDesktopCartItem(context, cartItems[index], cartProvider);
                   },
                ),
          ],
       ),
    );
  }

  Widget _buildDesktopCartItem(BuildContext context, CartItem item, CartProvider cartProvider) {
     return FutureBuilder<DocumentSnapshot>(
        future: FirebaseUtils.firestore.collection('products').doc(item.id).get(),
        builder: (context, snapshot) {
           String? imageUrl;
           double mrp = item.price;
           double discount = 0;
           String weight = item.isLoose ? '1 kg' : '1 pc'; // Default fallback
           String shopName = '';
           
           if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              imageUrl = data['image_url'];
              mrp = (data['mrp'] as num?)?.toDouble() ?? item.price;
              discount = (data['discount'] as num?)?.toDouble() ?? 0.0;
              weight = data['unit'] ?? weight;
           }

           bool hasDiscount = discount > 0 || mrp > item.price;
           
           return Row(
              children: [
                 // Checkbox
                 Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                       color: AppColors.primaryDark,
                       borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.check, size: 14, color: Colors.white),
                 ),
                 const SizedBox(width: 16),
                 // Image
                 Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                       borderRadius: BorderRadius.circular(8),
                       border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ClipRRect(
                       borderRadius: BorderRadius.circular(8),
                       child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.image, color: Colors.grey))
                          : const Icon(Icons.shopping_bag, color: Colors.grey),
                    ),
                 ),
                 const SizedBox(width: 16),
                 // Details
                 Expanded(
                    child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                          Row(
                             children: [
                                Expanded(child: Text(item.name, style: AppTextStyles.bodySemiBold(color: AppColors.textDark))),
                                if (hasDiscount) ...[
                                   const SizedBox(width: 8),
                                   Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                         color: const Color(0xFFDCFCE7),
                                         borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text("${((mrp - item.price) / mrp * 100).toStringAsFixed(0)}% OFF", style: const TextStyle(color: Color(0xFF166534), fontSize: 10, fontWeight: FontWeight.bold)),
                                   ),
                                ]
                             ],
                          ),
                          const SizedBox(height: 4),
                          Text(weight, style: AppTextStyles.captionMedium(color: AppColors.textMid)),
                          const SizedBox(height: 2),
                          if (shopName.isNotEmpty) Text(shopName, style: AppTextStyles.caption(color: AppColors.textLight)),
                       ],
                    ),
                 ),
                 const SizedBox(width: 24),
                 // Price
                 Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                       Text("₹${item.price.toStringAsFixed(0)}", style: AppTextStyles.heading2(color: AppColors.textDark)),
                       if (hasDiscount)
                          Text("₹${mrp.toStringAsFixed(0)}", style: const TextStyle(color: Colors.grey, decoration: TextDecoration.lineThrough, fontSize: 12)),
                    ],
                 ),
                 const SizedBox(width: 24),
                 // Qty
                 Container(
                    decoration: BoxDecoration(
                       border: Border.all(color: Colors.grey.shade300),
                       borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                       children: [
                          InkWell(
                             onTap: () {
                                if (item.quantity <= (item.isLoose ? 0.5 : 1.0)) {
                                   SoundService().removeFromCart();
                                } else {
                                   HapticFeedback.lightImpact();
                                }
                                cartProvider.updateQuantity(item.id, item.isLoose ? -0.5 : -1.0);
                             },
                             child: const Padding(padding: EdgeInsets.all(8.0), child: Icon(Icons.remove, size: 16, color: Colors.grey)),
                          ),
                          Container(
                             width: 32, alignment: Alignment.center,
                             child: Text(item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1), style: AppTextStyles.bodySemiBold(color: AppColors.textDark)),
                          ),
                          InkWell(
                             onTap: () {
                                HapticFeedback.lightImpact();
                                bool updated = cartProvider.updateQuantity(item.id, item.isLoose ? 0.5 : 1.0);
                                if (!updated) {
                                   SoundService().blocked();
                                   ScaffoldMessenger.of(context).showSnackBar(
                                     SnackBar(behavior: SnackBarBehavior.floating, content: Text(AppLocalizations.of(context)!.qty_exceeds), duration: const Duration(seconds: 1), backgroundColor: AppColors.error),
                                   );
                                }
                             },
                             child: const Padding(padding: EdgeInsets.all(8.0), child: Icon(Icons.add, size: 16, color: Colors.grey)),
                          ),
                       ],
                    ),
                 ),
                 const SizedBox(width: 24),
                 // Trash
                 InkWell(
                    onTap: () {
                       cartProvider.removeItem(item.id);
                       SoundService().removeFromCart();
                    },
                    child: Container(
                       padding: const EdgeInsets.all(10),
                       decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                       ),
                       child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    ),
                 ),
              ],
           );
        },
     );
  }

  Widget _buildDesktopOrderSummaryColumn(BuildContext context, CartProvider cartProvider) {
    final userProvider = Provider.of<UserProvider>(context);
    final double subtotal = cartProvider.cartTotal;
    final bool canDeliver = subtotal >= _minOrder;
    final double deliveryFee = (canDeliver && subtotal < _freeDeliveryThreshold)
        ? _deliveryFeeAmount
        : 0.0;
    final double finalTotal = subtotal + (canDeliver ? deliveryFee : 0);

    return Column(
      children: [
        // Order Summary Card
        Container(
           padding: const EdgeInsets.all(24),
           decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                 BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
              ],
              border: Border.all(color: Colors.grey.shade200),
           ),
           child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text("Order Summary", style: AppTextStyles.heading2(color: AppColors.textDark)),
                 const SizedBox(height: 16),
                 Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       Text("Subtotal (${cartProvider.itemsList.length} items)", style: AppTextStyles.bodyMedium(color: AppColors.textMid)),
                       Text("₹$subtotal", style: AppTextStyles.bodySemiBold(color: AppColors.textDark)),
                    ],
                 ),
                 const SizedBox(height: 12),
                 Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       Row(
                          children: const [
                             Text("Delivery Charges ", style: TextStyle(color: AppColors.textMid, fontSize: 14)),
                             Icon(Icons.info_outline, size: 14, color: AppColors.textMid),
                          ],
                       ),
                       Text("₹$deliveryFee", style: AppTextStyles.bodySemiBold(color: AppColors.textDark)),
                    ],
                 ),
                 const SizedBox(height: 16),
                 Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                       color: const Color(0xFFF0FDF4),
                       borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                          Text("Total Amount", style: AppTextStyles.bodySemiBold(color: AppColors.textDark)),
                          Text("₹$finalTotal", style: AppTextStyles.heading2(color: AppColors.primaryDark)),
                       ],
                    ),
                 ),
                 const SizedBox(height: 24),
                 SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                       onPressed: cartProvider.itemsList.isEmpty ? null : () {
                           if (canDeliver && userProvider.isServiceable) {
                               _showCheckoutForm(context, 'Delivery', finalTotal, deliveryFee, cartProvider);
                           } else if (userProvider.isPickupAllowed) {
                               _showCheckoutForm(context, 'Pickup', subtotal, 0.0, cartProvider);
                           } else {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot checkout"), backgroundColor: AppColors.error));
                           }
                       },
                       style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          disabledBackgroundColor: AppColors.bgTint,
                       ),
                       child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                             Text("Proceed to Checkout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                             SizedBox(width: 8),
                             Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                          ],
                       ),
                    ),
                 ),
              ],
           ),
        ),
        
        const SizedBox(height: 24),
        
        // Delivery Information Card
        Container(
           padding: const EdgeInsets.all(24),
           decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                 BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
              ],
              border: Border.all(color: Colors.grey.shade200),
           ),
           child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text("Delivery Information", style: AppTextStyles.heading2(color: AppColors.textDark)),
                 const SizedBox(height: 16),
                 Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       const Icon(Icons.location_on, color: AppColors.primaryDark, size: 24),
                       const SizedBox(width: 12),
                       Expanded(
                          child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                                Row(
                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                   children: [
                                      const Text("Deliver to", style: TextStyle(color: AppColors.textMid, fontSize: 12)),
                                      InkWell(
                                         onTap: () {
                                            Navigator.push(context, MaterialPageRoute(builder: (_) => const MapSelectionScreen()));
                                         },
                                         child: const Text("Change", style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold, fontSize: 12)),
                                      ),
                                   ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                   userProvider.deliveryAddress.isNotEmpty ? userProvider.deliveryAddress : "Please set delivery address",
                                   style: AppTextStyles.bodyMedium(color: AppColors.textDark),
                                   maxLines: 2,
                                   overflow: TextOverflow.ellipsis,
                                ),
                             ],
                          ),
                       ),
                    ],
                 ),
                 const SizedBox(height: 16),
                 Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                       color: Colors.blue.shade50,
                       borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                       children: [
                          const Icon(Icons.local_shipping, color: Colors.blue, size: 20),
                          const SizedBox(width: 12),
                          Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                                const Text("Estimated Delivery Time", style: TextStyle(color: Colors.blue, fontSize: 10)),
                                Text("30 - 45 minutes", style: AppTextStyles.bodySemiBold(color: Colors.blue.shade700)),
                             ],
                          ),
                       ],
                    ),
                 ),
              ],
           ),
        ),
      ],
    );
  }

  Widget _buildCartItem({"""

new_content = re.sub(build_body_regex, new_build_method, content, flags=re.DOTALL)

with open(filepath, 'w') as f:
    f.write(new_content)
print("Updated cart_screen.dart desktop layout")
