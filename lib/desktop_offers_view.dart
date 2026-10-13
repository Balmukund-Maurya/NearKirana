import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:near_kirana/app_theme.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:near_kirana/shop_provider.dart';
import 'package:near_kirana/user_provider.dart';
import 'package:near_kirana/utils/product_image_widget.dart';
import 'package:provider/provider.dart';
import 'package:near_kirana/l10n/app_localizations.dart';

class DesktopOffersView extends StatefulWidget {
  final Function(int) onNavigate;
  const DesktopOffersView({super.key, required this.onNavigate});

  @override
  State<DesktopOffersView> createState() => _DesktopOffersViewState();
}

class _DesktopOffersViewState extends State<DesktopOffersView> {
  final ScrollController _scrollController = ScrollController();
  List<DocumentSnapshot> _allOffers = [];
  List<DocumentSnapshot> _filteredOffers = [];
  List<DocumentSnapshot> _hotDeals = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  List<String> _categories = ['All'];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _fetchOffers();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final shopProvider = Provider.of<ShopProvider>(context, listen: false);
      final shopId = shopProvider.currentShopId;
      if (shopId == null) return;

      List<String>? shopCategories;
      final shopDoc = await FirebaseUtils.firestore
          .collection('shops')
          .doc(shopId)
          .get();
      if (shopDoc.exists && shopDoc.data()!['categories'] != null) {
        shopCategories = List<String>.from(shopDoc.data()!['categories']);
      } else {
        final doc = await FirebaseUtils.firestore
            .collection('settings')
            .doc('app_config')
            .get();
        if (doc.exists && doc.data()!['categories'] != null) {
          shopCategories = List<String>.from(doc.data()!['categories']);
        }
      }

      if (shopCategories != null && shopCategories.isNotEmpty) {
        if (mounted) {
          setState(() {
            _categories = ['All', ...shopCategories!];
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading categories for offers: $e');
    }
  }

  Future<void> _fetchOffers() async {
    setState(() => _isLoading = true);
    try {
      final shopId = Provider.of<ShopProvider>(
        context,
        listen: false,
      ).currentShopId;
      if (shopId == null || shopId.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final querySnapshot = await FirebaseUtils.firestore
          .collection('products')
          .where('shop_id', isEqualTo: shopId)
          .get();

      final List<DocumentSnapshot> offers = [];
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final price = (data['price'] as num?)?.toDouble() ?? 0.0;
        final mrp = (data['mrp'] as num?)?.toDouble() ?? 0.0;
        if (mrp > price && price > 0) {
          offers.add(doc);
        }
      }

      offers.sort((a, b) {
        final dataA = a.data() as Map<String, dynamic>;
        final dataB = b.data() as Map<String, dynamic>;
        final pA = (dataA['price'] as num?)?.toDouble() ?? 0.0;
        final mA = (dataA['mrp'] as num?)?.toDouble() ?? 0.0;
        final pB = (dataB['price'] as num?)?.toDouble() ?? 0.0;
        final mB = (dataB['mrp'] as num?)?.toDouble() ?? 0.0;

        final dA = ((mA - pA) / mA);
        final dB = ((mB - pB) / mB);
        return dB.compareTo(dA);
      });

      if (mounted) {
        setState(() {
          _allOffers = offers;
          _hotDeals = offers.take(4).toList();
          _isLoading = false;
        });
        _filterOffers();
      }
    } catch (e) {
      debugPrint('Error fetching offers: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterOffers() {
    if (_selectedCategory == 'All') {
      _filteredOffers = List.from(_allOffers);
    } else {
      _filteredOffers = _allOffers.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final cats = data['categories'] as List<dynamic>? ?? [];
        return cats.contains(_selectedCategory);
      }).toList();
    }
    setState(() {});
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
                  flex: 3,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroBanner(),
                        const SizedBox(height: 32),
                        _buildCategoryFilters(),
                        const SizedBox(height: 24),
                        _buildOffersGrid(),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 320,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      left: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [_buildHotDeals()],
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
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Offers & Discounts",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Save more on your daily essentials",
            style: TextStyle(fontSize: 16, color: AppColors.textMid),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBanner() {
    final shopProvider = Provider.of<ShopProvider>(context);
    final bannerUrl = shopProvider.shopBannerUrl;

    if (bannerUrl == null || bannerUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      height: 240,
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        image: DecorationImage(
          image: NetworkImage(bannerUrl),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedCategory = category);
                _filterOffers();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryDark : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryDark
                        : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textDark,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOffersGrid() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: AppColors.primaryDark),
        ),
      );
    }

    if (_filteredOffers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(
                Icons.local_offer_outlined,
                size: 64,
                color: AppColors.textLight,
              ),
              const SizedBox(height: 16),
              Text(
                "No offers available right now.",
                style: AppTextStyles.heading2(color: AppColors.textMid),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Available Offers (${_filteredOffers.length})",
              style: AppTextStyles.heading2(color: AppColors.textDark),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Text(
                    "Sort by: Latest",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "Grab the best deals and save on your favorite products",
          style: TextStyle(color: AppColors.textMid, fontSize: 14),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = 2;
            if (constraints.maxWidth > 1200)
              crossAxisCount = 4;
            else if (constraints.maxWidth > 800)
              crossAxisCount = 3;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: _filteredOffers.length,
              itemBuilder: (context, index) {
                final doc = _filteredOffers[index];
                return _buildOfferCard(doc);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildOfferCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Unknown';
    final price = (data['price'] as num?)?.toDouble() ?? 0.0;
    final mrp = (data['mrp'] as num?)?.toDouble() ?? 0.0;
    final imageUrl = data['imageUrl'] as String?;

    final discountPercent = ((mrp - price) / mrp * 100).round();

    // Assign a soft background color for visual variation (optional, like reference)
    final bgColors = [
      const Color(0xFFFFF0F0),
      const Color(0xFFF0FFF4),
      const Color(0xFFFFF9F0),
      const Color(0xFFF0F4FF),
    ];
    final colorIndex = doc.id.hashCode % bgColors.length;

    return Container(
      decoration: BoxDecoration(
        color: bgColors[colorIndex],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Badges
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "UP TO $discountPercent% OFF",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    Expanded(
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ProductImageWidget(
                            imageUrl: imageUrl,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    )
                  else
                    const Expanded(
                      child: Center(
                        child: Icon(
                          Icons.image_not_supported_rounded,
                          color: Colors.grey,
                          size: 40,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 140,
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onNavigate(0); // Navigate to Browse Products
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Shop Now",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 14),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: AppColors.textMid,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "Valid till stock lasts",
                      style: TextStyle(fontSize: 11, color: AppColors.textMid),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHotDeals() {
    if (_isLoading) return const SizedBox.shrink();
    if (_hotDeals.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: AppColors.error,
                ),
                const SizedBox(width: 8),
                Text(
                  "Hot Deals",
                  style: AppTextStyles.heading2(color: AppColors.textDark),
                ),
              ],
            ),
            const Text(
              "View All →",
              style: TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._hotDeals.map((doc) => _buildHotDealItem(doc)),
      ],
    );
  }

  Widget _buildHotDealItem(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Unknown';
    final price = (data['price'] as num?)?.toDouble() ?? 0.0;
    final mrp = (data['mrp'] as num?)?.toDouble() ?? 0.0;
    final quantity = data['quantity'] ?? '';
    final imageUrl = data['imageUrl'] as String?;

    final discountPercent = ((mrp - price) / mrp * 100).round();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? ProductImageWidget(imageUrl: imageUrl)
                : const Icon(
                    Icons.image_not_supported_rounded,
                    color: Colors.grey,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (quantity.toString().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    quantity.toString(),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      "$discountPercent% OFF",
                      style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      "₹$price",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "₹$mrp",
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        decoration: TextDecoration.lineThrough,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 12,
                      color: AppColors.textLight,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
