import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';

import 'package:near_kirana/firebase_utils.dart';
import 'shop_provider.dart';
import 'app_theme.dart';
import 'modern_loader.dart';
import 'cart_provider.dart';
import 'language_provider.dart';
import 'widgets/language_bottom_sheet.dart';
import 'super_admin_screen.dart' as super_admin_screen;
import 'auth_service.dart';

class ShopSelectorScreen extends StatefulWidget {
  const ShopSelectorScreen({super.key});

  @override
  State<ShopSelectorScreen> createState() => _ShopSelectorScreenState();
}

class _ShopSelectorScreenState extends State<ShopSelectorScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Position? _currentPosition;
  int _logoTapCount = 0;

  @override
  void initState() {
    super.initState();
    _loadExistingShop();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      debugPrint("Error fetching location: $e");
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingShop() async {
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);
    await shopProvider.loadCurrentShop();

    if (!mounted) return;
    if (shopProvider.currentShopId != null && shopProvider.currentShopId!.isNotEmpty) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _scanShopQR() async {
    HapticFeedback.mediumImpact();
    final res = await SimpleBarcodeScanner.scanBarcode(
      context,
      isShowFlashIcon: true,
    );

    if (res is String && res.isNotEmpty && res != '-1' && context.mounted) {
      await _verifyAndEnterShop(res);
    }
  }

  Future<void> _verifyAndEnterShop(String shopId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: ModernLoader(color: AppColors.primaryDark),
      ),
    );

    try {
      final shopDoc = await FirebaseUtils.firestore.collection('shops').doc(shopId).get();

      if (!mounted) return;
      Navigator.pop(context);

      if (shopDoc.exists) {
        final data = shopDoc.data() as Map<String, dynamic>;
        final shopName = data['shop_name'] ?? 'Unknown Shop';
        final isActive = data['is_active'] ?? true;
        final address = data['address']?.toString();
        final mobile = data['mobile']?.toString();
        final supportPhone = data['support_phone']?.toString() ?? mobile;
        final bannerUrl = data['banner_image_url']?.toString() ?? data['shop_image_url']?.toString();
        final whatsappTemplate = data['whatsapp_message_template']?.toString();
        final upiId = data['upi_id']?.toString() ?? data['vpa']?.toString();

        if (!isActive) {
          final lang = Provider.of<LanguageProvider>(context, listen: false);
          _showError(
            lang.isHindi
                ? 'यह दुकान अभी प्लेटफॉर्म पर सक्रिय नहीं है।'
                : lang.isHinglish
                    ? 'Yeh dukan abhi platform par active nahi hai.'
                    : 'This store is currently inactive on the platform.',
          );
          return;
        }

        final currentShopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
        if (currentShopId != null && currentShopId != shopId) {
          Provider.of<CartProvider>(context, listen: false).clearCart();
        }

        await Provider.of<ShopProvider>(context, listen: false).setShop(
          shopId,
          shopName,
          address: address,
          mobile: mobile,
          supportPhone: supportPhone,
          bannerUrl: bannerUrl,
          whatsappTemplate: whatsappTemplate,
          upiId: upiId,
        );

        HapticFeedback.heavyImpact();
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        final lang = Provider.of<LanguageProvider>(context, listen: false);
        _showError(
          lang.isHindi
              ? 'दुकान नहीं मिली। कृपया सही QR कोड स्कैन करें।'
              : lang.isHinglish
                  ? 'Dukan nahi mili. Kripya sahi QR Code scan karein.'
                  : 'Store not found. Please scan a valid store QR code.',
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showError('Network error: $e');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);
    final isHindi = langProvider.isHindi;
    final isHinglish = langProvider.isHinglish;

    final deliveryHeader = isHindi
        ? '10-25 मिनट में ताज़ा डिलीवरी'
        : isHinglish
            ? '10-25 Mins me Tez Delivery'
            : 'Delivery in 10-25 Mins';

    final welcomeTitle = isHindi
        ? 'किराना स्टोर चुनें'
        : isHinglish
            ? 'Apni Kirana Dukan Chunein'
            : 'Select Kirana Store';

    final searchHint = isHindi
        ? 'दुकान का नाम या इलाका खोजें...'
        : isHinglish
            ? 'Dukan ka naam ya area search karein...'
            : 'Search store name or area...';

    final scanQrText = isHindi
        ? 'स्टोर का QR कोड स्कैन करें'
        : isHinglish
            ? 'Dukan ka QR Code Scan Karein'
            : 'Scan Store QR Code';

    final nearbyHeader = isHindi
        ? 'आपके नज़दीकी उपलब्ध स्टोर'
        : isHinglish
            ? 'Aapke Paas Ke Stores'
            : 'Stores delivering to your area';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FA),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: CustomScrollView(
              slivers: [
                // Top Zepto/Blinkit Style Header
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top row with delivery tag & language pill
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.primaryDark.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.bolt_rounded,
                                    size: 16,
                                    color: AppColors.primaryDark,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    deliveryHeader,
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const LanguageTogglePill(),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Brand & Super Admin Tap Area
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () async {
                                _logoTapCount++;
                                if (_logoTapCount >= 5) {
                                  _logoTapCount = 0;
                                  final pin = await showDialog<String>(
                                    context: context,
                                    builder: (context) {
                                      final ctrl = TextEditingController();
                                      return AlertDialog(
                                        title: const Text('Super Admin PIN'),
                                        content: TextField(
                                          controller: ctrl,
                                          keyboardType: TextInputType.number,
                                          obscureText: true,
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, ctrl.text),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                  if (pin == '999999') {
                                    await AuthService().elevateToSuperAdmin();
                                    if (context.mounted) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const super_admin_screen.SuperAdminScreen(),
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryDark,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryDark.withValues(alpha: 0.25),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.storefront_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Near',
                                        style: GoogleFonts.outfit(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                      Text(
                                        'Kirana',
                                        style: GoogleFonts.outfit(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    welcomeTitle,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Search Bar
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F5F7),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade300, width: 0.8),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textDark),
                            decoration: InputDecoration(
                              hintText: searchHint,
                              hintStyle: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade500),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: AppColors.primaryDark,
                                size: 22,
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.grey),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Scan QR Button (Zepto Quick Action)
                        InkWell(
                          onTap: _scanShopQR,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.primaryDark.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.primaryDark.withValues(alpha: 0.25),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.qr_code_scanner_rounded,
                                  color: AppColors.primaryDark,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  scanQrText,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Section Title
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          nearbyHeader,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        if (_currentPosition != null)
                          Row(
                            children: [
                              const Icon(Icons.near_me_rounded, size: 12, color: AppColors.primaryDark),
                              const SizedBox(width: 3),
                              Text(
                                isHindi ? 'जीपीएस सक्रिय' : isHinglish ? 'GPS On' : 'GPS Active',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),

                // Store List Stream
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseUtils.firestore
                      .collection('shops')
                      .where('is_active', isEqualTo: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              'Error loading shops: ${snapshot.error}',
                              style: GoogleFonts.outfit(color: AppColors.error),
                            ),
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(48),
                          child: Center(child: ModernLoader(color: AppColors.primaryDark)),
                        ),
                      );
                    }

                    List<QueryDocumentSnapshot> allShops = snapshot.data!.docs;

                    // Filter out non-store docs or specific query
                    if (_searchQuery.isNotEmpty) {
                      allShops = allShops.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = (data['shop_name'] ?? '').toString().toLowerCase();
                        final address = (data['address'] ?? '').toString().toLowerCase();
                        return name.contains(_searchQuery) || address.contains(_searchQuery);
                      }).toList();
                    } else {
                      allShops = allShops.where((doc) {
                        final name = (doc['shop_name'] ?? '').toString();
                        return name.toLowerCase() != 'my shop';
                      }).toList();
                    }

                    // Check radius filtered shops vs all active shops
                    List<QueryDocumentSnapshot> filteredShops = List.from(allShops);
                    bool showingFallback = false;

                    if (_currentPosition != null) {
                      final withinRadius = allShops.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final sLat = (data['store_latitude'] ?? data['lat'] as num?)?.toDouble();
                        final sLng = (data['store_longitude'] ?? data['lng'] as num?)?.toDouble();

                        if (sLat != null && sLng != null) {
                          final dist = Geolocator.distanceBetween(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                            sLat,
                            sLng,
                          );
                          final deliveryRadiusKm = (data['delivery_radius_km'] as num?)?.toDouble() ?? 5.0;
                          final pickupRadiusKm = (data['pickup_radius_km'] as num?)?.toDouble() ?? 25.0;
                          final maxRadiusMeters = (deliveryRadiusKm > pickupRadiusKm ? deliveryRadiusKm : pickupRadiusKm) * 1000;

                          return dist <= maxRadiusMeters;
                        }
                        return false;
                      }).toList();

                      if (withinRadius.isNotEmpty) {
                        filteredShops = withinRadius;
                      } else {
                        // User is outside exact radius or on emulator. Gracefully show all active shops!
                        showingFallback = true;
                      }
                    }

                    // Sort by distance if available, otherwise by creation
                    filteredShops.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;

                      if (_currentPosition != null) {
                        final aLat = (aData['store_latitude'] ?? aData['lat'] as num?)?.toDouble();
                        final aLng = (aData['store_longitude'] ?? aData['lng'] as num?)?.toDouble();
                        final bLat = (bData['store_latitude'] ?? bData['lat'] as num?)?.toDouble();
                        final bLng = (bData['store_longitude'] ?? bData['lng'] as num?)?.toDouble();

                        if (aLat != null && aLng != null && bLat != null && bLng != null) {
                          final distA = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, aLat, aLng);
                          final distB = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, bLat, bLng);
                          return distA.compareTo(distB);
                        }
                      }

                      final aTime = aData['created_at'] as Timestamp?;
                      final bTime = bData['created_at'] as Timestamp?;
                      if (aTime == null && bTime == null) return 0;
                      if (aTime == null) return 1;
                      if (bTime == null) return -1;
                      return bTime.compareTo(aTime);
                    });

                    if (filteredShops.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.all(20),
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.store_mall_directory_outlined,
                                  size: 32,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                isHindi
                                    ? 'कोई दुकान उपलब्ध नहीं है'
                                    : isHinglish
                                        ? 'Koi shop nahi mili'
                                        : 'No shops available right now',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isHindi
                                    ? 'दुकानदार से QR कोड लेकर स्कैन करें या दूसरा सर्च करें।'
                                    : isHinglish
                                        ? 'Dukandar se QR Code lekar scan karein ya dusra search karein.'
                                        : 'Ask your local store for their QR code or try another search term.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index == 0 && showingFallback && _currentPosition != null) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.amber.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline_rounded, color: Colors.amber.shade900, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isHindi
                                            ? 'आपकी लोकेशन के पास सभी उपलब्ध स्टोर्स दिखाए जा रहे हैं:'
                                            : isHinglish
                                                ? 'Aapke area ke sabhi active stores yahan dikh rahe hain:'
                                                : 'Showing all active NearKirana stores available:',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.amber.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final actualIndex = (showingFallback && _currentPosition != null) ? index - 1 : index;
                            if (actualIndex >= filteredShops.length) return null;

                            final shop = filteredShops[actualIndex];
                            final data = shop.data() as Map<String, dynamic>;

                            String? distanceStr;
                            if (_currentPosition != null) {
                              final sLat = (data['store_latitude'] ?? data['lat'] as num?)?.toDouble();
                              final sLng = (data['store_longitude'] ?? data['lng'] as num?)?.toDouble();
                              if (sLat != null && sLng != null) {
                                final dist = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, sLat, sLng);
                                if (dist < 1000) {
                                  distanceStr = '${dist.toStringAsFixed(0)}m';
                                } else {
                                  distanceStr = '${(dist / 1000).toStringAsFixed(1)}km';
                                }
                              }
                            }

                            return _buildZeptoStoreCard(
                              shopId: shop.id,
                              data: data,
                              distanceStr: distanceStr,
                              isHindi: isHindi,
                              isHinglish: isHinglish,
                            );
                          },
                          childCount: filteredShops.length + ((showingFallback && _currentPosition != null) ? 1 : 0),
                        ),
                      ),
                    );
                  },
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 32),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZeptoStoreCard({
    required String shopId,
    required Map<String, dynamic> data,
    required String? distanceStr,
    required bool isHindi,
    required bool isHinglish,
  }) {
    final shopName = (data['shop_name'] ?? 'NearKirana Store').toString();
    final address = (data['address'] ?? 'Local Grocery & Daily Essentials').toString();
    final imageUrl = (data['banner_image_url'] ?? data['shop_image_url'])?.toString();

    final selectButtonText = isHindi
        ? 'दुकान चुनें'
        : isHinglish
            ? 'Select Karein'
            : 'Select Store';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _verifyAndEnterShop(shopId),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Store Avatar / Thumbnail
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primaryDark.withValues(alpha: 0.15)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: (imageUrl != null && imageUrl.startsWith('http'))
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Icon(Icons.storefront_rounded, color: AppColors.primaryDark, size: 28),
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.storefront_rounded, color: AppColors.primaryDark, size: 28),
                        ),
                ),

                const SizedBox(width: 14),

                // Store Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Store Name + Active Dot
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              shopName,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 3),

                      // Address
                      Text(
                        address,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 10),

                      // Zepto style Pill Badges
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          // Delivery Speed Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryDark.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.bolt_rounded,
                                  size: 13,
                                  color: AppColors.primaryDark,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '15-25 min',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Rating Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded, size: 13, color: Colors.amber.shade800),
                                const SizedBox(width: 2),
                                Text(
                                  '4.8',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Distance Badge
                          if (distanceStr != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.near_me_rounded, size: 11, color: Colors.grey.shade700),
                                  const SizedBox(width: 2),
                                  Text(
                                    distanceStr,
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Arrow Action
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            selectButtonText,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 10,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08, end: 0);
  }
}
