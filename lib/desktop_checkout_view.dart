import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:google_fonts/google_fonts.dart';

import 'package:near_kirana/cart_provider.dart';
import 'package:near_kirana/user_provider.dart';
import 'package:near_kirana/shop_provider.dart';
import 'package:near_kirana/app_theme.dart';
import 'package:near_kirana/sound_service.dart';
import 'package:near_kirana/atomic_order_service.dart';
import 'package:near_kirana/payment_service.dart';
import 'package:near_kirana/razorpay_service.dart';
import 'package:near_kirana/address_selection_bottom_sheet.dart';
import 'package:near_kirana/coupon_model.dart';
import 'package:near_kirana/widgets/coupon_widgets.dart';
import 'package:near_kirana/widgets/digital_receipt_dialog.dart';
import 'package:near_kirana/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:near_kirana/saved_address_model.dart';
import 'package:near_kirana/language_provider.dart';

class DesktopCheckoutView extends StatefulWidget {
  final VoidCallback onBackToCart;
  final VoidCallback onOrderPlaced;
  final String deliveryType;

  const DesktopCheckoutView({
    super.key,
    required this.onBackToCart,
    required this.onOrderPlaced,
    this.deliveryType = 'Delivery',
  });

  @override
  State<DesktopCheckoutView> createState() => _DesktopCheckoutViewState();
}

class _DesktopCheckoutViewState extends State<DesktopCheckoutView> {
  bool get _isPickup => widget.deliveryType.toLowerCase() == 'pickup';
  bool _isProcessingCheckout = false;
  int _selectedAddressIndex = 0;
  int _selectedPaymentIndex = 0; // 0: UPI, 1: Cash on Delivery, 2: Kirana Khata
  final TextEditingController _instructionsController = TextEditingController();
  final ScrollController _mobileScrollController = ScrollController();
  final Set<String> _selectedInstructionChips = {};
  CouponValidationResult? _appliedCouponResult;

  // Khata Verification State (Offline customers created by shop owner)
  bool _isLoadingKhata = true;
  bool _hasShopKhata = false;
  double _khataCreditLimit = 5000.0;
  double _currentKhataBalance = 0.0;
  String? _checkedShopId;
  String? _checkedPhone;

  final Color primaryGreen = AppColors.primaryDark;
  final Color activeLightGreen = const Color(0xFFF0FDF4);
  final Color activeBorderGreen = const Color(0xFF22C55E);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkCustomerKhata();
    });
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    _mobileScrollController.dispose();
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
    if ((currentShopId != _checkedShopId || customerPhone != _checkedPhone) && !_isLoadingKhata) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkCustomerKhata());
    }
    final cartItems = cartProvider.itemsList;

    // Derived Calculations
    double minOrder = 300;
    double freeDeliveryThreshold = 1000;
    double deliveryFeeAmount = 20;

    final double subtotal = cartProvider.cartTotal; // Real subtotal from cart
    final bool canDeliver = _isPickup ? true : (subtotal >= minOrder);
    final double deliveryFee = _isPickup
        ? 0.0
        : ((canDeliver && subtotal < freeDeliveryThreshold)
            ? deliveryFeeAmount
            : 0.0);

    // Promotional Coupon / Discount Engine (Feature 49)
    final double discount = _appliedCouponResult?.totalSavings ?? 0.0;
    final double finalTotal =
        max(0.0, subtotal + (_isPickup ? 0.0 : (canDeliver ? deliveryFee : 0)) - discount);

    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;

    if (!isDesktop) {
      return _buildMobileZeptoBlinkitCheckout(
        context: context,
        l10n: l10n,
        cartProvider: cartProvider,
        userProvider: userProvider,
        shopProvider: shopProvider,
        cartItems: cartItems,
        subtotal: subtotal,
        deliveryFee: deliveryFee,
        discount: discount,
        finalTotal: finalTotal,
        canDeliver: canDeliver,
        currentShopId: currentShopId,
        customerPhone: customerPhone,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
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
                    _buildStep(1, _isPickup ? (l10n?.store_pickup ?? 'Store Pickup') : (isDesktop ? (l10n?.delivery_address ?? 'Delivery Address') : (l10n?.address_lbl ?? 'Address')), isActive: true),
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
                      // SECTION 1: Delivery Address or Store Pickup Location
                      _buildSectionHeader(
                        1,
                        _isPickup
                            ? (l10n?.store_pickup ?? "Store Pickup Location")
                            : (l10n?.delivery_address ?? "Delivery Address"),
                        _isPickup
                            ? "Pick up your order directly from the shop counter"
                            : "Select a delivery address for your order",
                        trailing: _isPickup
                            ? null
                            : OutlinedButton.icon(
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
                        child: _isPickup
                            ? _buildStorePickupCard(shopProvider)
                            : Column(
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

                      // SECTION 2: Delivery Instructions / Store Pickup Note
                      _buildSectionHeader(
                        2,
                        _isPickup ? "Store Pickup Note (Optional)" : "Delivery Instructions (Optional)",
                        _isPickup ? "Add a note for the shopkeeper" : "Add special instructions for delivery partner",
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
                              deliveryFee: deliveryFee,
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
                                                      : "${_isPickup ? 'Pay at Store' : 'Place Order (COD)'} \u2022 \u20b9${finalTotal.toStringAsFixed(0)}",
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
                          final estimate = userProvider.getEstimatedDeliveryTime(deliveryType: _isPickup ? 'Pickup' : 'Delivery');
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
                                    Icon(
                                      _isPickup ? Icons.storefront_rounded : Icons.local_shipping,
                                      color: Colors.blue,
                                      size: 26,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _isPickup ? "Estimated Pickup Ready Time" : "Estimated Delivery Time",
                                            style: const TextStyle(
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

  // ==========================================
  // MOBILE ZEPTO / BLINKIT CHECKOUT EXPERIENCE
  // ==========================================

  Widget _buildMobileZeptoBlinkitCheckout({
    required BuildContext context,
    required AppLocalizations? l10n,
    required CartProvider cartProvider,
    required UserProvider userProvider,
    required ShopProvider shopProvider,
    required List<dynamic> cartItems,
    required double subtotal,
    required double deliveryFee,
    required double discount,
    required double finalTotal,
    required bool canDeliver,
    required String currentShopId,
    required String customerPhone,
  }) {
    final estimate = userProvider.getEstimatedDeliveryTime(deliveryType: _isPickup ? 'Pickup' : 'Delivery');
    final String shopName = (shopProvider.shopName ?? 'NearKirana Store').trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(7),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 15,
              color: AppColors.textDark,
            ),
          ),
          onPressed: widget.onBackToCart,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isPickup ? "Store Pickup" : (l10n?.checkout ?? "Checkout"),
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            Text(
              "${cartItems.length} items • ₹${finalTotal.toStringAsFixed(0)}",
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textMid,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE5E7EB), height: 1),
        ),
      ),
      body: SingleChildScrollView(
        controller: _mobileScrollController,
        padding: const EdgeInsets.only(left: 14, right: 14, top: 12, bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Zepto / Blinkit Delivery or Pickup ETA Banner
            _buildMobileDeliveryEtaBanner(estimate, cartItems.length, shopName),

            const SizedBox(height: 12),

            // 2. Zepto / Blinkit Delivery Address or Store Pickup Card
            if (_isPickup)
              _buildStorePickupCard(shopProvider)
            else
              _buildMobileAddressCard(context, userProvider, l10n),

            if (!_isPickup) ...[
              const SizedBox(height: 12),

              // 3. Zepto / Blinkit Delivery Instructions Card
              _buildMobileDeliveryInstructionsCard(),
            ],

            const SizedBox(height: 12),

            // 4. Zepto / Blinkit Review Items Preview
            _buildMobileCartItemsCard(cartItems, l10n),

            const SizedBox(height: 12),

            // 5. Promotional Coupon & Discount Engine
            CouponInputCard(
              subtotal: subtotal,
              deliveryFee: deliveryFee,
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

            const SizedBox(height: 12),

            // 6. Payment Method Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 18,
                        color: AppColors.primaryDark,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n?.payment_method ?? "Payment Method",
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildZeptoBlinkitPaymentSection(
                    context: context,
                    shopUpiId: (shopProvider.shopUpiId ?? '').trim(),
                    shopName: shopName,
                    finalTotal: finalTotal,
                    isDesktop: false,
                    l10n: l10n,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 7. Bill Details Breakdown
            _buildMobileBillDetailsCard(
              subtotal: subtotal,
              deliveryFee: deliveryFee,
              discount: discount,
              finalTotal: finalTotal,
              cartItemsCount: cartItems.length,
              l10n: l10n,
            ),

            const SizedBox(height: 12),

            // 8. Cancellation Policy & Trust Card
            _buildMobileTrustAndPolicyCard(),

            const SizedBox(height: 16),
          ],
        ),
      ),
      bottomNavigationBar: _buildMobileStickyBottomBar(
        context: context,
        cartProvider: cartProvider,
        finalTotal: finalTotal,
        deliveryFee: deliveryFee,
        discount: discount,
      ),
    );
  }

  Widget _buildMobileDeliveryEtaBanner(
    dynamic estimate,
    int itemCount,
    String shopName,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F5E9), Color(0xFFF7FAF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC8E6C9), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.primaryDark,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPickup ? Icons.storefront_rounded : Icons.bolt_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _isPickup ? "Pickup Ready Time" : "Estimated Delivery Time",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            estimate.formattedWindow,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isPickup
                          ? "Pick up $itemCount items from $shopName counter"
                          : "Shipment of $itemCount items from $shopName",
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: AppColors.textMid,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 12, color: Colors.blue.shade700),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    estimate.disclaimer,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: Colors.blue.shade800,
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

  Widget _buildStorePickupCard(ShopProvider shopProvider) {
    final String shopName = (shopProvider.shopName ?? 'NearKirana Store').trim();
    final String shopAddress = (shopProvider.shopAddress ?? 'Shop Counter / Store Location').trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.primaryDark,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            shopName,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "STORE PICKUP",
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF166534),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      shopAddress,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textDark,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Collect directly at the store billing counter",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.textMid,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 14,
                  color: AppColors.success,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Self Pickup • Free Service Fee • Quick Counter Handover",
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF166534),
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

  Widget _buildMobileAddressCard(
    BuildContext context,
    UserProvider userProvider,
    AppLocalizations? l10n,
  ) {
    SavedAddress? selectedAddr;
    if (userProvider.savedAddressesList.isNotEmpty) {
      if (_selectedAddressIndex >= 0 &&
          _selectedAddressIndex < userProvider.savedAddressesList.length) {
        selectedAddr = userProvider.savedAddressesList[_selectedAddressIndex];
      } else {
        selectedAddr = userProvider.savedAddressesList.first;
      }
    }

    final String addressLabel = selectedAddr?.label ??
        (userProvider.addressLabel.isNotEmpty ? userProvider.addressLabel : "Home");
    final String formattedAddress = selectedAddr?.formattedAddress ??
        (userProvider.currentLat != null
            ? "${userProvider.customerHouseNo.isNotEmpty ? '${userProvider.customerHouseNo}, ' : ''}${userProvider.autoLocality}"
            : "No delivery address selected");
    final bool isServiceable = selectedAddr != null
        ? userProvider.evaluateAddressServiceability(selectedAddr).isServiceable
        : userProvider.isServiceable;
    final double distKm = selectedAddr != null
        ? userProvider.evaluateAddressServiceability(selectedAddr).distanceKm
        : (userProvider.currentLat != null && userProvider.currentLng != null
            ? userProvider
                .evaluateAddressServiceability(SavedAddress(
                  id: 'current',
                  label: 'Home',
                  address: userProvider.deliveryAddress,
                  latitude: userProvider.currentLat!,
                  longitude: userProvider.currentLng!,
                ))
                .distanceKm
            : 0.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.home_rounded,
                  color: AppColors.primaryDark,
                  size: 22,
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
                          addressLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "DEFAULT",
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF166534),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      formattedAddress,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textDark,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (userProvider.deliveryAddress.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        userProvider.deliveryAddress,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textMid,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  await AddressSelectionBottomSheet.show(context, isCheckoutMode: true);
                  if (mounted) setState(() {});
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  side: const BorderSide(color: AppColors.primaryDark, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  "Change",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isServiceable ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isServiceable ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                  size: 14,
                  color: isServiceable ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isServiceable
                        ? "${distKm.toStringAsFixed(1)} km away • Deliverable to your doorstep"
                        : "Currently outside store delivery radius",
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isServiceable ? const Color(0xFF166534) : AppColors.error,
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

  Widget _buildMobileDeliveryInstructionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_bike_rounded, size: 18, color: AppColors.primaryDark),
              const SizedBox(width: 8),
              Text(
                "Delivery Instructions",
                style: GoogleFonts.poppins(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                "(Optional)",
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInstructionChip(
                icon: Icons.volume_off_outlined,
                label: "Avoid calling",
                rawText: "Avoid calling",
              ),
              _buildInstructionChip(
                icon: Icons.notifications_off_outlined,
                label: "Don't ring bell",
                rawText: "Don't ring bell",
              ),
              _buildInstructionChip(
                icon: Icons.door_front_door_outlined,
                label: "Leave at door",
                rawText: "Leave at door",
              ),
              _buildInstructionChip(
                icon: Icons.phone_in_talk_outlined,
                label: "Call on arrival",
                rawText: "Call on arrival",
              ),
              _buildInstructionChip(
                icon: Icons.directions_outlined,
                label: "Follow directions",
                rawText: "Follow directions",
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _instructionsController,
            maxLines: 2,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textDark),
            decoration: InputDecoration(
              hintText: "Add specific instructions (e.g. Ring bell, gate code, landmark...)",
              hintStyle: GoogleFonts.poppins(fontSize: 12, color: AppColors.textLight),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                borderSide: BorderSide(color: AppColors.primaryDark, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              "${_instructionsController.text.length}/200",
              style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textLight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionChip({
    required IconData icon,
    required String label,
    required String rawText,
  }) {
    final bool isSelected = _selectedInstructionChips.contains(rawText);
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedInstructionChips.remove(rawText);
            String current = _instructionsController.text;
            current = current.replaceAll(rawText, '').replaceAll(', ,', ',').trim();
            if (current.startsWith(',')) current = current.substring(1).trim();
            if (current.endsWith(',')) current = current.substring(0, current.length - 1).trim();
            _instructionsController.text = current;
          } else {
            _selectedInstructionChips.add(rawText);
            final current = _instructionsController.text.trim();
            if (current.isEmpty) {
              _instructionsController.text = rawText;
            } else if (!current.contains(rawText)) {
              _instructionsController.text = "$current, $rawText";
            }
          }
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryDark : const Color(0xFFE5E7EB),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? AppColors.primaryDark : AppColors.textMid,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primaryDark : AppColors.textDark,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              const Icon(Icons.check_rounded, size: 14, color: AppColors.primaryDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMobileCartItemsCard(List<dynamic> cartItems, AppLocalizations? l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined, size: 18, color: AppColors.primaryDark),
                  const SizedBox(width: 8),
                  Text(
                    "Review Items (${cartItems.length})",
                    style: GoogleFonts.poppins(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: widget.onBackToCart,
                child: Row(
                  children: [
                    const Icon(Icons.edit_outlined, size: 13, color: AppColors.primaryDark),
                    const SizedBox(width: 4),
                    Text(
                      "Edit Cart",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cartItems.length,
            separatorBuilder: (_, _) => const Divider(height: 16, color: Color(0xFFF3F4F6)),
            itemBuilder: (ctx, i) {
              final item = cartItems[i];
              return Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: AppColors.primaryDark,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          "${item.isLoose ? 'Loose' : 'Pack'} • Qty: ${item.quantity.toStringAsFixed(0)}",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.textMid,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "₹${(item.price * item.quantity).toStringAsFixed(0)}",
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBillDetailsCard({
    required double subtotal,
    required double deliveryFee,
    required double discount,
    required double finalTotal,
    required int cartItemsCount,
    required AppLocalizations? l10n,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.primaryDark),
              const SizedBox(width: 8),
              Text(
                l10n?.bill_details ?? "Bill Details",
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildMobileBillRow("Item Subtotal", "₹${subtotal.toStringAsFixed(0)}"),
          const SizedBox(height: 10),
          _buildMobileBillRow(
            _isPickup ? "Delivery Fee (Store Pickup)" : "Delivery Partner Fee",
            (_isPickup || deliveryFee == 0) ? "FREE" : "₹${deliveryFee.toStringAsFixed(0)}",
            isFree: _isPickup || deliveryFee == 0,
          ),
          if (discount > 0) ...[
            const SizedBox(height: 10),
            _buildMobileBillRow(
              "Coupon Discount",
              "-₹${discount.toStringAsFixed(0)}",
              isDiscount: true,
            ),
          ],
          const SizedBox(height: 10),
          _buildMobileBillRow("Handling & Packaging", "FREE", isFree: true),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Color(0xFFE5E7EB), height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "To Pay",
                style: GoogleFonts.poppins(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                "₹${finalTotal.toStringAsFixed(0)}",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
          if (discount > 0) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.celebration_rounded, color: Color(0xFF166534), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "You are saving ₹${discount.toStringAsFixed(0)} on this order!",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF166534),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileBillRow(
    String label,
    String value, {
    bool isFree = false,
    bool isDiscount = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.textMid,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (isFree)
          Row(
            children: [
              Text(
                "₹30",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  decoration: TextDecoration.lineThrough,
                  color: AppColors.textLight,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                "FREE",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
            ],
          )
        else
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: isDiscount ? FontWeight.w700 : FontWeight.w600,
              color: isDiscount ? AppColors.success : AppColors.textDark,
            ),
          ),
      ],
    );
  }

  Widget _buildMobileTrustAndPolicyCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security_rounded, size: 15, color: AppColors.primaryDark),
              const SizedBox(width: 6),
              Text(
                "Cancellation Policy",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Orders cannot be cancelled once packed by your local Kirana store. 100% Genuine and Fresh products delivered safely.",
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppColors.textMid,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileStickyBottomBar({
    required BuildContext context,
    required CartProvider cartProvider,
    required double finalTotal,
    required double deliveryFee,
    required double discount,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
        border: const Border(
          top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            InkWell(
              onTap: () {
                if (_mobileScrollController.hasClients) {
                  _mobileScrollController.animateTo(
                    _mobileScrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOut,
                  );
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _selectedPaymentIndex == 0
                            ? Icons.bolt_rounded
                            : _selectedPaymentIndex == 2
                                ? Icons.menu_book_rounded
                                : Icons.payments_rounded,
                        size: 13,
                        color: AppColors.primaryDark,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _selectedPaymentIndex == 0
                            ? "PAY USING UPI"
                            : _selectedPaymentIndex == 2
                                ? "KIRANA KHATA"
                                : (_isPickup ? "PAY AT STORE" : "PAY ON DELIVERY"),
                        style: GoogleFonts.poppins(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      Text(
                        "₹${finalTotal.toStringAsFixed(0)}",
                        style: GoogleFonts.poppins(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textMid),
                    ],
                  ),
                  Text(
                    "View Detailed Bill",
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 52,
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
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isProcessingCheckout
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                _selectedPaymentIndex == 0
                                    ? (_isPickup ? "Place Pickup" : "Place Order")
                                    : _selectedPaymentIndex == 2
                                        ? "Order via Khata"
                                        : (_isPickup ? "Confirm Pickup" : "Place Order (COD)"),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ],
                        ),
                ),
              ),
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
                    subtitle: "Google Pay, PhonePe, Paytm, BHIM",
                    badgeText: "FASTEST",
                    badgeColor: const Color(0xFF047857),
                    iconColor: const Color(0xFF047857),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPaymentOptionCard(
                    index: 1,
                    icon: _isPickup ? Icons.storefront_rounded : Icons.payments_rounded,
                    title: _isPickup ? "Pay at Store" : (l10n?.cash_on_delivery ?? "Cash on Delivery"),
                    subtitle: _isPickup ? "Pay cash or scan UPI QR at the store counter" : "Pay cash or scan QR at doorstep",
                    badgeText: _isPickup ? "AT STORE" : "POPULAR",
                    badgeColor: const Color(0xFF2563EB),
                    iconColor: const Color(0xFF2563EB),
                  ),
                ),
                if (_hasShopKhata) ...[
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
                subtitle: "Google Pay, PhonePe, Paytm, or BHIM",
                badgeText: "FASTEST",
                badgeColor: const Color(0xFF047857),
                iconColor: const Color(0xFF047857),
              ),
              const SizedBox(height: 10),
              _buildPaymentOptionCard(
                index: 1,
                icon: _isPickup ? Icons.storefront_rounded : Icons.payments_rounded,
                title: _isPickup ? "Pay at Store" : (l10n?.cash_on_delivery ?? "Cash on Delivery"),
                subtitle: _isPickup ? "Pay cash or scan UPI QR at the store counter" : "Pay cash or scan QR at your doorstep",
                badgeText: _isPickup ? "AT STORE" : "POPULAR",
                badgeColor: const Color(0xFF2563EB),
                iconColor: const Color(0xFF2563EB),
              ),
              if (_hasShopKhata) ...[
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
                  : (_hasShopKhata
                      ? _buildKhataDetailBox()
                      : const SizedBox.shrink()),
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
                  Icons.bolt_rounded,
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
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_outlined,
                  color: Color(0xFF16A34A),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Click 'Place Order' below to pay via your preferred UPI app. Order will be confirmed automatically on successful payment.",
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: const Color(0xFF166534),
                      fontWeight: FontWeight.w500,
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
            child: Icon(
              _isPickup ? Icons.storefront_rounded : Icons.delivery_dining_rounded,
              color: const Color(0xFF1D4ED8),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isPickup
                      ? "Pay ₹${finalTotal.toStringAsFixed(0)} at Store"
                      : "Pay ₹${finalTotal.toStringAsFixed(0)} on Delivery",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: const Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isPickup
                      ? "Pay in cash or scan the store UPI QR code when collecting your order from the shop counter."
                      : "Pay in cash or ask delivery partner to scan their UPI QR code upon arrival at your doorstep.",
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
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "Credit Limit: ₹${_khataCreditLimit.toStringAsFixed(0)}  •  Current Udhaar: ₹${_currentKhataBalance.toStringAsFixed(0)}",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF78350F),
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

  /// Verifies if the customer is an offline customer created by the shop owner with an active Khata
  Future<void> _checkCustomerKhata() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final shopProvider = Provider.of<ShopProvider>(context, listen: false);
      final String shopId = shopProvider.currentShopId ?? '';
      final String rawPhone = userProvider.phoneNumber.trim();

      if (shopId == _checkedShopId && rawPhone == _checkedPhone && !_isLoadingKhata) {
        return;
      }
      _checkedShopId = shopId;
      _checkedPhone = rawPhone;

      if (shopId.isEmpty || rawPhone.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoadingKhata = false;
            _hasShopKhata = false;
            if (_selectedPaymentIndex == 2) _selectedPaymentIndex = 0;
          });
        }
        return;
      }

      String cleanPhone = rawPhone.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.length > 10) {
        cleanPhone = cleanPhone.substring(cleanPhone.length - 10);
      }

      final phonesToSearch = <String>{
        rawPhone,
        cleanPhone,
        if (cleanPhone.isNotEmpty) '+91$cleanPhone',
        if (cleanPhone.isNotEmpty) '91$cleanPhone',
      }.where((p) => p.isNotEmpty).toList();

      final querySnapshot = await FirebaseUtils.firestore
          .collection('customers')
          .where('mobile', whereIn: phonesToSearch.take(10).toList())
          .get();

      bool hasKhata = false;
      double creditLimit = 5000.0;
      double balance = 0.0;

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final shopIds = (data['shop_ids'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final shopBalances = data['shop_balances'] as Map<String, dynamic>?;

        // Offline customer must be created by shop owner for this shop
        if (shopIds.contains(shopId) ||
            (shopBalances != null && shopBalances.containsKey(shopId))) {
          if (data['is_banned'] != true) {
            hasKhata = true;
            creditLimit = (data['credit_limit'] as num?)?.toDouble() ?? 5000.0;
            balance = (shopBalances?[shopId] as num?)?.toDouble() ??
                ((data['total_udhaar'] as num?)?.toDouble() ?? 0.0);
            break;
          }
        }
      }

      if (mounted) {
        setState(() {
          _isLoadingKhata = false;
          _hasShopKhata = hasKhata;
          _khataCreditLimit = creditLimit;
          _currentKhataBalance = balance;
          if (!hasKhata && _selectedPaymentIndex == 2) {
            _selectedPaymentIndex = 0;
          }
        });
      }
    } catch (e) {
      debugPrint('Error verifying customer Khata: $e');
      if (mounted) {
        setState(() {
          _isLoadingKhata = false;
          _hasShopKhata = false;
          if (_selectedPaymentIndex == 2) {
            _selectedPaymentIndex = 0;
          }
        });
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
    if (!_isPickup && (userProvider.currentLat == null || userProvider.currentLng == null)) {
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

      // Fetch Razorpay key (from provider or Firestore fallback)
      String rzpKey = shopProvider.razorpayKeyId ?? '';
      if (rzpKey.isEmpty) {
        try {
          final settingsDoc = await FirebaseUtils.firestore
              .collection('admin_settings')
              .doc('general')
              .get();
          if (settingsDoc.exists && settingsDoc.data()?['razorpay_key_id'] != null) {
            final key = (settingsDoc.data()!['razorpay_key_id'] as String).trim();
            if (key.isNotEmpty) rzpKey = key;
          }
        } catch (_) {}
      }
      if (rzpKey.isEmpty) {
        rzpKey = 'rzp_test_1DP5mmOlF5G5ag';
      }

      // Check if user is banned and verify shop Khata record
      String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.length > 10) {
        cleanPhone = cleanPhone.substring(cleanPhone.length - 10);
      }
      final phonesToSearch = <String>{
        phone,
        cleanPhone,
        if (cleanPhone.isNotEmpty) '+91$cleanPhone',
        if (cleanPhone.isNotEmpty) '91$cleanPhone',
      }.where((p) => p.isNotEmpty).toList();

      QuerySnapshot<Map<String, dynamic>>? customerQuery;
      try {
        customerQuery = await FirebaseUtils.firestore
            .collection('customers')
            .where('mobile', whereIn: phonesToSearch.take(10).toList())
            .get();
      } catch (e) {
        debugPrint('Customer check error: $e');
      }

      Map<String, dynamic>? shopCustomerData;
      if (customerQuery != null && customerQuery.docs.isNotEmpty) {
        for (final doc in customerQuery.docs) {
          final data = doc.data();
          final shopIds = (data['shop_ids'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          final shopBalances = data['shop_balances'] as Map<String, dynamic>?;
          if (shopIds.contains(shopId) ||
              (shopBalances != null && shopBalances.containsKey(shopId))) {
            shopCustomerData = data;
            break;
          }
        }
      }

      if (shopCustomerData != null && shopCustomerData['is_banned'] == true) {
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

      // Khata eligibility check: only offline customer created by shop owner for this shop
      bool hasShopKhataRecord = shopCustomerData != null;
      bool khataEligible = false;
      if (hasShopKhataRecord) {
        final double creditLimit =
            (shopCustomerData['credit_limit'] as num?)?.toDouble() ?? 5000.0;
        final shopBalances = shopCustomerData['shop_balances'] as Map<String, dynamic>?;
        final double currentUdhaar =
            (shopBalances?[shopId] as num?)?.toDouble() ??
            ((shopCustomerData['total_udhaar'] as num?)?.toDouble() ?? 0.0);
        khataEligible = (currentUdhaar + finalTotal) <= creditLimit;
      }

      // Direct payment method resolution based on customer selection on screen
      String paymentMethod;
      String paymentStatus;
      String? finalUpiRefId;
      Map<String, dynamic> extraPaymentData = {};
      bool isRazorpaySuccess = false;

      if (_selectedPaymentIndex == 1) {
        // Cash on Delivery
        paymentMethod = PaymentMethod.cod;
        paymentStatus = 'Pending';
      } else if (_selectedPaymentIndex == 2) {
        // Kirana Khata: Only for offline customers whose khata was created by the shop owner
        if (!hasShopKhataRecord || !_hasShopKhata) {
          setState(() => _isProcessingCheckout = false);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Khata sirf unhi offline customers ke liye hai jinka khata dukan malik ne create kiya hai.'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }
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
        paymentMethod = 'Kirana Khata';
        paymentStatus = 'Pending (Khata)';
      } else {
        // Instant UPI Payment via Razorpay Gateway (Google Pay, PhonePe, Paytm, BHIM, etc.)
        RazorpayCheckoutResult rzpResult;
        try {
          rzpResult = await RazorpayService().checkout(
            keyId: rzpKey,
            amount: finalTotal,
            shopName: shopName,
            customerPhone: phone,
            customerName: customerName,
            description: 'Order from $shopName',
            notes: {
              'shop_id': shopId,
              'customer_phone': phone,
              'payment_flow': 'checkout_upi',
            },
          );
        } catch (e) {
          rzpResult = RazorpayFailureResult(
            code: -1,
            message: 'UPI payment initiation error: $e',
          );
        }

        if (rzpResult is RazorpaySuccessResult) {
          // Payment Successful -> Confirm Order!
          paymentMethod = PaymentMethod.upi;
          paymentStatus = PaymentStatus.paid;
          finalUpiRefId = rzpResult.paymentId;
          isRazorpaySuccess = true;
          extraPaymentData = {
            'razorpay_payment_id': rzpResult.paymentId,
            if (rzpResult.orderId != null) 'razorpay_order_id': rzpResult.orderId,
            if (rzpResult.signature != null) 'razorpay_signature': rzpResult.signature,
            'verified_by': 'Razorpay Gateway',
            'verified_at': FieldValue.serverTimestamp(),
          };
        } else {
          // Payment Failed / Cancelled -> Reject Order (Do not place in database)
          setState(() => _isProcessingCheckout = false);
          if (context.mounted) {
            final failureMsg = (rzpResult is RazorpayFailureResult && rzpResult.message.isNotEmpty)
                ? rzpResult.message
                : 'Payment fail ho gaya ya cancel kiya gaya. Order place nahi hua.';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(failureMsg),
                backgroundColor: AppColors.error,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          return; // Stop and reject!
        }
      }

      // Build delivery address
      String finalDeliveryAddress;
      if (_isPickup) {
        final String sAddress = (shopProvider.shopAddress ?? '').trim();
        finalDeliveryAddress = 'Store Pickup at $shopName${sAddress.isNotEmpty ? ' ($sAddress)' : ' (Shop Counter)'}';
      } else {
        finalDeliveryAddress = 'House: ${userProvider.customerHouseNo}';
        if (userProvider.customerLandmark.isNotEmpty) {
          finalDeliveryAddress += ', Landmark: ${userProvider.customerLandmark}';
        }
        finalDeliveryAddress += ' — (Locality: ${userProvider.autoLocality})';
        if (userProvider.addressLabel.isNotEmpty) {
          finalDeliveryAddress += ' [${userProvider.addressLabel}]';
        }
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
          'pay_${phone}_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';

      final estimate = userProvider.getEstimatedDeliveryTime(deliveryType: _isPickup ? 'Pickup' : 'Delivery');

      final result = await AtomicOrderService.instance.placeOrderAtomic(
        OrderPlacementParams(
          shopId: shopId,
          customerName: customerName,
          customerPhone: phone,
          deliveryAddress: finalDeliveryAddress,
          customerLat: _isPickup ? (userProvider.storeLat ?? userProvider.currentLat) : userProvider.currentLat,
          customerLng: _isPickup ? (userProvider.storeLng ?? userProvider.currentLng) : userProvider.currentLng,
          deliveryType: _isPickup ? 'Pickup' : 'Delivery',
          deliveryFee: _isPickup ? 0.0 : deliveryFee,
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
      if (isRazorpaySuccess && finalUpiRefId != null) {
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
                  result.isDuplicate ? "Order Already Received!" : "Order Placed Successfully!",
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
      final langProvider = Provider.of<LanguageProvider>(context, listen: false);
      final isHindi = langProvider.isHindi;
      final isHinglish = langProvider.isHinglish;
      final errStr = e.toString().toLowerCase();

      String userMessage = isHindi
          ? "ऑर्डर करने में समस्या: $e"
          : (isHinglish ? "Order place karne me problem: $e" : "Failed to place order: $e");

      if (errStr.contains('unavailable') ||
          errStr.contains('unable to resolve host') ||
          errStr.contains('offline') ||
          errStr.contains('network') ||
          errStr.contains('socketexception')) {
        userMessage = isHindi
            ? "इंटरनेट कनेक्शन समस्या। कृपया अपना नेटवर्क जांचें और दोबारा प्रयास करें।"
            : (isHinglish
                ? "Internet connection problem hai. Kripya network check karke dubara try karein."
                : "Network connection issue. Please check your internet connection and try again.");
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userMessage),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessingCheckout = false);
    }
  }
}
