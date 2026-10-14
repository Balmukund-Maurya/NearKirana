import 'package:near_kirana/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';

import 'cart_provider.dart';
import 'user_provider.dart';
import 'app_theme.dart';
import 'sound_service.dart';
import 'shop_provider.dart';

import 'package:near_kirana/firebase_utils.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_service.dart';
import 'payment_service.dart';
import 'desktop_checkout_view.dart';
import 'atomic_order_service.dart';
import 'address_selection_bottom_sheet.dart';
import 'shopping_list_service.dart';
import 'widgets/voice_order_sheet.dart';

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
      final shopId = Provider.of<ShopProvider>(
        context,
        listen: false,
      ).currentShopId;
      DocumentSnapshot<Map<String, dynamic>>? shopDoc;

      if (shopId != null && shopId.isNotEmpty) {
        shopDoc = await FirebaseUtils.firestore
            .collection('shops')
            .doc(shopId)
            .get();
      }

      if ((shopDoc?.exists ?? false) && mounted) {
        final data = shopDoc!.data()!;
        setState(() {
          _minOrder = (data['minimum_order'] as num?)?.toDouble() ?? 300.0;
          _freeDeliveryThreshold =
              (data['free_delivery_threshold'] as num?)?.toDouble() ?? 500.0;
          _deliveryFeeAmount =
              (data['delivery_fee'] as num?)?.toDouble() ?? 20.0;
        });
      } else {
        final doc = await FirebaseUtils.firestore
            .collection('settings')
            .doc('app_config')
            .get();
        if (doc.exists && mounted) {
          final data = doc.data()!;
          setState(() {
            _minOrder = (data['minimum_order'] as num?)?.toDouble() ?? 300.0;
            _freeDeliveryThreshold =
                (data['free_delivery_threshold'] as num?)?.toDouble() ?? 500.0;
            _deliveryFeeAmount =
                (data['delivery_fee'] as num?)?.toDouble() ?? 20.0;
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
        actions: [
          Consumer<CartProvider>(
            builder: (context, cart, _) {
              if (cart.items.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.bookmark_add_outlined),
                tooltip: 'Save Cart as List',
                onPressed: () => _showSaveCartAsListDialog(context, cart),
              );
            },
          ),
        ],
      ),
      body: Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
          final cartItems = cartProvider.itemsList;

          if (cartItems.isEmpty) {
            return Center(
              child:
                  Column(
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
                            style: AppTextStyles.heading2(
                              color: AppColors.textMid,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              final shopProvider = Provider.of<ShopProvider>(context, listen: false);
                              VoiceOrderSheet.show(
                                context,
                                shopId: shopProvider.currentShopId ?? '',
                              );
                            },
                            icon: const Icon(Icons.mic_rounded, color: Colors.white, size: 20),
                            label: const Text(
                              'Order by Voice (बोलकर सामान मंगाएं)',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryDark,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.1, end: 0)
                      .scaleXY(
                        begin: 1.0,
                        end: 1.05,
                        duration: 1500.ms,
                        curve: Curves.easeInOut,
                      ),
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
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text(
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

            if (canDeliver && isWithinRadius) ...[
              Builder(
                builder: (context) {
                  final estimate = userProvider.getEstimatedDeliveryTime(deliveryType: 'Delivery');
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 16, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Est. Delivery: ${estimate.formattedWindow} (${estimate.formattedTimeRange})',
                                style: TextStyle(
                                  color: Colors.blue.shade900,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                estimate.disclaimer,
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],

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
                            setState(() {
                              _isCheckout = true;
                            });
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
                        canDeliver
                            ? 'Free Delivery'
                            : 'Min. ₹${_minOrder.toStringAsFixed(0)}',
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
                        setState(() {
                          _isCheckout = true;
                        });
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

  // ignore: unused_element
  void _showCheckoutForm(
    BuildContext context,
    String deliveryType,
    double finalTotal,
    double feeAmount,
    CartProvider cartProvider,
  ) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);
    final shopId = shopProvider.currentShopId;
    final String shopUpiId = (shopProvider.shopUpiId ?? '').trim();
    final String shopName = (shopProvider.shopName ?? 'NearKirana Store')
        .trim();
    final nameController = TextEditingController(
      text: userProvider.customerName,
    );
    final phoneController = TextEditingController(
      text: userProvider.phoneNumber,
    );
    final utrController = TextEditingController();
    String selectedPaymentMethod = 'Cash on Delivery';
    bool showQrCode = false;

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
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        bool isProcessing = false;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              padding: EdgeInsets.only(
                bottom:
                    MediaQuery.of(context).viewInsets.bottom +
                    MediaQuery.of(context).padding.bottom +
                    10,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Checkout - $deliveryType',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(bottomSheetContext),
                        ),
                      ],
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
                      InkWell(
                        onTap: () async {
                          final selected =
                              await AddressSelectionBottomSheet.show(
                                context,
                                isCheckoutMode: true,
                              );
                          if (selected != null && mounted) {
                            setState(() {});
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: !userProvider.isServiceable &&
                                      userProvider.currentLat != null
                                  ? Colors.red.withValues(alpha: 0.5)
                                  : Colors.grey[200]!,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: (!userProvider.isServiceable &&
                                          userProvider.currentLat != null)
                                      ? Colors.red.withValues(alpha: 0.1)
                                      : const Color(
                                          0xFF4CAF50,
                                        ).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  userProvider.activeAddress?.icon ??
                                      (userProvider.addressLabel == 'Home'
                                          ? Icons.home_rounded
                                          : userProvider.addressLabel ==
                                                      'Work' ||
                                                  userProvider.addressLabel ==
                                                      'Office'
                                              ? Icons.work_rounded
                                              : Icons.location_on_rounded),
                                  color: (!userProvider.isServiceable &&
                                          userProvider.currentLat != null)
                                      ? Colors.red
                                      : const Color(0xFF4CAF50),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            userProvider
                                                        .activeAddress
                                                        ?.label
                                                        .isNotEmpty ==
                                                    true
                                                ? 'Delivering to ${userProvider.activeAddress!.label}'
                                                : (userProvider
                                                        .addressLabel
                                                        .isNotEmpty
                                                    ? 'Delivering to ${userProvider.addressLabel}'
                                                    : 'Delivery Address'),
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (userProvider
                                                .activeAddress
                                                ?.isDefault ==
                                            true) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 1.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF4CAF50,
                                              ).withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'DEFAULT',
                                              style: GoogleFonts.poppins(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(
                                                  0xFF2E7D32,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      userProvider.activeAddress != null
                                          ? userProvider
                                              .activeAddress!
                                              .formattedAddress
                                          : (userProvider.currentLat != null
                                              ? (userProvider
                                                      .customerHouseNo
                                                      .isNotEmpty
                                                  ? '${userProvider.customerHouseNo}, ${userProvider.autoLocality}'
                                                  : (userProvider
                                                          .deliveryAddress
                                                          .isNotEmpty
                                                      ? userProvider
                                                          .deliveryAddress
                                                      : userProvider
                                                          .autoLocality))
                                              : 'Please select delivery address'),
                                      style: GoogleFonts.poppins(
                                        color: Colors.grey[600],
                                        fontSize: 13,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (userProvider.currentLat != null &&
                                        !userProvider.isServiceable) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          userProvider
                                                  .serviceabilityError ??
                                              'Outside delivery zone',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: Colors.red[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final selected =
                                      await AddressSelectionBottomSheet
                                          .show(
                                            context,
                                            isCheckoutMode: true,
                                          );
                                  if (selected != null && mounted) {
                                    setState(() {});
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
                      ),
                    ],

                    // Payment Method Selection Section
                    const SizedBox(height: 20),
                    Text(
                      'Payment Method',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Option 1: Cash on Delivery / Pay at Store
                    InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          selectedPaymentMethod = 'Cash on Delivery';
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: selectedPaymentMethod == 'Cash on Delivery'
                              ? const Color(0xFF4CAF50).withValues(alpha: 0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selectedPaymentMethod == 'Cash on Delivery'
                                ? const Color(0xFF4CAF50)
                                : Colors.grey[300]!,
                            width: selectedPaymentMethod == 'Cash on Delivery'
                                ? 2
                                : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color:
                                    selectedPaymentMethod == 'Cash on Delivery'
                                    ? const Color(
                                        0xFF4CAF50,
                                      ).withValues(alpha: 0.15)
                                    : Colors.grey[100],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                deliveryType == 'Delivery'
                                    ? Icons.payments_outlined
                                    : Icons.storefront_rounded,
                                color:
                                    selectedPaymentMethod == 'Cash on Delivery'
                                    ? const Color(0xFF4CAF50)
                                    : Colors.grey[600],
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    deliveryType == 'Delivery'
                                        ? 'Cash on Delivery'
                                        : 'Pay at Counter (Cash)',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    deliveryType == 'Delivery'
                                        ? 'Pay in cash when order is delivered'
                                        : 'Pay at store counter during pickup',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      selectedPaymentMethod ==
                                          'Cash on Delivery'
                                      ? const Color(0xFF4CAF50)
                                      : Colors.grey[400]!,
                                  width: 2,
                                ),
                              ),
                              child: selectedPaymentMethod == 'Cash on Delivery'
                                  ? Center(
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFF4CAF50),
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Option 2: UPI Payment (GPay, PhonePe, Paytm, QR)
                    InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          selectedPaymentMethod = 'UPI';
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: selectedPaymentMethod == 'UPI'
                              ? const Color(0xFF4CAF50).withValues(alpha: 0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selectedPaymentMethod == 'UPI'
                                ? const Color(0xFF4CAF50)
                                : Colors.grey[300]!,
                            width: selectedPaymentMethod == 'UPI' ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: selectedPaymentMethod == 'UPI'
                                    ? const Color(
                                        0xFF4CAF50,
                                      ).withValues(alpha: 0.15)
                                    : Colors.grey[100],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.qr_code_scanner_rounded,
                                color: selectedPaymentMethod == 'UPI'
                                    ? const Color(0xFF4CAF50)
                                    : Colors.grey[600],
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'UPI Payment',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF4CAF50,
                                          ).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          'Instant & Direct',
                                          style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF4CAF50),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'GPay, PhonePe, Paytm, BHIM or Scan QR',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selectedPaymentMethod == 'UPI'
                                      ? const Color(0xFF4CAF50)
                                      : Colors.grey[400]!,
                                  width: 2,
                                ),
                              ),
                              child: selectedPaymentMethod == 'UPI'
                                  ? Center(
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFF4CAF50),
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (selectedPaymentMethod == 'UPI') ...[
                      const SizedBox(height: 12),
                      if (shopUpiId.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: Colors.orange,
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'This shopkeeper has not configured online UPI yet. Please use Cash on Delivery.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Shop UPI ID',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          shopUpiId,
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textDark,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.copy_rounded,
                                      size: 18,
                                      color: Color(0xFF4CAF50),
                                    ),
                                    tooltip: 'Copy UPI ID',
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(text: shopUpiId),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'UPI ID copied to clipboard',
                                          ),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        HapticFeedback.lightImpact();
                                        final upiUrl =
                                            'upi://pay?pa=$shopUpiId&pn=${Uri.encodeComponent(shopName)}&am=${finalTotal.toStringAsFixed(2)}&cu=INR&tn=${Uri.encodeComponent('NearKirana Order')}';
                                        try {
                                          final uri = Uri.parse(upiUrl);
                                          final launched = await launchUrl(
                                            uri,
                                            mode:
                                                LaunchMode.externalApplication,
                                          );
                                          if (!launched && context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'No UPI app found. You can scan the QR code below!',
                                                ),
                                                backgroundColor: Colors.orange,
                                              ),
                                            );
                                            setState(() => showQrCode = true);
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Could not open UPI app: $e. Scan QR below.',
                                                ),
                                                backgroundColor: Colors.orange,
                                              ),
                                            );
                                            setState(() => showQrCode = true);
                                          }
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.open_in_new_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('Pay via App'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF4CAF50,
                                        ),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        setState(
                                          () => showQrCode = !showQrCode,
                                        );
                                      },
                                      icon: Icon(
                                        showQrCode
                                            ? Icons.qr_code_rounded
                                            : Icons.qr_code_scanner_rounded,
                                        size: 18,
                                      ),
                                      label: Text(
                                        showQrCode ? 'Hide QR' : 'Show QR',
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF4CAF50,
                                        ),
                                        side: const BorderSide(
                                          color: Color(0xFF4CAF50),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (showQrCode) ...[
                                const SizedBox(height: 16),
                                Center(
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey[300]!,
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Colors.black12,
                                              blurRadius: 8,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: QrImageView(
                                          data:
                                              'upi://pay?pa=$shopUpiId&pn=${Uri.encodeComponent(shopName)}&am=${finalTotal.toStringAsFixed(2)}&cu=INR&tn=${Uri.encodeComponent('NearKirana Order')}',
                                          version: QrVersions.auto,
                                          size: 160.0,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Scan with Google Pay, PhonePe, or Paytm',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        'Amount: ₹${finalTotal.toStringAsFixed(2)}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF4CAF50),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              TextField(
                                controller: utrController,
                                decoration: InputDecoration(
                                  labelText:
                                      'UPI Reference / UTR No. (Optional)',
                                  hintText:
                                      'e.g. 12-digit UTR from payment receipt',
                                  prefixIcon: const Icon(
                                    Icons.receipt_long_rounded,
                                    size: 20,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: isProcessing
                          ? null
                          : () async {
                              if (isProcessing) return;

                              if (nameController.text.trim().isEmpty ||
                                  phoneController.text.trim().isEmpty) {
                                showBottomSheetError(
                                  context,
                                  'Please enter your name and phone number.',
                                );
                                return;
                              }

                              // Immediately lock UI synchronously to prevent duplicate order / double-tap race conditions
                              setState(() {
                                isProcessing = true;
                              });

                              final prefs =
                                  await SharedPreferences.getInstance();
                              if (!context.mounted) return;

                              final int lastOrderTime =
                                  prefs.getInt('last_order_time') ?? 0;
                              final int now =
                                  DateTime.now().millisecondsSinceEpoch;
                              if (now - lastOrderTime < 180000) {
                                // 3 minutes cooldown
                                setState(() => isProcessing = false);
                                showBottomSheetError(
                                  context,
                                  AppLocalizations.of(context)!.wait_3_min,
                                );
                                return;
                              }

                              if (deliveryType == 'Delivery' &&
                                  (userProvider.currentLat == null ||
                                      userProvider.currentLng == null)) {
                                setState(() => isProcessing = false);
                                showBottomSheetError(
                                  context,
                                  'Please add a delivery address on the map.',
                                );
                                return;
                              }
                              if (deliveryType == 'Delivery' &&
                                  userProvider.customerHouseNo.isEmpty &&
                                  userProvider.deliveryAddress.isEmpty) {
                                setState(() => isProcessing = false);
                                showBottomSheetError(
                                  context,
                                  'Please enter your House/Flat No.',
                                );
                                return;
                              }
                              if (deliveryType == 'Delivery' &&
                                  !userProvider.isServiceable) {
                                setState(() => isProcessing = false);
                                showBottomSheetError(
                                  context,
                                  userProvider.serviceabilityError ??
                                      'Not serviceable.',
                                );
                                return;
                              }

                              if (selectedPaymentMethod == 'UPI' &&
                                  shopUpiId.isEmpty) {
                                setState(() => isProcessing = false);
                                showBottomSheetError(
                                  context,
                                  'This shopkeeper has not configured online UPI yet. Please select Cash on Delivery.',
                                );
                                return;
                              }

                              // Khata is strictly for offline customers now.
                              // We only check if the user is banned.
                              try {
                                final customerQuery = await FirebaseFirestore
                                    .instance
                                    .collection('customers')
                                    .where(
                                      'mobile',
                                      isEqualTo: phoneController.text.trim(),
                                    )
                                    .where('shop_ids', arrayContains: shopId)
                                    .limit(1)
                                    .get();

                                if (customerQuery.docs.isNotEmpty) {
                                  final customerData = customerQuery.docs.first
                                      .data();
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
                                      AppLocalizations.of(
                                        context,
                                      )!.store_closed_error,
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
                                      AppLocalizations.of(
                                        context,
                                      )!.ghost_cart_error,
                                    );
                                    setState(() => isProcessing = false);
                                  }
                                  return; // Abort checkout so they can see new cart
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
                                    finalDeliveryAddress =
                                        userProvider.deliveryAddress;
                                  }
                                }

                                final orderItems = cartProvider.itemsList
                                    .map(
                                      (item) => OrderItemRequest(
                                        productId: item.id,

                                        name: item.name,

                                        price: item.price,

                                        quantity: item.quantity,

                                        isLoose: item.isLoose,

                                        imageUrl: item.imageUrl,
                                      ),
                                    )
                                    .toList();

                                final idempotencyKey =
                                    '${AuthService().currentUid ?? phoneController.text.trim()}_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';

                                final orderResult = await AtomicOrderService
                                    .instance
                                    .placeOrderAtomic(
                                      OrderPlacementParams(
                                        shopId: shopId ?? '',

                                        customerUid: AuthService().currentUid,

                                        customerName: nameController.text
                                            .trim(),

                                        customerPhone: phoneController.text
                                            .trim(),

                                        deliveryAddress:
                                            deliveryType == 'Delivery'
                                            ? finalDeliveryAddress
                                            : null,

                                        customerLat: deliveryType == 'Delivery'
                                            ? userProvider.currentLat
                                            : null,

                                        customerLng: deliveryType == 'Delivery'
                                            ? userProvider.currentLng
                                            : null,

                                        deliveryType: deliveryType,

                                        deliveryFee: deliveryFee,

                                        paymentMethod: selectedPaymentMethod,

                                        paymentStatus:
                                            selectedPaymentMethod == 'UPI'
                                            ? (utrController.text
                                                      .trim()
                                                      .isNotEmpty
                                                  ? PaymentStatus
                                                        .pendingVerification
                                                  : PaymentStatus
                                                        .paymentPending)
                                            : PaymentStatus.unpaid,

                                        upiId: selectedPaymentMethod == 'UPI'
                                            ? shopUpiId
                                            : null,

                                        upiRefId:
                                            (selectedPaymentMethod == 'UPI' &&
                                                utrController.text
                                                    .trim()
                                                    .isNotEmpty)
                                            ? utrController.text.trim()
                                            : null,

                                        idempotencyKey: idempotencyKey,

                                        items: orderItems,

                                        minOrder: minOrder,

                                        freeDeliveryThreshold:
                                            freeDeliveryThreshold,
                                      ),
                                    );

                                if (selectedPaymentMethod == 'UPI') {
                                  try {
                                    await PaymentService()
                                        .initiateOnlinePayment(
                                          orderId: orderResult.orderId,
                                          shopId: shopId ?? '',
                                          amount: orderResult.totalAmount,
                                          customerPhone: phoneController.text
                                              .trim(),
                                          customerName: nameController.text
                                              .trim(),
                                          paymentMethod: PaymentMethod.upi,
                                          upiId: shopUpiId,
                                          payeeName: shopName,
                                        );
                                  } catch (e) {
                                    debugPrint(
                                      'Payment session initiation error: $e',
                                    );
                                  }
                                }

                                final processedTotal = orderResult.totalAmount;

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
                                  await prefs.setString(
                                    'customerName',
                                    nameController.text.trim(),
                                  );
                                  await prefs.setString(
                                    'customerPhone',
                                    phoneController.text.trim(),
                                  );
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
                                              AppLocalizations.of(
                                                context,
                                              )!.order_placed,
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            deliveryType == 'Pickup'
                                                ? AppLocalizations.of(
                                                    context,
                                                  )!.thank_you_order_pickup
                                                : AppLocalizations.of(
                                                    context,
                                                  )!.thank_you_order.replaceAll(
                                                    '{total}',
                                                    processedTotal.toString(),
                                                  ),
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  selectedPaymentMethod == 'UPI'
                                                  ? const Color(
                                                      0xFF4CAF50,
                                                    ).withValues(alpha: 0.1)
                                                  : Colors.grey[100],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color:
                                                    selectedPaymentMethod ==
                                                        'UPI'
                                                    ? const Color(
                                                        0xFF4CAF50,
                                                      ).withValues(alpha: 0.3)
                                                    : Colors.grey[300]!,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  selectedPaymentMethod == 'UPI'
                                                      ? Icons
                                                            .check_circle_outline
                                                      : Icons.payments_outlined,
                                                  size: 16,
                                                  color:
                                                      selectedPaymentMethod ==
                                                          'UPI'
                                                      ? const Color(0xFF4CAF50)
                                                      : Colors.grey[700],
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  selectedPaymentMethod == 'UPI'
                                                      ? (utrController.text
                                                                .trim()
                                                                .isNotEmpty
                                                            ? 'Payment: UPI (Verification Pending)'
                                                            : 'Payment: UPI (Pending)')
                                                      : 'Payment: Cash on Delivery',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        selectedPaymentMethod ==
                                                            'UPI'
                                                        ? Colors.orange[800]
                                                        : Colors.grey[800],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            if (dialogContext.mounted) {
                                              Navigator.pop(dialogContext);
                                            }
                                          },
                                          child: Text(
                                            AppLocalizations.of(
                                              context,
                                            )!.ok_btn,
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
                                      if (stock <= 0) {
                                        cartProvider.removeItem(id);
                                        showBottomSheetError(
                                          context,
                                          "Kshama karein! 🚨 '$name' abhi kisi aur customer ne kharid liya hai aur stock khatam ho gaya hai. Item cart se hata diya gaya hai.",
                                        );
                                      } else {
                                        cartProvider.setQuantity(id, stock);
                                        showBottomSheetError(
                                          context,
                                          "Oh no! 🚨 '$name' ka kewal ${stock.toStringAsFixed(0)} bacha hai. Kisi aur ne baki stock le liya. Aapka cart update kar diya gaya hai.",
                                        );
                                      }
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
                                  } else if (errorMsg.startsWith(
                                    'MIN_ORDER_ERROR|',
                                  )) {
                                    final parts = errorMsg.split('|');
                                    if (parts.length >= 2) {
                                      final min =
                                          double.tryParse(parts[1]) ?? 0;
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
                              'Confirm Order • ₹${finalTotal.toStringAsFixed(0)} (${selectedPaymentMethod == 'UPI' ? 'UPI' : 'COD'})',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
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
    final double deliveryFee =
        (subtotal >= _minOrder && subtotal < _freeDeliveryThreshold)
        ? _deliveryFeeAmount
        : 0.0;
    final double finalTotal =
        subtotal + ((subtotal >= _minOrder) ? deliveryFee : 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER ROW
          Row(
            children: [
              const Icon(
                Icons.shopping_cart_outlined,
                size: 36,
                color: Color(0xFF111827),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'My Cart',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  Text(
                    'Review your items and proceed to checkout',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  ),
                ],
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => cartProvider.clearCart(),
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 18,
                ),
                label: const Text(
                  'Clear Cart',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  side: BorderSide(color: Colors.red.shade100, width: 1.5),
                  backgroundColor: Colors.red.shade50.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Cart Items (${cartItems.length})',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              TextButton(
                                onPressed: () {},
                                child: const Text(
                                  'Continue Shopping →',
                                  style: TextStyle(
                                    color: Color(0xFF047857),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32),
                          if (cartItems.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(child: Text("Cart is empty")),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: cartItems.length,
                              separatorBuilder: (_, _) => const Divider(
                                height: 32,
                                color: Color(0xFFF3F4F6),
                              ),
                              itemBuilder: (ctx, i) {
                                final item = cartItems[i];
                                final hasDiscount = i % 2 == 0;
                                final originalPrice = hasDiscount
                                    ? item.price * 1.1
                                    : item.price;

                                return Row(
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF047857),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.image,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Color(0xFF111827),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            item.isLoose ? '1 kg' : '1 pc',
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Sharma Kirana Store',
                                            style: TextStyle(
                                              color: Colors.grey.shade400,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (hasDiscount)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Text(
                                          '10% OFF',
                                          style: TextStyle(
                                            color: Color(0xFF166534),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    else
                                      const SizedBox(width: 50),
                                    const SizedBox(width: 24),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '₹${item.price.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                        if (hasDiscount)
                                          Text(
                                            '₹${originalPrice.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              decoration:
                                                  TextDecoration.lineThrough,
                                              color: Colors.grey.shade400,
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 24),
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.remove,
                                              size: 16,
                                            ),
                                            onPressed: () {
                                              if (item.quantity > 1) {
                                                cartProvider.updateQuantity(
                                                  item.id,
                                                  item.quantity - 1,
                                                );
                                              } else {
                                                cartProvider.removeItem(
                                                  item.id,
                                                );
                                              }
                                            },
                                            padding: const EdgeInsets.all(8),
                                            constraints: const BoxConstraints(),
                                          ),
                                          Text(
                                            item.quantity.toStringAsFixed(0),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.add,
                                              size: 16,
                                            ),
                                            onPressed: () =>
                                                cartProvider.updateQuantity(
                                                  item.id,
                                                  item.quantity + 1,
                                                ),
                                            padding: const EdgeInsets.all(8),
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    InkWell(
                                      onTap: () =>
                                          cartProvider.removeItem(item.id),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Saved for Later (2)',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              TextButton(
                                onPressed: () {},
                                child: const Text(
                                  'View All →',
                                  style: TextStyle(
                                    color: Color(0xFF047857),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSavedItemCard(
                                  "Aashirvaad Atta",
                                  "5 kg",
                                  "Sharma Kirana Store",
                                  "₹210",
                                  "₹230",
                                  "9% OFF",
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildSavedItemCard(
                                  "Dettol Soap",
                                  "125 g",
                                  "Verma Store",
                                  "₹45",
                                  "",
                                  "",
                                ),
                              ),
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
                          const Text(
                            'Order Summary',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Subtotal (${cartItems.length} items)',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                              Text(
                                '₹${subtotal.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Delivery Charges ',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                  Icon(
                                    Icons.info_outline,
                                    size: 14,
                                    color: Colors.grey.shade400,
                                  ),
                                ],
                              ),
                              Text(
                                '₹${deliveryFee.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Amount',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                Text(
                                  '₹${finalTotal.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: cartItems.isEmpty
                                  ? null
                                  : () {
                                      setState(() {
                                        _isCheckout = true;
                                      });
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF047857),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text(
                                    'Proceed to Checkout',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_forward,
                                    size: 16,
                                    color: Colors.white,
                                  ),
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
                          const Text(
                            'Delivery Information',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Color(0xFF047857),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Deliver to',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const Text(
                                      'Shivaji Nagar, Bhopal - 462001',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Change',
                                  style: TextStyle(
                                    color: Color(0xFF166534),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Builder(
                            builder: (context) {
                              final estimate = userProvider.getEstimatedDeliveryTime(deliveryType: 'Delivery');
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.shade100),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.local_shipping,
                                          color: Colors.blue,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Estimated Delivery Time',
                                                style: TextStyle(
                                                  color: Colors.blue,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  Text(
                                                    estimate.formattedWindow,
                                                    style: TextStyle(
                                                      color: Colors.blue.shade700,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    '(${estimate.formattedTimeRange})',
                                                    style: TextStyle(
                                                      color: Colors.blue.shade600,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      estimate.disclaimer,
                                      style: TextStyle(
                                        color: Colors.blue.shade700,
                                        fontSize: 10,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Available Offers',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              TextButton(
                                onPressed: () {},
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(50, 30),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'See All →',
                                  style: TextStyle(
                                    color: Color(0xFF047857),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildOfferCard(
                            Icons.local_offer,
                            const Color(0xFFDCFCE7),
                            const Color(0xFF166534),
                            "Get 10% OFF",
                            "On orders above ₹500",
                            const Color(0xFFDCFCE7),
                            const Color(0xFF166534),
                          ),
                          const Divider(height: 24),
                          _buildOfferCard(
                            Icons.local_shipping,
                            const Color(0xFFFFEDD5),
                            const Color(0xFFC2410C),
                            "Free Delivery",
                            "On orders above ₹700",
                            const Color(0xFFFFEDD5),
                            const Color(0xFFC2410C),
                          ),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'You Might Also Like',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              TextButton(
                                onPressed: () {},
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(50, 30),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'See All →',
                                  style: TextStyle(
                                    color: Color(0xFF047857),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSmallProductCard(
                                  "Surf Excel",
                                  "1 kg",
                                  "₹180",
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSmallProductCard(
                                  "Brooke Bond Tea",
                                  "500 g",
                                  "₹260",
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSmallProductCard(
                                  "Colgate Toothpaste",
                                  "200 g",
                                  "₹105",
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSavedItemCard(
    String title,
    String weight,
    String shop,
    String price,
    String oldPrice,
    String discount,
  ) {
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
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.image, color: Colors.grey),
              ),
              const Spacer(),
              const Icon(Icons.favorite_border, color: Colors.grey, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            weight,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            shop,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                price,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF111827),
                ),
              ),
              if (oldPrice.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  oldPrice,
                  style: TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: Colors.grey.shade400,
                    fontSize: 12,
                  ),
                ),
              ],
              if (discount.isNotEmpty) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    discount,
                    style: const TextStyle(
                      color: Color(0xFF166534),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Move to Cart',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferCard(
    IconData icon,
    Color iconBg,
    Color iconColor,
    String title,
    String subtitle,
    Color btnBg,
    Color btnColor,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF111827),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: btnBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Apply',
            style: TextStyle(
              color: btnColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
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
          Align(
            alignment: Alignment.topRight,
            child: const Icon(
              Icons.favorite_border,
              color: Colors.grey,
              size: 14,
            ),
          ),
          Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.image, color: Colors.grey, size: 16),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: Color(0xFF111827),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            weight,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                price,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFF111827),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF047857),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Add',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSaveCartAsListDialog(BuildContext context, CartProvider cart) {
    HapticFeedback.lightImpact();
    final nameCtrl = TextEditingController(text: 'My Grocery List');
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Save Cart as Shopping List', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Save all ${cart.itemCount} current cart items to quickly reorder next time.',
              style: const TextStyle(fontSize: 13, color: AppColors.textMid),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g. Weekly Grocery, Monthly Ration',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.bookmark_border_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              Navigator.pop(dialogCtx);
              await ShoppingListService().createListFromCart(
                name: name,
                customerPhone: userProvider.phoneNumber,
                shopId: shopProvider.currentShopId ?? '',
                cartItems: cart.itemsList,
              );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Saved "${nameCtrl.text}" to your shopping lists!'),
                    backgroundColor: AppColors.primaryDark,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Save List'),
          ),
        ],
      ),
    );
  }
}
