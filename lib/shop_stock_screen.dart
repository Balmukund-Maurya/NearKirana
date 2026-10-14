import 'package:near_kirana/l10n/app_localizations.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'admin_product_details_screen.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'modern_loader.dart';
import 'shop_provider.dart';
import 'utils/product_image_widget.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'widgets/admin_top_header.dart';
import 'admin_add_product_screen.dart';
import 'admin_suppliers_screen.dart';
import 'admin_batch_expiry_screen.dart';

class ShopStockScreen extends StatefulWidget {
  const ShopStockScreen({super.key});

  @override
  State<ShopStockScreen> createState() => _ShopStockScreenState();
}

class _ShopStockScreenState extends State<ShopStockScreen> {
  String? _selectedProductBarcode;
  String? _selectedProductName;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final List<DocumentSnapshot> _products = [];
  String _searchQuery = '';
  Timer? _debounce;
  bool _isLoading = false;
  bool _hasMore = true;
  final int _limit = 20;
  DocumentSnapshot? _lastDocument;
  bool _showLowStockOnly = false;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _fetchProducts();
      }
    });
  }

  Future<void> _fetchProducts() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
      if (shopId == null || shopId.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasMore = false;
          });
        }
        return;
      }

      Query q = FirebaseUtils.firestore
          .collection('products')
          .where('shop_id', isEqualTo: shopId);

      if (_searchQuery.isNotEmpty) {
        q = q.where('searchKeywords', arrayContains: _searchQuery);
      } else {
        q = q.orderBy('name');
      }

      q = q.limit(_limit);

      if (_lastDocument != null) {
        q = q.startAfterDocument(_lastDocument!);
      }

      final querySnapshot = await q.get();

      if (querySnapshot.docs.length < _limit) {
        _hasMore = false;
      }

      if (querySnapshot.docs.isNotEmpty) {
        _lastDocument = querySnapshot.docs.last;
        _products.addAll(querySnapshot.docs);
      }

      // FIX-15: Auto-fetch more if low stock filter results in very few visible items
      if (_showLowStockOnly && _hasMore) {
        final lowStockCount = _products.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final stock = (data['stock_quantity'] as num?)?.toDouble() ?? 0.0;
          final isLoose = data['is_loose'] ?? false;
          return stock <= (isLoose ? 2.0 : 5.0);
        }).length;

        // If we found less than 10 low stock items, keep fetching
        if (lowStockCount < 10) {
          _isLoading = false; // Reset to allow next fetch
          return await _fetchProducts();
        }
      }
    } catch (e) {
      debugPrint('Error fetching stock: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refresh() async {
    HapticFeedback.lightImpact();
    setState(() {
      _products.clear();
      _lastDocument = null;
      _hasMore = true;
    });
    await _fetchProducts();
  }

  @override
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
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 800) {
          return _buildDesktopLayout(context);
        }
        return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(AppLocalizations.of(context)!.shop_stock),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminBatchExpiryScreen()),
              ).then((_) => _refresh());
            },
            icon: const Icon(Icons.event_busy_rounded, size: 18),
            label: const Text('Expiry', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminSuppliersScreen()),
              ).then((_) => _refresh());
            },
            icon: const Icon(Icons.local_shipping_rounded, size: 18),
            label: const Text('Purchases', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter & Search Bar
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Low Stock Only',
                      style: AppTextStyles.bodySemiBold(
                        color: AppColors.textDark,
                      ),
                    ),
                    Switch(
                      value: _showLowStockOnly,
                      onChanged: (val) {
                        HapticFeedback.selectionClick();
                        setState(() => _showLowStockOnly = val);
                        // FIX-15: Refresh list when filter is toggled
                        _refresh();
                      },
                      activeThumbColor: AppColors.error,
                      inactiveTrackColor: AppColors.bgTint,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                    _debounce = Timer(const Duration(milliseconds: 500), () {
                      if (mounted) {
                        setState(() => _searchQuery = value.trim().toLowerCase());
                        _refresh();
                      }
                    });
                  },
                  style: AppTextStyles.bodyMedium(color: AppColors.textDark),
                  decoration: InputDecoration(
                    hintText: 'Search inventory...',
                    hintStyle: AppTextStyles.bodyMedium(
                      color: AppColors.textMid,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.primaryDark,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppColors.textMid,
                            ),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              _searchController.clear();
                              if (_debounce?.isActive ?? false) _debounce!.cancel();
                              setState(() => _searchQuery = '');
                              _refresh();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: _products.isEmpty && _isLoading
                ? const Center(
                    child: ModernLoader(color: AppColors.primaryDark,
                    ),
                  )
                : _products.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_rounded,
                          size: 80,
                          color: AppColors.bgTint,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No products found.',
                          style: AppTextStyles.bodySemiBold(
                            color: AppColors.textMid,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _refresh,
                    color: AppColors.primaryDark,
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(
                        top: 12,
                        left: 16,
                        right: 16,
                        bottom: 100,
                      ),
                      itemCount: _products.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _products.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(
                              child: ModernLoader(color: AppColors.primaryDark,
                              ),
                            ),
                          );
                        }

                        final product = _products[index];
                        final data = product.data() as Map<String, dynamic>;
                        final String name = data['name'] ?? 'Unknown';
                        final double stock =
                            (data['stock_quantity'] as num?)?.toDouble() ?? 0.0;
                        final bool isLoose = data['is_loose'] ?? false;
                        final double price =
                            (data['price'] as num?)?.toDouble() ?? 0.0;
                        final String unit = isLoose ? 'kg/L' : 'pc';
                        final String imageUrl = data['image_url'] ?? '';

                        final bool isLowStock = stock <= (isLoose ? 2.0 : 5.0);

                        if (_showLowStockOnly && !isLowStock) {
                          return const SizedBox.shrink();
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isLowStock
                                  ? AppColors.error.withValues(alpha: 0.3)
                                  : AppColors.bgTint,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                                                        onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _selectedProductBarcode = product.id;
                                _selectedProductName = product['name'];
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppColors.bgTint,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isLowStock ? AppColors.error : AppColors.primaryLight,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: imageUrl.isNotEmpty
                                          ? ProductImageWidget(imageUrl: imageUrl, width: 48, height: 48)
                                          : Icon(
                                              isLoose ? Icons.scale_rounded : Icons.inventory_rounded,
                                              color: isLowStock ? AppColors.error : AppColors.primaryDark,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: AppTextStyles.heading2(
                                            color: AppColors.textDark,
                                          ).copyWith(fontSize: 16),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '₹$price / $unit',
                                          style: AppTextStyles.bodyMedium(
                                            color: AppColors.textMid,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isLowStock
                                          ? AppColors.error.withValues(
                                              alpha: 0.1,
                                            )
                                          : AppColors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isLowStock
                                            ? AppColors.error
                                            : AppColors.bgTint,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          'Stock',
                                          style: AppTextStyles.captionMedium(
                                            color: isLowStock
                                                ? AppColors.error
                                                : AppColors.textMid,
                                          ).copyWith(fontSize: 10),
                                        ),
                                        Text(
                                          stock.toStringAsFixed(isLoose ? 1 : 0),
                                          style: AppTextStyles.bodySemiBold(
                                            color: isLowStock
                                                ? AppColors.error
                                                : AppColors.primaryDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ).animate().fadeIn(
                          delay: Duration(milliseconds: 30 * (index % 10)),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_shop_stock_screen',
        onPressed: () {
          HapticFeedback.mediumImpact();
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAddProductScreen())).then((_) => _refresh());
        },
        backgroundColor: AppColors.primaryDark,
        icon: const Icon(Icons.add_rounded, color: AppColors.white),
        label: const Text('Add Product', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
      ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack),
    );
      }
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Column(
      children: [
        const AdminTopHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDesktopPageHeader(),
                const SizedBox(height: 32),
                _buildDesktopSummaryCards(),
                const SizedBox(height: 32),
                _buildDesktopFiltersAndSearch(),
                const SizedBox(height: 24),
                _buildDesktopProductTable(),
                const SizedBox(height: 24),
                _buildDesktopPagination(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopPageHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Products', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 8),
            Text('Manage your products, update stock, prices and more', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAddProductScreen())).then((_) => _refresh());
          },
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Add Product', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF136633),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopSummaryCards() {
    int totalProducts = _products.length;
    int inStock = 0;
    int lowStock = 0;
    int outOfStock = 0;

    for (var doc in _products) {
      final data = doc.data() as Map<String, dynamic>;
      final stock = (data['stock_quantity'] as num?)?.toDouble() ?? 0.0;
      final isLoose = data['is_loose'] ?? false;
      final threshold = isLoose ? 2.0 : 5.0;
      if (stock <= 0) {
        outOfStock++;
      } else if (stock <= threshold) {
        lowStock++;
      } else {
        inStock++;
      }
    }

    return Row(
      children: [
        buildSummaryCard('Total Products', '$totalProducts', Icons.inventory_2_rounded, const Color(0xFF1F9444), const Color(0xFFE8F5E9)),
        const SizedBox(width: 24),
        buildSummaryCard('In Stock', '$inStock', Icons.shopping_cart_rounded, const Color(0xFF007AFF), const Color(0xFFE3F2FD)),
        const SizedBox(width: 24),
        buildSummaryCard('Low Stock', '$lowStock', Icons.warning_rounded, const Color(0xFFFF7B00), const Color(0xFFFFF3E0)),
        const SizedBox(width: 24),
        buildSummaryCard('Out of Stock', '$outOfStock', Icons.block_rounded, const Color(0xFFF04456), const Color(0xFFFFEBEE)),
      ],
    );
  }

  Widget buildSummaryCard(String title, String value, IconData icon, Color color, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text(title, style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopFiltersAndSearch() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                    _debounce = Timer(const Duration(milliseconds: 500), () {
                      if (mounted) {
                        setState(() => _searchQuery = value.trim().toLowerCase());
                        _refresh();
                      }
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search products by name, category, or brand...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                    prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.filter_list_rounded, color: Colors.grey.shade600),
                  const SizedBox(width: 12),
                  Text('Filters', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            buildDropdownFilter('All Categories'),
            const SizedBox(width: 16),
            buildDropdownFilter('All Status'),
            const SizedBox(width: 16),
            buildDropdownFilter('All Stock Levels'),
            const SizedBox(width: 16),
            buildDropdownFilter('Sort by Name'),
          ],
        ),
      ],
    );
  }

  Widget buildDropdownFilter(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: TextStyle(color: Colors.grey.shade800, fontSize: 14)),
          const SizedBox(width: 32),
          Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade600, size: 20),
        ],
      ),
    );
  }

  Widget _buildDesktopProductTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 24, child: Icon(Icons.check_box_outline_blank, color: Colors.grey, size: 20)),
                const SizedBox(width: 24),
                Expanded(flex: 3, child: Text('Product', style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Category', style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Price', style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('Stock', style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('Status', style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.bold))),
                SizedBox(width: 100, child: Text('Actions', style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
              ],
            ),
          ),
          // Table Body
          if (_isLoading && _products.isEmpty)
            const Padding(padding: EdgeInsets.all(48), child: ModernLoader(color: Color(0xFF136633)))
          else if (_products.isEmpty)
            const Padding(padding: EdgeInsets.all(48), child: Text('No products found.', style: TextStyle(color: Colors.grey)))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _products.length,
              separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
              itemBuilder: (context, index) {
                final doc = _products[index];
                final data = doc.data() as Map<String, dynamic>;
                
                final name = data['name'] ?? 'Unknown';
                final barcode = data['barcode'] ?? doc.id;
                final imageUrl = data['image_url'];
                final quantity = data['quantity']?.toString() ?? '';
                final isLoose = data['is_loose'] ?? false;
                final unit = isLoose ? 'kg' : 'pcs';
                final price = data['price']?.toString() ?? '0';
                final originalPrice = data['mrp']?.toString();
                final stock = (data['stock_quantity'] as num?)?.toDouble() ?? 0.0;
                final categories = data['categories'] as List<dynamic>? ?? [];
                final primaryCategory = categories.isNotEmpty ? categories.first.toString() : 'Other';

                // Status logic
                final threshold = isLoose ? 2.0 : 5.0;
                String status = 'In Stock';
                Color statusColor = const Color(0xFF1F9444);
                Color statusBg = const Color(0xFFE8F5E9);
                if (stock <= 0) {
                  status = 'Out of Stock';
                  statusColor = const Color(0xFFF04456);
                  statusBg = const Color(0xFFFFEBEE);
                } else if (stock <= threshold) {
                  status = 'Low Stock';
                  statusColor = const Color(0xFFFF7B00);
                  statusBg = const Color(0xFFFFF3E0);
                }

                // Discount logic
                String? discountBadge;
                if (originalPrice != null && originalPrice.isNotEmpty) {
                  final p = double.tryParse(price) ?? 0;
                  final m = double.tryParse(originalPrice) ?? 0;
                  if (m > p && m > 0) {
                    final off = ((m - p) / m * 100).round();
                    discountBadge = '$off% OFF';
                  }
                }

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedProductBarcode = barcode;
                      _selectedProductName = name;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      const SizedBox(width: 24, child: Icon(Icons.check_box_outline_blank, color: Colors.grey, size: 20)),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: ProductImageWidget(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  Text('$quantity $unit', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(6)),
                            child: Text(primaryCategory, style: TextStyle(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.w500)),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            Text('₹$price', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            if (originalPrice != null && discountBadge != null) ...[
                              const SizedBox(width: 8),
                              Text('₹$originalPrice', style: TextStyle(color: Colors.grey.shade400, decoration: TextDecoration.lineThrough, fontSize: 13)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(4)),
                                child: Text(discountBadge, style: const TextStyle(color: Color(0xFF1F9444), fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(isLoose ? stock.toStringAsFixed(1) : stock.toInt().toString(), style: TextStyle(color: Colors.grey.shade800, fontSize: 14)),
                      ),
                      Expanded(
                        flex: 1,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                            child: Text(status, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            InkWell(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminAddProductScreen(barcode: barcode))).then((_) => _refresh()),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
                                child: Icon(Icons.edit_outlined, size: 18, color: Colors.grey.shade700),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _showDeleteConfirmation(context, barcode, name),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: const Color(0xFFFFF1F1), border: Border.all(color: const Color(0xFFFFE4E4)), borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFF04456)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String barcode, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Handle delete
              FirebaseUtils.firestore.collection('products').doc(barcode).delete().then((_) {
                if (context.mounted) {
                  _refresh();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Product deleted successfully')),
                  );
                }
              }).catchError((e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: $e')),
                  );
                }
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF04456)),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopPagination() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Showing 1 to ${_products.length} products', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
        Row(
          children: [
            buildPaginationButton(Icons.chevron_left_rounded),
            const SizedBox(width: 8),
            buildPaginationPage('1', true),
            const SizedBox(width: 8),
            buildPaginationPage('2', false),
            const SizedBox(width: 8),
            buildPaginationPage('3', false),
            const SizedBox(width: 8),
            Text('...', style: TextStyle(color: Colors.grey.shade400)),
            const SizedBox(width: 8),
            buildPaginationPage('15', false),
            const SizedBox(width: 8),
            buildPaginationButton(Icons.chevron_right_rounded),
          ],
        ),
      ],
    );
  }

  Widget buildPaginationButton(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Icon(icon, color: Colors.grey.shade700, size: 18),
    );
  }

  Widget buildPaginationPage(String page, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF136633) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isActive ? const Color(0xFF136633) : Colors.grey.shade200),
      ),
      child: Text(page, style: TextStyle(color: isActive ? Colors.white : Colors.grey.shade700, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
    );
  }

}
