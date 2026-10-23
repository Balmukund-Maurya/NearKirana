import 'package:near_kirana/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'user_provider.dart';
import 'language_provider.dart';
import 'app_theme.dart';
import 'sound_service.dart';
import 'modern_loader.dart';
import 'shop_provider.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'payment_service.dart';
import 'order_state_machine.dart';
import 'my_orders_desktop_wrapper.dart';
import 'package:near_kirana/widgets/substitution_widgets.dart';
import 'package:near_kirana/product_substitution_service.dart';
import 'package:near_kirana/widgets/rating_review_dialog.dart';
import 'package:near_kirana/widgets/order_complaint_section.dart';
import 'package:near_kirana/widgets/reorder_summary_dialog.dart';
import 'package:near_kirana/shopping_list_service.dart';
import 'package:near_kirana/customer_live_tracking_screen.dart';

class MyOrdersScreen extends StatelessWidget {
  final bool isTab;
  const MyOrdersScreen({super.key, this.isTab = false});

  Future<void> _makeDirectPhoneCall(String phone) async {
    HapticFeedback.mediumImpact();
    try {
      String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.isEmpty) return;
      if (cleanPhone.length == 10) cleanPhone = '91$cleanPhone';
      
      final Uri launchUri = Uri(scheme: 'tel', path: '+$cleanPhone');
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        await launchUrl(Uri.parse('tel:$cleanPhone'));
      }
    } catch (e) {
      debugPrint('Could not launch dialer: $e');
    }
  }

  Future<void> _callDeliveryBoyOrStore(BuildContext context, Map<String, dynamic> data) async {
    HapticFeedback.mediumImpact();
    final String riderPhone = (data['delivery_boy_phone'] ??
            data['delivery_partner_phone'] ??
            data['rider_phone'] ??
            (data['delivery_partner'] is Map ? data['delivery_partner']['phone'] : null) ??
            (data['delivery_boy'] is Map ? data['delivery_boy']['phone'] : null) ??
            '')
        .toString()
        .trim();

    // If delivery partner is assigned, call delivery boy directly
    if (riderPhone.isNotEmpty) {
      await _makeDirectPhoneCall(riderPhone);
      return;
    }

    // Fallback: If no delivery boy is assigned yet, call shop owner
    await _callShopOwner(context);
  }

  Future<void> _callShopOwner(BuildContext context) async {
    HapticFeedback.mediumImpact();
    try {
      final shopProvider = Provider.of<ShopProvider>(context, listen: false);
      String phone = shopProvider.shopSupportPhone?.toString() ?? shopProvider.shopMobile?.toString() ?? '';
      phone = phone.replaceAll(RegExp(r'\D'), '');
      if (phone.length == 10) phone = '91$phone';
      
      final Uri launchUri = Uri(scheme: 'tel', path: '+$phone');
      await launchUrl(launchUri);
    } catch (e) {
      debugPrint('Could not launch dialer: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final langProvider = Provider.of<LanguageProvider>(context);
    final shopProvider = Provider.of<ShopProvider>(context);
    final String phone = userProvider.phoneNumber;

    final isHindi = langProvider.isHindi;
    final isHinglish = langProvider.isHinglish;

    final String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final String last10 = cleanPhone.length >= 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
    final List<String> phoneVariants = {
      phone,
      cleanPhone,
      last10,
      if (last10.length == 10) '+91$last10',
      if (last10.length == 10) '91$last10',
    }.where((p) => p.trim().isNotEmpty).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: MediaQuery.of(context).size.width > 800 ? null : AppBar(
        automaticallyImplyLeading: !isTab,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: Text(
          isHindi
              ? 'मेरे ऑर्डर'
              : (isHinglish ? 'Mere Orders' : 'My Orders'),
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: phone.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.login_rounded,
                    size: 80,
                    color: AppColors.textLight,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.please_login,
                    style: AppTextStyles.bodyMedium(color: AppColors.textMid),
                  ),
                ],
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseUtils.firestore
                  .collection('orders')
                  .where('phone_number', whereIn: phoneVariants)
                  .limit(100)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: ModernLoader(color: AppColors.primaryDark),
                  );
                }

                final orders = snapshot.data?.docs ?? [];

                // Sort orders by created_at descending
                orders.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = aData['created_at'] as Timestamp?;
                  final bTime = bData['created_at'] as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

                if (orders.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.shopping_bag_outlined,
                              size: 56,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            isHindi
                                ? 'अभी तक कोई ऑर्डर नहीं है'
                                : (isHinglish ? 'Abhi koi orders nahi hain' : 'No Orders Yet'),
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isHindi
                                ? 'जब आप ऑर्डर करेंगे, तो आपके लाइव ट्रैकिंग और पुराने ऑर्डर यहाँ दिखाई देंगे।'
                                : (isHinglish
                                    ? 'Jab aap order karenge, live tracking aur order history yahan dikhegi.'
                                    : 'Your live tracking and past order history will appear here once you order.'),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: const Color(0xFF64748B),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (MediaQuery.of(context).size.width > 800) {
                  return MyOrdersDesktopWrapper(orders: orders);
                }

                // Partition orders into Active (Ongoing) and Past Orders
                final activeOrders = <QueryDocumentSnapshot>[];
                final pastOrders = <QueryDocumentSnapshot>[];

                for (final doc in orders) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status']?.toString() ?? 'Pending';
                  if (status == OrderStatus.delivered ||
                      status == OrderStatus.cancelled ||
                      status == OrderStatus.rejected ||
                      status == OrderStatus.deliveryFailed) {
                    pastOrders.add(doc);
                  } else {
                    activeOrders.add(doc);
                  }
                }

                return ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(
                    top: 14,
                    left: 14,
                    right: 14,
                    bottom: 120, // generous bottom padding to avoid bottom navigation overlap
                  ),
                  children: [
                    // --- ACTIVE / ONGOING ORDERS SECTION (Zepto / Blinkit live tracker) ---
                    if (activeOrders.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isHindi
                                  ? 'चालू ऑर्डर (${activeOrders.length})'
                                  : (isHinglish
                                      ? 'Ongoing Orders (${activeOrders.length})'
                                      : 'Active Orders (${activeOrders.length})'),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...activeOrders.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final double total = double.tryParse(data['total_amount']?.toString() ?? '0') ?? 0.0;
                        final String status = data['status'] ?? 'Pending';
                        final Timestamp? createdAt = data['created_at'] as Timestamp?;
                        final dateStr = _formatDateStr(createdAt);
                        final String? cancellationReason = data['cancellation_reason'];
                        final items = data['items'] as List<dynamic>? ?? [];

                        return _buildActiveOrderCard(
                          context: context,
                          langProvider: langProvider,
                          shopProvider: shopProvider,
                          doc: doc,
                          data: data,
                          dateStr: dateStr,
                          total: total,
                          status: status,
                          cancellationReason: cancellationReason,
                          items: items,
                        );
                      }),
                      const SizedBox(height: 16),
                    ],

                    // --- PAST ORDERS / ORDER HISTORY SECTION (Zepto / Blinkit history cards) ---
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 10),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.history_rounded,
                            size: 16,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isHindi
                                ? 'पुराने ऑर्डर (${pastOrders.length})'
                                : (isHinglish
                                    ? 'Order History (${pastOrders.length})'
                                    : 'Past Orders (${pastOrders.length})'),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (pastOrders.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Center(
                          child: Text(
                            isHindi
                                ? 'कोई पुराना ऑर्डर नहीं है।'
                                : (isHinglish ? 'Koi past orders nahi hain.' : 'No past delivered orders yet.'),
                            style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF64748B)),
                          ),
                        ),
                      )
                    else
                      ...pastOrders.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final double total = double.tryParse(data['total_amount']?.toString() ?? '0') ?? 0.0;
                        final String status = data['status'] ?? 'Delivered';
                        final Timestamp? createdAt = data['created_at'] as Timestamp?;
                        final dateStr = _formatDateStr(createdAt);
                        final String? cancellationReason = data['cancellation_reason'];
                        final items = data['items'] as List<dynamic>? ?? [];

                        return _buildPastOrderCard(
                          context: context,
                          langProvider: langProvider,
                          shopProvider: shopProvider,
                          doc: doc,
                          data: data,
                          dateStr: dateStr,
                          total: total,
                          status: status,
                          cancellationReason: cancellationReason,
                          items: items,
                        );
                      }),
                  ],
                );
              },
            ),
    );
  }

  /// Clean user-friendly 6-8 char Order ID avoiding ugly technical prefixes
  String _cleanOrderId(String id) {
    final clean = id.replaceAll(RegExp(r'^(ord_|pay_|order_|desktop_)+', caseSensitive: false), '');
    if (clean.length > 8) {
      return clean.substring(clean.length - 8).toUpperCase();
    }
    return clean.toUpperCase();
  }

  /// Formatted date and time string
  String _formatDateStr(Timestamp? createdAt) {
    if (createdAt == null) return '';
    final dt = createdAt.toDate();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minuteStr = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hour:$minuteStr $ampm';
  }

  /// Zepto / Blinkit style Active / Ongoing Order Card
  Widget _buildActiveOrderCard({
    required BuildContext context,
    required LanguageProvider langProvider,
    ShopProvider? shopProvider,
    required QueryDocumentSnapshot doc,
    required Map<String, dynamic> data,
    required String dateStr,
    required double total,
    required String status,
    required String? cancellationReason,
    required List<dynamic> items,
  }) {
    final isHindi = langProvider.isHindi;
    final isHinglish = langProvider.isHinglish;
    final String paymentMethod = data['payment_method'] ?? 'Cash on Delivery';
    final String? paymentStatus = data['payment_status'] as String?;
    final bool isRefunded = paymentStatus == PaymentStatus.refunded;
    final bool isPendingVerification = paymentStatus == PaymentStatus.pendingVerification;
    final bool isFailed = paymentStatus == PaymentStatus.failed;
    final bool isPaymentPending = paymentStatus == PaymentStatus.paymentPending;
    final String? upiRefId = data['upi_ref_id'] as String?;
    final proposals = ProductSubstitutionService.getAllProposals(data);
    final pendingProposals = proposals.where((p) => p.isPending).toList();
    final bool isPickup = (data['delivery_type'] ?? '') == 'Pickup';
    final String storeName = (data['shop_name'] ?? shopProvider?.shopName ?? 'NearKirana Store').toString();

    // Summary item preview text
    final previewNames = items.take(2).map((i) {
      final name = (i as Map)['name']?.toString() ?? 'Item';
      final qty = i['quantity']?.toString() ?? '1';
      return '$name ($qty)';
    }).join(', ');
    final remainingCount = items.length > 2 ? ' +${items.length - 2} more' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Header: Store Info + Live Status Badge
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    size: 20,
                    color: Color(0xFF047857),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        storeName,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '#${_cleanOrderId(doc.id)} • $dateStr',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildOrderStatusBadge(status),
              ],
            ),
          ),

          // 2. Delivery Window / Status Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isPickup ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isPickup ? const Color(0xFFBBF7D0) : const Color(0xFFBFDBFE),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isPickup ? Icons.storefront_rounded : Icons.electric_moped_rounded,
                    color: isPickup ? const Color(0xFF047857) : const Color(0xFF1D4ED8),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isPickup
                          ? (isHindi ? 'स्टोर पिकअप के लिए तैयार' : 'Ready for Store Pickup')
                          : '${isHindi ? 'अनुमानित डिलीवरी:' : 'Arriving in:'} ${data['estimated_delivery_window'] ?? '25–35 mins'}',
                      style: GoogleFonts.poppins(
                        color: isPickup ? const Color(0xFF047857) : const Color(0xFF1E40AF),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Compact 4-Stage Progress Stepper
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _buildTimeline(status, context, isPickup: isPickup),
          ),

          // 4. Delivery OTP PIN (if active delivery and PIN exists)
          if (status != OrderStatus.delivered &&
              status != OrderStatus.cancelled &&
              status != OrderStatus.rejected &&
              data.containsKey('delivery_pin')) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: Color(0xFF047857),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isHindi ? 'डिलीवरी पिन (पार्टनर को बताएं)' : 'Delivery PIN (Share at doorstep)',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF10B981), width: 1.2),
                      ),
                      child: Text(
                        data['delivery_pin'].toString(),
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                          color: const Color(0xFF047857),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // 5. Payment Warning / UTR Banner (if UPI and pending/failed)
          if (paymentMethod == 'UPI' && status != 'Cancelled' && (isPendingVerification || isPaymentPending || isFailed)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isFailed
                      ? const Color(0xFFFEF2F2)
                      : (isPendingVerification ? const Color(0xFFFFFBEB) : const Color(0xFFFFF7ED)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isFailed
                        ? const Color(0xFFFECACA)
                        : (isPendingVerification ? const Color(0xFFFDE68A) : const Color(0xFFFED7AA)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isFailed
                          ? Icons.error_outline_rounded
                          : (isPendingVerification ? Icons.hourglass_top_rounded : Icons.info_outline_rounded),
                      size: 16,
                      color: isFailed
                          ? const Color(0xFFDC2626)
                          : (isPendingVerification ? const Color(0xFFB45309) : const Color(0xFFC2410C)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isFailed
                            ? 'Payment rejected. Check or re-submit UTR.'
                            : (isPendingVerification
                                ? 'Verifying payment: ${upiRefId ?? ''}'
                                : 'Missing payment ref. Submit UTR to verify.'),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: isFailed
                              ? const Color(0xFFDC2626)
                              : (isPendingVerification ? const Color(0xFFB45309) : const Color(0xFFC2410C)),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showUpdateUtrDialog(context, doc.id, upiRefId),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        upiRefId != null ? 'Edit UTR' : 'Enter UTR',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isFailed ? const Color(0xFFDC2626) : const Color(0xFF047857),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (isRefunded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.replay_rounded, size: 16, color: Colors.purple),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Refund Processed: ₹${(data['refund_amount'] ?? data['total_amount'] ?? 0).toString()} (ID: ${data['refund_id'] ?? 'REF-DONE'})',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.purple.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // 6. Substitution Banner (if any)
          if (pendingProposals.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: SubstitutionApprovalBanner(
                orderId: doc.id,
                proposals: pendingProposals,
              ),
            ),
          ],

          // 7. Items Summary Preview & Total Price
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${items.length} ${items.length == 1 ? 'item' : 'items'} • $previewNames$remainingCount',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF475569),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '₹${total.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 6),
                _buildCustomerPaymentStatusBadge(paymentStatus, paymentMethod),
              ],
            ),
          ),

          const Divider(height: 16, color: Color(0xFFF1F5F9)),

          // 8. Action Buttons (Zepto / Blinkit style)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                // Live track button if Out for Delivery or Rider is assigned
                if ((status == OrderStatus.outForDelivery ||
                     status.toLowerCase().contains('delivery') ||
                     status.toLowerCase().contains('transit') ||
                     status.toLowerCase().contains('dispatch') ||
                     (data['delivery_boy_name'] != null && data['delivery_boy_name'].toString().isNotEmpty) ||
                     (data['delivery_partner_id'] != null && data['delivery_partner_id'].toString().isNotEmpty)) &&
                    status != OrderStatus.delivered &&
                    status != OrderStatus.cancelled &&
                    status != OrderStatus.rejected) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        CustomerLiveTrackingScreen.open(
                          context,
                          orderId: doc.id,
                          orderData: data,
                        );
                      },
                      icon: const Icon(Icons.location_on_rounded, size: 14),
                      label: Text(
                        isHindi ? 'लाइव ट्रैक' : 'Live Track',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Cancel button if Pending
                if (status == OrderStatus.pending) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmCancelOrder(context, doc.id, data, items),
                      icon: const Icon(Icons.cancel_outlined, size: 14, color: Color(0xFFDC2626)),
                      label: Text(
                        isHindi ? 'रद्द करें' : (isHinglish ? 'Cancel' : 'Cancel'),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Call Delivery Boy or Store button
                () {
                  final String riderPhone = (data['delivery_boy_phone'] ??
                          data['delivery_partner_phone'] ??
                          data['rider_phone'] ??
                          (data['delivery_partner'] is Map ? data['delivery_partner']['phone'] : null) ??
                          (data['delivery_boy'] is Map ? data['delivery_boy']['phone'] : null) ??
                          '')
                      .toString()
                      .trim();
                  final bool hasRiderAssigned = riderPhone.isNotEmpty;

                  return OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _callDeliveryBoyOrStore(context, data);
                    },
                    icon: Icon(
                      hasRiderAssigned ? Icons.delivery_dining_rounded : Icons.call_outlined,
                      size: 15,
                      color: hasRiderAssigned ? const Color(0xFF0C831F) : const Color(0xFF334155),
                    ),
                    label: Text(
                      hasRiderAssigned
                          ? (isHindi ? 'राइडर' : 'Rider')
                          : (isHindi ? 'कॉल' : 'Call'),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: hasRiderAssigned ? const Color(0xFF0C831F) : const Color(0xFF334155),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: hasRiderAssigned ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1),
                      ),
                      backgroundColor: hasRiderAssigned ? const Color(0xFFF0FDF4) : Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                }(),
                const SizedBox(width: 8),

                // View Summary / Bill details
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showOrderDetailsSheet(
                      context,
                      doc: doc,
                      data: data,
                      total: total,
                      status: status,
                      dateStr: dateStr,
                      items: items,
                    ),
                    icon: const Icon(Icons.receipt_long_outlined, size: 14),
                    label: Text(
                      isHindi ? 'बिल सारांश' : (isHinglish ? 'Bill Dekhein' : 'View Bill'),
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF047857),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  /// Zepto / Blinkit style Past Order (Order History) Card
  Widget _buildPastOrderCard({
    required BuildContext context,
    required LanguageProvider langProvider,
    ShopProvider? shopProvider,
    required QueryDocumentSnapshot doc,
    required Map<String, dynamic> data,
    required String dateStr,
    required double total,
    required String status,
    required String? cancellationReason,
    required List<dynamic> items,
  }) {
    final isHindi = langProvider.isHindi;
    final isHinglish = langProvider.isHinglish;
    final String paymentMethod = data['payment_method'] ?? 'Cash on Delivery';
    final String storeName = (data['shop_name'] ?? shopProvider?.shopName ?? 'NearKirana Store').toString();
    final bool isDelivered = status == OrderStatus.delivered || status == 'Delivered';
    final bool isCancelled = status == OrderStatus.cancelled || status == 'Cancelled' || status == OrderStatus.rejected;

    // Summary item preview text
    final previewNames = items.take(2).map((i) {
      final name = (i as Map)['name']?.toString() ?? 'Item';
      final qty = i['quantity']?.toString() ?? '1';
      return '$name ($qty)';
    }).join(', ');
    final remainingCount = items.length > 2 ? ' +${items.length - 2} more' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Row: Store Name & Date + Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    size: 18,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        storeName,
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '#${_cleanOrderId(doc.id)} • $dateStr',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildOrderStatusBadge(status),
              ],
            ),

            const SizedBox(height: 10),

            // 2. Items Preview
            Text(
              '${items.length} ${items.length == 1 ? 'item' : 'items'}: $previewNames$remainingCount',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF334155),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 8),

            // 3. Amount & Payment Method Row
            Row(
              children: [
                Text(
                  '₹${total.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 8),
                _buildCustomerPaymentStatusBadge(data['payment_status'] as String?, paymentMethod),
                const Spacer(),
                if (isDelivered && data['is_reviewed'] != true) ...[
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      showDialog(
                        context: context,
                        builder: (ctx) => RatingReviewDialog(
                          orderId: doc.id,
                          shopId: data['shop_id']?.toString() ?? '',
                          items: items,
                          customerName: data['customer_name']?.toString(),
                          customerPhone: data['phone_number']?.toString(),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 3),
                        Text(
                          isHindi ? 'रेट करें' : (isHinglish ? 'Rate Karein' : 'Rate Order'),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),

            if (isCancelled && cancellationReason != null && cancellationReason.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Reason: $cancellationReason',
                style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFFDC2626)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const Divider(height: 18, color: Color(0xFFF1F5F9)),

            // 4. Zepto / Blinkit Bottom Actions: Reorder & View Summary
            Row(
              children: [
                // Reorder Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      final shopId = data['shop_id']?.toString() ?? '';
                      ReorderSummaryDialog.showForItems(
                        context: context,
                        sourceTitle: 'Order #${_cleanOrderId(doc.id)}',
                        shopId: shopId,
                        items: items.map((i) => Map<String, dynamic>.from(i as Map)).toList(),
                      );
                    },
                    icon: const Icon(Icons.replay_rounded, size: 14),
                    label: Text(
                      isHindi ? 'फिर से ऑर्डर करें' : (isHinglish ? 'Order Again' : 'Reorder'),
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF047857),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // View Summary / Bill Details
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showOrderDetailsSheet(
                      context,
                      doc: doc,
                      data: data,
                      total: total,
                      status: status,
                      dateStr: dateStr,
                      items: items,
                    ),
                    icon: const Icon(Icons.receipt_long_outlined, size: 14, color: Color(0xFF334155)),
                    label: Text(
                      isHindi ? 'बिल देखें' : (isHinglish ? 'Bill Dekhein' : 'View Bill'),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF334155),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Detailed Order Receipt / Bill Bottom Sheet (Zepto / Blinkit style)
  void _showOrderDetailsSheet(
    BuildContext context, {
    required QueryDocumentSnapshot doc,
    required Map<String, dynamic> data,
    required double total,
    required String status,
    required String dateStr,
    required List<dynamic> items,
  }) {
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isHindi = langProvider.isHindi;
    final isHinglish = langProvider.isHinglish;
    final String paymentMethod = data['payment_method'] ?? 'Cash on Delivery';
    final double subtotal = (data['subtotal'] as num?)?.toDouble() ?? total;
    final double discount = (data['discount'] as num?)?.toDouble() ?? 0.0;
    final double deliveryFee = (data['delivery_fee'] as num?)?.toDouble() ?? 0.0;
    final String? deliveryAddress = data['delivery_address']?.toString();
    final String shopId = data['shop_id']?.toString() ?? '';
    final String storeName = (data['shop_name'] ?? 'NearKirana Store').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Sheet Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHindi ? 'ऑर्डर सारांश' : (isHinglish ? 'Order Summary' : 'Order Summary'),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '#${_cleanOrderId(doc.id)} • $dateStr',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Store & Status Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.storefront_rounded, size: 16, color: Color(0xFF047857)),
                            const SizedBox(width: 6),
                            Text(
                              storeName,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        _buildOrderStatusBadge(status),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Items List Header
                    Text(
                      isHindi ? 'आइटम्स (${items.length})' : 'Items (${items.length})',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Items List
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: items.map((item) {
                          final itemData = item as Map<String, dynamic>;
                          final itemName = itemData['name'] ?? 'Item';
                          final itemQty = itemData['quantity'] ?? 1;
                          final itemPrice = itemData['price'] ?? 0;
                          final isSubstituted = itemData['is_substituted'] == true;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        itemName,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF1E293B),
                                        ),
                                      ),
                                      if (isSubstituted && itemData['substituted_from'] != null)
                                        SubstitutedItemBadge(
                                          originalName: itemData['substituted_from'].toString(),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '$itemQty x ₹$itemPrice',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Bill Details
                    Text(
                      isHindi ? 'बिल विवरण' : 'Bill Details',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isHindi ? 'सामान का मूल्य' : 'Items Subtotal',
                                style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
                              ),
                              Text(
                                '₹${subtotal.toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          if (discount > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.discount_outlined, size: 12, color: Color(0xFF047857)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Coupon Discount (${data['coupon_code'] ?? 'OFF'})',
                                      style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF047857)),
                                    ),
                                  ],
                                ),
                                Text(
                                  '-₹${discount.toStringAsFixed(0)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF047857),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isHindi ? 'डिलीवरी चार्ज' : 'Delivery Fee',
                                style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
                              ),
                              Text(
                                deliveryFee > 0 ? '₹${deliveryFee.toStringAsFixed(0)}' : 'FREE',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: deliveryFee > 0 ? const Color(0xFF0F172A) : const Color(0xFF047857),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16, color: Color(0xFFE2E8F0)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isHindi ? 'कुल राशि' : 'Total Amount',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                '₹${total.toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF047857),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Payment: $paymentMethod',
                              style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Delivery Address (if home delivery)
                    if (deliveryAddress != null && deliveryAddress.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        isHindi ? 'डिलीवरी का पता' : 'Delivery Address',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                deliveryAddress,
                                style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF334155)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Order Help & Complaints
                    const SizedBox(height: 16),
                    OrderComplaintSection(
                      orderId: doc.id,
                      shopId: shopId,
                      customerPhone: data['phone_number']?.toString() ?? '',
                      customerName: data['customer_name']?.toString() ?? 'Customer',
                      orderItems: items,
                      orderStatus: status,
                      orderData: data,
                    ),

                    const SizedBox(height: 16),

                    // Save as Shopping List action
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showSaveOrderAsListDialog(
                            context,
                            doc.id,
                            data['phone_number']?.toString() ?? '',
                            shopId,
                            items,
                          );
                        },
                        icon: const Icon(Icons.bookmark_add_outlined, size: 15),
                        label: Text(
                          isHindi ? 'शॉपिंग लिस्ट में सेव करें' : 'Save as Shopping List',
                          style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          foregroundColor: const Color(0xFF334155),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
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

  /// Cancellation confirmation helper
  void _confirmCancelOrder(
    BuildContext context,
    String orderId,
    Map<String, dynamic> data,
    List<dynamic> items,
  ) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          AppLocalizations.of(context)!.cancel_order_q,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
          AppLocalizations.of(context)!.cancel_order_sure,
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              AppLocalizations.of(context)!.no_btn,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await FirebaseUtils.firestore.runTransaction((transaction) async {
                  final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
                  final snapshot = await transaction.get(orderRef);
                  if (!snapshot.exists) throw Exception('Order not found');

                  final currentStatus = snapshot.data()?['status'] ?? OrderStatus.pending;
                  OrderStateMachine.assertValidTransition(currentStatus, OrderStatus.cancelled);
                  if (currentStatus != OrderStatus.pending) throw Exception('NOT_PENDING');

                  // Restore stock
                  for (var item in items) {
                    final itemData = item as Map<String, dynamic>;
                    final String? itemId = itemData['id']?.toString();
                    if (itemId != null) {
                      final productRef = FirebaseUtils.firestore.collection('products').doc(itemId);
                      transaction.update(productRef, {
                        'stock_quantity': FieldValue.increment(itemData['quantity']),
                      });
                    }
                  }

                  final orderData = snapshot.data() ?? {};
                  final currentPaymentStatus = orderData['payment_status'] as String?;
                  final bool wasPaid = currentPaymentStatus == PaymentStatus.paid;
                  final double orderTotal = (orderData['total_amount'] as num?)?.toDouble() ?? 0.0;

                  final orderUpdates = <String, dynamic>{
                    'status': 'Cancelled',
                    'cancellation_reason': 'Cancelled by customer',
                  };

                  if (wasPaid) {
                    orderUpdates['payment_status'] = PaymentStatus.refunded;
                    orderUpdates['refund_id'] = PaymentService.generateRefundId();
                    orderUpdates['refund_amount'] = orderTotal;
                    orderUpdates['refund_reason'] = 'Order cancelled by customer';
                    orderUpdates['refunded_at'] = FieldValue.serverTimestamp();
                    orderUpdates['refunded_by'] = 'customer';
                  }

                  transaction.update(orderRef, orderUpdates);
                });

                if (context.mounted) {
                  SoundService().success();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Order cancelled successfully.'),
                      backgroundColor: Color(0xFFDC2626),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString().contains('NOT_PENDING')
                          ? 'Sorry, this order is already being processed.'
                          : 'Failed to cancel order: $e'),
                      backgroundColor: const Color(0xFFDC2626),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: Text(
              AppLocalizations.of(context)!.yes_cancel,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _showSaveOrderAsListDialog(
    BuildContext context,
    String orderId,
    String phone,
    String shopId,
    List<dynamic> items,
  ) {
    final nameCtrl = TextEditingController(text: 'Reorder List #$orderId');
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Save Order as List', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Save items from this order to quickly reorder next time:'),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
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
              Navigator.pop(dialogCtx);
              await ShoppingListService().createListFromOrder(
                orderId: orderId,
                name: nameCtrl.text.trim(),
                customerPhone: phone,
                shopId: shopId,
                items: items,
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

  Widget _buildOrderStatusBadge(String status) {
    Color bg;
    Color border;
    Color textColor;
    IconData icon;

    switch (status) {
      case OrderStatus.delivered:
        bg = AppColors.primaryLight.withValues(alpha: 0.15);
        border = AppColors.primaryDark.withValues(alpha: 0.3);
        textColor = AppColors.primaryDark;
        icon = Icons.check_circle_rounded;
        break;
      case OrderStatus.cancelled:
      case OrderStatus.rejected:
        bg = AppColors.error.withValues(alpha: 0.1);
        border = AppColors.error.withValues(alpha: 0.3);
        textColor = AppColors.error;
        icon = Icons.cancel_rounded;
        break;
      case OrderStatus.outForDelivery:
        bg = Colors.blue.withValues(alpha: 0.12);
        border = Colors.blue.withValues(alpha: 0.3);
        textColor = Colors.blue.shade800;
        icon = Icons.moped_rounded;
        break;
      case OrderStatus.packing:
      case OrderStatus.ready:
        bg = Colors.teal.withValues(alpha: 0.12);
        border = Colors.teal.withValues(alpha: 0.3);
        textColor = Colors.teal.shade800;
        icon = Icons.inventory_2_rounded;
        break;
      case OrderStatus.pending:
      default:
        bg = Colors.amber.withValues(alpha: 0.15);
        border = Colors.amber.withValues(alpha: 0.3);
        textColor = Colors.amber.shade900;
        icon = Icons.schedule_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textColor),
          const SizedBox(width: 4),
          Text(
            status,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(
    String currentStatus,
    BuildContext context, {
    bool isPickup = false,
  }) {
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    final isHindi = langProvider.isHindi;
    final isHinglish = langProvider.isHinglish;

    if (currentStatus == OrderStatus.cancelled ||
        currentStatus == 'Cancelled' ||
        currentStatus == 'Rejected') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isHindi
                    ? 'यह ऑर्डर कैंसिल हो चुका है'
                    : (isHinglish
                        ? 'Yeh order cancel ho gaya hai'
                        : 'This order has been cancelled'),
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF991B1B),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final int activeMilestone;
    if (currentStatus == OrderStatus.delivered || currentStatus == 'Delivered') {
      activeMilestone = 3;
    } else if (currentStatus == OrderStatus.outForDelivery ||
        currentStatus == 'Out for Delivery' ||
        currentStatus == OrderStatus.ready ||
        currentStatus == 'Ready') {
      activeMilestone = 2;
    } else if (currentStatus == OrderStatus.packing ||
        currentStatus == OrderStatus.packed ||
        currentStatus == 'Packing' ||
        currentStatus == 'Packed') {
      activeMilestone = 1;
    } else {
      activeMilestone = 0;
    }

    final List<String> stepLabels;
    if (isPickup) {
      if (isHindi) {
        stepLabels = ['ऑर्डर दिया', 'तैयार हो रहा', 'पिकअप तैयार', 'पिकअप हुआ'];
      } else if (isHinglish) {
        stepLabels = ['Order Placed', 'Preparing', 'Ready to Pick', 'Picked Up'];
      } else {
        stepLabels = ['Placed', 'Preparing', 'Ready', 'Picked Up'];
      }
    } else {
      if (isHindi) {
        stepLabels = ['ऑर्डर दिया', 'पैकिंग', 'रास्ते में', 'डिलीवर हुआ'];
      } else if (isHinglish) {
        stepLabels = ['Order Placed', 'Packing', 'On the Way', 'Delivered'];
      } else {
        stepLabels = ['Placed', 'Packing', 'On the way', 'Delivered'];
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Row(
        children: List.generate(stepLabels.length * 2 - 1, (index) {
          if (index.isOdd) {
            final stepIndex = index ~/ 2;
            return _buildTimelineLine(activeMilestone > stepIndex);
          } else {
            final stepIndex = index ~/ 2;
            return _buildTimelineStep(stepLabels[stepIndex], stepIndex, activeMilestone);
          }
        }),
      ),
    );
  }

  Widget _buildTimelineStep(String label, int stepIndex, int currentIndex) {
    final bool isCompleted = stepIndex <= currentIndex;
    final bool isCurrent = stepIndex == currentIndex;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted ? AppColors.primaryDark : Colors.grey.shade300,
            border: isCurrent
                ? Border.all(color: AppColors.primaryLight, width: 2.5)
                : null,
            boxShadow: isCompleted
                ? [
                    BoxShadow(
                      color: AppColors.primaryDark.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: isCompleted
              ? const Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: AppColors.white,
                )
              : null,
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 66,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 10,
              height: 1.15,
              fontWeight: isCurrent
                  ? FontWeight.w700
                  : (isCompleted ? FontWeight.w600 : FontWeight.w400),
              color: isCompleted ? AppColors.primaryDark : AppColors.textLight,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineLine(bool isCompleted) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(bottom: 22),
        height: 2.5,
        decoration: BoxDecoration(
          color: isCompleted ? AppColors.primaryDark : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(1.5),
        ),
      ),
    );
  }

  Widget _buildCustomerPaymentStatusBadge(String? status, String method) {
    Color bg;
    Color border;
    Color textColor;
    String label;
    IconData icon;

    switch (status) {
      case PaymentStatus.paid:
        bg = AppColors.primaryLight.withValues(alpha: 0.15);
        border = AppColors.primaryDark.withValues(alpha: 0.3);
        textColor = AppColors.primaryDark;
        label = 'Paid Online';
        icon = Icons.check_circle_rounded;
        break;
      case PaymentStatus.refunded:
        bg = Colors.purple.withValues(alpha: 0.1);
        border = Colors.purple.withValues(alpha: 0.3);
        textColor = Colors.purple.shade700;
        label = 'Refunded';
        icon = Icons.replay_rounded;
        break;
      case PaymentStatus.pendingVerification:
        bg = Colors.amber.withValues(alpha: 0.15);
        border = Colors.amber.withValues(alpha: 0.4);
        textColor = Colors.amber.shade900;
        label = 'Pending Verification';
        icon = Icons.hourglass_top_rounded;
        break;
      case PaymentStatus.failed:
        bg = AppColors.error.withValues(alpha: 0.1);
        border = AppColors.error.withValues(alpha: 0.3);
        textColor = AppColors.error;
        label = 'Failed';
        icon = Icons.cancel_rounded;
        break;
      case PaymentStatus.paymentPending:
        bg = Colors.orange.withValues(alpha: 0.1);
        border = Colors.orange.withValues(alpha: 0.3);
        textColor = Colors.orange.shade900;
        label = 'Payment Pending';
        icon = Icons.pending_actions_rounded;
        break;
      default:
        bg = Colors.grey.withValues(alpha: 0.1);
        border = Colors.grey.withValues(alpha: 0.3);
        textColor = AppColors.textMid;
        label = (method == 'UPI') ? 'Pending' : 'Pay on Delivery';
        icon = Icons.schedule_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.caption(color: textColor).copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showUpdateUtrDialog(BuildContext context, String orderId, String? currentUtr) {
    final controller = TextEditingController(text: currentUtr ?? '');
    String? errorText;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primaryDark),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Submit Payment UTR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter 12-digit UPI Transaction / UTR number from your payment app (GPay, PhonePe, Paytm):',
                  style: TextStyle(fontSize: 13, color: AppColors.textMid),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    labelText: 'UTR / Transaction ID',
                    hintText: 'e.g. 423948291039',
                    errorText: errorText,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.receipt_long_rounded),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final utr = controller.text.trim();
                  if (!PaymentService().isValidUtr(utr)) {
                    setDialogState(() {
                      errorText = 'Enter valid 8-35 character UTR / ref number';
                    });
                    return;
                  }
                  try {
                    await PaymentService().submitCustomerUtr(orderId: orderId, utr: utr);
                    if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text('UTR submitted! Shopkeeper will verify shortly.'),
                          backgroundColor: AppColors.primaryDark,
                        ),
                      );
                    }
                  } catch (e) {
                    setDialogState(() {
                      errorText = e.toString().replaceAll('Exception: ', '');
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Submit'),
              ),
            ],
          );
        },
      ),
    );
  }
}
