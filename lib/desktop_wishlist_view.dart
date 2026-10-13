import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:near_kirana/app_theme.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:near_kirana/shop_provider.dart';
import 'package:near_kirana/user_provider.dart';
import 'package:near_kirana/cart_provider.dart';
import 'package:near_kirana/wishlist_provider.dart';
import 'package:near_kirana/utils/product_image_widget.dart';
import 'package:provider/provider.dart';

class DesktopWishlistView extends StatefulWidget {
  final Function(int) onNavigate;
  const DesktopWishlistView({super.key, required this.onNavigate});

  @override
  State<DesktopWishlistView> createState() => _DesktopWishlistViewState();
}

class _DesktopWishlistViewState extends State<DesktopWishlistView> {
  bool _isLoading = true;
  List<DocumentSnapshot> _wishlistProducts = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchWishlistProducts();
  }

  Future<void> _fetchWishlistProducts() async {
    setState(() => _isLoading = true);
    try {
      final shopProvider = Provider.of<ShopProvider>(context, listen: false);
      final wishlistProvider = Provider.of<WishlistProvider>(context, listen: false);
      final shopId = shopProvider.currentShopId;
      
      if (shopId == null || wishlistProvider.wishlistItems.isEmpty) {
        if (mounted) {
          setState(() {
            _wishlistProducts = [];
            _isLoading = false;
          });
        }
        return;
      }

      // Fetch products in chunks if necessary, but since it's a simple query we fetch all matching
      // Firestore 'whereIn' supports max 10 items. So we chunk it.
      final List<DocumentSnapshot> products = [];
      final itemIds = wishlistProvider.wishlistItems;
      
      for (var i = 0; i < itemIds.length; i += 10) {
        final end = (i + 10 < itemIds.length) ? i + 10 : itemIds.length;
        final chunk = itemIds.sublist(i, end);
        
        final querySnapshot = await FirebaseUtils.firestore
            .collection('products')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
            
        // Only keep products from the current shop
        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          if (data['shop_id'] == shopId) {
            products.add(doc);
          }
        }
      }

      if (mounted) {
        setState(() {
          _wishlistProducts = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching wishlist: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _removeProduct(String productId) {
    Provider.of<WishlistProvider>(context, listen: false).toggleWishlist(productId);
    setState(() {
      _wishlistProducts.removeWhere((doc) => doc.id == productId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7F9FC),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatsRow(),
                        const SizedBox(height: 24),
                        _buildToolbar(),
                        const SizedBox(height: 24),
                        _buildProductGrid(),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 320,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(left: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMyCartPanel(),
                        const SizedBox(height: 24),
                        _buildPromoCard(),
                        const SizedBox(height: 16),
                        _buildContinueShoppingCard(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 32, left: 32, right: 32, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "My Wishlist",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Save your favorite products and shop them anytime",
            style: TextStyle(fontSize: 16, color: AppColors.textMid),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    int inStock = 0;
    int lowStock = 0;
    int outOfStock = 0;
    
    for (var doc in _wishlistProducts) {
      final data = doc.data() as Map<String, dynamic>;
      final stock = (data['stock'] as num?)?.toInt() ?? 0;
      final inStockBool = data['inStock'] as bool? ?? true;
      
      if (!inStockBool || stock == 0) {
        outOfStock++;
      } else if (stock <= 5 && stock > 0) {
        lowStock++;
      } else {
        inStock++;
      }
    }

    return Row(
      children: [
        _buildStatCard(
          icon: Icons.favorite_border_rounded,
          count: _wishlistProducts.length,
          label: "Wishlist Items",
          color: const Color(0xFFE8F5E9),
          iconColor: const Color(0xFF2E7D32),
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          icon: Icons.inventory_2_outlined,
          count: inStock,
          label: "In Stock",
          color: const Color(0xFFE3F2FD),
          iconColor: const Color(0xFF1565C0),
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          icon: Icons.error_outline_rounded,
          count: lowStock,
          label: "Low Stock",
          color: const Color(0xFFFFF3E0),
          iconColor: const Color(0xFFE65100),
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          icon: Icons.remove_shopping_cart_outlined,
          count: outOfStock,
          label: "Out of Stock",
          color: const Color(0xFFFFEBEE),
          iconColor: const Color(0xFFC62828),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required int count,
    required String label,
    required Color color,
    required Color iconColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: iconColor,
                    height: 1.1,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: iconColor.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: const InputDecoration(
                hintText: 'Search in wishlist...',
                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        const Spacer(),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              const Icon(Icons.swap_vert_rounded, color: Colors.grey, size: 20),
              const SizedBox(width: 8),
              const Text("Sort by: Recently Added", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
              const SizedBox(width: 8),
              const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey, size: 20),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.grid_view_rounded, color: AppColors.primaryDark),
                onPressed: () {},
                splashRadius: 20,
              ),
              IconButton(
                icon: const Icon(Icons.list_rounded, color: Colors.grey),
                onPressed: () {},
                splashRadius: 20,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductGrid() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(60),
          child: CircularProgressIndicator(color: AppColors.primaryDark),
        ),
      );
    }

    final filteredProducts = _wishlistProducts.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['name'] as String?)?.toLowerCase() ?? '';
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    if (filteredProducts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(80),
          child: Column(
            children: [
              const Icon(Icons.favorite_border_rounded, size: 80, color: Colors.grey),
              const SizedBox(height: 24),
              const Text(
                "My Wishlist is Empty",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              const SizedBox(height: 8),
              const Text(
                "Save products you love and find them here later.",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => widget.onNavigate(0),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text("Browse Products", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 3;
        if (constraints.maxWidth > 1200) crossAxisCount = 4;
        else if (constraints.maxWidth < 900) crossAxisCount = 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.72,
          ),
          itemCount: filteredProducts.length,
          itemBuilder: (context, index) {
            return _buildWishlistCard(filteredProducts[index]);
          },
        );
      },
    );
  }

  Widget _buildWishlistCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Unknown';
    final price = (data['price'] as num?)?.toDouble() ?? 0.0;
    final mrp = (data['mrp'] as num?)?.toDouble() ?? 0.0;
    final imageUrl = data['imageUrl'] as String?;
    final quantityStr = data['quantity'] ?? '';
    
    final stock = (data['stock'] as num?)?.toInt() ?? 0;
    final inStockBool = data['inStock'] as bool? ?? true;
    final isAvailable = inStockBool && stock > 0;
    final isLowStock = isAvailable && stock <= 5;
    
    final discountPercent = mrp > price ? ((mrp - price) / mrp * 100).round() : 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (discountPercent > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "$discountPercent% OFF",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  )
                else
                  const SizedBox(),
                InkWell(
                  onTap: () => _removeProduct(doc.id),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: AppColors.error,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Center(
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? ProductImageWidget(imageUrl: imageUrl, fit: BoxFit.contain)
                    : const Icon(Icons.image_not_supported_rounded, color: Colors.grey, size: 48),
              ),
            ),
          ),
          
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (quantityStr.toString().isNotEmpty)
                    Text(
                      quantityStr.toString(),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        "₹$price",
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppColors.textDark,
                        ),
                      ),
                      if (mrp > price) ...[
                        const SizedBox(width: 8),
                        Text(
                          "₹$mrp",
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            decoration: TextDecoration.lineThrough,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isAvailable
                              ? (isLowStock ? Colors.orange : AppColors.primaryDark)
                              : AppColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isAvailable
                            ? (isLowStock ? "Low Stock" : "In Stock")
                            : "Out of Stock",
                        style: TextStyle(
                          fontSize: 12,
                          color: isAvailable
                              ? (isLowStock ? Colors.orange.shade800 : AppColors.primaryDark)
                              : AppColors.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isAvailable
                          ? () {
                              final cartProvider = Provider.of<CartProvider>(context, listen: false);
                              cartProvider.addItem(
                                doc.id,
                                name,
                                price,
                                data['isLoose'] ?? false,
                                (data['stock'] as num?)?.toDouble() ?? 0.0,
                                imageUrl: imageUrl,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Added to cart'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.shopping_cart_outlined, size: 16),
                      label: const Text("Add to Cart", style: TextStyle(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyCartPanel() {
    final cartProvider = Provider.of<CartProvider>(context);
    final items = cartProvider.itemsList;
    final total = cartProvider.cartTotal;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "My Cart (${items.length})",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                InkWell(
                  onTap: () {
                    // This could open full cart view if there is one
                  },
                  child: Row(
                    children: const [
                      Text(
                        "View Cart",
                        style: TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.primaryDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  "Your cart is empty",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length > 3 ? 3 : items.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F9FC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: (item.imageUrl?.isNotEmpty ?? false)
                            ? ProductImageWidget(imageUrl: item.imageUrl!)
                            : const Icon(Icons.image_not_supported_rounded, color: Colors.grey, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "₹${item.price.toInt()}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item.isLoose ? item.quantity : item.quantity.toInt()} ${item.isLoose ? 'kg' : 'units'}',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          if (item.quantity > 1) {
                                            cartProvider.setQuantity(item.id, item.quantity - 1);
                                          } else {
                                            cartProvider.removeItem(item.id);
                                          }
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          child: Icon(Icons.remove, size: 14),
                                        ),
                                      ),
                                      Text("${item.quantity}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                      InkWell(
                                        onTap: () {
                                          cartProvider.setQuantity(item.id, item.quantity + 1);
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          child: Icon(Icons.add, size: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                InkWell(
                                  onTap: () => cartProvider.removeItem(item.id),
                                  child: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 18),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          if (items.length > 3)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
              ),
              child: Center(
                child: Text(
                  "+ ${items.length - 3} more items",
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFF4FBF7),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Total Amount",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      "₹${total.toInt()}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: items.isEmpty ? null : () {},
                    icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 18),
                    label: const Text("Place Order", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCFCE7)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.primaryDark,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.percent_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Special Offers for You",
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark, fontSize: 13),
                ),
                Text(
                  "Get exclusive offers on your favourite products",
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.textDark),
        ],
      ),
    );
  }

  Widget _buildContinueShoppingCard() {
    return InkWell(
      onTap: () => widget.onNavigate(0),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFF8F9FA),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shopping_bag_outlined, color: AppColors.textDark, size: 16),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Continue Shopping",
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark, fontSize: 13),
                  ),
                  Text(
                    "Browse more products",
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.textDark),
          ],
        ),
      ),
    );
  }
}
