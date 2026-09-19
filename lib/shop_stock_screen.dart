import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'admin_product_forms.dart';
import 'app_theme.dart';
import 'modern_loader.dart';
import 'shop_provider.dart';
import 'language_provider.dart';
import 'utils/product_image_widget.dart';

class ShopStockScreen extends StatefulWidget {
  const ShopStockScreen({super.key});

  @override
  State<ShopStockScreen> createState() => _ShopStockScreenState();
}

class _ShopStockScreenState extends State<ShopStockScreen> {
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

      Query q = FirebaseFirestore.instance
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
          return _fetchProducts();
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
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(Provider.of<LanguageProvider>(context).translate('shop_stock')),
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
                      activeColor: AppColors.error,
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
                              AdminProductForms.showEditProductDialog(
                                context,
                                product.id,
                              );
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
                                          '${stock.toStringAsFixed(isLoose ? 1 : 0)}',
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
          AdminProductForms.showManualAddProductForm(context);
        },
        backgroundColor: AppColors.primaryDark,
        icon: const Icon(Icons.add_rounded, color: AppColors.white),
        label: const Text('Add Product', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
      ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }
}
