import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'utils/product_image_widget.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'cart_provider.dart';
import 'language_provider.dart';
import 'user_provider.dart';
import 'app_theme.dart';
import 'sound_service.dart';
import 'map_selection_screen.dart';
import 'modern_loader.dart';
import 'shop_provider.dart';
import 'animation_helpers.dart';

class CustomerShopTab extends StatefulWidget {
  const CustomerShopTab({super.key});

  @override
  State<CustomerShopTab> createState() => _CustomerShopTabState();
}

class _CustomerShopTabState extends State<CustomerShopTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;
  String _selectedCategory = 'All';
  List<String> _categories = [
    'All',
    'Dal',
    'Rice',
    'Spices',
    'Oil',
    'Snacks',
    'Soap',
    'Loose',
  ];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    try {
      // FIX-1: Unified collection path — settings/app_config
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('app_config')
          .get();
      if (doc.exists && doc.data()!['categories'] != null) {
        if (mounted) {
          setState(() {
            _categories = [
              'All',
              ...List<String>.from(doc.data()!['categories']),
            ];
          });
        }
      }
    } catch (e) {
      // Keep default
    }
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final shopProvider = Provider.of<ShopProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          // Custom curved header
          _buildHeader(context, langProvider, userProvider, shopProvider),
          // Category chips
          _buildCategories(context, langProvider),
          // Out of service banner
          if (!userProvider.isServiceable)
            Container(
              width: double.infinity,
              color: AppColors.error.withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_off_outlined,
                    color: AppColors.error,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      userProvider.serviceabilityError ??
                          'Delivery not available in your area',
                      style: AppTextStyles.captionMedium(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                  if ((userProvider.serviceabilityError ?? '').contains(
                        'permission',
                      ) ||
                      (userProvider.serviceabilityError ?? '').contains(
                        'disabled',
                      )) ...[
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        if ((userProvider.serviceabilityError ?? '').contains(
                          'permission',
                        )) {
                          await Geolocator.openAppSettings();
                        } else {
                          await Geolocator.openLocationSettings();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.white,
                        foregroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        langProvider.translate('fix_btn'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  IconButton(
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: AppColors.error,
                      size: 18,
                    ),
                    onPressed: () => userProvider.checkServiceability(),
                    tooltip: 'Check Again',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          // Product grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: ProductGrid(
                searchQuery: _searchQuery,
                selectedCategory: _selectedCategory,
                buildProductCard: _buildProductCard,
                userProvider: userProvider,
                langProvider: langProvider,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    LanguageProvider langProvider,
    UserProvider userProvider,
    ShopProvider shopProvider,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, Color(0xFF4A9D3F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((shopProvider.shopBannerUrl ?? '').isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 90,
                        width: double.infinity,
                        child: Image.network(
                          shopProvider.shopBannerUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: AppColors.white.withValues(alpha: 0.2),
                            child: const Center(child: Icon(Icons.image_not_supported_rounded, color: Colors.white)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Top Row: Brand & Greeting
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        langProvider.translate('app_name'),
                        style: AppTextStyles.heading1(
                          color: AppColors.white,
                        ).copyWith(fontSize: 22),
                      ),
                      Text(
                        '${langProvider.translate('greeting') == 'greeting' ? 'Namaste' : langProvider.translate('greeting')}, ${userProvider.customerName.isEmpty ? 'Guest' : userProvider.customerName.split(' ').first}',
                        style: AppTextStyles.bodyMedium(
                          color: AppColors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Bottom Row: Location Selector & Delivery Pill
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            double? initialLat = userProvider.currentLat;
                            double? initialLng = userProvider.currentLng;
                            if (initialLat == null || initialLng == null) {
                              bool serviceEnabled =
                                  await Geolocator.isLocationServiceEnabled();
                              if (!serviceEnabled && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(behavior: SnackBarBehavior.floating, content: Text(langProvider.translate('please_enable_gps')),
                                  ),
                                );
                                return;
                              }
                              try {
                                Position position =
                                    await Geolocator.getCurrentPosition(
                                      locationSettings: const LocationSettings(
                                        accuracy: LocationAccuracy.low,
                                        timeLimit: Duration(seconds: 10),
                                      ),
                                    );
                                initialLat = position.latitude;
                                initialLng = position.longitude;
                              } catch (e) {
                                initialLat = userProvider.storeLat ?? 0.0;
                                initialLng = userProvider.storeLng ?? 0.0;
                              }
                            }
                            if (!context.mounted) return;
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MapSelectionScreen(
                                  initialLat: initialLat ?? 0.0,
                                  initialLng: initialLng ?? 0.0,
                                ),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    userProvider.addressLabel == 'Home'
                                        ? Icons.home_rounded
                                        : userProvider.addressLabel == 'Work'
                                        ? Icons.work_rounded
                                        : Icons.location_on_rounded,
                                    color: AppColors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      userProvider.addressLabel.isNotEmpty
                                          ? 'Delivering to ${userProvider.addressLabel}'
                                          : 'Select Location',
                                      style: AppTextStyles.heading2(
                                        color: AppColors.white,
                                      ).copyWith(fontSize: 16),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_drop_down_rounded,
                                    color: AppColors.white,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                userProvider.currentLat != null
                                    ? '${userProvider.customerHouseNo.isNotEmpty ? "${userProvider.customerHouseNo}, " : ""}${userProvider.autoLocality}'
                                    : 'Tap to add your delivery address',
                                style: AppTextStyles.caption(
                                  color: AppColors.white.withValues(alpha: 0.9),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Delivery status pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: userProvider.isServiceable
                              ? AppColors.primaryLight.withValues(alpha: 0.25)
                              : AppColors.error.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: userProvider.isServiceable
                                ? AppColors.primaryLight
                                : AppColors.accentPink,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              userProvider.isServiceable
                                  ? Icons.local_shipping_outlined
                                  : Icons.location_off_outlined,
                              color: AppColors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              userProvider.isServiceable
                                  ? 'Delivery OK'
                                  : 'Out of Range',
                              style: AppTextStyles.caption(
                                color: AppColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Search bar
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    HapticFeedback.selectionClick();
                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                    _debounce = Timer(const Duration(milliseconds: 500), () {
                      if (mounted) {
                        setState(() => _searchQuery = value.trim().toLowerCase());
                      }
                    });
                  },
                  decoration: InputDecoration(
                    hintText: langProvider.translate('search_hint'),
                    hintStyle: AppTextStyles.body(color: AppColors.textLight),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.primaryDark,
                      size: 22,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppColors.textMid,
                              size: 20,
                            ),
                        onPressed: () {
                              _searchController.clear();
                              if (_debounce?.isActive ?? false) _debounce!.cancel();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 4,
                    ),
                    isDense: true,
                  ),
                  style: AppTextStyles.bodyMedium(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategories(BuildContext context, LanguageProvider langProvider) {
    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;
          final displayName =
              langProvider.translate('cat_${category.toLowerCase()}') ==
                  'cat_${category.toLowerCase()}'
              ? category
              : langProvider.translate('cat_${category.toLowerCase()}');
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedCategory = category);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryDark : AppColors.white,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryDark
                        : AppColors.bgTint,
                    width: 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primaryDark.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  displayName,
                  style: AppTextStyles.captionMedium(
                    color: isSelected ? AppColors.white : AppColors.textMid,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductCard({
    required BuildContext context,
    required String id,
    required String name,
    required double price,
    required bool isLoose,
    String? imageUrl,
    required Map<String, dynamic> productData,
    required bool isServiceable,
  }) {
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    final double stock =
        (productData['stock_quantity'] as num?)?.toDouble() ?? 0.0;
    final bool isOutOfStock = stock <= 0;

    final String quantityStr = productData['quantity']?.toString() ?? '';
    final bool isVegetarian = productData['isVegetarian'] ?? true;
    final bool hasVegStatus = productData['isFoodItem'] ?? true;

    return GestureDetector(
      onTap: isOutOfStock
          ? null
          : () => _showProductDetails(
              context,
              id,
              name,
              price,
              isLoose,
              imageUrl,
              productData,
            ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.bgTint, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            Expanded(
              flex: 11, // Increased to give image more space and reduce empty text gap
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(18.5),
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Center(
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? ProductImageWidget(
                              imageUrl: imageUrl,
                              fit: BoxFit.contain,
                            )
                          : const Icon(
                              Icons.image_not_supported_rounded,
                              color: AppColors.textLight,
                              size: 40,
                            ),
                    ),
                  ),

                  // Out of Stock Badge
                  if (isOutOfStock)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.6),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(18.5),
                          ),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.textDark,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'OUT OF STOCK',
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Veg / Non-Veg Indicator
                  if (hasVegStatus)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isVegetarian
                                ? AppColors.primaryDark
                                : AppColors.error,
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.circle,
                          color: isVegetarian
                              ? AppColors.primaryDark
                              : AppColors.error,
                          size: 8,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Details Section
            Expanded(
              flex: 9, // Reduced to compress the space between text and buttons
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySemiBold(
                            color: AppColors.textDark,
                          ).copyWith(height: 1.2, fontSize: 13),
                        ),
                        if (quantityStr.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            quantityStr,
                            style: AppTextStyles.captionMedium(
                              color: AppColors.textMid,
                            ),
                          ),
                        ],
                      ],
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: FittedBox(
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '₹$price',
                              style: AppTextStyles.heading2(
                                color: AppColors.primaryDark,
                              ).copyWith(fontSize: 15),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),

                        // Cart Controls
                        Expanded(
                          child: Consumer<CartProvider>(
                          builder: (context, cartProvider, child) {
                            final cartItem = cartProvider.items[id];
                            final bool isInCart = cartItem != null;

                            if (isOutOfStock) {
                              return Container(
                                height: 32,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: AppColors.bgTint,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'No Stock',
                                  style: AppTextStyles.captionMedium(
                                    color: AppColors.textMid,
                                  ),
                                ),
                              );
                            }

                            if (!isInCart) {
                              return SizedBox(
                                height: 32,
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (!isServiceable) {
                                      HapticFeedback.heavyImpact();
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(behavior: SnackBarBehavior.floating, content: Text(
                                            langProvider.translate('error_cant_deliver'),
                                        ),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                      return;
                                    }
                                    bool added = cartProvider.addItem(
                                      id,
                                      name,
                                      price,
                                      isLoose,
                                      stock,
                                    );
                                    if (added) {
                                      SoundService().addToCart();
                                    } else {
                                      HapticFeedback.heavyImpact();
                                      SoundService().blocked();
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(behavior: SnackBarBehavior.floating, content: Text(
                                            langProvider.translate(
                                              'qty_exceeds',
                                            ),
                                          ),
                                          backgroundColor: AppColors.error,
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isServiceable
                                        ? AppColors.primaryLight.withValues(
                                            alpha: 0.15,
                                          )
                                        : AppColors.textLight.withValues(
                                            alpha: 0.15,
                                          ),
                                    foregroundColor: isServiceable
                                        ? AppColors.primaryDark
                                        : AppColors.textMid,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(
                                        color: isServiceable
                                            ? AppColors.primaryLight
                                            : AppColors.textLight,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      langProvider.translate('add'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ).animate().scale(
                                begin: const Offset(0.95, 0.95),
                                end: const Offset(1, 1),
                                duration: 200.ms,
                                curve: Curves.easeOut,
                              );
                            }

                            // Plus/Minus Controls
                            return Container(
                              height: 32,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppColors.primaryDark,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryDark.withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          cartProvider.updateQuantity(
                                            id,
                                            isLoose ? -0.5 : -1.0,
                                          );
                                        },
                                        child: const Center(
                                          child: Icon(Icons.remove_rounded, color: AppColors.white, size: 16),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      color: AppColors.white.withValues(
                                        alpha: 0.15,
                                      ),
                                      alignment: Alignment.center,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          isLoose
                                              ? cartItem.quantity.toStringAsFixed(1)
                                              : cartItem.quantity
                                                    .toInt()
                                                    .toString(),
                                          style: AppTextStyles.bodySemiBold(
                                            color: AppColors.white,
                                          ).copyWith(fontSize: 13),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                        onTap: () {
                                          if (!isServiceable) {
                                            HapticFeedback.heavyImpact();
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(behavior: SnackBarBehavior.floating, content: Text(langProvider.translate('error_cant_deliver')),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                            return;
                                          }
                                          HapticFeedback.lightImpact();
                                          bool updated = cartProvider.updateQuantity(
                                            id,
                                            isLoose ? 0.5 : 1.0,
                                          );
                                          if (!updated) {
                                            SoundService().blocked();
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(behavior: SnackBarBehavior.floating, content: Text(
                                                  langProvider.translate('max_stock'),
                                                ),
                                                backgroundColor: AppColors.error,
                                                duration: const Duration(seconds: 1),
                                              ),
                                            );
                                          }
                                        },
                                        child: const Center(
                                          child: Icon(Icons.add_rounded, color: AppColors.white, size: 16),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ).animate().scale(
                              begin: const Offset(0.95, 0.95),
                              end: const Offset(1, 1),
                              duration: 200.ms,
                              curve: Curves.easeOut,
                            );
                          },
                        ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProductDetails(
    BuildContext context,
    String id,
    String name,
    double price,
    bool isLoose,
    String? imageUrl,
    Map<String, dynamic> productData,
  ) {
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    final String brand = productData['brand'] ?? '';
    final String quantity = productData['quantity'] ?? '';
    final String ingredients = productData['ingredients'] ?? '';
    final bool isVegetarian =
        productData['isVegetarian'] ?? true; // Default to Veg
    final bool hasVegStatus = productData['isFoodItem'] ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Header
              Container(
                height: 320,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? ProductImageWidget(
                              imageUrl: imageUrl,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: 320,
                            )
                          : const Icon(
                              Icons.image_not_supported_rounded,
                              size: 80,
                              color: AppColors.textLight,
                            ),
                    ),
                    Positioned(
                      top: 16,
                      right: 16,
                      child: IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textMid,
                          size: 30,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    if (hasVegStatus)
                      Positioned(
                        top: 20,
                        left: 20,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isVegetarian
                                  ? AppColors.success
                                  : AppColors.error,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.circle,
                            color: isVegetarian
                                ? AppColors.success
                                : AppColors.error,
                            size: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Product Info
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (brand.isNotEmpty)
                        Text(
                          brand.toUpperCase(),
                          style:
                              AppTextStyles.captionMedium(
                                color: AppColors.accentPink,
                              ).copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        name,
                        style: AppTextStyles.heading1(
                          color: AppColors.textDark,
                        ).copyWith(fontSize: 22),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹$price',
                        style: AppTextStyles.heading2(
                          color: AppColors.primaryDark,
                        ).copyWith(fontSize: 24),
                      ),
                      const SizedBox(height: 20),
                      const Divider(color: AppColors.bgTint),
                      const SizedBox(height: 10),
                      if (quantity.isNotEmpty) ...[
                        _buildDetailRow('Quantity/Weight:', quantity),
                        const SizedBox(height: 10),
                      ],
                      if (ingredients.isNotEmpty) ...[
                        Text(
                          'Ingredients',
                          style: AppTextStyles.heading2(
                            color: AppColors.textDark,
                          ).copyWith(fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ingredients,
                          style: AppTextStyles.bodyMedium(
                            color: AppColors.textMid,
                          ).copyWith(height: 1.5, fontSize: 14),
                        ),
                      ] else ...[
                        Text(
                          'No detailed information available for this product.',
                          style: AppTextStyles.bodyMedium(
                            color: AppColors.textLight,
                          ).copyWith(fontStyle: FontStyle.italic, fontSize: 14),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Bottom Add to Cart Bar
              Container(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: 16 + MediaQuery.of(context).padding.bottom,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      offset: const Offset(0, -4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Consumer<CartProvider>(
                  builder: (context, cartProvider, child) {
                    final cartItem = cartProvider.items[id];
                    final bool isInCart = cartItem != null;
                    final double stock =
                        (productData['stock_quantity'] as num?)?.toDouble() ??
                        0.0;
                    final bool isOutOfStock = stock <= 0;

                    if (isOutOfStock) {
                      return ElevatedButton(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.textLight,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Out of Stock',
                          style: AppTextStyles.button(color: AppColors.white),
                        ),
                      );
                    }

                    if (!isInCart) {
                      return ElevatedButton(
                        onPressed: () {
                          bool added = cartProvider.addItem(
                            id,
                            name,
                            price,
                            isLoose,
                            stock,
                          );
                          if (added) {
                            SoundService().addToCart();
                          } else {
                            HapticFeedback.heavyImpact();
                            SoundService().blocked();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(behavior: SnackBarBehavior.floating, content: Text(
                                  langProvider.translate('qty_exceeds'),
                                ),
                                backgroundColor: AppColors.error,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          langProvider.translate('add'),
                          style: AppTextStyles.button(color: AppColors.white),
                        ),
                      );
                    }

                    // Plus/Minus Controls
                    return Container(
                      height: 55,
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.remove_rounded,
                              color: AppColors.white,
                              size: 24,
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              cartProvider.updateQuantity(
                                id,
                                isLoose ? -0.5 : -1.0,
                              );
                            },
                          ),
                          Text(
                            isLoose
                                ? cartItem.quantity.toStringAsFixed(1)
                                : cartItem.quantity.toInt().toString(),
                            style: AppTextStyles.heading2(
                              color: AppColors.white,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.add_rounded,
                              color: AppColors.white,
                              size: 24,
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              bool updated = cartProvider.updateQuantity(
                                id,
                                isLoose ? 0.5 : 1.0,
                              );
                              if (!updated) {
                                SoundService().blocked();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(behavior: SnackBarBehavior.floating, content: Text(
                                      langProvider.translate('max_stock'),
                                    ),
                                    backgroundColor: AppColors.error,
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySemiBold(
            color: AppColors.textDark,
          ).copyWith(fontSize: 14),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.bodyMedium(
              color: AppColors.textMid,
            ).copyWith(fontSize: 14),
          ),
        ),
      ],
    );
  }
}

class ProductGrid extends StatefulWidget {
  final String searchQuery;
  final String selectedCategory;
  final Widget Function({
    required BuildContext context,
    required String id,
    required String name,
    required double price,
    required bool isLoose,
    String? imageUrl,
    required Map<String, dynamic> productData,
    required bool isServiceable,
  })
  buildProductCard;
  final UserProvider userProvider;
  final LanguageProvider langProvider;

  const ProductGrid({
    super.key,
    this.searchQuery = '',
    this.selectedCategory = 'All',
    required this.buildProductCard,
    required this.userProvider,
    required this.langProvider,
  });

  @override
  State<ProductGrid> createState() => _ProductGridState();
}

class _ProductGridState extends State<ProductGrid> {
  final ScrollController _scrollController = ScrollController();
  final List<DocumentSnapshot> _products = [];
  bool _isLoading = false;
  bool _hasMore = true;
  final int _limit = 20;
  DocumentSnapshot? _lastDocument;

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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ProductGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery ||
        oldWidget.selectedCategory != widget.selectedCategory) {
      _refresh();
    }
  }

  Future<void> _fetchProducts() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

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

      if (widget.searchQuery.isNotEmpty) {
        q = q.where('searchKeywords', arrayContains: widget.searchQuery);
      } else {
        if (widget.selectedCategory != 'All') {
          q = q.where(
            Filter.or(
              Filter('categories', arrayContains: widget.selectedCategory),
              Filter('category', isEqualTo: widget.selectedCategory),
            ),
          );
        } else {
          q = q.orderBy('name');
        }
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
    } catch (e) {
      debugPrint('Error fetching products: $e');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _products.clear();
      _lastDocument = null;
      _hasMore = true;
    });
    await _fetchProducts();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _products.isEmpty) {
      return const Center(
        child: ModernLoader(color: Color(0xFF4CAF50)),
      );
    }

    final displayProducts = _products;

    if (displayProducts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                widget.searchQuery.isNotEmpty
                    ? "We couldn't find any items matching '${widget.searchQuery}'."
                    : widget.langProvider.translate('no_product'),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: GridView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16.0,
          mainAxisSpacing: 16.0,
          mainAxisExtent:
              280, // Fixed height for every card to prevent layout breaking
        ),
        itemCount: displayProducts.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == displayProducts.length) {
            return const Center(child: ModernLoader());
          }

          final product = displayProducts[index];
          final productData = product.data() as Map<String, dynamic>;

          return widget.buildProductCard(
            context: context,
            id: product.id,
            name: productData['name'] ?? '',
            price: (productData['price'] as num?)?.toDouble() ?? 0.0,
            isLoose: productData['is_loose'] ?? false,
            imageUrl: productData['image_url'],
            productData: productData,
            isServiceable: widget.userProvider.isServiceable,
          ).fadeSlideUp(delay: (index % 10) * 50);
        },
      ),
    );
  }
}
