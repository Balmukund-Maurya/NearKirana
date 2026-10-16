import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:near_kirana/cart_provider.dart';
import 'package:near_kirana/user_provider.dart';
import 'package:near_kirana/shop_provider.dart';
import 'package:near_kirana/app_theme.dart';
import 'package:near_kirana/sound_service.dart';
import 'package:near_kirana/atomic_order_service.dart';
import 'package:near_kirana/payment_service.dart';
import 'package:near_kirana/address_selection_bottom_sheet.dart';
import 'package:near_kirana/coupon_model.dart';
import 'package:near_kirana/widgets/coupon_widgets.dart';
import 'package:near_kirana/widgets/digital_receipt_dialog.dart';
import 'package:near_kirana/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:near_kirana/widgets/payment_bottom_sheet.dart';

class DesktopCheckoutView extends StatefulWidget {
  final VoidCallback onBackToCart;
  final VoidCallback onOrderPlaced;

  const DesktopCheckoutView({
    super.key,
    required this.onBackToCart,
    required this.onOrderPlaced,
  });

  @override
  State<DesktopCheckoutView> createState() => _DesktopCheckoutViewState();
}

class _DesktopCheckoutViewState extends State<DesktopCheckoutView> {
  bool _isProcessingCheckout = false;
  int _selectedAddressIndex = 0;
  int _selectedPaymentIndex = 0; // 0: UPI, 1: Cash on Delivery, 2: Kirana Khata
  bool _showQrCode = false;
  final TextEditingController _instructionsController = TextEditingController();
  CouponValidationResult? _appliedCouponResult;

  final Color primaryGreen = const Color(
    0xFF0F766E,
  ); // or similar NearKirana green
  final Color activeLightGreen = const Color(0xFFF0FDF4);
  final Color activeBorderGreen = const Color(0xFF22C55E);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cartProvider = Provider.of<CartProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final shopProvider = Provider.of<ShopProvider>(context);
    final String currentShopId = shopProvider.currentShopId ?? '';
    final String customerPhone = userProvider.phoneNumber;
    final cartItems = cartProvider.itemsList;

    // Derived Calculations
    double minOrder = 300;
    double freeDeliveryThreshold = 1000;
    double deliveryFeeAmount = 20;

    final double subtotal = cartProvider.cartTotal; // Real subtotal from cart
    final bool canDeliver = subtotal >= minOrder;
    final double deliveryFee = (canDeliver && subtotal < freeDeliveryThreshold)
        ? deliveryFeeAmount
        : 0.0;

    // Promotional Coupon / Discount Engine (Feature 49)
    final double discount = _appliedCouponResult?.totalSavings ?? 0.0;
    final double finalTotal =
        max(0.0, subtotal + (canDeliver ? deliveryFee : 0) - discount);

    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 40 : 16,
          vertical: isDesktop ? 32 : 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: widget.onBackToCart,
                  icon: const Icon(
                    Icons.arrow_back,
                    size: 16,
                    color: Color(0xFF4B5563),
                  ),
                  label: Text(
                    isDesktop ? (l10n?.back_to_cart ?? "Back to Cart") : (l10n?.cancel ?? "Back"),
                    style: const TextStyle(
                      color: Color(0xFF4B5563),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 16 : 12,
                      vertical: isDesktop ? 16 : 12,
                    ),
                  ),
                ),
                SizedBox(width: isDesktop ? 24 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n?.checkout ?? "Checkout",
                        style: TextStyle(
                          fontSize: isDesktop ? 28 : 22,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Complete your order in a few simple steps",
                        style: TextStyle(
                          fontSize: isDesktop ? 14 : 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isDesktop ? 40 : 20),

            // PROGRESS TRACKER
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Row(
                  children: [
                    _buildStep(1, isDesktop ? (l10n?.delivery_address ?? 'Delivery Address') : (l10n?.address_lbl ?? 'Address'), isActive: true),
                    _buildLine(isActive: true),
                    _buildStep(2, isDesktop ? (l10n?.order_summary ?? 'Order Review') : "Review", isActive: false),
                    _buildLine(isActive: false),
                    _buildStep(3, isDesktop ? (l10n?.payment_method ?? 'Payment Method') : "Payment", isActive: false),
                    _buildLine(isActive: false),
                    _buildStep(4, isDesktop ? (l10n?.place_order ?? 'Place Order') : "Done", isActive: false),
                  ],
                ),
              ),
            ),
            SizedBox(height: isDesktop ? 40 : 24),

            // MAIN CONTENT
            Builder(
              builder: (context) {
                final leftColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      // SECTION 1: Delivery Address
                      _buildSectionHeader(
                        1,
                        l10n?.delivery_address ?? "Delivery Address",
                        "Select a delivery address for your order",
                        trailing: OutlinedButton.icon(
                          onPressed: () async {
                            await AddressSelectionBottomSheet.show(
                              context,
                              isCheckoutMode: true,
                            );
                            if (mounted) setState(() {});
                          },
                          icon: const Icon(
                            Icons.add,
                            size: 16,
                            color: Color(0xFF047857),
                          ),
                          label: Text(
                            l10n?.add_address_btn ?? "Manage / Add Address",
                            style: const TextStyle(
                              color: Color(0xFF047857),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF047857)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: EdgeInsets.only(left: isDesktop ? 48 : 0),
                        child: Column(
                          children: [
                            if (userProvider.savedAddressesList.isNotEmpty)
                              ...userProvider.savedAddressesList.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final addr = entry.value;
                                final serv = userProvider.evaluateAddressServiceability(addr);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildAddressCard(
                                    idx,
                                    addr.label,
                                    addr.formattedAddress,
                                    serv.isServiceable
                                        ? '${serv.distanceKm.toStringAsFixed(1)} km away • Deliverable'
                                        : (serv.errorMessage ?? 'Outside delivery area'),
                                    addr.icon,
                                    isDefault: addr.isDefault,
                                    isServiceable: serv.isServiceable,
                                    onTap: () {
                                      setState(() => _selectedAddressIndex = idx);
                                      userProvider.selectAddressForCheckout(addr);
                                    },
                                    onEdit: () async {
                                      await AddressSelectionBottomSheet.show(
                                        context,
                                        isCheckoutMode: true,
                                      );
                                      if (mounted) setState(() {});
                                    },
                                  ),
                                );
                              })
                            else
                              _buildAddressCard(
                                0,
                                userProvider.addressLabel.isNotEmpty ? userProvider.addressLabel : "Home",
                                userProvider.currentLat != null
                                    ? "${userProvider.customerHouseNo}, ${userProvider.autoLocality}"
                                    : "No saved address",
                                userProvider.currentLat != null
                                    ? userProvider.deliveryAddress
                                    : "Please tap 'Manage / Add Address' to set your delivery address",
                                Icons.home_outlined,
                                isDefault: true,
                                isServiceable: userProvider.isServiceable,
                                onTap: () async {
                                  await AddressSelectionBottomSheet.show(
                                    context,
                                    isCheckoutMode: true,
                                  );
                                  if (mounted) setState(() {});
                                },
                                onEdit: () async {
                                  await AddressSelectionBottomSheet.show(
                                    context,
                                    isCheckoutMode: true,
                                  );
                                  if (mounted) setState(() {});
                                },
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // SECTION 2: Delivery Instructions
                      _buildSectionHeader(
                        2,
                        "Delivery Instructions (Optional)",
                        "Add special instructions for delivery partner",
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: EdgeInsets.only(left: isDesktop ? 48 : 0),
                        child: TextField(
                          controller: _instructionsController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText:
                                "e.g. Ring the bell, leave at the door, call before delivery, etc.",
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                              borderSide: BorderSide(color: Color(0xFF047857)),
                            ),
                            counterText: "0/200",
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // SECTION 3: Payment Method
                      _buildSectionHeader(
                        3,
                        l10n?.payment_method ?? "Payment Method",
                        "Choose your preferred payment method",
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: EdgeInsets.only(left: isDesktop ? 48 : 0),
                        child: _buildZeptoBlinkitPaymentSection(
                          context: context,
                          shopUpiId: (shopProvider.shopUpiId ?? '').trim(),
                          shopName: (shopProvider.shopName ?? 'NearKirana Store').trim(),
                          finalTotal: finalTotal,
                          isDesktop: isDesktop,
                          l10n: l10n,
                        ),
                      ),
                    ],
                  );

                  // RIGHT COLUMN
                  final rightColumn = SizedBox(
                    width: isDesktop ? 380 : double.infinity,
                    child: Column(
                      children: [
                      // ORDER SUMMARY CARD
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
                                Expanded(
                                  child: Text(
                                    "${l10n?.order_summary ?? 'Order Summary'} (${cartItems.length} ${l10n?.items ?? 'items'})",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: widget.onBackToCart,
                                  child: Row(
                                    children: const [
                                      Icon(
                                        Icons.edit,
                                        size: 14,
                                        color: Color(0xFF047857),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        "Edit Cart",
                                        style: TextStyle(
                                          color: Color(0xFF047857),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // ITEMS LIST
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
                                // Mock some values for UI fidelity if real data doesn't have it
                                final bool hasDiscount = i % 2 == 0;
                                final double originalPrice = hasDiscount
                                    ? item.price * 1.1
                                    : item.price;

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Image Placeholder
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.image,
                                        color: Colors.grey,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF111827),
                                              fontSize: 14,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            item.isLoose ? "1 kg" : "1 pc",
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (hasDiscount) ...[
                                            const SizedBox(height: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFDCFCE7),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                "10% OFF",
                                                style: TextStyle(
                                                  color: Color(0xFF166534),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          "₹${item.price.toStringAsFixed(0)}",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                        if (hasDiscount)
                                          Text(
                                            "₹${originalPrice.toStringAsFixed(0)}",
                                            style: TextStyle(
                                              decoration:
                                                  TextDecoration.lineThrough,
                                              color: Colors.grey.shade400,
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 16),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        item.quantity.toStringAsFixed(0),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),

                            const Divider(height: 32, color: Color(0xFFE5E7EB)),

                            // COUPONS & DISCOUNT ENGINE (Feature 49)
                            CouponInputCard(
                              subtotal: subtotal,
                              shopId: currentShopId.isNotEmpty ? currentShopId : null,
                              customerPhone: customerPhone.isNotEmpty ? customerPhone : null,
                              appliedResult: _appliedCouponResult,
                              onCouponApplied: (result) {
                                setState(() {
                                  _appliedCouponResult = result;
                                });
                              },
                              onCouponRemoved: () {
                                setState(() {
                                  _appliedCouponResult = null;
                                });
                              },
                            ),
                            const SizedBox(height: 16),

                            // PRICE DETAILS
                            Text(
                              l10n?.bill_details ?? "Price Details",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "${l10n?.subtotal ?? 'Subtotal'} (${cartItems.length} ${l10n?.items ?? 'items'})",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  "₹${subtotal.toStringAsFixed(0)}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
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
                                      "${l10n?.delivery_charges ?? 'Delivery Charges'} ",
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
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
                                  deliveryFee == 0 ? (l10n?.free_delivery_label ?? "FREE") : "₹${deliveryFee.toStringAsFixed(0)}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: deliveryFee == 0 ? const Color(0xFF166534) : const Color(0xFF111827),
                                  ),
                                ),
                              ],
                            ),
                            if (discount > 0) ...[
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    l10n?.coupon_discount ?? "Discount",
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    "- ₹${discount.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                      color: Color(0xFF166534),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            const SizedBox(height: 20),
                            // TOTAL AMOUNT
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    l10n?.total_amount ?? "Total Amount",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  Text(
                                    "₹${finalTotal.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            if (discount > 0) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.local_offer,
                                      color: Color(0xFF166534),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "You are saving ₹${discount.toStringAsFixed(0)} on this order!",
                                      style: const TextStyle(
                                        color: Color(0xFF166534),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),
                            // PLACE ORDER BUTTON
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _isProcessingCheckout
                                    ? null
                                    : () => _executeOrder(
                                        context,
                                        cartProvider,
                                        finalTotal,
                                        deliveryFee,
                                      ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF047857),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isProcessingCheckout
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              _selectedPaymentIndex == 0
                                                  ? "Pay Online / UPI \u2022 \u20b9${finalTotal.toStringAsFixed(0)}"
                                                  : _selectedPaymentIndex == 2
                                                      ? "Order via Khata \u2022 \u20b9${finalTotal.toStringAsFixed(0)}"
                                                      : "Place Order (COD) \u2022 \u20b9${finalTotal.toStringAsFixed(0)}",
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14.5,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Icon(
                                            Icons.arrow_forward,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.security,
                                  size: 14,
                                  color: Color(0xFF047857),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    "Your payment information is secure and encrypted",
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 11,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                      // DELIVERY INFO BOX
                      Builder(
                        builder: (context) {
                          final estimate = userProvider.getEstimatedDeliveryTime(deliveryType: 'Delivery');
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
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
                                      size: 26,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "Estimated Delivery Time",
                                            style: TextStyle(
                                              color: Colors.blue,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Wrap(
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            spacing: 8,
                                            children: [
                                              Text(
                                                estimate.formattedWindow,
                                                style: TextStyle(
                                                  color: Colors.blue.shade800,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              Text(
                                                "(${estimate.formattedTimeRange})",
                                                style: TextStyle(
                                                  color: Colors.blue.shade600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      size: 13,
                                      color: Colors.blue.shade600,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        estimate.disclaimer,
                                        style: TextStyle(
                                          color: Colors.blue.shade700,
                                          fontSize: 10,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );

                if (isDesktop) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: leftColumn,
                      ),
                      const SizedBox(width: 32),
                      rightColumn,
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      leftColumn,
                      const SizedBox(height: 32),
                      rightColumn,
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // UI HELPERS

  Widget _buildStep(int stepNum, String label, {required bool isActive}) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF047857) : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            stepNum.toString(),
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey.shade500,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 75,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isActive ? const Color(0xFF111827) : Colors.grey.shade400,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLine({required bool isActive}) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 24, left: 8, right: 8),
        color: isActive ? const Color(0xFF047857) : Colors.grey.shade200,
      ),
    );
  }

  Widget _buildSectionHeader(
    int stepNum,
    String title,
    String subtitle, {
    Widget? trailing,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 500;
        final headerContent = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF047857),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                stepNum.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        );

        if (trailing == null) {
          return headerContent;
        }

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              headerContent,
              const SizedBox(height: 12),
              trailing,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: headerContent),
            const SizedBox(width: 16),
            trailing,
          ],
        );
      },
    );
  }

  Widget _buildAddressCard(
    int index,
    String type,
    String title,
    String address,
    IconData icon, {
    bool isDefault = false,
    bool isServiceable = true,
    VoidCallback? onTap,
    VoidCallback? onEdit,
  }) {
    final isSelected = _selectedAddressIndex == index;
    return InkWell(
      onTap: onTap ?? () => setState(() => _selectedAddressIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? activeLightGreen : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? activeBorderGreen
                : (!isServiceable ? Colors.red.shade200 : Colors.grey.shade200),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Custom Radio
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? activeBorderGreen : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: isSelected
                  ? Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: activeBorderGreen,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            // Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Icon(icon, color: const Color(0xFF4B5563), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        type,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF111827),
                        ),
                      ),
                      if (isDefault)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "Default",
                            style: TextStyle(
                              color: Color(0xFF166534),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (!isServiceable)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "Not Serviceable",
                            style: TextStyle(
                              color: Color(0xFFB91C1C),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF374151),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    address,
                    style: TextStyle(
                      color: !isServiceable
                          ? Colors.red.shade700
                          : Colors.grey.shade500,
                      fontSize: 13,
                      fontWeight:
                          !isServiceable ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onEdit ?? () {},
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFE5E7EB)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.edit, size: 14, color: Color(0xFF374151)),
                  SizedBox(width: 4),
                  Text(
                    "Edit",
                    style: TextStyle(color: Color(0xFF374151), fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZeptoBlinkitPaymentSection({
    required BuildContext context,
    required String shopUpiId,
    required String shopName,
    required double finalTotal,
    required bool isDesktop,
    AppLocalizations? l10n,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 3 Modern Quick-Commerce Payment Method Cards
        if (isDesktop)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildPaymentOptionCard(
                    index: 0,
                    icon: Icons.bolt_rounded,
                    title: l10n?.pay_online_upi ?? "UPI",
                    subtitle: "Google Pay, PhonePe, Paytm, QR",
                    badgeText: "⚡ FASTEST",
                    badgeColor: const Color(0xFF047857),
                    iconColor: const Color(0xFF047857),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPaymentOptionCard(
                    index: 1,
                    icon: Icons.payments_rounded,
                    title: l10n?.cash_on_delivery ?? "Cash on Delivery",
                    subtitle: "Pay cash or scan QR at doorstep",
                    badgeText: "POPULAR",
                    badgeColor: const Color(0xFF2563EB),
                    iconColor: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPaymentOptionCard(
                    index: 2,
                    icon: Icons.menu_book_rounded,
                    title: "Kirana Khata",
                    subtitle: "Add to monthly store ledger",
                    badgeText: "0% INTEREST",
                    badgeColor: const Color(0xFFD97706),
                    iconColor: const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              _buildPaymentOptionCard(
                index: 0,
                icon: Icons.bolt_rounded,
                title: l10n?.pay_online_upi ?? "UPI",
                subtitle: "Google Pay, PhonePe, Paytm, or QR",
                badgeText: "⚡ FASTEST",
                badgeColor: const Color(0xFF047857),
                iconColor: const Color(0xFF047857),
              ),
              const SizedBox(height: 10),
              _buildPaymentOptionCard(
                index: 1,
                icon: Icons.payments_rounded,
                title: l10n?.cash_on_delivery ?? "Cash on Delivery",
                subtitle: "Pay cash or scan QR at your doorstep",
                badgeText: "POPULAR",
                badgeColor: const Color(0xFF2563EB),
                iconColor: const Color(0xFF2563EB),
              ),
              const SizedBox(height: 10),
              _buildPaymentOptionCard(
                index: 2,
                icon: Icons.menu_book_rounded,
                title: "Kirana Khata (Pay Later)",
                subtitle: "Add to monthly store ledger (verified)",
                badgeText: "0% INTEREST",
                badgeColor: const Color(0xFFD97706),
                iconColor: const Color(0xFFD97706),
              ),
            ],
          ),

        // Contextual Details Section based on selected payment method
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _selectedPaymentIndex == 0
              ? _buildUpiDetailBox(
                  context: context,
                  shopUpiId: shopUpiId,
                  shopName: shopName,
                  finalTotal: finalTotal,
                )
              : _selectedPaymentIndex == 1
                  ? _buildCodDetailBox(finalTotal: finalTotal)
                  : _buildKhataDetailBox(),
        ),

        // Security & NPCI Assurance Strip (Blinkit / Zepto trust badge)
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.verified_user_rounded,
                color: Color(0xFF047857),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "100% Safe & Secure Payments • NPCI UPI Certified",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF374151),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.lock, size: 12, color: Color(0xFF047857)),
                    SizedBox(width: 4),
                    Text(
                      "Encrypted",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentOptionCard({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required Color iconColor,
  }) {
    final isSelected = _selectedPaymentIndex == index;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedPaymentIndex = index);
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? activeLightGreen : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeBorderGreen : Colors.grey.shade200,
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeBorderGreen.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF047857).withValues(alpha: 0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? const Color(0xFF047857) : iconColor,
                    size: 22,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? activeBorderGreen : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: isSelected
                      ? Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: activeBorderGreen,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
                color: isSelected ? const Color(0xFF065F46) : const Color(0xFF111827),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpiDetailBox({
    required BuildContext context,
    required String shopUpiId,
    required String shopName,
    required double finalTotal,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFA7F3D0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF047857).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Color(0xFF047857),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Instant UPI Payment",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    Text(
                      "Pay directly to store via Google Pay, PhonePe, Paytm, or BHIM",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Supported UPI Apps Row
          Row(
            children: [
              _buildUpiAppChip(
                name: "GPay",
                bgColor: const Color(0xFFE8F0FE),
                textColor: const Color(0xFF1A73E8),
              ),
              const SizedBox(width: 8),
              _buildUpiAppChip(
                name: "PhonePe",
                bgColor: const Color(0xFFF3E8FF),
                textColor: const Color(0xFF5F259F),
              ),
              const SizedBox(width: 8),
              _buildUpiAppChip(
                name: "Paytm",
                bgColor: const Color(0xFFE0F2FE),
                textColor: const Color(0xFF002E6E),
              ),
              const SizedBox(width: 8),
              _buildUpiAppChip(
                name: "BHIM / Any",
                bgColor: const Color(0xFFFFF7ED),
                textColor: const Color(0xFFC2410C),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (shopUpiId.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Store UPI ID is being updated. You can proceed with Cash on Delivery at your doorstep.",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Store UPI ID with 1-Tap Copy
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Store UPI VPA",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      Text(
                        shopUpiId,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: shopUpiId));
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("UPI ID copied to clipboard"),
                          duration: Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.copy_rounded, size: 14, color: Color(0xFF047857)),
                          SizedBox(width: 4),
                          Text(
                            "Copy",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Action Buttons: Pay via UPI App OR Scan QR
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _launchUpiApp(
                      context: context,
                      shopUpiId: shopUpiId,
                      shopName: shopName,
                      finalTotal: finalTotal,
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: Text(
                      "Pay via UPI App (₹${finalTotal.toStringAsFixed(0)})",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF047857),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _showQrCode = !_showQrCode);
                  },
                  icon: Icon(
                    _showQrCode ? Icons.visibility_off_outlined : Icons.qr_code_2_rounded,
                    size: 16,
                  ),
                  label: Text(_showQrCode ? "Hide QR" : "Show QR"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF047857),
                    side: const BorderSide(color: Color(0xFF047857)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),
              ],
            ),

            if (_showQrCode) ...[
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      QrImageView(
                        data: 'upi://pay?pa=$shopUpiId&pn=${Uri.encodeComponent(shopName)}&am=${finalTotal.toStringAsFixed(2)}&cu=INR&tn=${Uri.encodeComponent('NearKirana Order')}',
                        version: QrVersions.auto,
                        size: 150.0,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Scan to Pay ₹${finalTotal.toStringAsFixed(2)}",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF047857),
                        ),
                      ),
                      Text(
                        "Google Pay • PhonePe • Paytm • BHIM",
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],


          ],
        ],
      ),
    );
  }

  Widget _buildCodDetailBox({required double finalTotal}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFDBEAFE),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.delivery_dining_rounded,
              color: Color(0xFF1D4ED8),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Pay ₹${finalTotal.toStringAsFixed(0)} on Delivery",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: const Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Pay in cash or ask delivery partner to scan their UPI QR code upon arrival at your doorstep.",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKhataDetailBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: Color(0xFFB45309),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Kirana Khata (Pay Later / Udhaar)",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Order amount will be added to your verified monthly shop ledger. Settle weekly or at month end directly with the store owner.",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUpiApp({
    required BuildContext context,
    required String shopUpiId,
    required String shopName,
    required double finalTotal,
  }) async {
    HapticFeedback.lightImpact();
    final upiUrl =
        'upi://pay?pa=$shopUpiId&pn=${Uri.encodeComponent(shopName)}&am=${finalTotal.toStringAsFixed(2)}&cu=INR&tn=${Uri.encodeComponent('NearKirana Order')}';
    try {
      final uri = Uri.parse(upiUrl);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("UPI App me payment complete karein. Payment hone ke baad order place karein."),
            backgroundColor: Color(0xFF047857),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
          ),
        );
      } else if (!launched && context.mounted) {
        setState(() => _showQrCode = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No UPI app found. Please scan the QR code to pay!"),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        setState(() => _showQrCode = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Could not open UPI app directly. Scan the QR code below."),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildUpiAppChip({
    required String name,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }


  // ─────────────────────────────────────────────────────────
  // EXECUTE ORDER — Zepto/Blinkit style: Payment sheet first,
  // then order placed only after successful payment.
  // ─────────────────────────────────────────────────────────
  Future<void> _executeOrder(
    BuildContext context,
    CartProvider cartProvider,
    double finalTotal,
    double deliveryFee,
  ) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.currentLat == null || userProvider.currentLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please add a delivery address first"),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isProcessingCheckout = true);
    try {
      final String customerName =
          userProvider.customerName.isEmpty ? "Customer" : userProvider.customerName;
      final String phone = userProvider.phoneNumber.trim();
      if (phone.isEmpty || phone == "0000000000" || phone.length != 10) {
        setState(() => _isProcessingCheckout = false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Please login with a valid 10-digit phone number"),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final shopProvider = Provider.of<ShopProvider>(context, listen: false);
      final String shopId = shopProvider.currentShopId ?? '';
      final String shopName = shopProvider.currentShopName.isNotEmpty
          ? shopProvider.currentShopName
          : 'NearKirana Store';
      final String shopUpiId = (shopProvider.shopUpiId ?? '').trim();

      // Fetch Razorpay key (from provider or Firestore fallback)
      String rzpKey = shopProvider.razorpayKeyId ?? '';
      if (rzpKey.isEmpty) {
        try {
          final settingsDoc = await FirebaseUtils.firestore
              .collection('admin_settings')
              .doc('general')
              .get();
          if (settingsDoc.exists && settingsDoc.data()?['razorpay_key_id'] != null) {
            rzpKey = (settingsDoc.data()!['razorpay_key_id'] as String).trim();
          }
        } catch (_) {}
      }

      // Check if user is banned
      QuerySnapshot<Map<String, dynamic>>? customerQuery;
      try {
        customerQuery = await FirebaseUtils.firestore
            .collection('customers')
            .where('mobile', isEqualTo: phone)
            .where('shop_ids', arrayContains: shopId)
            .limit(1)
            .get();
        if (customerQuery.docs.isNotEmpty) {
          final d = customerQuery.docs.first.data();
          if (d['is_banned'] == true) {
            setState(() => _isProcessingCheckout = false);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Aapka account block kar diya gaya hai. Kripya dukan par sampark karein.'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
            return;
          }
        }
      } catch (e) {
        debugPrint('Ban check error: $e');
      }

      // Khata eligibility check
      bool khataEligible = false;
      if (customerQuery != null && customerQuery.docs.isNotEmpty) {
        final d = customerQuery.docs.first.data();
        final double creditLimit = (d['credit_limit'] as num?)?.toDouble() ?? 5000.0;
        final shopBalances = d['shop_balances'] as Map<String, dynamic>?;
        final double currentUdhaar =
            (shopBalances?[shopId] as num?)?.toDouble() ??
            ((d['total_udhaar'] as num?)?.toDouble() ?? 0.0);
        khataEligible = (currentUdhaar + finalTotal) <= creditLimit;
      }

      setState(() => _isProcessingCheckout = false);

      // ── OPEN PAYMENT BOTTOM SHEET (Zepto/Blinkit style) ──
      if (!context.mounted) return;
      final payResult = await PaymentBottomSheet.show(
        context,
        amount: finalTotal,
        shopUpiId: shopUpiId,
        shopName: shopName,
        razorpayKeyId: rzpKey,
        customerPhone: phone,
        customerName: customerName,
        shopId: shopId,
        khataEligible: khataEligible,
      );

      // User dismissed the sheet without paying
      if (payResult == null || payResult is PaymentSheetCancelled) return;

      // ── PLACE ORDER (only reached after payment success/selection) ──
      setState(() => _isProcessingCheckout = true);

      String paymentMethod;
      String paymentStatus;
      String? finalUpiRefId;
      Map<String, dynamic> extraPaymentData = {};

      if (payResult is PaymentSheetRazorpaySuccess) {
        paymentMethod = payResult.paymentMethod;
        paymentStatus = payResult.paymentStatus;
        finalUpiRefId = payResult.razorpayPaymentId;
        extraPaymentData = Map<String, dynamic>.from(payResult.extraData);
      } else if (payResult is PaymentSheetUpiQrPending) {
        paymentMethod = payResult.paymentMethod;
        paymentStatus = payResult.paymentStatus;
        extraPaymentData = Map<String, dynamic>.from(payResult.extraData);
      } else if (payResult is PaymentSheetCodSelected) {
        // Khata credit limit final check
        if (customerQuery != null && customerQuery.docs.isNotEmpty) {
          // (already checked above — safe to proceed)
        }
        paymentMethod = payResult.paymentMethod;
        paymentStatus = payResult.paymentStatus;
      } else if (payResult is PaymentSheetKhataSelected) {
        // Final khata validation
        if (!khataEligible) {
          setState(() => _isProcessingCheckout = false);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Khata credit limit exceed ho rahi hai. COD ya UPI chunein.'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }
        paymentMethod = payResult.paymentMethod;
        paymentStatus = payResult.paymentStatus;
      } else {
        setState(() => _isProcessingCheckout = false);
        return;
      }

      // Build delivery address
      String finalDeliveryAddress = 'House: \${userProvider.customerHouseNo}';
      if (userProvider.customerLandmark.isNotEmpty) {
        finalDeliveryAddress += ', Landmark: \${userProvider.customerLandmark}';
      }
      finalDeliveryAddress += ' — (Locality: \${userProvider.autoLocality})';
      if (userProvider.addressLabel.isNotEmpty) {
        finalDeliveryAddress += ' [\${userProvider.addressLabel}]';
      }

      final items = cartProvider.itemsList
          .map((item) => OrderItemRequest(
                productId: item.id,
                name: item.name,
                price: item.price,
                quantity: item.quantity,
                isLoose: item.isLoose,
                imageUrl: item.imageUrl,
              ))
          .toList();

      final idempotencyKey =
          'pay_\${phone}_\${DateTime.now().millisecondsSinceEpoch}_\${Random().nextInt(999999)}';

      final estimate = userProvider.getEstimatedDeliveryTime(deliveryType: 'Delivery');

      final result = await AtomicOrderService.instance.placeOrderAtomic(
        OrderPlacementParams(
          shopId: shopId,
          customerName: customerName,
          customerPhone: phone,
          deliveryAddress: finalDeliveryAddress,
          customerLat: userProvider.currentLat,
          customerLng: userProvider.currentLng,
          deliveryType: 'Delivery',
          deliveryFee: deliveryFee,
          paymentMethod: paymentMethod,
          paymentStatus: paymentStatus,
          upiRefId: finalUpiRefId,
          instructions: _instructionsController.text.trim(),
          idempotencyKey: idempotencyKey,
          couponCode: _appliedCouponResult?.coupon?.code,
          items: items,
          extraData: {
            'estimated_delivery_window': estimate.formattedWindow,
            'estimated_delivery_min_minutes': estimate.minMinutes,
            'estimated_delivery_max_minutes': estimate.maxMinutes,
            'estimated_delivery_arrival_range': estimate.formattedTimeRange,
            'estimated_delivery_disclaimer': estimate.disclaimer,
            'estimated_delivery_details': estimate.toMap(),
            ...extraPaymentData,
          },
        ),
      );

      // If Razorpay payment succeeded, write payment audit trail
      if (payResult is PaymentSheetRazorpaySuccess && finalUpiRefId != null) {
        try {
          final session = await PaymentService().initiateOnlinePayment(
            orderId: result.orderId,
            shopId: shopId,
            amount: result.totalAmount,
            customerPhone: phone,
            customerName: customerName,
            paymentMethod: paymentMethod,
          );
          await PaymentService().verifyAndConfirmGatewayPayment(
            orderId: result.orderId,
            transactionId: session.transactionId,
            gatewayPaymentRef: finalUpiRefId,
            gatewaySignature: extraPaymentData['razorpay_signature']?.toString(),
            verifiedBy: 'Razorpay Gateway',
          );
        } catch (e) {
          debugPrint('Payment audit trail warning: $e');
        }
      }

      final receiptOrderData = {
        'order_id': result.orderId,
        'items': items.map((i) => {
          'id': i.productId, 'name': i.name, 'quantity': i.quantity,
          'price': i.price, 'total_price': i.quantity * i.price, 'is_loose': i.isLoose,
        }).toList(),
        'subtotal': cartProvider.cartTotal,
        'discount': _appliedCouponResult?.discountAmount ?? 0.0,
        'coupon_code': _appliedCouponResult?.coupon?.code,
        'delivery_fee': deliveryFee,
        'total_amount': result.totalAmount,
        'payment_method': paymentMethod,
        'payment_status': paymentStatus,
        'customer_name': customerName,
        'phone_number': phone,
        'delivery_address': finalDeliveryAddress,
        'delivery_pin': result.deliveryPin,
        'created_at': DateTime.now().toIso8601String(),
      };

      cartProvider.clearCart();
      SoundService().orderSuccess();

      if (!context.mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            Navigator.pop(ctx);
            widget.onOrderPlaced();
          },
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(color: const Color(0xFFF0FDF4), shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF22C55E), width: 2)),
                  child: const Icon(Icons.check_rounded, color: Color(0xFF047857), size: 40),
                ),
                const SizedBox(height: 16),
                Text(
                  result.isDuplicate ? "Order Already Received!" : "Order Placed Successfully! 🎉",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "Your order will be delivered soon.\nDelivery PIN: \${result.deliveryPin}",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                if (paymentStatus == PaymentStatus.pendingVerification) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        'Payment verification pending. Dukan par confirm hoga.',
                        style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                      )),
                    ]),
                  ),
                ],
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => DigitalReceiptDialog.showForOrder(ctx, orderData: receiptOrderData, orderId: result.orderId),
                  icon: const Icon(Icons.receipt_long, size: 18),
                  label: const Text("View Digital Receipt"),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () { Navigator.pop(ctx); widget.onOrderPlaced(); },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF047857),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text("Continue Shopping", style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      if (mounted) widget.onOrderPlaced();

    } on InsufficientStockException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.userFriendlyMessage), backgroundColor: AppColors.error),
      );
    } on InvalidCouponException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Coupon Error: ${e.message}"), backgroundColor: AppColors.error),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to place order: $e"), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isProcessingCheckout = false);
    }
  }
}
