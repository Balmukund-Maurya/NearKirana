import 'package:near_kirana/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';

import 'map_selection_screen.dart';
import 'cart_provider.dart';
import 'user_provider.dart';
import 'app_theme.dart';
import 'sound_service.dart';
import 'modern_loader.dart';
import 'shop_provider.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'desktop_checkout_view.dart';

class CartScreen extends StatefulWidget {
  final bool isTab;
  const CartScreen({super.key, this.isTab = false});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isCheckout = false;

  // FIX-5: Store settings cache for cart UI
  double _minOrder = 300.0;
  double _freeDeliveryThreshold = 500.0;
  double _deliveryFeeAmount = 20.0;
  // FIX-12: Max udhaar limit cache

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CartProvider>(context, listen: false).syncPricesWithServer();
      _fetchCartSettings(); // FIX-5: Load dynamic settings
    });
  }

  Future<void> _fetchCartSettings() async {
    try {
      final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
      DocumentSnapshot<Map<String, dynamic>>? shopDoc;

      if (shopId != null && shopId.isNotEmpty) {
        shopDoc = await FirebaseUtils.firestore.collection('shops').doc(shopId).get();
      }

      if ((shopDoc?.exists ?? false) && mounted) {
        final data = shopDoc!.data()!;
        setState(() {
          _minOrder = (data['minimum_order'] as num?)?.toDouble() ?? 300.0;
          _freeDeliveryThreshold = (data['free_delivery_threshold'] as num?)?.toDouble() ?? 500.0;
          _deliveryFeeAmount = (data['delivery_fee'] as num?)?.toDouble() ?? 20.0;
        });
      } else {
        final doc = await FirebaseUtils.firestore.collection('settings').doc('app_config').get();
        if (doc.exists && mounted) {
          final data = doc.data()!;
          setState(() {
            _minOrder = (data['minimum_order'] as num?)?.toDouble() ?? 300.0;
            _freeDeliveryThreshold = (data['free_delivery_threshold'] as num?)?.toDouble() ?? 500.0;
            _deliveryFeeAmount = (data['delivery_fee'] as num?)?.toDouble() ?? 20.0;
          });
        }
      }
    } catch (e) {
      // Use default values on error
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckout) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: DesktopCheckoutView(
          onBackToCart: () => setState(() => _isCheckout = false),
          onOrderPlaced: () {
            setState(() => _isCheckout = false);
          },
        ),
      );
    }


    if (MediaQuery.of(context).size.width > 800) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: Consumer<CartProvider>(
          builder: (context, cartProvider, child) {
            return _buildDesktopCart(context, cartProvider);
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
  }

  Widget _buildCartItem({
    required String id,
    required String name,
    required String price,
    required double quantity,
    required bool isLoose,
    required CartProvider cartProvider,
    required BuildContext context,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgTint, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon Container
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isLoose
                  ? AppColors.accentPink.withValues(alpha: 0.15)
                  : AppColors.primaryLight.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isLoose ? Icons.scale_rounded : Icons.shopping_bag_rounded,
              color: isLoose ? AppColors.accentPink : AppColors.primaryDark,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.bodySemiBold(
                    color: AppColors.textDark,
                  ).copyWith(fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  price,
                  style: AppTextStyles.heading2(
                    color: AppColors.primaryDark,
                  ).copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Quantity Controls
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.bgTint),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildQtyButton(
                  icon: Icons.remove_rounded,
                  onPressed: () {
                    if (quantity <= (isLoose ? 0.5 : 1.0)) {
                      SoundService().removeFromCart();
                    } else {
                      HapticFeedback.lightImpact();
                    }
                    cartProvider.updateQuantity(id, isLoose ? -0.5 : -1.0);
                  },
                ),
                Container(
                  width: 32,
                  alignment: Alignment.center,
                  child: Text(
                    quantity.toStringAsFixed(
                      quantity.truncateToDouble() == quantity ? 0 : 1,
                    ),
                    style: AppTextStyles.bodySemiBold(
                      color: AppColors.textDark,
                    ).copyWith(fontSize: 14),
                  ),
                ),
                _buildQtyButton(
                  icon: Icons.add_rounded,
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
                            AppLocalizations.of(context)!.qty_exceeds,
                          ),
                          duration: const Duration(seconds: 1),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1, end: 0);
  }

  Widget _buildQtyButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 20, color: AppColors.textMid),
      ),
    );
  }

  Widget _buildCheckoutBottomBar(
    BuildContext context,
    CartProvider cartProvider,
  ) {
    final userProvider = Provider.of<UserProvider>(context);
    final double subtotal = cartProvider.cartTotal;
    // FIX-5: Use dynamic settings from Firebase instead of hardcoded values
    final bool canDeliver = subtotal >= _minOrder;
    final bool isWithinRadius = userProvider.isServiceable;
    final String? geoFenceError = userProvider.serviceabilityError;
    // FIX-3: Separate pickup serviceability
    final bool isPickupAllowed = userProvider.isPickupAllowed;
    final String? pickupError = userProvider.pickupError;
    final double deliveryFee = (canDeliver && subtotal < _freeDeliveryThreshold)
        ? _deliveryFeeAmount
        : 0.0;
    final double finalTotal = subtotal + (canDeliver ? deliveryFee : 0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.subtotal,
                  style: AppTextStyles.bodyMedium(color: AppColors.textMid),
                ),
                Text(
                  '₹$subtotal',
                  style: AppTextStyles.bodySemiBold(color: AppColors.textDark),
                ),
              ],
            ),
            if (canDeliver && deliveryFee > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context)!.delivery_fee,
                    style: AppTextStyles.bodyMedium(color: AppColors.textMid),
                  ),
                  Text(
                    '+₹$deliveryFee',
                    style: AppTextStyles.bodySemiBold(
                      color: AppColors.accentPink,
                    ),
                  ),
                ],
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1, thickness: 1, color: AppColors.bgTint),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${AppLocalizations.of(context)!.total_amount}:',
                  style: AppTextStyles.heading2(color: AppColors.textDark),
                ),
                Text(
                  '₹$finalTotal',
                  style: AppTextStyles.heading1(color: AppColors.primaryDark),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (!isWithinRadius)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_off_rounded,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        geoFenceError ?? 'Outside delivery area',
                        style: AppTextStyles.captionMedium(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(),

            // Delivery Option 1: Ghar Tak Delivery
            Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: (canDeliver && isWithinRadius)
                        ? () {
                            HapticFeedback.mediumImpact();
                            setState(() { _isCheckout = true; });
                          }
                        : null,
                    icon: const Icon(Icons.moped_rounded, size: 24),
                    label: Text(
                      '${AppLocalizations.of(context)!.home_delivery}${deliveryFee > 0 ? ' (+₹$deliveryFee)' : ''}',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canDeliver
                          ? AppColors.accentPink
                          : AppColors.bgTint,
                      foregroundColor: canDeliver
                          ? AppColors.white
                          : AppColors.textLight,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: AppTextStyles.button(),
                      elevation: 0,
                    ),
                  ),
                ),
                if (!canDeliver || subtotal >= 500)
                  Positioned(
                    top: -12,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: canDeliver
                              ? AppColors.primaryDark
                              : AppColors.accentPink,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        // FIX-5: Show dynamic minimum order amount
                        canDeliver ? 'Free Delivery' : 'Min. ₹${_minOrder.toStringAsFixed(0)}',
                        style: AppTextStyles.captionMedium(
                          color: canDeliver
                              ? AppColors.primaryDark
                              : AppColors.accentPink,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ).animate().scale(
                    delay: 200.ms,
                    duration: 300.ms,
                    curve: Curves.easeOutBack,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Delivery Option 2: Dukaan Se Pickup
            // FIX-3: Use isPickupAllowed (larger radius) instead of delivery isWithinRadius
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: isPickupAllowed
                    ? () {
                        HapticFeedback.mediumImpact();
                        setState(() { _isCheckout = true; });
                      }
                    : null,
                icon: const Icon(Icons.storefront_rounded, size: 24),
                label: Text(AppLocalizations.of(context)!.store_pickup),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPickupAllowed
                      ? AppColors.primaryLight.withValues(alpha: 0.2)
                      : AppColors.bgTint,
                  foregroundColor: isPickupAllowed
                      ? AppColors.primaryDark
                      : AppColors.textLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isPickupAllowed
                          ? AppColors.primaryLight
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  textStyle: AppTextStyles.button(),
                  elevation: 0,
                ),
              ),
            ),
            if (!isPickupAllowed && pickupError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  pickupError,
                  style: AppTextStyles.caption(color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showCheckoutForm(
    BuildContext context,
    String deliveryType,
    double finalTotal,
    double feeAmount,
    CartProvider cartProvider,
  ) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final shopId = Provider.of<ShopProvider>(context, listen: false).currentShopId;
    final nameController = TextEditingController(
      text: userProvider.customerName,
    );
    final phoneController = TextEditingController(
      text: userProvider.phoneNumber,
    );

    void showBottomSheetError(BuildContext ctx, String msg) {
      showDialog(
        context: ctx,
        builder: (dialogCtx) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10.0,
                  offset: Offset(0.0, 10.0),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: Colors.orange,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20.0),
                Text(
                  'Dhyan Dein',
                  style: GoogleFonts.poppins(
                    fontSize: 20.0,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12.0),
                Text(
                  msg,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14.0,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24.0),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(
                        0xFF4CAF50,
                      ), // App primary green
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: Text(
                      'Theek Hai',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        bool isProcessing = false;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 
                        MediaQuery.of(context).padding.bottom +
                        10,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Checkout - $deliveryType',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Aapka Naam',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !isProcessing,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.none,
                    decoration: InputDecoration(
                      labelText: 'Mobile Number',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    enabled: false,
                    readOnly: true,
                  ),
                  if (deliveryType == 'Delivery') ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              userProvider.addressLabel == 'Home'
                                  ? Icons.home_rounded
                                  : userProvider.addressLabel == 'Work'
                                  ? Icons.work_rounded
                                  : Icons.location_on_rounded,
                              color: const Color(0xFF4CAF50),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userProvider.addressLabel.isNotEmpty
                                      ? 'Delivering to ${userProvider.addressLabel}'
                                      : 'Delivery Address',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  userProvider.currentLat != null
                                      ? (userProvider.customerHouseNo.isNotEmpty
                                          ? '${userProvider.customerHouseNo}, ${userProvider.autoLocality}'
                                          : (userProvider.deliveryAddress.isNotEmpty
                                              ? userProvider.deliveryAddress
                                              : userProvider.autoLocality))
                                      : 'Please add your delivery address',
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              double? initialLat = userProvider.currentLat;
                              double? initialLng = userProvider.currentLng;

                              if (initialLat == null || initialLng == null) {
                                bool serviceEnabled =
                                    await Geolocator.isLocationServiceEnabled();
                                if (!serviceEnabled && context.mounted) {
                                  showBottomSheetError(
                                    context,
                                    'Kripya apna GPS on karein aur try karein.',
                                  );
                                  return;
                                }

                                LocationPermission permission =
                                    await Geolocator.checkPermission();
                                if (permission == LocationPermission.denied) {
                                  permission =
                                      await Geolocator.requestPermission();
                                  if (permission == LocationPermission.denied &&
                                      context.mounted) {
                                    showBottomSheetError(
                                      context,
                                      'Location permission required to set address.',
                                    );
                                    return;
                                  }
                                }

                                if (permission ==
                                        LocationPermission.deniedForever &&
                                    context.mounted) {
                                  showBottomSheetError(
                                    context,
                                    'Location permission is permanently denied.',
                                  );
                                  return;
                                }

                                if (context.mounted) {
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (ctx) => const Center(
                                      child: ModernLoader(),
                                    ),
                                  );
                                }

                                try {
                                  Position position =
                                      await Geolocator.getCurrentPosition(
                                        locationSettings:
                                            const LocationSettings(
                                              accuracy: LocationAccuracy.low,
                                              timeLimit: Duration(seconds: 10),
                                            ),
                                      );
                                  initialLat = position.latitude;
                                  initialLng = position.longitude;
                                } catch (e) {
                                  // If it fails, fallback to store location
                                  initialLat = userProvider.storeLat ?? 0.0;
                                  initialLng = userProvider.storeLng ?? 0.0;
                                }

                                if (context.mounted) {
                                  Navigator.pop(context); // close loader
                                }
                              }

                              if (!context.mounted) return;

                              final LatLng? selectedLocation =
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MapSelectionScreen(
                                        initialLat: initialLat ?? 0.0,
                                        initialLng: initialLng ?? 0.0,
                                      ),
                                    ),
                                  );
                              if (selectedLocation != null && context.mounted) {
                                setState(() {
                                  // Just rebuild to show new address from userProvider
                                });
                              }
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF4CAF50),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              userProvider.currentLat != null
                                  ? 'CHANGE'
                                  : 'ADD',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isProcessing
                        ? null
                        : () async {
                            if (nameController.text.isEmpty ||
                                phoneController.text.isEmpty) {
                              return;
                            }

                            final prefs = await SharedPreferences.getInstance();
                            if (!context.mounted) return;

                            final int lastOrderTime =
                                prefs.getInt('last_order_time') ?? 0;
                            final int now =
                                DateTime.now().millisecondsSinceEpoch;
                            if (now - lastOrderTime < 180000) {
                              // 3 minutes cooldown
                              showBottomSheetError(
                                context,
                                AppLocalizations.of(context)!.wait_3_min,
                              );
                              return;
                            }

                            if (deliveryType == 'Delivery' &&
                                (userProvider.currentLat == null ||
                                    userProvider.currentLng == null)) {
                              showBottomSheetError(
                                context,
                                'Please add a delivery address on the map.',
                              );
                              return;
                            }
                            if (deliveryType == 'Delivery' &&
                                userProvider.customerHouseNo.isEmpty &&
                                userProvider.deliveryAddress.isEmpty) {
                              showBottomSheetError(
                                context,
                                'Please enter your House/Flat No.',
                              );
                              return;
                            }
                            if (deliveryType == 'Delivery' &&
                                !userProvider.isServiceable) {
                              showBottomSheetError(
                                context,
                                userProvider.serviceabilityError ??
                                    'Not serviceable.',
                              );
                              return;
                            }


                            setState(() {
                              isProcessing = true;
                            });

                            // Khata is strictly for offline customers now. 
                            // We only check if the user is banned.
                            try {
                              final customerQuery = await FirebaseFirestore
                                  .instance
                                  .collection('customers')
                                  .where('mobile', isEqualTo: phoneController.text.trim())
                                  .where('shop_ids', arrayContains: shopId)
                                  .limit(1)
                                  .get();

                              if (customerQuery.docs.isNotEmpty) {
                                final customerData = customerQuery.docs.first.data();
                                if (customerData['is_banned'] == true) {
                                  setState(() => isProcessing = false);
                                  if (context.mounted) {
                                    showBottomSheetError(
                                      context,
                                      'Aapka account block kar diya gaya hai. Kripya dukan par sampark karein.',
                                    );
                                  }
                                  return;
                                }
                              }
                            } catch (e) {
                              // Ignore and proceed if there's a read error
                            }

                            try {
                              // FIX-1: Unified path — settings/app_config
                              final settingsDoc = await FirebaseFirestore
                                  .instance
                                  .collection('settings')
                                  .doc('app_config')
                                  .get();
                              double minOrder = 300.0;
                              double freeDeliveryThreshold = 500.0;
                              double deliveryFee = 20.0;
                              bool isStoreOpen = true;
                              if (settingsDoc.exists) {
                                final data = settingsDoc.data()!;
                                minOrder =
                                    (data['minimum_order'] as num?)
                                        ?.toDouble() ??
                                    300.0;
                                freeDeliveryThreshold =
                                    (data['free_delivery_threshold'] as num?)
                                        ?.toDouble() ??
                                    500.0;
                                deliveryFee =
                                    (data['delivery_fee'] as num?)
                                        ?.toDouble() ??
                                    20.0;
                                isStoreOpen = data['is_store_open'] ?? true;
                              }

                              if (!isStoreOpen) {
                                if (context.mounted) {
                                  showBottomSheetError(
                                    context,
                                    AppLocalizations.of(context)!.store_closed_error,
                                  );
                                  setState(() => isProcessing = false);
                                }
                                return;
                              }

                              // PRE-CHECK 1: Ghost Cart (Products deleted by admin but still in cart)
                              List<String> itemsToRemove = [];
                              for (var item in cartProvider.itemsList) {
                                final doc = await FirebaseUtils.firestore
                                    .collection('products')
                                    .doc(item.id)
                                    .get();
                                if (!doc.exists) {
                                  itemsToRemove.add(item.id);
                                }
                              }

                              if (itemsToRemove.isNotEmpty) {
                                if (context.mounted) {
                                  for (String id in itemsToRemove) {
                                    cartProvider.removeItem(id);
                                  }
                                  showBottomSheetError(
                                    context,
                                    AppLocalizations.of(context)!.ghost_cart_error,
                                  );
                                  setState(() => isProcessing = false);
                                }
                                return; // Abort checkout so they can see new cart
                              }

                              final processedTotal = await FirebaseUtils.firestore.runTransaction((
                                transaction,
                              ) async {
                                double recalculatedSubtotal = 0.0;
                                List<Map<String, dynamic>> verifiedItemsMap =
                                    [];
                                Map<DocumentReference, double> stockUpdates =
                                    {};

                                // 1. Read phase (all reads must come before writes)
                                for (var item in cartProvider.itemsList) {
                                  final productRef = FirebaseUtils.firestore
                                      .collection('products')
                                      .doc(item.id);
                                  final snapshot = await transaction.get(
                                    productRef,
                                  );

                                  if (!snapshot.exists) {
                                    throw Exception(
                                      'Product "${item.name}" is no longer available in the shop.',
                                    );
                                  }

                                  final data =
                                      snapshot.data() as Map<String, dynamic>;
                                  final currentStock =
                                      (data['stock_quantity'] as num?)
                                          ?.toDouble() ??
                                      0.0;
                                  final currentPrice =
                                      (data['price'] as num?)?.toDouble() ??
                                      0.0;

                                  if (currentStock < item.quantity) {
                                    throw Exception(
                                      'STOCK_ERROR|${item.id}|${item.name}|$currentStock',
                                    );
                                  }
                                  if (currentPrice != item.price) {
                                    throw Exception(
                                      'PRICE_CHANGED|${item.id}|${item.name}|$currentPrice',
                                    );
                                  }

                                  recalculatedSubtotal +=
                                      currentPrice * item.quantity;
                                  stockUpdates[productRef] =
                                      currentStock - item.quantity;

                                  verifiedItemsMap.add({
                                    'id': item.id,
                                    'name': data['name'] ?? item.name,
                                    'price': currentPrice,
                                    'quantity': item.quantity,
                                    'isLoose': item.isLoose,
                                  });
                                }

                                // 2. Calculate live final total securely using settings
                                final bool canDeliverLive =
                                    recalculatedSubtotal >= minOrder;
                                
                                // FIX-18: Abort if it's a delivery order and the live subtotal is less than minimum
                                if (deliveryType == 'Delivery' && !canDeliverLive) {
                                  throw Exception(
                                    'MIN_ORDER_ERROR|$minOrder',
                                  );
                                }

                                final double liveDeliveryFee =
                                    (canDeliverLive &&
                                        recalculatedSubtotal <
                                            freeDeliveryThreshold &&
                                        deliveryType == 'Delivery')
                                    ? deliveryFee
                                    : 0.0;
                                final double liveFinalTotal =
                                    recalculatedSubtotal + liveDeliveryFee;

                                // 3. Write phase
                                for (var entry in stockUpdates.entries) {
                                  transaction.update(entry.key, {
                                    'stock_quantity': entry.value,
                                  });
                                }

                                String finalDeliveryAddress = '';
                                if (deliveryType == 'Delivery') {
                                  if (userProvider.customerHouseNo.isNotEmpty) {
                                    finalDeliveryAddress =
                                        'House: ${userProvider.customerHouseNo}';
                                    if (userProvider
                                        .customerLandmark
                                        .isNotEmpty) {
                                      finalDeliveryAddress +=
                                          ', Landmark: ${userProvider.customerLandmark}';
                                    }
                                    finalDeliveryAddress +=
                                        ' — (Locality: ${userProvider.autoLocality})';
                                    if (userProvider.addressLabel.isNotEmpty) {
                                      finalDeliveryAddress +=
                                          ' [${userProvider.addressLabel}]';
                                    }
                                  } else {
                                    // Fallback for legacy users
                                    finalDeliveryAddress = userProvider.deliveryAddress;
                                  }
                                }

                                final orderRef = FirebaseUtils.firestore
                                    .collection('orders')
                                    .doc();
                                final String deliveryPin =
                                    (1000 + Random().nextInt(9000)).toString();

                                transaction.set(orderRef, {
                                  'shop_id': shopId,
                                  'customer_name': nameController.text,
                                  'phone_number': phoneController.text,
                                  'delivery_address': deliveryType == 'Delivery'
                                      ? finalDeliveryAddress
                                      : null,
                                  'customer_lat': deliveryType == 'Delivery'
                                      ? userProvider.currentLat
                                      : null,
                                  'customer_lng': deliveryType == 'Delivery'
                                      ? userProvider.currentLng
                                      : null,
                                  'delivery_type': deliveryType,
                                  'delivery_fee': liveDeliveryFee,
                                  'total_amount': liveFinalTotal,
                                  'items': verifiedItemsMap,
                                  'status': 'Pending',
                                  'delivery_pin': deliveryPin,
                                  'payment_method': 'Cash on Delivery',
                                  'created_at': FieldValue.serverTimestamp(),
                                });

                                return liveFinalTotal;
                              });

                              if (context.mounted) {
                                Provider.of<UserProvider>(
                                  context,
                                  listen: false,
                                ).setUser(
                                  nameController.text.trim(),
                                  phoneController.text.trim(),
                                );
                                Navigator.pop(context); // Close BottomSheet
                                cartProvider.clearCart();
                                await prefs.setInt(
                                  'last_order_time',
                                  DateTime.now().millisecondsSinceEpoch,
                                );
                                // FIX-6: Persist updated name to SharedPreferences
                                await prefs.setString('customerName', nameController.text.trim());
                                await prefs.setString('customerPhone', phoneController.text.trim());
                                if (!context.mounted) return;

                                SoundService().orderSuccess();
                                showDialog(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    title: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          color: Color(0xFF4CAF50),
                                          size: 30,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            AppLocalizations.of(context)!.order_placed,
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    content: Text(
                                      deliveryType == 'Pickup'
                                          ? AppLocalizations.of(context)!.thank_you_order_pickup
                                          : AppLocalizations.of(context)!.thank_you_order
                                              .replaceAll(
                                                '{total}',
                                                processedTotal.toString(),
                                              ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          if (dialogContext.mounted) {
                                            Navigator.pop(dialogContext);
                                          }
                                        },
                                        child: Text(
                                          AppLocalizations.of(context)!.ok_btn,
                                          style: GoogleFonts.poppins(
                                            color: const Color(0xFF4CAF50),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                setState(() {
                                  isProcessing = false;
                                });

                                String errorMsg = e.toString().replaceAll(
                                  'Exception: ',
                                  '',
                                );
                                if (errorMsg.startsWith('STOCK_ERROR|')) {
                                  final parts = errorMsg.split('|');
                                  if (parts.length >= 4) {
                                    final id = parts[1];
                                    final name = parts[2];
                                    final stock =
                                        double.tryParse(parts[3]) ?? 0;
                                    cartProvider.setQuantity(id, stock);

                                    showBottomSheetError(
                                      context,
                                      "Oh no! 🚨 '$name' only has ${stock.toStringAsFixed(0)} left in stock. We've updated your cart.",
                                    );
                                    return;
                                  }
                                } else if (errorMsg.startsWith(
                                  'PRICE_CHANGED|',
                                )) {
                                  final parts = errorMsg.split('|');
                                  if (parts.length >= 4) {
                                    final id = parts[1];
                                    final name = parts[2];
                                    final newPrice =
                                        double.tryParse(parts[3]) ?? 0;
                                    cartProvider.updatePrice(id, newPrice);

                                    showBottomSheetError(
                                      context,
                                      "Oops! 🏷️ The price of '$name' has changed to ₹$newPrice. We've updated your cart with the latest price.",
                                    );
                                    return;
                                  }
                                } else if (errorMsg.startsWith('MIN_ORDER_ERROR|')) {
                                  final parts = errorMsg.split('|');
                                  if (parts.length >= 2) {
                                    final min = double.tryParse(parts[1]) ?? 0;
                                    showBottomSheetError(
                                      context,
                                      "Minimum order value is ₹$min for delivery. Please add more items.",
                                    );
                                    return;
                                  }
                                } else if (errorMsg.toLowerCase().contains(
                                      'unavailable',
                                    ) ||
                                    errorMsg.toLowerCase().contains(
                                      'network',
                                    ) ||
                                    errorMsg.toLowerCase().contains(
                                      'offline',
                                    ) ||
                                    errorMsg.toLowerCase().contains(
                                      'client is offline',
                                    )) {
                                  errorMsg =
                                      'No internet connection. Please check your network and try again.';
                                }

                                showBottomSheetError(
                                  context,
                                  errorMsg.contains('Error')
                                      ? errorMsg
                                      : 'Error placing order: $errorMsg',
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: isProcessing
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            AppLocalizations.of(context)!.confirm_order
                                .replaceAll('{total}', finalTotal.toString()),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

    Widget _buildDesktopCart(BuildContext context, CartProvider cartProvider) {
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


}
