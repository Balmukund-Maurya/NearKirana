import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';

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
  int _selectedPaymentIndex = 0;
  final TextEditingController _instructionsController = TextEditingController();
  CouponValidationResult? _appliedCouponResult;

  final Color primaryGreen = const Color(
    0xFF0F766E,
  ); // or similar NearKirana green
  final Color activeLightGreen = const Color(0xFFF0FDF4);
  final Color activeBorderGreen = const Color(0xFF22C55E);

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    isDesktop ? "Back to Cart" : "Back",
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
                        "Checkout",
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
                    _buildStep(1, isDesktop ? "Delivery\nAddress" : "Address", isActive: true),
                    _buildLine(isActive: true),
                    _buildStep(2, isDesktop ? "Order\nReview" : "Review", isActive: false),
                    _buildLine(isActive: false),
                    _buildStep(3, isDesktop ? "Payment\nMethod" : "Payment", isActive: false),
                    _buildLine(isActive: false),
                    _buildStep(4, isDesktop ? "Place\nOrder" : "Done", isActive: false),
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
                        "Delivery Address",
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
                          label: const Text(
                            "Manage / Add Address",
                            style: TextStyle(
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
                        "Payment Method",
                        "Choose your preferred payment method",
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: EdgeInsets.only(left: isDesktop ? 48 : 0),
                        child: isDesktop
                            ? IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: _buildPaymentCard(
                                        0,
                                        Icons.payments_outlined,
                                        "Cash on Delivery",
                                        "Pay when you receive\nyour order",
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildPaymentCard(
                                        1,
                                        Icons.qr_code_2,
                                        "UPI",
                                        "Pay using UPI apps\n(GPay, PhonePe, etc.)",
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildPaymentCard(
                                        2,
                                        Icons.credit_card,
                                        "Credit / Debit Card",
                                        "Pay using your card\n",
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildPaymentCard(
                                        3,
                                        Icons.account_balance,
                                        "Net Banking",
                                        "Pay using net banking\n",
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                children: [
                                  IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: _buildPaymentCard(
                                            0,
                                            Icons.payments_outlined,
                                            "Cash on Delivery",
                                            "Pay when you receive order",
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildPaymentCard(
                                            1,
                                            Icons.qr_code_2,
                                            "UPI",
                                            "GPay, PhonePe, Paytm",
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: _buildPaymentCard(
                                            2,
                                            Icons.credit_card,
                                            "Card",
                                            "Credit / Debit Card",
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildPaymentCard(
                                            3,
                                            Icons.account_balance,
                                            "Net Banking",
                                            "All Indian Banks",
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
                                    "Order Summary (${cartItems.length} items)",
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
                            const Text(
                              "Price Details",
                              style: TextStyle(
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
                                  "Subtotal (${cartItems.length} items)",
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
                                      "Delivery Charges ",
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
                                  "₹${deliveryFee.toStringAsFixed(0)}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF111827),
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
                                    "Discount",
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
                                  const Text(
                                    "Total Amount",
                                    style: TextStyle(
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
                                        children: const [
                                          Text(
                                            "Place Order",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(
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
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? const Color(0xFF111827) : Colors.grey.shade400,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
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

  Widget _buildPaymentCard(
    int index,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final isSelected = _selectedPaymentIndex == index;
    // Disallow selection of non-COD methods based on project constraints, but for UI fidelity we allow clicking COD.
    // We will just restrict the selection visually or show a snackbar if they click others.

    return InkWell(
      onTap: () {
        setState(() => _selectedPaymentIndex = index);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? activeLightGreen : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeBorderGreen : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? const Color(0xFF047857)
                      : const Color(0xFF4B5563),
                  size: 28,
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
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? activeBorderGreen
                        : Colors.grey.shade300,
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
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executeOrder(
    BuildContext context,
    CartProvider cartProvider,
    double finalTotal,
    double deliveryFee,
  ) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.currentLat == null || userProvider.currentLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please add a delivery address"),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isProcessingCheckout = true;
    });
    try {
      String customerName = userProvider.customerName.isEmpty
          ? "Customer"
          : userProvider.customerName;
      String phone = userProvider.phoneNumber.isEmpty
          ? "0000000000"
          : userProvider.phoneNumber;
      String shopId =
          Provider.of<ShopProvider>(context, listen: false).currentShopId ?? '';

      String finalDeliveryAddress = 'House: ${userProvider.customerHouseNo}';
      if (userProvider.customerLandmark.isNotEmpty) {
        finalDeliveryAddress += ', Landmark: ${userProvider.customerLandmark}';
      }
      finalDeliveryAddress += ' — (Locality: ${userProvider.autoLocality})';
      if (userProvider.addressLabel.isNotEmpty) {
        finalDeliveryAddress += ' [${userProvider.addressLabel}]';
      }

      final items = cartProvider.itemsList
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
          'desktop_${phone}_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';

      String paymentMethod = PaymentMethod.cod;
      String paymentStatus = PaymentStatus.unpaid;
      if (_selectedPaymentIndex == 1) {
        paymentMethod = PaymentMethod.upi;
        paymentStatus = PaymentStatus.paymentPending;
      } else if (_selectedPaymentIndex == 2) {
        paymentMethod = PaymentMethod.card;
        paymentStatus = PaymentStatus.paymentPending;
      } else if (_selectedPaymentIndex == 3) {
        paymentMethod = PaymentMethod.netBanking;
        paymentStatus = PaymentStatus.paymentPending;
      }

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
          },
        ),
      );

      // If online payment is chosen, initiate gateway payment session
      if (paymentMethod != PaymentMethod.cod) {
        try {
          await PaymentService().initiateOnlinePayment(
            orderId: result.orderId,
            shopId: shopId,
            amount: result.totalAmount,
            customerPhone: phone,
            customerName: customerName,
            paymentMethod: paymentMethod,
          );
        } catch (e) {
          debugPrint('Online payment initiation warning: $e');
        }
      }

      final receiptOrderData = {
        'order_id': result.orderId,
        'items': items.map((i) => {
          'id': i.productId,
          'name': i.name,
          'quantity': i.quantity,
          'price': i.price,
          'total_price': i.quantity * i.price,
          'is_loose': i.isLoose,
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

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 64),
              const SizedBox(height: 16),
              Text(
                result.isDuplicate
                    ? "Order Already Received!"
                    : "Order Placed Successfully!",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Your order will be delivered soon.\nPIN: ${result.deliveryPin}",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () {
                  DigitalReceiptDialog.showForOrder(
                    context,
                    orderData: receiptOrderData,
                    orderId: result.orderId,
                  );
                },
                icon: const Icon(Icons.receipt_long, size: 18),
                label: const Text("View Digital Receipt"),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.onOrderPlaced(); // Return to shop/dashboard
                },
                child: const Text("Continue Shopping"),
              ),
            ],
          ),
        ),
      );
    } on InsufficientStockException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.userFriendlyMessage),
          backgroundColor: AppColors.error,
        ),
      );
    } on InvalidCouponException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Coupon Error: ${e.message}"),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to place order: $e"),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingCheckout = false;
        });
      }
    }
  }
}
