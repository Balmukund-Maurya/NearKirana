import 'package:near_kirana/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: MediaQuery.of(context).size.width > 800 ? null : AppBar(
        automaticallyImplyLeading: !isTab,
        title: Text(AppLocalizations.of(context)!.my_orders),
      ),
      body: phone.isEmpty || shopProvider.currentShopId == null
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
                  .where('phone_number', isEqualTo: phone)
                  .where('shop_id', isEqualTo: shopProvider.currentShopId)
                  .limit(100)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: ModernLoader(color: AppColors.primaryDark,
                    ),
                  );
                }

                final orders = snapshot.data?.docs ?? [];

                // Sort orders manually
                orders.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = aData['created_at'] as Timestamp?;
                  final bTime = bData['created_at'] as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime); // descending
                });

                if (orders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_rounded,
                          size: 80,
                          color: AppColors.bgTint,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context)?.no_orders_title ??
                              AppLocalizations.of(context)!.no_orders,
                          style: AppTextStyles.heading2(
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppLocalizations.of(context)?.no_orders_subtitle ??
                              'Your past orders and live tracking will appear here.',
                          style: AppTextStyles.bodyMedium(
                            color: AppColors.textMid,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                if (MediaQuery.of(context).size.width > 800) {
                  return MyOrdersDesktopWrapper(orders: orders);
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(
                    top: 16,
                    left: 16,
                    right: 16,
                    bottom: 80,
                  ),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final doc = orders[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final double total =
                        double.tryParse(
                          data['total_amount']?.toString() ?? '0',
                        ) ??
                        0.0;
                    final String status = data['status'] ?? 'Pending';
                    final Timestamp? createdAt =
                        data['created_at'] as Timestamp?;
                    final dateStr = createdAt != null
                        ? '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}'
                        : '';
                    final String? cancellationReason =
                        data['cancellation_reason'];
                    final items = data['items'] as List<dynamic>? ?? [];

                    return _buildOrderCard(
                          context: context,
                          langProvider: langProvider,
                          doc: doc,
                          data: data,
                          dateStr: dateStr,
                          total: total,
                          status: status,
                          cancellationReason: cancellationReason,
                          items: items,
                        )
                        .animate()
                        .fadeIn(delay: Duration(milliseconds: 50 * index))
                        .slideY(begin: 0.1, end: 0);
                  },
                );
              },
            ),
      floatingActionButton: MediaQuery.of(context).size.width > 800 ? null : FloatingActionButton.extended(
        heroTag: 'fab_my_orders_screen',
        onPressed: () => _callShopOwner(context),
        backgroundColor: AppColors.accentPink,
        icon: const Icon(Icons.call_rounded, color: AppColors.white),
        label: Text(
          AppLocalizations.of(context)!.call_shop,
          style: AppTextStyles.button(),
        ),
      ).animate().scale(delay: 500.ms),
    );
  }

  Widget _buildOrderCard({
    required BuildContext context,
    required LanguageProvider langProvider,
    required QueryDocumentSnapshot doc,
    required Map<String, dynamic> data,
    required String dateStr,
    required double total,
    required String status,
    required String? cancellationReason,
    required List<dynamic> items,
  }) {
    final String paymentMethod = data['payment_method'] ?? 'Cash on Delivery';
    final String? paymentStatus = data['payment_status'] as String?;
    final bool isRefunded = paymentStatus == PaymentStatus.refunded;
    final bool isPendingVerification = paymentStatus == PaymentStatus.pendingVerification;
    final bool isFailed = paymentStatus == PaymentStatus.failed;
    final bool isPaymentPending = paymentStatus == PaymentStatus.paymentPending;
    final String? upiRefId = data['upi_ref_id'] as String?;
    final proposals = ProductSubstitutionService.getAllProposals(data);
    final pendingProposals = proposals.where((p) => p.isPending).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.date,
                      style: AppTextStyles.captionMedium(
                        color: AppColors.textMid,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: AppTextStyles.bodySemiBold(
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.total_amount,
                      style: AppTextStyles.captionMedium(
                        color: AppColors.textMid,
                      ),
                    ),
                    Text(
                      '₹$total',
                      style: AppTextStyles.heading2(
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (paymentMethod == 'UPI')
                        ? AppColors.primaryLight.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        (paymentMethod == 'UPI')
                            ? Icons.account_balance_wallet_rounded
                            : (paymentMethod == 'Khata'
                                ? Icons.book_rounded
                                : Icons.payments_rounded),
                        size: 14,
                        color: (paymentMethod == 'UPI')
                            ? AppColors.primaryDark
                            : AppColors.textMid,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        paymentMethod,
                        style: AppTextStyles.captionMedium(
                          color: (paymentMethod == 'UPI')
                              ? AppColors.primaryDark
                              : AppColors.textMid,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                _buildCustomerPaymentStatusBadge(paymentStatus, paymentMethod),
              ],
            ),
            if (paymentMethod == 'UPI' && status != 'Cancelled' && (isPendingVerification || isPaymentPending || isFailed)) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isFailed
                      ? AppColors.error.withValues(alpha: 0.08)
                      : (isPendingVerification
                          ? Colors.amber.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isFailed
                        ? AppColors.error.withValues(alpha: 0.3)
                        : (isPendingVerification
                            ? Colors.amber.withValues(alpha: 0.3)
                            : Colors.orange.withValues(alpha: 0.3)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isFailed
                          ? Icons.error_outline_rounded
                          : (isPendingVerification
                              ? Icons.hourglass_top_rounded
                              : Icons.info_outline_rounded),
                      size: 16,
                      color: isFailed
                          ? AppColors.error
                          : (isPendingVerification
                              ? Colors.amber.shade900
                              : Colors.orange.shade900),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isFailed
                            ? 'Payment rejected. Check or re-submit UTR.'
                            : (isPendingVerification
                                ? 'Verifying payment: ${upiRefId ?? ''}'
                                : 'Missing payment ref. Submit UTR to verify.'),
                        style: AppTextStyles.caption(
                          color: isFailed
                              ? AppColors.error
                              : (isPendingVerification
                                  ? Colors.amber.shade900
                                  : Colors.orange.shade900),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showUpdateUtrDialog(context, doc.id, upiRefId),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        upiRefId != null ? 'Edit UTR' : 'Enter UTR',
                        style: AppTextStyles.caption(
                          color: isFailed ? AppColors.error : AppColors.primaryDark,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (isRefunded) ...[
              const SizedBox(height: 10),
              Container(
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
                        style: AppTextStyles.caption(color: Colors.purple.shade800).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1, thickness: 1, color: AppColors.bgTint),
            ),

            if (status == OrderStatus.cancelled)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  cancellationReason != null && cancellationReason.isNotEmpty
                      ? 'Order Cancelled: $cancellationReason'
                      : AppLocalizations.of(context)!.order_cancelled,
                  style: AppTextStyles.bodySemiBold(
                    color: AppColors.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else if (status == OrderStatus.rejected)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cancel_outlined, color: AppColors.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Order Rejected: ${data['rejection_reason'] ?? cancellationReason ?? 'Store unavailable'}',
                        style: AppTextStyles.bodySemiBold(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              if (status == OrderStatus.deliveryFailed) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.deepOrange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.deepOrange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Delivery Attempt Failed: ${data['delivery_failure_reason'] ?? 'Pending Re-dispatch'}. Store will re-attempt shortly.',
                          style: AppTextStyles.captionMedium(
                            color: Colors.deepOrange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (status != OrderStatus.delivered &&
                  status != OrderStatus.cancelled &&
                  status != OrderStatus.rejected) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule_rounded, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Estimated Delivery: ${data['estimated_delivery_window'] ?? '35–50 mins'}${data['estimated_delivery_arrival_range'] != null ? ' (${data['estimated_delivery_arrival_range']})' : ''}',
                              style: TextStyle(
                                color: Colors.blue.shade900,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              data['estimated_delivery_disclaimer'] ??
                                  'Approximate delivery window. Variations may occur based on rush & traffic.',
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
                ),
              ],
              _buildTimeline(status, context),
              if (status == OrderStatus.pending) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      showDialog(
                        context: context,
                        builder: (dialogCtx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          title: Text(
                            AppLocalizations.of(context)!.cancel_order_q,
                            style: AppTextStyles.heading2(
                              color: AppColors.textDark,
                            ),
                          ),
                          content: Text(
                            AppLocalizations.of(context)!.cancel_order_sure,
                            style: AppTextStyles.bodyMedium(
                              color: AppColors.textMid,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogCtx),
                              child: Text(
                                AppLocalizations.of(context)!.no_btn,
                                style: AppTextStyles.bodySemiBold(
                                  color: AppColors.textMid,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error,
                                foregroundColor: AppColors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              onPressed: () async {
                                Navigator.pop(dialogCtx);
                                try {
                                  await FirebaseUtils.firestore
                                      .runTransaction((transaction) async {
                                        final orderRef = FirebaseFirestore
                                            .instance
                                            .collection('orders')
                                            .doc(doc.id);
                                        final snapshot = await transaction.get(
                                          orderRef,
                                        );

                                        if (!snapshot.exists) {
                                          throw Exception('Order not found');
                                        }

                                        final status =
                                            snapshot.data()?['status'] ??
                                            OrderStatus.pending;
                                        OrderStateMachine.assertValidTransition(
                                          status,
                                          OrderStatus.cancelled,
                                        );
                                        if (status != OrderStatus.pending) {
                                          throw Exception('NOT_PENDING');
                                        }

                                        // --- READ PHASE ---
                                        final Map<DocumentReference, DocumentSnapshot> productDocs = {};
                                        for (var item in items) {
                                          final itemData = item as Map<String, dynamic>;
                                          final String? itemId = itemData['id']?.toString();
                                          if (itemId != null) {
                                            final productRef = FirebaseUtils.firestore.collection('products').doc(itemId);
                                            productDocs[productRef] = await transaction.get(productRef);
                                          }
                                        }

                                        // --- WRITE PHASE ---
                                        for (var item in items) {
                                          final itemData = item as Map<String, dynamic>;
                                          final String? itemId = itemData['id']?.toString();
                                          if (itemId != null) {
                                            final productRef = FirebaseUtils.firestore.collection('products').doc(itemId);
                                            final productDoc = productDocs[productRef];
                                            if (productDoc != null && productDoc.exists) {
                                              transaction.update(productRef, {
                                                'stock_quantity': FieldValue.increment(itemData['quantity']),
                                              });
                                            }
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
                                    final wasPaid = (data['payment_status'] as String?) == PaymentStatus.paid;
                                    final total = (data['total_amount'] as num?)?.toDouble() ?? 0.0;
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text(wasPaid
                                            ? 'Order Cancelled & Refund Initiated'
                                            : AppLocalizations.of(context)!.order_cancelled),
                                        content: Text(wasPaid
                                            ? 'Your order has been cancelled and a refund of ₹${total.toStringAsFixed(0)} has been recorded.'
                                            : 'Your order has been cancelled successfully.'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    if (e.toString().contains('NOT_PENDING')) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(behavior: SnackBarBehavior.floating, content: Text(
                                            'Sorry, this order is already being processed and cannot be cancelled.',
                                          ),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(behavior: SnackBarBehavior.floating, content: Text(
                                            'Failed to cancel order. Please try again.',
                                          ),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  }
                                  debugPrint('Cancel error: $e');
                                }
                              },
                              child: Text(AppLocalizations.of(context)!.yes_cancel),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.cancel_rounded,
                      color: AppColors.error,
                      size: 18,
                    ),
                    label: Text(
                      AppLocalizations.of(context)!.cancel_order_btn,
                      style: AppTextStyles.bodySemiBold(color: AppColors.error),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.error.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],

            if (status == 'Out for Delivery' &&
                data.containsKey('delivery_boy_name')) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.moped_rounded,
                            color: Colors.blue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(context)!.out_for_delivery,
                                style: AppTextStyles.captionMedium(
                                  color: Colors.blue,
                                ),
                              ),
                              Text(
                                data['delivery_boy_name'],
                                style: AppTextStyles.bodySemiBold(
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (data['delivery_boy_phone'] != null &&
                            data['delivery_boy_phone'].toString().isNotEmpty)
                          IconButton(
                            icon: const Icon(
                              Icons.call_rounded,
                              color: Colors.blue,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.blue.withValues(alpha: 0.2),
                            ),
                            onPressed: () async {
                              HapticFeedback.lightImpact();
                              final Uri launchUri = Uri(
                                scheme: 'tel',
                                path: data['delivery_boy_phone'].toString(),
                              );
                              if (await canLaunchUrl(launchUri)) {
                                await launchUrl(launchUri);
                              }
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          CustomerLiveTrackingScreen.open(
                            context,
                            orderId: doc.id,
                            orderData: data,
                          );
                        },
                        icon: const Icon(Icons.location_on_rounded, size: 16),
                        label: const Text('Live Track on Map (लाइव ट्रैक करें)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (status != 'Delivered' &&
                status != 'Cancelled' &&
                data.containsKey('delivery_pin')) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accentPink.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.accentPink.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accentPink.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.pin_rounded,
                        color: AppColors.accentPink,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.delivery_pin,
                            style: AppTextStyles.captionMedium(
                              color: AppColors.accentPink,
                            ),
                          ),
                          Text(
                            data['delivery_pin'].toString(),
                            style: AppTextStyles.heading1(
                              color: AppColors.textDark,
                            ).copyWith(letterSpacing: 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (pendingProposals.isNotEmpty) ...[
              const SizedBox(height: 14),
              SubstitutionApprovalBanner(
                orderId: doc.id,
                proposals: pendingProposals,
              ),
            ],

            if (status == OrderStatus.delivered) ...[
              if (data['is_reviewed'] == true) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    RatingDisplayPill(
                      rating: (data['shop_rating'] as num?)?.toDouble() ?? 5.0,
                      label: 'Reviewed',
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Thank you for your feedback!',
                      style: AppTextStyles.captionMedium(color: AppColors.textMid),
                    ),
                  ],
                ),
              ] else ...[
                OrderReviewPromptBanner(
                  orderId: doc.id,
                  shopId: data['shop_id']?.toString() ?? '',
                  items: items,
                  customerName: data['customer_name']?.toString(),
                  customerPhone: data['phone_number']?.toString(),
                ),
              ],
            ],

            OrderComplaintSection(
              orderId: doc.id,
              shopId: data['shop_id']?.toString() ?? '',
              customerPhone: data['phone_number']?.toString() ?? '',
              customerName: data['customer_name']?.toString() ?? 'Customer',
              orderItems: items,
              orderStatus: status,
              orderData: data,
            ),

            const SizedBox(height: 16),
            Material(
              color: Colors.transparent,
              child: Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                collapsedIconColor: AppColors.primaryDark,
                iconColor: AppColors.primaryDark,
                title: Text(
                  '${items.length} ${AppLocalizations.of(context)!.items}',
                  style: AppTextStyles.bodySemiBold(color: AppColors.textDark),
                ),
                children: items.map((item) {
                  final itemData = item as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                itemData['name'] ?? '',
                                style: AppTextStyles.bodyMedium(
                                  color: AppColors.textMid,
                                ),
                              ),
                              if (itemData['is_substituted'] == true &&
                                  itemData['substituted_from'] != null)
                                SubstitutedItemBadge(
                                  originalName: itemData['substituted_from'].toString(),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          'Qty: ${itemData['quantity']} x ₹${itemData['price']}',
                          style: AppTextStyles.bodySemiBold(
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    final phone = data['phone_number']?.toString() ?? '';
                    final shopId = data['shop_id']?.toString() ?? '';
                    _showSaveOrderAsListDialog(context, doc.id, phone, shopId, items);
                  },
                  icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                  label: const Text('Save as List'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    side: BorderSide(color: AppColors.primaryDark.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    final shopId = data['shop_id']?.toString() ?? '';
                    ReorderSummaryDialog.showForItems(
                      context: context,
                      sourceTitle: 'Order #${doc.id}',
                      shopId: shopId,
                      items: items.map((i) => Map<String, dynamic>.from(i as Map)).toList(),
                    );
                  },
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text('Reorder'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
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

  Widget _buildTimeline(String currentStatus, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentIndex = OrderStateMachine.getTimelineStepIndex(currentStatus);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildTimelineStep(l10n?.order_status_pending ?? 'Pending', 0, currentIndex),
          _buildTimelineLine(currentIndex > 0),
          _buildTimelineStep(l10n?.order_status_accepted ?? 'Accepted', 1, currentIndex),
          _buildTimelineLine(currentIndex > 1),
          _buildTimelineStep(l10n?.order_status_packing ?? 'Packing', 2, currentIndex),
          _buildTimelineLine(currentIndex > 2),
          _buildTimelineStep(l10n?.order_status_ready ?? 'Ready', 3, currentIndex),
          _buildTimelineLine(currentIndex > 3),
          _buildTimelineStep(l10n?.order_status_out ?? 'Out', 4, currentIndex),
          _buildTimelineLine(currentIndex > 4),
          _buildTimelineStep(l10n?.order_status_delivered ?? 'Delivered', 5, currentIndex),
        ],
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
            color: isCompleted ? AppColors.primaryDark : AppColors.bgTint,
            border: isCurrent
                ? Border.all(color: AppColors.primaryLight, width: 2.5)
                : null,
            boxShadow: isCompleted
                ? [
                    BoxShadow(
                      color: AppColors.primaryDark.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
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
        Text(
          label,
          style: AppTextStyles.caption(
            color: isCompleted
                ? AppColors.primaryDark
                : AppColors.textLight,
          ).copyWith(
            fontSize: 10,
            fontWeight: isCompleted ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineLine(bool isCompleted) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(bottom: 20, left: 2, right: 2),
        height: 2.5,
        decoration: BoxDecoration(
          color: isCompleted ? AppColors.primaryDark : AppColors.bgTint,
          borderRadius: BorderRadius.circular(2),
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
