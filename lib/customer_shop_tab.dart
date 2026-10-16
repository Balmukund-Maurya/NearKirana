import 'package:near_kirana/l10n/app_localizations.dart';
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
import 'wishlist_provider.dart';
import 'animation_helpers.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'widgets/voice_order_sheet.dart';

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
    'Wishlist',
    'Dal',
    'Rice',
    'Spices',
    'Oil',
    'Snacks',
    'Soap',
    'Loose',
  ];

  String? _lastShopId;

  @override
  void initState() {
    super.initState();
    // Fetch categories will be called in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shopId = Provider.of<ShopProvider>(context).currentShopId;
    if (shopId != _lastShopId && shopId != null) {
      _lastShopId = shopId;
      _fetchCategories(shopId);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchCategories(String shopId) async {
    try {
      debugPrint('Fetching categories for shopId: $shopId');
      List<String>? shopCategories;

      if (shopId.isNotEmpty) {
        final shopDoc = await FirebaseUtils.firestore
            .collection('shops')
            .doc(shopId)
            .get();
        if (shopDoc.exists) {
          final data = shopDoc.data()!;
          if (data.containsKey('categories') && data['categories'] != null) {
            shopCategories = List<String>.from(data['categories']);
            debugPrint('Loaded from shop: $shopCategories');
          } else {
            debugPrint('No categories field in shop doc');
          }
        } else {
          debugPrint('Shop doc does not exist');
        }
      }

      if (shopCategories == null || shopCategories.isEmpty) {
        debugPrint('Falling back to app_config');
        final doc = await FirebaseUtils.firestore
            .collection('settings')
            .doc('app_config')
            .get();
        if (doc.exists && doc.data()!['categories'] != null) {
          shopCategories = List<String>.from(doc.data()!['categories']);
          debugPrint('Loaded from app_config: $shopCategories');
        }
      }

      if (shopCategories != null && shopCategories.isNotEmpty) {
        if (mounted) {
          setState(() {
            _categories = ['All', 'Wishlist', ...shopCategories!];
          });
          debugPrint('Updated _categories state: $_categories');
        } else {
          debugPrint('Widget not mounted, skipping setState');
        }
      }
    } catch (e, stack) {
      debugPrint('Error in _fetchCategories: $e\n$stack');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final shopProvider = Provider.of<ShopProvider>(context);
    final langProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          // Custom curved header (Mobile Only)
          if (MediaQuery.of(context).size.width <= 800)
            _buildHeader(context, langProvider, userProvider, shopProvider)
          else
            _buildDesktopHeader(langProvider),
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
                        AppLocalizations.of(context)!.fix_btn,
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

  Widget _buildDesktopHeader(LanguageProvider langProvider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 32, left: 32, right: 32, bottom: 24),
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Browse Products",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Fresh groceries and daily essentials from your neighborhood store",
            style: TextStyle(fontSize: 16, color: AppColors.textMid),
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
    final l10n = AppLocalizations.of(context);
    final userName = userProvider.customerName.isEmpty
        ? 'Guest'
        : userProvider.customerName.split(' ').first;
    final shopName = shopProvider.shopName ?? l10n?.app_name ?? 'NearKirana';
    final addressLabel = userProvider.addressLabel.isNotEmpty
        ? userProvider.addressLabel
        : 'Home';
    final locationText = userProvider.currentLat != null
        ? '${userProvider.customerHouseNo.isNotEmpty ? "${userProvider.customerHouseNo}, " : ""}${userProvider.autoLocality}'
        : 'Tap to add your delivery address';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryDark, Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33047857),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((shopProvider.shopBannerUrl ?? '').isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 85,
                    width: double.infinity,
                    child: Image.network(
                      shopProvider.shopBannerUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.white.withValues(alpha: 0.15),
                        child: const Center(
                          child: Icon(Icons.image_not_supported_rounded, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Top Bar: Fast Delivery ETA & Store Pill + User Greeting
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFFFD54F)),
                          const SizedBox(width: 4),
                          Text(
                            "10-15 MINS",
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFFFD54F),
                              letterSpacing: 0.4,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              color: Colors.white70,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              shopName,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // User greeting pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          userName,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Location Row + Delivery status pill
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () async {
                        double? initialLat = userProvider.currentLat;
                        double? initialLng = userProvider.currentLng;
                        if (initialLat == null || initialLng == null) {
                          bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                          if (!serviceEnabled && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                behavior: SnackBarBehavior.floating,
                                content: Text(
                                  AppLocalizations.of(context)!.please_enable_gps,
                                ),
                              ),
                            );
                            return;
                          }
                          try {
                            Position position = await Geolocator.getCurrentPosition(
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
                      child: Row(
                        children: [
                          Icon(
                            userProvider.addressLabel == 'Home'
                                ? Icons.home_rounded
                                : userProvider.addressLabel == 'Work'
                                    ? Icons.work_rounded
                                    : Icons.location_on_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Delivering to $addressLabel',
                                        style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ],
                                ),
                                Text(
                                  locationText,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Serviceability Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: userProvider.isServiceable
                          ? Colors.white.withValues(alpha: 0.2)
                          : AppColors.error.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: userProvider.isServiceable
                            ? Colors.white.withValues(alpha: 0.35)
                            : Colors.white70,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          userProvider.isServiceable
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          color: userProvider.isServiceable
                              ? const Color(0xFF69F0AE)
                              : Colors.white,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          userProvider.isServiceable ? 'Delivery OK' : 'Out of Range',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Zepto/Blinkit Style Sleek Search Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
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
                    _debounce = Timer(const Duration(milliseconds: 400), () {
                      if (mounted) {
                        setState(() => _searchQuery = value.trim().toLowerCase());
                      }
                    });
                  },
                  decoration: InputDecoration(
                    hintText: "Search 'atta, dal, chips, oil...'",
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.grey.shade400,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.primaryDark,
                      size: 22,
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_searchQuery.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: AppColors.textMid, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              if (_debounce?.isActive ?? false) _debounce!.cancel();
                              setState(() => _searchQuery = '');
                            },
                          ),
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              VoiceOrderSheet.show(
                                context,
                                shopId: shopProvider.currentShopId ?? '',
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppColors.primaryDark.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.mic_rounded,
                                color: AppColors.primaryDark,
                                size: 19,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    isDense: true,
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategories(BuildContext context, LanguageProvider langProvider) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: isDesktop ? 120 : 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 32 : 16,
              vertical: 6,
            ),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              final isSelected = category == _selectedCategory;
              final isWishlist = category == 'Wishlist';
              final l10n = AppLocalizations.of(context)!;
              String displayName = category;
              IconData catIcon = Icons.category_rounded;
              switch (category.toLowerCase()) {
                case 'all':
                  displayName = l10n.cat_all;
                  catIcon = Icons.grid_view_rounded;
                  break;
                case 'wishlist':
                  displayName = 'Wishlist';
                  catIcon = Icons.favorite_rounded;
                  break;
                case 'dal':
                  displayName = l10n.cat_dal;
                  catIcon = Icons.eco_rounded;
                  break;
                case 'rice':
                  displayName = l10n.cat_rice;
                  catIcon = Icons.rice_bowl_rounded;
                  break;
                case 'spices':
                  displayName = l10n.cat_spices;
                  catIcon = Icons.spa_rounded;
                  break;
                case 'oil':
                  displayName = l10n.cat_oil;
                  catIcon = Icons.water_drop_rounded;
                  break;
                case 'snacks':
                  displayName = l10n.cat_snacks;
                  catIcon = Icons.fastfood_rounded;
                  break;
                case 'soap':
                  displayName = l10n.cat_soap;
                  catIcon = Icons.soap_rounded;
                  break;
                case 'loose':
                  displayName = l10n.cat_loose;
                  catIcon = Icons.shopping_bag_rounded;
                  break;
              }

              if (isDesktop) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCategory = category);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 100,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFE8F5E9)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryDark
                              : Colors.grey.shade200,
                          width: isSelected ? 1.5 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            catIcon,
                            color: isSelected
                                ? AppColors.primaryDark
                                : AppColors.textMid,
                            size: 32,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            displayName,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected
                                  ? AppColors.primaryDark
                                  : AppColors.textDark,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return Consumer<WishlistProvider>(
                builder: (context, wishlistProvider, _) {
                  final wishlistCount = wishlistProvider.wishlistItems.length;
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
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryDark
                              : Colors.white,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primaryDark
                                : (isWishlist ? const Color(0xFFFCA5A5) : const Color(0xFFE5E7EB)),
                            width: 1.2,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.primaryDark.withValues(alpha: 0.25),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isWishlist) ...[
                              Icon(
                                Icons.favorite_rounded,
                                size: 14,
                                color: isSelected ? Colors.white : const Color(0xFFEF4444),
                              ),
                              const SizedBox(width: 5),
                            ],
                            Text(
                              isWishlist && wishlistCount > 0
                                  ? '$displayName ($wishlistCount)'
                                  : displayName,
                              style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                color: isSelected
                                    ? Colors.white
                                    : (isWishlist ? const Color(0xFFDC2626) : AppColors.textDark),
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        if (isDesktop) ...[
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        if (_debounce?.isActive ?? false) _debounce!.cancel();
                        _debounce = Timer(
                          const Duration(milliseconds: 300),
                          () {
                            if (mounted) {
                              setState(
                                () => _searchQuery = val.trim().toLowerCase(),
                              );
                            }
                          },
                        );
                      },
                      decoration: InputDecoration(
                        hintText: "Search products...",
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: Colors.grey.shade500,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(
                            Icons.mic_rounded,
                            color: AppColors.primaryDark,
                            size: 22,
                          ),
                          tooltip: AppLocalizations.of(context)?.order_by_voice_btn ?? 'Order by Voice',
                          onPressed: () {
                            final shopProvider = Provider.of<ShopProvider>(context, listen: false);
                            VoiceOrderSheet.show(
                              context,
                              shopId: shopProvider.currentShopId ?? '',
                            );
                          },
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                _buildDesktopFilterDropdown("Sort by", "Popular"),
                const SizedBox(width: 16),
                _buildDesktopFilterDropdown("Brand", "All Brands"),
                const SizedBox(width: 16),
                _buildDesktopFilterDropdown("Price", "All Prices"),
                const Spacer(),
                Container(
                  height: 40,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.grid_view_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: const Icon(
                          Icons.view_list_rounded,
                          color: Colors.grey,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildDesktopFilterDropdown(String label, String value) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          if (label != "Brand" && label != "Price")
            Text(
              "$label: ",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
        ],
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
    final double stock =
        (productData['stock_quantity'] as num?)?.toDouble() ?? 0.0;
    final bool isOutOfStock = stock <= 0;

    final String quantityStr = productData['quantity']?.toString() ?? '';
    final bool isVegetarian = productData['isVegetarian'] ?? true;
    final bool hasVegStatus = productData['isFoodItem'] ?? true;
    final int discount = (productData['discount'] as num?)?.toInt() ?? 0;
    final double? mrp = (productData['mrp'] as num?)?.toDouble() ??
        (discount > 0 ? (price / (1 - (discount / 100))) : null);

    final double? rating =
        (productData['average_rating'] as num?)?.toDouble();
    final int ratingCount =
        (productData['rating_count'] as num?)?.toInt() ?? 0;

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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Image Section
            Expanded(
              flex: 11,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(15),
                      ),
                    ),
                    padding: const EdgeInsets.all(10),
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
                          color: Colors.white.withValues(alpha: 0.65),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(15),
                          ),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F2937),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'OUT OF STOCK',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Top Left: Veg/Non-Veg & Discount
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasVegStatus)
                          Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isVegetarian
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFDC2626),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.circle,
                              color: isVegetarian
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFDC2626),
                              size: 7,
                            ),
                          ),
                        if (discount > 0) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$discount% OFF',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Top Right: Enhanced Wishlist Heart Icon
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Consumer<WishlistProvider>(
                      builder: (context, wishlistProvider, child) {
                        final isInWishlist = wishlistProvider.isInWishlist(id);
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              wishlistProvider.toggleWishlist(id);
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(milliseconds: 2000),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  backgroundColor: isInWishlist
                                      ? AppColors.textDark
                                      : AppColors.primaryDark,
                                  content: Row(
                                    children: [
                                      Icon(
                                        isInWishlist
                                            ? Icons.favorite_border_rounded
                                            : Icons.favorite_rounded,
                                        color: isInWishlist
                                            ? Colors.white70
                                            : Colors.redAccent,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          isInWishlist
                                              ? "Removed from Wishlist"
                                              : "Added to Wishlist ❤️",
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  action: isInWishlist
                                      ? null
                                      : SnackBarAction(
                                          label: "VIEW",
                                          textColor: const Color(0xFFFFD54F),
                                          onPressed: () {
                                            setState(
                                              () => _selectedCategory =
                                                  'Wishlist',
                                            );
                                          },
                                        ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.92),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (child, anim) =>
                                    ScaleTransition(scale: anim, child: child),
                                child: Icon(
                                  isInWishlist
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  key: ValueKey<bool>(isInWishlist),
                                  color: isInWishlist
                                      ? const Color(0xFFE53935)
                                      : Colors.grey.shade400,
                                  size: 17,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Product Details Section
            Expanded(
              flex: 10,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Quick delivery pill or rating badge
                        if (rating != null && ratingCount > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(0xFFFDE68A),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 11,
                                      color: Color(0xFFF59E0B),
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF92400E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '($ratingCount)',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.timer_outlined,
                                size: 11,
                                color: AppColors.primaryDark,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '10-15 mins',
                                style: GoogleFonts.poppins(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 4),
                        // Title
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Quantity / Unit
                        Text(
                          quantityStr.isNotEmpty
                              ? quantityStr
                              : (isLoose ? 'Loose' : ''),
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMid,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),

                    // Price & Cart Controls (Zepto / Blinkit Signature Layout)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Price section
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '₹${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 1)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                              if (discount > 0 && mrp != null)
                                Text(
                                  '₹${mrp.toStringAsFixed(0)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.grey.shade400,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Action / ADD / Stepper Button
                        Consumer<CartProvider>(
                          builder: (context, cartProvider, child) {
                            final cartItem = cartProvider.items[id];
                            final bool isInCart = cartItem != null;

                            if (isOutOfStock) {
                              return Container(
                                height: 32,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'No Stock',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              );
                            }

                            if (!isInCart) {
                              // Zepto Style ADD button
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () {
                                    if (!isServiceable) {
                                      HapticFeedback.heavyImpact();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          behavior: SnackBarBehavior.floating,
                                          content: Text(
                                            AppLocalizations.of(context)!
                                                .error_cant_deliver,
                                          ),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                      return;
                                    }
                                    HapticFeedback.lightImpact();
                                    bool added = cartProvider.addItem(
                                      id,
                                      name,
                                      price,
                                      isLoose,
                                      stock,
                                      imageUrl: imageUrl,
                                    );
                                    if (added) {
                                      SoundService().addToCart();
                                    } else {
                                      HapticFeedback.heavyImpact();
                                      SoundService().blocked();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          behavior: SnackBarBehavior.floating,
                                          content: Text(
                                            AppLocalizations.of(context)!
                                                .qty_exceeds,
                                          ),
                                          backgroundColor: AppColors.error,
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    height: 32,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isServiceable
                                          ? Colors.white
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isServiceable
                                            ? AppColors.primaryDark
                                            : Colors.grey.shade300,
                                        width: 1.2,
                                      ),
                                      boxShadow: isServiceable
                                          ? [
                                              BoxShadow(
                                                color: AppColors.primaryDark
                                                    .withValues(alpha: 0.08),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'ADD',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: isServiceable
                                                ? AppColors.primaryDark
                                                : Colors.grey.shade400,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        Icon(
                                          Icons.add_rounded,
                                          size: 15,
                                          color: isServiceable
                                              ? AppColors.primaryDark
                                              : Colors.grey.shade400,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ).animate().scale(
                                begin: const Offset(0.95, 0.95),
                                end: const Offset(1, 1),
                                duration: 150.ms,
                                curve: Curves.easeOut,
                              );
                            }

                            // Zepto Style Stepper Button
                            return Container(
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.primaryDark,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryDark.withValues(alpha: 0.25),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Minus button
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: const BorderRadius.horizontal(
                                        left: Radius.circular(8),
                                      ),
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        cartProvider.updateQuantity(
                                          id,
                                          isLoose ? -0.5 : -1.0,
                                        );
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 6,
                                        ),
                                        child: Icon(
                                          Icons.remove_rounded,
                                          color: Colors.white,
                                          size: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Quantity text
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: Text(
                                      isLoose
                                          ? cartItem.quantity.toStringAsFixed(1)
                                          : cartItem.quantity.toInt().toString(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  // Plus button
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: const BorderRadius.horizontal(
                                        right: Radius.circular(8),
                                      ),
                                      onTap: () {
                                        if (!isServiceable) {
                                          HapticFeedback.heavyImpact();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              behavior: SnackBarBehavior.floating,
                                              content: Text(
                                                AppLocalizations.of(context)!
                                                    .error_cant_deliver,
                                              ),
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
                                            SnackBar(
                                              behavior: SnackBarBehavior.floating,
                                              content: Text(
                                                AppLocalizations.of(context)!
                                                    .max_stock,
                                              ),
                                              backgroundColor: AppColors.error,
                                              duration: const Duration(seconds: 1),
                                            ),
                                          );
                                        }
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 6,
                                        ),
                                        child: Icon(
                                          Icons.add_rounded,
                                          color: Colors.white,
                                          size: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ).animate().scale(
                              begin: const Offset(0.95, 0.95),
                              end: const Offset(1, 1),
                              duration: 150.ms,
                              curve: Curves.easeOut,
                            );
                          },
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
                            imageUrl: imageUrl,
                          );
                          if (added) {
                            SoundService().addToCart();
                          } else {
                            HapticFeedback.heavyImpact();
                            SoundService().blocked();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                behavior: SnackBarBehavior.floating,
                                content: Text(
                                  AppLocalizations.of(context)!.qty_exceeds,
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
                          AppLocalizations.of(context)!.add,
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
                                  SnackBar(
                                    behavior: SnackBarBehavior.floating,
                                    content: Text(
                                      AppLocalizations.of(context)!.max_stock,
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
      final shopId = Provider.of<ShopProvider>(
        context,
        listen: false,
      ).currentShopId;

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

      if (widget.searchQuery.isNotEmpty) {
        q = q.where('searchKeywords', arrayContains: widget.searchQuery);
      } else {
        if (widget.selectedCategory != 'All') {
          if (widget.selectedCategory == 'Wishlist') {
            final wishlistProvider =
                Provider.of<WishlistProvider>(context, listen: false);
            final wishlistIds = wishlistProvider.wishlistItems;
            if (wishlistIds.isEmpty) {
              if (mounted) {
                setState(() {
                  _products.clear();
                  _isLoading = false;
                  _hasMore = false;
                });
              }
              return;
            }
            if (wishlistIds.length <= 30) {
              q = q.where(FieldPath.documentId, whereIn: wishlistIds);
            }
          } else {
            q = q.where(
              Filter.or(
                Filter('categories', arrayContains: widget.selectedCategory),
                Filter('category', isEqualTo: widget.selectedCategory),
              ),
            );
          }
        } else {
          q = q.orderBy('name');
        }
      }

      q = q.limit(_limit);

      if (_lastDocument != null) {
        q = q.startAfterDocument(_lastDocument!);
      }

      final querySnapshot = await q.get();

      if (querySnapshot.docs.length < _limit ||
          widget.selectedCategory == 'Wishlist') {
        _hasMore = false;
      }

      if (querySnapshot.docs.isNotEmpty) {
        _lastDocument = querySnapshot.docs.last;
        if (widget.selectedCategory == 'Wishlist') {
          final wishlistProvider =
              Provider.of<WishlistProvider>(context, listen: false);
          final wishlistIds = wishlistProvider.wishlistItems;
          final filtered = querySnapshot.docs.where(
            (doc) => wishlistIds.contains(doc.id),
          );
          _products.addAll(filtered);
        } else {
          _products.addAll(querySnapshot.docs);
        }
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
      return const Center(child: ModernLoader(color: Color(0xFF4CAF50)));
    }

    final displayProducts = _products;

    if (displayProducts.isEmpty) {
      if (widget.selectedCategory == 'Wishlist') {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.favorite_rounded,
                    size: 54,
                    color: Colors.red.shade400,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Your Wishlist is Empty",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Explore products and tap the heart icon ❤️ on any item to save it to your wishlist.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.textMid,
                  ),
                ),
              ],
            ),
          ),
        );
      }
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
                    : AppLocalizations.of(context)!.no_product,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 2;
        if (constraints.maxWidth > 1200) {
          crossAxisCount = 5;
        } else if (constraints.maxWidth > 900) {
          crossAxisCount = 4;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 3;
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: GridView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
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

              return widget
                  .buildProductCard(
                    context: context,
                    id: product.id,
                    name: productData['name'] ?? '',
                    price: (productData['price'] as num?)?.toDouble() ?? 0.0,
                    isLoose: productData['is_loose'] ?? false,
                    imageUrl: productData['image_url'],
                    productData: productData,
                    isServiceable: widget.userProvider.isServiceable,
                  )
                  .fadeSlideUp(delay: (index % 10) * 50);
            },
          ),
        );
      },
    );
  }
}
