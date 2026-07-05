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
    final String phone = userProvider.phoneNumber;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        automaticallyImplyLeading: !isTab,
        title: Text(langProvider.translate('my_orders')),
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
                    langProvider.translate('please_login'),
                    style: AppTextStyles.bodyMedium(color: AppColors.textMid),
                  ),
                ],
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('phone_number', isEqualTo: phone)
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
                          langProvider.translate('no_orders'),
                          style: AppTextStyles.bodyMedium(
                            color: AppColors.textMid,
                          ),
                        ),
                      ],
                    ),
                  );
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _callShopOwner(context),
        backgroundColor: AppColors.accentPink,
        icon: const Icon(Icons.call_rounded, color: AppColors.white),
        label: Text(
          langProvider.translate('call_shop'),
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
                      langProvider.translate('date'),
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
                      langProvider.translate('total_amount'),
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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1, thickness: 1, color: AppColors.bgTint),
            ),

            if (status == 'Cancelled')
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
                      ? 'Order Cancel by Shop. Reason: $cancellationReason'
                      : langProvider.translate('order_cancelled'),
                  style: AppTextStyles.bodySemiBold(
                    color: AppColors.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else ...[
              _buildTimeline(status),
              if (status == 'Pending') ...[
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
                            langProvider.translate('cancel_order_q'),
                            style: AppTextStyles.heading2(
                              color: AppColors.textDark,
                            ),
                          ),
                          content: Text(
                            langProvider.translate('cancel_order_sure'),
                            style: AppTextStyles.bodyMedium(
                              color: AppColors.textMid,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogCtx),
                              child: Text(
                                langProvider.translate('no_btn'),
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
                                  await FirebaseFirestore.instance
                                      .runTransaction((transaction) async {
                                        final orderRef = FirebaseFirestore
                                            .instance
                                            .collection('orders')
                                            .doc(doc.id);
                                        final snapshot = await transaction.get(
                                          orderRef,
                                        );

                                        if (!snapshot.exists)
                                          throw Exception('Order not found');

                                        final status =
                                            snapshot.data()?['status'] ??
                                            'Pending';
                                        if (status != 'Pending') {
                                          throw Exception('NOT_PENDING');
                                        }

                                        // --- READ PHASE ---
                                        final Map<DocumentReference, DocumentSnapshot> productDocs = {};
                                        for (var item in items) {
                                          final itemData = item as Map<String, dynamic>;
                                          final String? itemId = itemData['id']?.toString();
                                          if (itemId != null) {
                                            final productRef = FirebaseFirestore.instance.collection('products').doc(itemId);
                                            productDocs[productRef] = await transaction.get(productRef);
                                          }
                                        }

                                        // --- WRITE PHASE ---
                                        for (var item in items) {
                                          final itemData = item as Map<String, dynamic>;
                                          final String? itemId = itemData['id']?.toString();
                                          if (itemId != null) {
                                            final productRef = FirebaseFirestore.instance.collection('products').doc(itemId);
                                            final productDoc = productDocs[productRef];
                                            if (productDoc != null && productDoc.exists) {
                                              transaction.update(productRef, {
                                                'stock_quantity': FieldValue.increment(itemData['quantity']),
                                              });
                                            }
                                          }
                                        }

                                        transaction.update(orderRef, {
                                          'status': 'Cancelled',
                                        });
                                      });
                                  if (context.mounted) {
                                    SoundService().success();
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text(langProvider.translate('order_cancelled')),
                                        content: const Text('Your order has been cancelled successfully.'),
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
                              child: Text(langProvider.translate('yes_cancel')),
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
                      langProvider.translate('cancel_order_btn'),
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
                child: Row(
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
                            langProvider.translate('out_for_delivery'),
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
                            langProvider.translate('delivery_pin'),
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

            const SizedBox(height: 16),
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                collapsedIconColor: AppColors.primaryDark,
                iconColor: AppColors.primaryDark,
                title: Text(
                  '${items.length} ${langProvider.translate('items')}',
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
                          child: Text(
                            itemData['name'] ?? '',
                            style: AppTextStyles.bodyMedium(
                              color: AppColors.textMid,
                            ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline(String currentStatus) {
    int currentIndex = 0;
    if (currentStatus == 'Packed') currentIndex = 1;
    if (currentStatus == 'Out for Delivery' || currentStatus == 'Ready')
      currentIndex = 2;
    if (currentStatus == 'Delivered') currentIndex = 3;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildTimelineStep('Pending', 0, currentIndex),
          _buildTimelineLine(currentIndex > 0),
          _buildTimelineStep('Packed', 1, currentIndex),
          _buildTimelineLine(currentIndex > 1),
          _buildTimelineStep('Out', 2, currentIndex),
          _buildTimelineLine(currentIndex > 2),
          _buildTimelineStep('Delivered', 3, currentIndex),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(String label, int stepIndex, int currentIndex) {
    final bool isCompleted = stepIndex <= currentIndex;
    final bool isCurrent = stepIndex == currentIndex;
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted ? AppColors.primaryDark : AppColors.bgTint,
            border: isCurrent
                ? Border.all(color: AppColors.primaryLight, width: 3)
                : null,
            boxShadow: isCompleted
                ? [
                    BoxShadow(
                      color: AppColors.primaryDark.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: isCompleted
              ? const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: AppColors.white,
                )
              : null,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style:
              AppTextStyles.captionMedium(
                color: isCompleted
                    ? AppColors.primaryDark
                    : AppColors.textLight,
              ).copyWith(
                fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
              ),
        ),
      ],
    );
  }

  Widget _buildTimelineLine(bool isCompleted) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(bottom: 24, left: 4, right: 4),
        height: 3,
        decoration: BoxDecoration(
          color: isCompleted ? AppColors.primaryDark : AppColors.bgTint,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
