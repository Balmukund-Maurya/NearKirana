import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'app_theme.dart';
import 'sound_service.dart';
import 'modern_loader.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'animation_helpers.dart';
import 'package:near_kirana/firebase_utils.dart';

class AdminOrderCard extends StatelessWidget {
  final DocumentSnapshot orderDoc;

  const AdminOrderCard({super.key, required this.orderDoc});

  @override
  Widget build(BuildContext context) {
    final data = orderDoc.data() as Map<String, dynamic>;
    final String customerName = data['customer_name'] ?? 'Unknown';
    final String phone = data['phone_number'] ?? '';
    final String type = data['delivery_type'] ?? '';
    final String status = data['status'] ?? 'Pending';
    final double total =
        double.tryParse(data['total_amount']?.toString() ?? '0') ?? 0.0;
    final String? deliveryAddress = data['delivery_address'];
    final double? customerLat = (data['customer_lat'] as num?)?.toDouble();
    final double? customerLng = (data['customer_lng'] as num?)?.toDouble();
    final List items = data['items'] ?? [];
    final Timestamp? createdAt = data['created_at'] as Timestamp?;
    final String timeStr = createdAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(createdAt.toDate())
        : '';
    final bool isPaid =
        data['payment_method'] != null && data['payment_method'] != 'Unpaid';
    final String paymentMethod = data['payment_method'] ?? 'Unpaid';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getStatusColor(status).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _getStatusColor(status).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _getStatusColor(status).withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _getStatusIcon(status),
                      color: _getStatusColor(status),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      status.toUpperCase(),
                      style: AppTextStyles.bodySemiBold(
                        color: _getStatusColor(status),
                      ).copyWith(letterSpacing: 1, fontSize: 12),
                    ),
                  ],
                ).animate(key: ValueKey(status)).popIn(),
                Text(
                  timeStr,
                  style: AppTextStyles.captionMedium(color: AppColors.textMid),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer Info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerName,
                            style: AppTextStyles.heading2(
                              color: AppColors.textDark,
                            ).copyWith(fontSize: 18),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.phone_rounded,
                                size: 14,
                                color: AppColors.textMid,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                phone,
                                style: AppTextStyles.captionMedium(
                                  color: AppColors.textMid,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: type == 'Delivery'
                            ? Colors.blue.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: type == 'Delivery'
                              ? Colors.blue.withValues(alpha: 0.3)
                              : Colors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            type == 'Delivery'
                                ? Icons.moped_rounded
                                : Icons.storefront_rounded,
                            size: 16,
                            color: type == 'Delivery'
                                ? Colors.blue
                                : Colors.orange,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            type,
                            style: AppTextStyles.bodySemiBold(
                              color: type == 'Delivery'
                                  ? Colors.blue
                                  : Colors.orange,
                            ).copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (type == 'Delivery' &&
                    deliveryAddress != null &&
                    deliveryAddress.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: AppColors.textMid,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            deliveryAddress,
                            style: AppTextStyles.bodyMedium(
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            HapticFeedback.lightImpact();
                            Uri url;
                            if (customerLat != null && customerLng != null) {
                              url = Uri.parse(
                                'https://www.google.com/maps/dir/?api=1&destination=$customerLat,$customerLng',
                              );
                            } else {
                              url = Uri.parse(
                                'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(deliveryAddress)}',
                              );
                            }
                            try {
                              await launchUrl(
                                url,
                                mode: LaunchMode.externalApplication,
                              );
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(behavior: SnackBarBehavior.floating, content: Text('Could not open Maps.'),
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(
                            Icons.directions_rounded,
                            color: Colors.blue,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.blue.withValues(alpha: 0.1),
                          ),
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ],

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.bgTint,
                  ),
                ),

                // Items
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
                    title: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withValues(
                              alpha: 0.2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${items.length}',
                            style: AppTextStyles.bodySemiBold(
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Items Ordered',
                          style: AppTextStyles.bodySemiBold(
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                    children: items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: 8.0,
                          left: 8,
                          right: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '• ${item['name']}',
                                style: AppTextStyles.bodyMedium(
                                  color: AppColors.textMid,
                                ),
                              ),
                            ),
                            Text(
                              '${item['quantity']}x',
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

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.bgTint,
                  ),
                ),

                // Total & Payment Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Amount',
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isPaid
                            ? AppColors.primaryLight.withValues(alpha: 0.2)
                            : AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPaid
                              ? AppColors.primaryDark
                              : AppColors.error,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isPaid
                                ? Icons.check_circle_rounded
                                : Icons.pending_rounded,
                            size: 14,
                            color: isPaid
                                ? AppColors.primaryDark
                                : AppColors.error,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            paymentMethod,
                            style: AppTextStyles.bodySemiBold(
                              color: isPaid
                                  ? AppColors.primaryDark
                                  : AppColors.error,
                            ).copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Actions
                if (status == 'Pending' ||
                    status == 'Packed' ||
                    status == 'Out for Delivery' ||
                    status == 'Ready') ...[
                  const SizedBox(height: 20),
                  _buildActionRow(context, orderDoc, type, status, total),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(
    BuildContext context,
    DocumentSnapshot orderDoc,
    String deliveryType,
    String currentStatus,
    double totalAmount,
  ) {
    final String orderId = orderDoc.id;
    final Map<String, dynamic> data = orderDoc.data() as Map<String, dynamic>;

    if (currentStatus == 'Pending' ||
        currentStatus == 'Packed' ||
        currentStatus == 'Out for Delivery' ||
        currentStatus == 'Ready') {
      return Row(
        children: [
          Expanded(
            child: _buildCancelButton(context, orderId, totalAmount, data),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _buildNextStepButton(
              context,
              orderId,
              data,
              deliveryType,
              currentStatus,
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: _buildNextStepButton(
        context,
        orderId,
        data,
        deliveryType,
        currentStatus,
      ),
    );
  }

  Widget _buildNextStepButton(
    BuildContext context,
    String orderId,
    Map<String, dynamic> data,
    String deliveryType,
    String currentStatus,
  ) {
    String nextStatus = '';
    String buttonText = '';
    IconData buttonIcon = Icons.check_rounded;
    Color buttonColor = AppColors.primaryDark;

    if (currentStatus == 'Pending') {
      nextStatus = 'Packed';
      buttonText = 'Pack Order';
      buttonIcon = Icons.inventory_2_rounded;
      buttonColor = Colors.orange;
    } else if (currentStatus == 'Packed') {
      if (deliveryType == 'Delivery') {
        nextStatus = 'Out for Delivery';
        buttonText = 'Dispatch';
        buttonIcon = Icons.moped_rounded;
        buttonColor = Colors.blue;
      } else {
        nextStatus = 'Ready';
        buttonText = 'Ready for Pickup';
        buttonIcon = Icons.storefront_rounded;
        buttonColor = Colors.blue;
      }
    } else if (currentStatus == 'Out for Delivery' ||
        currentStatus == 'Ready') {
      nextStatus = 'Delivered';
      buttonText = 'Verify Delivery';
      buttonIcon = Icons.done_all_rounded;
      buttonColor = AppColors.primaryDark;
    }

    return ElevatedButton.icon(
      onPressed: () {
        HapticFeedback.mediumImpact();
        if (nextStatus == 'Delivered') {
          _showDeliveryVerificationDialog(context, orderId, data, nextStatus);
        } else if (nextStatus == 'Out for Delivery') {
          _showDispatchDialog(context, orderId, data, nextStatus);
        } else {
          FirebaseUtils.firestore.collection('orders').doc(orderId).update({
            'status': nextStatus,
          });
          SoundService().statusUpdated();
        }
      },
      icon: Icon(buttonIcon, size: 20),
      label: Text(buttonText),
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        foregroundColor: AppColors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
    );
  }

  Widget _buildCancelButton(
    BuildContext context,
    String orderId,
    double totalAmount,
    Map<String, dynamic> data,
  ) {
    return TextButton.icon(
      onPressed: () {
        HapticFeedback.lightImpact();
        _showCancelDialog(context, orderId, totalAmount, data);
      },
      icon: const Icon(Icons.cancel_rounded, size: 18),
      label: const Text('Cancel'),
      style: TextButton.styleFrom(
        backgroundColor: AppColors.error.withValues(alpha: 0.1),
        foregroundColor: AppColors.error,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Future<void> _showDeliveryVerificationDialog(
    BuildContext context,
    String orderId,
    Map<String, dynamic> data,
    String nextStatus,
  ) async {
    final expectedPin = data['delivery_pin']?.toString();
    final pinController = TextEditingController();
    bool showError = false;
    bool showPaymentError = false;
    String? selectedPayment;
    if (data['payment_method'] == 'Cash' ||
        data['payment_method'] == 'UPI' ||
        data['payment_method'] == 'Khata') {
      selectedPayment = data['payment_method'];
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.verified_user_rounded,
                color: AppColors.primaryDark,
              ),
              const SizedBox(width: 8),
              Text(
                'Verify Delivery',
                style: AppTextStyles.heading2(color: AppColors.textDark),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (expectedPin != null && expectedPin.isNotEmpty) ...[
                  Text(
                    'Ask customer for their 4-digit PIN',
                    style: AppTextStyles.captionMedium(
                      color: AppColors.textMid,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      letterSpacing: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                    decoration: InputDecoration(
                      hintText: '----',
                      errorText: showError ? 'Invalid PIN' : null,
                      filled: true,
                      fillColor: AppColors.bgTint,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      counterText: '',
                    ),
                    onChanged: (v) {
                      if (showError) setState(() => showError = false);
                    },
                  ),
                  const SizedBox(height: 24),
                ],

                Text(
                  'Payment Received Via:',
                  style: AppTextStyles.bodySemiBold(color: AppColors.textDark),
                ),
                if (showPaymentError)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '* Please select a payment method',
                      style: AppTextStyles.captionMedium(color: AppColors.error),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: ['Cash', 'UPI', 'Khata'].map((method) {
                    final isSelected = selectedPayment == method;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              selectedPayment = method;
                              showPaymentError = false;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryLight.withValues(alpha: 0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primaryDark
                                    : AppColors.bgTint,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              method,
                              style: AppTextStyles.bodySemiBold(
                                color: isSelected
                                    ? AppColors.primaryDark
                                    : AppColors.textMid,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 12,
                    children: [
                      if (expectedPin != null && expectedPin.isNotEmpty)
                        TextButton(
                          onPressed: () async {
                            if (selectedPayment == null) {
                              setState(() => showPaymentError = true);
                              return;
                            }
                            HapticFeedback.lightImpact();
                            Navigator.pop(dialogContext);
                            // FIX-26: Admin bypass logic should also use atomic batch for Khata updates
                            final batch = FirebaseUtils.firestore.batch();
                            final orderRef = FirebaseUtils.firestore
                                .collection('orders')
                                .doc(orderId);

                            batch.update(orderRef, {
                              'status': nextStatus,
                              'payment_method': selectedPayment,
                              'pin_bypassed': true,
                            });

                            if (nextStatus == 'Delivered' && selectedPayment == 'Khata') {
                              final phone = data['phone_number'] as String?;
                              final total = (data['total_amount'] as num?)?.toDouble() ?? 0.0;
                              if (phone != null && total > 0) {
                                final customerQuery = await FirebaseUtils.firestore
                                    .collection('customers')
                                    .where('mobile', isEqualTo: phone)
                                    .limit(1)
                                    .get();
                                if (customerQuery.docs.isNotEmpty) {
                                  final customerRef = customerQuery.docs.first.reference;
                                  batch.update(customerRef, {
                                    'shop_balances.${data['shop_id']}': FieldValue.increment(total),
                                    'total_udhaar': FieldValue.increment(total),
                                    'shop_ids': FieldValue.arrayUnion([data['shop_id']]),
                                  });
                                  batch.set(customerRef.collection('khata_transactions').doc(), {
                                    'amount': total,
                                    'type': 'debit',
                                    'shop_id': data['shop_id'],
                                    'description': 'Order Delivered (#${orderId.substring(0, 5)})',
                                    'timestamp': FieldValue.serverTimestamp(),
                                  });
                                }
                              }
                            }

                            await batch.commit();
                            SoundService().orderDelivered();
                          },
                          child: Text(
                            'Skip PIN',
                            style: AppTextStyles.bodySemiBold(color: AppColors.error),
                          ),
                        ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(
                          'Cancel',
                          style: AppTextStyles.bodySemiBold(color: AppColors.textMid),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          if (selectedPayment == null) {
                            setState(() => showPaymentError = true);
                            return;
                          }
                          if (expectedPin == null ||
                              expectedPin.isEmpty ||
                              pinController.text.trim() == expectedPin) {
                            Navigator.pop(dialogContext);

                            // FIX-8: Atomic batch — Khata + order status update together
                            final batch = FirebaseUtils.firestore.batch();
                            final orderRef = FirebaseUtils.firestore
                                .collection('orders')
                                .doc(orderId);

                            // Add order status update to batch
                            batch.update(orderRef, {
                              'status': nextStatus,
                              'payment_method': selectedPayment,
                            });

                            // Add Khata update to SAME batch if delivered via Khata
                            if (nextStatus == 'Delivered' && selectedPayment == 'Khata') {
                              final phone = data['phone_number'] as String?;
                              final total = (data['total_amount'] as num?)?.toDouble() ?? 0.0;
                              if (phone != null && total > 0) {
                                final customerQuery = await FirebaseUtils.firestore
                                    .collection('customers')
                                    .where('mobile', isEqualTo: phone)
                                    .limit(1)
                                    .get();
                                if (customerQuery.docs.isNotEmpty) {
                                  final customerRef = customerQuery.docs.first.reference;
                                  batch.update(customerRef, {
                                    'shop_balances.${data['shop_id']}': FieldValue.increment(total),
                                    'total_udhaar': FieldValue.increment(total),
                                    'shop_ids': FieldValue.arrayUnion([data['shop_id']]),
                                  });
                                  batch.set(customerRef.collection('khata_transactions').doc(), {
                                    'amount': total,
                                    'type': 'debit',
                                    'shop_id': data['shop_id'],
                                    'description': 'Order Delivered (#${orderId.substring(0, 5)})',
                                    'timestamp': FieldValue.serverTimestamp(),
                                  });
                                }
                              }
                            }

                            await batch.commit();
                            SoundService().orderDelivered();
                          } else {
                            HapticFeedback.heavyImpact();
                            setState(() => showError = true);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('Confirm'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDispatchDialog(
    BuildContext context,
    String orderId,
    Map<String, dynamic> data,
    String nextStatus,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final boyNameController = TextEditingController(
      text: prefs.getString('last_delivery_boy_name') ?? '',
    );
    final boyPhoneController = TextEditingController(
      text: prefs.getString('last_delivery_boy_phone') ?? '',
    );

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Assign Delivery',
          style: AppTextStyles.heading2(color: AppColors.textDark),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: boyNameController,
              decoration: InputDecoration(
                labelText: 'Delivery Boy Name (e.g. Raju)',
                labelStyle: AppTextStyles.bodyMedium(color: AppColors.textMid),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: boyPhoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number (Optional)',
                labelStyle: AppTextStyles.bodyMedium(color: AppColors.textMid),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodySemiBold(color: AppColors.textMid),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = boyNameController.text.trim();
              final phone = boyPhoneController.text.trim();
              if (name.isEmpty) {
                HapticFeedback.heavyImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(behavior: SnackBarBehavior.floating, content: Text('Please enter a name.')),
                );
                return;
              }

              await prefs.setString('last_delivery_boy_name', name);
              await prefs.setString('last_delivery_boy_phone', phone);

              FirebaseUtils.firestore
                  .collection('orders')
                  .doc(orderId)
                  .update({
                    'status': nextStatus,
                    'delivery_boy_name': name,
                    'delivery_boy_phone': phone,
                  });
              SoundService().orderDispatched();
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text('Dispatch Order'),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(
    BuildContext context,
    String orderId,
    double totalAmount,
    Map<String, dynamic> data,
  ) {
    String selectedReason = 'Out of Stock';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.error),
              const SizedBox(width: 8),
              Text(
                'Cancel Order',
                style: AppTextStyles.heading2(color: AppColors.textDark),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select a reason for cancellation:',
                style: AppTextStyles.bodyMedium(color: AppColors.textMid),
              ),
              const SizedBox(height: 12),
              RadioGroup<String>(
                groupValue: selectedReason,
                onChanged: (val) => setState(() => selectedReason = val!),
                child: Column(
                  children: [
                    ...[
                      'Out of Stock',
                      'Shop is Closed',
                      'Outside Delivery Area',
                      'Other',
                    ].map((reason) {
                      return RadioListTile<String>(
                        title: Text(
                          reason,
                          style: AppTextStyles.bodyMedium(color: AppColors.textDark),
                        ),
                        value: reason,
                        activeColor: AppColors.error,
                        contentPadding: EdgeInsets.zero,
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'No, Keep It',
                style: AppTextStyles.bodySemiBold(color: AppColors.textMid),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                _executeCancellation(
                  context,
                  orderId,
                  data,
                  selectedReason,
                  totalAmount,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text('Cancel Order'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executeCancellation(
    BuildContext context,
    String orderId,
    Map<String, dynamic> data,
    String selectedReason,
    double finalTotal,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: ModernLoader(color: AppColors.primaryDark),
      ),
    );
    try {
      final phone = data['phone_number'] as String?;
      // FIX-2: Check payment_method, not delivery_type (delivery_type is 'Delivery'/'Pickup' only)
      final paymentMethod = data['payment_method'] as String?;
      DocumentReference? customerRef;

      // Prepare Khata logic outside transaction
      if (paymentMethod == 'Khata' && phone != null) {
        final customerQuery = await FirebaseUtils.firestore
            .collection('customers')
            .where('mobile', isEqualTo: phone)
            .limit(1)
            .get();
        if (customerQuery.docs.isNotEmpty) {
          customerRef = customerQuery.docs.first.reference;
        }
      }

      await FirebaseUtils.firestore.runTransaction((transaction) async {
        final orderDocRef = FirebaseUtils.firestore
            .collection('orders')
            .doc(orderId);
        final orderSnapshot = await transaction.get(orderDocRef);
        
        if (!orderSnapshot.exists) {
          throw Exception('Order not found');
        }

        final status = orderSnapshot.data()?['status'] as String?;
        if (status == 'Cancelled') {
          throw Exception('Already cancelled');
        }

        final items = data['items'] as List<dynamic>? ?? [];
        
        // --- 1. PERFORM ALL READS FIRST ---
        final Map<DocumentReference, DocumentSnapshot> productDocs = {};
        for (var item in items) {
          final String? itemId = item['id']?.toString();
          if (itemId != null) {
            final productRef = FirebaseUtils.firestore.collection('products').doc(itemId);
            productDocs[productRef] = await transaction.get(productRef);
          }
        }
        
        // --- 2. PERFORM ALL WRITES ---
        if (status == 'Delivered' && customerRef != null) {
          transaction.update(customerRef, {
            'shop_balances.${data['shop_id']}': FieldValue.increment(-finalTotal),
          });
          transaction.set(customerRef.collection('khata_transactions').doc(), {
            'amount': finalTotal,
            'type': 'credit',
            'shop_id': data['shop_id'],
            'description': 'Order Cancelled #${orderId.substring(0, 5)}',
            'timestamp': FieldValue.serverTimestamp(),
          });
        }

        transaction.update(orderDocRef, {
          'status': 'Cancelled',
          'cancellation_reason': selectedReason,
        });

        for (var item in items) {
          final String? itemId = item['id']?.toString();
          if (itemId != null) {
            final double qty = (item['quantity'] as num).toDouble();
            final productRef = FirebaseUtils.firestore.collection('products').doc(itemId);
            
            final productDoc = productDocs[productRef];
            if (productDoc != null && productDoc.exists) {
              transaction.update(productRef, {
                'stock_quantity': FieldValue.increment(qty),
              });
            }
          }
        }
      });

      if (context.mounted) {
        Navigator.pop(context); // Close loading indicator
        SoundService().play('cancel.mp3');
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Order Cancelled'),
            content: const Text('The order has been cancelled and stock has been restored successfully.'),
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
        Navigator.pop(context); // Close loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(behavior: SnackBarBehavior.floating, content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Packed':
        return Colors.blue;
      case 'Out for Delivery':
        return Colors.blueAccent;
      case 'Ready':
        return Colors.blueAccent;
      case 'Delivered':
        return AppColors.primaryDark;
      case 'Cancelled':
        return AppColors.error;
      default:
        return AppColors.textMid;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Pending':
        return Icons.pending_actions_rounded;
      case 'Packed':
        return Icons.inventory_2_rounded;
      case 'Out for Delivery':
        return Icons.moped_rounded;
      case 'Ready':
        return Icons.storefront_rounded;
      case 'Delivered':
        return Icons.check_circle_rounded;
      case 'Cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.info_rounded;
    }
  }
}
