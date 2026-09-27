import 'package:near_kirana/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'shop_provider.dart';
import 'app_theme.dart';
import 'modern_loader.dart';
import 'cart_provider.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:geolocator/geolocator.dart';
import 'super_admin_screen.dart' as super_admin_screen;

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
          _showError('Yeh dukan abhi platform par active nahi hai.');
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
        _showError('Dukan nahi mili. Kripya sahi QR Code scan karein.');
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = AppLocalizations.of(context)!;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom - 48,
                maxWidth: 450,
              ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
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
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('OK')),
                                ],
                              );
                            }
                          );
                          if (pin == '999999') {
                            if (context.mounted) {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const super_admin_screen.SuperAdminScreen()));
                            }
                          }
                        }
                      },
                      child: Icon(
                        Icons.storefront_rounded,
                        size: 80,
                        color: AppColors.primaryDark,
                      )
                          .animate()
                          .fadeIn(duration: 600.ms)
                          .scale(curve: Curves.easeOutBack),
                    ),
                const SizedBox(height: 12),
                Text(
                  langProvider.welcome_title,
                  style: AppTextStyles.heading1(color: AppColors.textDark).copyWith(fontSize: 28),
                  textAlign: TextAlign.center,
                )
                    .animate()
                    .fadeIn(delay: 200.ms)
                    .slideY(begin: 0.2, end: 0),
                const SizedBox(height: 8),
                Text(
                  langProvider.search_shop_subtitle,
                  style: AppTextStyles.bodyMedium(color: AppColors.textMid),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 300.ms),
                const SizedBox(height: 20),
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: langProvider.search_shop_hint,
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryDark),
                    filled: true,
                    fillColor: AppColors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ).animate().fadeIn(delay: 400.ms),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _scanShopQR,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: Text(AppLocalizations.of(context)!.scan_shop_qr),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: AppColors.primaryDark, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ).animate().fadeIn(delay: 500.ms),
                const SizedBox(height: 20),
                StreamBuilder<QuerySnapshot>(
                        stream: FirebaseUtils.firestore
                            .collection('shops')
                            .where('is_active', isEqualTo: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return SizedBox(
                              height: 180,
                              child: Center(child: Text('Error: ${snapshot.error}')),
                            );
                          }
                          if (!snapshot.hasData) {
                            return const SizedBox(
                              height: 180,
                              child: Center(child: ModernLoader()),
                            );
                          }

                          List<QueryDocumentSnapshot> shops = snapshot.data!.docs;

                          if (_searchQuery.isEmpty) {
                            shops = shops.where((doc) {
                              final name = (doc['shop_name'] ?? '').toString();
                              return name.toLowerCase() != 'my shop';
                            }).toList();
                          } else {
                            shops = shops.where((doc) {
                              final name = (doc['shop_name'] ?? '').toString().toLowerCase();
                              return name.contains(_searchQuery);
                            }).toList();
                          }

                          if (_currentPosition != null) {
                            shops = shops.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final sLat = (data['store_latitude'] ?? data['lat'] as num?)?.toDouble();
                              final sLng = (data['store_longitude'] ?? data['lng'] as num?)?.toDouble();
                              
                              if (sLat != null && sLng != null) {
                                final dist = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, sLat, sLng);
                                final deliveryRadiusKm = (data['delivery_radius_km'] as num?)?.toDouble() ?? 5.0;
                                final pickupRadiusKm = (data['pickup_radius_km'] as num?)?.toDouble() ?? 25.0;
                                final maxRadiusMeters = (deliveryRadiusKm > pickupRadiusKm ? deliveryRadiusKm : pickupRadiusKm) * 1000;
                                
                                return dist <= maxRadiusMeters;
                              }
                              return true;
                            }).toList();
                          }

                          shops.sort((a, b) {
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

                          if (_searchQuery.isEmpty) {
                            shops = shops.take(5).toList();
                          }

                          if (shops.isEmpty) {
                            return SizedBox(
                              height: 180,
                              child: Center(child: Text(AppLocalizations.of(context)!.error_no_shop_found)),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: shops.length,
                            itemBuilder: (context, index) {
                              final shop = shops[index];
                                  final data = shop.data() as Map<String, dynamic>;
                                  
                                  String distanceText = '';
                                  if (_currentPosition != null) {
                                    final sLat = (data['store_latitude'] ?? data['lat'] as num?)?.toDouble();
                                    final sLng = (data['store_longitude'] ?? data['lng'] as num?)?.toDouble();
                                    if (sLat != null && sLng != null) {
                                      final dist = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, sLat, sLng);
                                      if (dist < 1000) {
                                        distanceText = ' • ${(dist).toStringAsFixed(0)}m away';
                                      } else {
                                        distanceText = ' • ${(dist / 1000).toStringAsFixed(1)}km away';
                                      }
                                    }
                                  }

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      leading: CircleAvatar(
                                        backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
                                        child: const Icon(Icons.store, color: AppColors.primaryDark),
                                      ),
                                      title: Text(
                                        data['shop_name'] ?? '',
                                        style: AppTextStyles.heading2(color: AppColors.textDark),
                                      ),
                                      subtitle: Text(
                                        '${data['address'] ?? ''}$distanceText',
                                        style: AppTextStyles.captionMedium(color: AppColors.textMid),
                                      ),
                                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                                  onTap: () => _verifyAndEnterShop(shop.id),
                                ),
                              );
                            },
                          );
                        },
                      ),
                  ], // ends inner column children
                ), // ends inner column
              ], // ends outer column children
            ), // ends outer column
            ), // ends ConstrainedBox
          ), // ends Center
        ), // ends SingleChildScrollView
      ), // ends SafeArea
    ); // ends Scaffold
  }
}
