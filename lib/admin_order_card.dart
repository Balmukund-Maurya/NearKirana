import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'sound_service.dart';
import 'modern_loader.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'payment_service.dart';
import 'order_state_machine.dart';
import 'notification_service.dart';
import 'language_provider.dart';
import 'package:near_kirana/widgets/substitution_widgets.dart';
import 'package:near_kirana/product_substitution_service.dart';
import 'package:near_kirana/widgets/assign_delivery_partner_dialog.dart';
import 'package:near_kirana/customer_live_tracking_screen.dart';

class AdminOrderCard extends StatelessWidget {
  final DocumentSnapshot orderDoc;

  const AdminOrderCard({super.key, required this.orderDoc});

  void _callCustomer(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    try {
      await launchUrl(uri);
    } catch (_) {}
  }

  void _whatsappCustomer(String phone, String customerName) async {
    if (phone.isEmpty) return;
    String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (!cleanPhone.startsWith('91') && cleanPhone.length == 10) {
      cleanPhone = '91$cleanPhone';
    }
    final uri = Uri.parse(
      'https://wa.me/$cleanPhone?text=${Uri.encodeComponent('Namaste $customerName ji, aapka NearKirana order update:')}',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);

    String t(String en, String hi, String hinglish) {
      if (lang.isHindi) return hi;
      if (lang.isHinglish) return hinglish;
      return en;
    }

    String getLocalizedStatus(String s) {
      switch (s) {
        case OrderStatus.pending:
          return t('PENDING', 'लंबित', 'PENDING');
        case OrderStatus.accepted:
          return t('ACCEPTED', 'स्वीकृत', 'ACCEPTED');
        case OrderStatus.packing:
          return t('PACKING', 'पैकिंग जारी', 'PACKING');
        case OrderStatus.packed:
          return t('PACKED', 'पैक हुआ', 'PACKED');
        case OrderStatus.ready:
          return t('READY', 'तैयार है', 'READY');
        case OrderStatus.outForDelivery:
          return t('OUT FOR DELIVERY', 'डिलीवरी पर निकला', 'OUT FOR DELIVERY');
        case OrderStatus.delivered:
          return t('DELIVERED', 'डिलीवर हुआ', 'DELIVERED');
        case OrderStatus.deliveryFailed:
          return t('DELIVERY FAILED', 'डिलीवरी असफल', 'DELIVERY FAILED');
        case OrderStatus.cancelled:
          return t('CANCELLED', 'रद्द किया', 'CANCELLED');
        case OrderStatus.rejected:
          return t('REJECTED', 'अस्वीकृत', 'REJECTED');
        default:
          return s.toUpperCase();
      }
    }

    String getLocalizedDeliveryType(String dt) {
      if (dt == 'Delivery') {
        return t('Delivery', 'डिलीवरी', 'Delivery');
      }
      return t('Pickup', 'पिकअप', 'Pickup');
    }

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
        ? DateFormat('dd MMM, hh:mm a').format(createdAt.toDate())
        : '';
    final String paymentMethod = data['payment_method'] ?? 'Unpaid';
    final String paymentStatus =
        data['payment_status'] ??
        (paymentMethod == 'Cash on Delivery'
            ? PaymentStatus.unpaid
            : PaymentStatus.pendingVerification);
    final bool isPaid = paymentStatus == PaymentStatus.paid;
    final bool isPendingVerification =
        paymentStatus == PaymentStatus.pendingVerification ||
        paymentStatus == PaymentStatus.paymentPending;
    final bool isFailed = paymentStatus == PaymentStatus.failed;
    final bool isRefunded = paymentStatus == PaymentStatus.refunded;
    final String? upiRefId = data['upi_ref_id']?.toString();
    final proposals = ProductSubstitutionService.getAllProposals(data);
    final pendingProposals = proposals.where((p) => p.isPending).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Status, Delivery Type, Order ID & Timestamp
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Status Pill with colored dot
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getStatusColor(status).withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStatusIcon(status),
                            size: 12,
                            color: _getStatusColor(status),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            getLocalizedStatus(status),
                            style: TextStyle(
                              color: _getStatusColor(status),
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Delivery Type Chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: type == 'Delivery' ? const Color(0xFFEFF6FF) : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: type == 'Delivery' ? const Color(0xFFBFDBFE) : const Color(0xFFFDE68A),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            type == 'Delivery' ? Icons.moped_rounded : Icons.storefront_rounded,
                            size: 13,
                            color: type == 'Delivery' ? const Color(0xFF2563EB) : const Color(0xFFD97706),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            getLocalizedDeliveryType(type),
                            style: TextStyle(
                              color: type == 'Delivery' ? const Color(0xFF2563EB) : const Color(0xFFD97706),
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Time & Order ID
                Row(
                  children: [
                    Text(
                      timeStr,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Substitution Notice if pending
                if (pendingProposals.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFFD97706)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${pendingProposals.length} ${t('item substitution awaiting customer approval', 'सामान बदलाव पर ग्राहक की मंजूरी बाकी', 'item substitution customer approval pending')}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Customer Info Row with Direct Call & WhatsApp buttons
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF0C831F).withValues(alpha: 0.1),
                      child: Text(
                        customerName.isNotEmpty ? customerName[0].toUpperCase() : 'C',
                        style: const TextStyle(
                          color: Color(0xFF0C831F),
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                Icons.phone_outlined,
                                size: 13,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                phone,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (phone.isNotEmpty) ...[
                      // Quick Call Button
                      IconButton(
                        onPressed: () => _callCustomer(phone),
                        icon: const Icon(Icons.call_rounded, size: 18, color: Color(0xFF0C831F)),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFDCFCE7),
                          padding: const EdgeInsets.all(8),
                          minimumSize: const Size(36, 36),
                        ),
                        tooltip: t('Call Customer', 'कॉल करें', 'Call Karein'),
                      ),
                      const SizedBox(width: 8),
                      // Quick WhatsApp Button
                      IconButton(
                        onPressed: () => _whatsappCustomer(phone, customerName),
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Color(0xFF0284C7)),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFE0F2FE),
                          padding: const EdgeInsets.all(8),
                          minimumSize: const Size(36, 36),
                        ),
                        tooltip: t('WhatsApp', 'व्हाट्सएप', 'WhatsApp'),
                      ),
                    ],
                  ],
                ),

                // Review Rating Banner if reviewed
                if (data['is_reviewed'] == true) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 6),
                        Text(
                          '${t('Rating', 'रेटिंग', 'Rating')}: ${(data['shop_rating'] as num?)?.toDouble() ?? 5.0} / 5.0',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF92400E),
                          ),
                        ),
                        if (data['review_comment'] != null &&
                            data['review_comment'].toString().trim().isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '"${data['review_comment']}"',
                              style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: Colors.amber.shade900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                // Delivery Address Card
                if (type == 'Delivery' &&
                    deliveryAddress != null &&
                    deliveryAddress.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0C831F).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFF0C831F),
                            size: 15,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            deliveryAddress,
                            style: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                                  SnackBar(
                                    behavior: SnackBarBehavior.floating,
                                    content: Text(t('Could not open Maps.', 'मैप्स नहीं खुल पाया', 'Maps open nahi ho paya.')),
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(
                            Icons.directions_rounded,
                            color: Color(0xFF2563EB),
                            size: 18,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFEFF6FF),
                            padding: const EdgeInsets.all(6),
                            minimumSize: const Size(32, 32),
                          ),
                          tooltip: t('Navigate', 'रास्ता देखें', 'Directions'),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                // Items Accordion
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    collapsedIconColor: const Color(0xFF0C831F),
                    iconColor: const Color(0xFF0C831F),
                    title: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Text(
                            '${items.length}',
                            style: const TextStyle(
                              color: Color(0xFF065F46),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          t('Items Ordered', 'सामान ऑर्डर किए', 'Items Order Kiye'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    children: items.map((item) {
                      final String itemId = item['id']?.toString() ?? item['productId']?.toString() ?? '';
                      final String itemName = item['name']?.toString() ?? '';
                      final bool isSubstituted = item['is_substituted'] == true;
                      final String? substitutedFrom = item['substituted_from']?.toString();
                      final pendingProposal = proposals.where((p) =>
                          p.isPending &&
                          (p.originalProductId == itemId ||
                              p.originalProductName.toLowerCase() == itemName.toLowerCase())).firstOrNull;
                      final bool canPropose = ['Pending', 'Accepted', 'Packing', 'Packed'].contains(status) &&
                          pendingProposal == null;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSubstituted
                              ? const Color(0xFFECFDF5)
                              : (pendingProposal != null ? Colors.amber.shade50 : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSubstituted
                                ? const Color(0xFFA7F3D0)
                                : (pendingProposal != null ? Colors.amber.shade300 : const Color(0xFFF1F5F9)),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFF16A34A),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      item['name'] ?? '',
                                      style: const TextStyle(
                                        color: Color(0xFF1E293B),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${item['quantity']}x • ₹${((item['price'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            if (isSubstituted && substitutedFrom != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: SubstitutedItemBadge(originalName: substitutedFrom),
                              ),
                            if (pendingProposal != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Proposal Pending: "${pendingProposal.substituteProductName}" (${pendingProposal.formattedDifference})',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber.shade900,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () async {
                                        await ProductSubstitutionService.instance.cancelSubstitutionProposal(
                                          orderId: orderDoc.id,
                                          proposalId: pendingProposal.id,
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        child: Text(
                                          t('Cancel', 'रद्द करें', 'Cancel'),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (canPropose)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  icon: const Icon(Icons.swap_horiz, size: 14, color: Color(0xFF0C831F)),
                                  label: Text(
                                    t('Suggest Alternative', 'दूसरा सामान सुझाएं', 'Suggest Alternative'),
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF0C831F), fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: () {
                                    ProposeSubstitutionDialog.show(
                                      context,
                                      orderId: orderDoc.id,
                                      item: Map<String, dynamic>.from(item as Map),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const Divider(height: 20, thickness: 1, color: Color(0xFFF1F5F9)),

                // Total & Payment Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('Total Amount', 'कुल राशि', 'Total Amount'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          '₹${total.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0C831F),
                          ),
                        ),
                      ],
                    ),
                    Builder(
                      builder: (context) {
                        final Color badgeBg;
                        final Color badgeBorder;
                        final IconData badgeIcon;
                        final String badgeText;

                        if (isPaid) {
                          badgeBg = const Color(0xFFECFDF5);
                          badgeBorder = const Color(0xFF0C831F);
                          badgeIcon = Icons.check_circle_rounded;
                          badgeText = (paymentMethod == 'UPI')
                              ? t('UPI (Paid)', 'UPI (भुगतान सफल)', 'UPI (Paid)')
                              : '$paymentMethod (${t('Paid', 'भुगतान सफल', 'Paid')})';
                        } else if (isRefunded) {
                          badgeBg = Colors.purple.withValues(alpha: 0.12);
                          badgeBorder = Colors.purple;
                          badgeIcon = Icons.currency_exchange_rounded;
                          badgeText = t('Refunded', 'रिफंड हुआ', 'Refunded');
                        } else if (isFailed) {
                          badgeBg = AppColors.error.withValues(alpha: 0.12);
                          badgeBorder = AppColors.error;
                          badgeIcon = Icons.cancel_rounded;
                          badgeText = t('Payment Failed', 'भुगतान असफल', 'Payment Failed');
                        } else if (isPendingVerification) {
                          badgeBg = const Color(0xFFFFFBEB);
                          badgeBorder = const Color(0xFFD97706);
                          badgeIcon = Icons.hourglass_top_rounded;
                          badgeText = t('UPI (Verify Pending)', 'UPI (वेरिफिकेशन बाकी)', 'UPI (Verify Pending)');
                        } else {
                          badgeBg = const Color(0xFFF1F5F9);
                          badgeBorder = const Color(0xFF94A3B8);
                          badgeIcon = Icons.payments_outlined;
                          badgeText = t('COD (Unpaid)', 'कैश ऑन डिलीवरी (बाकी)', 'COD (Unpaid)');
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: badgeBorder, width: 1),
                          ),
                          child: Row(
                            children: [
                              Icon(badgeIcon, size: 14, color: badgeBorder),
                              const SizedBox(width: 5),
                              Text(
                                badgeText,
                                style: TextStyle(
                                  color: badgeBorder,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),

                if (upiRefId != null && upiRefId.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.receipt_long_rounded,
                          size: 14,
                          color: Color(0xFF0C831F),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'UPI UTR: ',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                          ),
                        ),
                        SelectableText(
                          upiRefId,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Shopkeeper Payment Verification Action Block for UPI
                if (paymentMethod == 'UPI' &&
                    isPendingVerification &&
                    status != 'Cancelled') ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.verified_user_outlined,
                              size: 16,
                              color: Color(0xFFD97706),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                t(
                                  'Verify customer payment before confirming:',
                                  'ऑर्डर कन्फर्म करने से पहले भुगतान चेक करें:',
                                  'Customer payment verify karein confirm karne se pehle:',
                                ),
                                style: const TextStyle(
                                  color: Color(0xFF92400E),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                  size: 16,
                                ),
                                label: Text(t('Verify & Mark Paid', 'भुगतान चेक हुआ', 'Verify & Mark Paid')),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0C831F),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () async {
                                  final utr = upiRefId ?? 'SHOP_CONFIRMED';
                                  await PaymentService().verifyAndMarkPaid(
                                    orderId: orderDoc.id,
                                    shopId: data['shop_id'] ?? '',
                                    utrRef: utr,
                                    verifiedBy: 'Shop Owner Verified',
                                  );
                                  if (context.mounted) {
                                    SoundService().success();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          t('Payment verified & marked Paid!', 'भुगतान वेरिफाई हो गया!', 'Payment verified & marked Paid!'),
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.close_rounded, size: 16),
                              label: Text(t('Invalid UTR', 'गलत UTR', 'Invalid UTR')),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () async {
                                await PaymentService().markPaymentFailed(
                                  orderId: orderDoc.id,
                                  shopId: data['shop_id'] ?? '',
                                  reason:
                                      'Payment not received / Invalid UTR provided by customer.',
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        t('Payment marked as Failed.', 'भुगतान असफल मार्क किया गया।', 'Payment marked as Failed.'),
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // Delivery Partner Assignment Banner
                if (data['delivery_boy_name'] != null && data['delivery_boy_name'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.two_wheeler_rounded, size: 18, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${t('Rider', 'राइडर', 'Rider')}: ${data['delivery_boy_name']} (${data['delivery_status'] ?? 'assigned'})${data['delivery_boy_phone'] != null && data['delivery_boy_phone'].toString().isNotEmpty ? ' • ${data['delivery_boy_phone']}' : ''}',
                            style: const TextStyle(
                              color: Color(0xFF1E3A8A),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        TextButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            CustomerLiveTrackingScreen.open(
                              context,
                              orderId: orderDoc.id,
                              orderData: data,
                            );
                          },
                          icon: const Icon(Icons.location_on_rounded, size: 14),
                          label: Text(t('Track Live', 'लाइव ट्रैक', 'Track Live')),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF1E3A8A),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Refund Information Banner
                if (isRefunded) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.purple.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.currency_exchange_rounded,
                          size: 16,
                          color: Colors.purple,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Refund Processed: ₹${(data['refund_amount'] as num?)?.toDouble() ?? total} | ID: ${data['refund_id'] ?? 'REF_CONFIRMED'}',
                            style: AppTextStyles.captionMedium(
                              color: Colors.purple.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Delivery Failed Information Banner
                if (status == OrderStatus.deliveryFailed) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.deepOrange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.report_problem_rounded,
                          size: 16,
                          color: Colors.deepOrange,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${t('Delivery Failed', 'डिलीवरी असफल', 'Delivery Failed')}: ${data['delivery_failure_reason'] ?? 'Customer unavailable'}',
                            style: AppTextStyles.captionMedium(
                              color: Colors.deepOrange.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Rejected Order Banner
                if (status == OrderStatus.rejected) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.cancel_rounded,
                          size: 16,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${t('Order Rejected', 'ऑर्डर अस्वीकृत', 'Order Rejected')}: ${data['cancellation_reason'] ?? 'Shop unavailable'}',
                            style: AppTextStyles.captionMedium(
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Actions
                if (OrderStatus.activeStatuses.contains(status)) ...[
                  const SizedBox(height: 14),
                  _buildActionRow(context, orderDoc, type, status, total, t),
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
    String Function(String, String, String) t,
  ) {
    final String orderId = orderDoc.id;
    final Map<String, dynamic> data = orderDoc.data() as Map<String, dynamic>;

    if (currentStatus == OrderStatus.outForDelivery) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                _showFailedDeliveryDialog(context, orderId, data);
              },
              icon: const Icon(Icons.report_problem_rounded, size: 16),
              label: Text(t('Failed Delivery', 'डिलीवरी असफल', 'Failed Delivery')),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepOrange,
                side: const BorderSide(color: Colors.deepOrange),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: _buildNextStepButton(
              context,
              orderId,
              data,
              deliveryType,
              currentStatus,
              t,
            ),
          ),
        ],
      );
    }

    if (currentStatus == OrderStatus.deliveryFailed) {
      return Row(
        children: [
          Expanded(
            child: _buildCancelButton(
              context,
              orderId,
              totalAmount,
              data,
              label: t('Return Order', 'वापस लें', 'Return Order'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: _buildNextStepButton(
              context,
              orderId,
              data,
              deliveryType,
              currentStatus,
              t,
            ),
          ),
        ],
      );
    }

    if (currentStatus == OrderStatus.pending) {
      return Row(
        children: [
          Expanded(
            child: _buildCancelButton(
              context,
              orderId,
              totalAmount,
              data,
              label: t('Reject Order', 'अस्वीकार करें', 'Reject Karein'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: _buildNextStepButton(
              context,
              orderId,
              data,
              deliveryType,
              currentStatus,
              t,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildCancelButton(
            context,
            orderId,
            totalAmount,
            data,
            label: t('Cancel', 'रद्द करें', 'Cancel'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: _buildNextStepButton(
            context,
            orderId,
            data,
            deliveryType,
            currentStatus,
            t,
          ),
        ),
      ],
    );
  }


  void _showFailedDeliveryDialog(
    BuildContext context,
    String orderId,
    Map<String, dynamic> data,
  ) {
    String selectedReason = 'Customer Unreachable / Phone Switched Off';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.report_problem_rounded,
                color: Colors.deepOrange,
              ),
              const SizedBox(width: 8),
              Text(
                'Report Failed Delivery',
                style: AppTextStyles.heading2(color: AppColors.textDark),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select reason why delivery could not be completed:',
                  style: AppTextStyles.bodyMedium(color: AppColors.textMid),
                ),
                const SizedBox(height: 12),
                RadioGroup<String>(
                  groupValue: selectedReason,
                  onChanged: (val) => setState(() => selectedReason = val!),
                  child: Column(
                    children: [
                      ...[
                        'Customer Unreachable / Phone Switched Off',
                        'Customer Refused to Accept Order',
                        'Incorrect / Incomplete Address',
                        'Customer Asked to Reschedule',
                        'Door Locked / Nobody Home',
                        'Other',
                      ].map((reason) {
                        return RadioListTile<String>(
                          title: Text(
                            reason,
                            style: AppTextStyles.bodyMedium(
                              color: AppColors.textDark,
                            ),
                          ),
                          value: reason,
                          activeColor: Colors.deepOrange,
                          contentPadding: EdgeInsets.zero,
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
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
                Navigator.pop(dialogContext);
                try {
                  OrderStateMachine.assertValidTransition(
                    data['status'] ?? OrderStatus.outForDelivery,
                    OrderStatus.deliveryFailed,
                  );
                  await FirebaseUtils.firestore
                      .collection('orders')
                      .doc(orderId)
                      .update({
                        'status': OrderStatus.deliveryFailed,
                        'delivery_failure_reason': selectedReason,
                        'delivery_failed_at': FieldValue.serverTimestamp(),
                      });
                  NotificationService.dispatchOrderStatusNotification(
                    orderId: orderId,
                    newStatus: OrderStatus.deliveryFailed,
                    customerPhone: data['phone_number']?.toString() ?? '',
                    customerUid: data['customer_uid']?.toString(),
                    shopId: data['shop_id']?.toString() ?? '',
                    orderTotal: (data['total_amount'] as num?)?.toDouble(),
                    failureReason: selectedReason,
                  );
                  SoundService().statusUpdated();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        behavior: SnackBarBehavior.floating,
                        content: Text(
                          'Order marked as Delivery Failed. You can re-dispatch or return/cancel.',
                        ),
                        backgroundColor: Colors.deepOrange,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        content: Text(
                          'Error: ${e.toString().replaceAll('Exception: ', '')}',
                        ),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Mark Failed'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextStepButton(
    BuildContext context,
    String orderId,
    Map<String, dynamic> data,
    String deliveryType,
    String currentStatus, [
    String Function(String, String, String)? t,
  ]) {
    final nextStatus = OrderStateMachine.getNextProgressiveStatus(
      currentStatus,
      deliveryType: deliveryType,
    );
    if (nextStatus == null) return const SizedBox.shrink();

    final rawButtonText = OrderStateMachine.getProgressiveButtonLabel(
      currentStatus,
      deliveryType: deliveryType,
    );
    final buttonIcon = OrderStateMachine.getProgressiveButtonIcon(
      currentStatus,
    );
    final buttonColor = OrderStateMachine.getProgressiveButtonColor(
      currentStatus,
    );

    String buttonText = rawButtonText;
    if (t != null) {
      if (rawButtonText.contains('Accept')) {
        buttonText = t('Accept Order', 'ऑर्डर स्वीकारें', 'Order Accept Karein');
      } else if (rawButtonText.contains('Start Packing') || rawButtonText.contains('Pack')) {
        buttonText = t('Start Packing', 'पैकिंग शुरू करें', 'Packing Shuru Karein');
      } else if (rawButtonText.contains('Ready')) {
        buttonText = t('Mark Ready', 'तैयार मार्क करें', 'Ready Mark Karein');
      } else if (rawButtonText.contains('Dispatch')) {
        buttonText = t('Dispatch Order', 'ऑर्डर भेजें', 'Dispatch Order');
      } else if (rawButtonText.contains('Deliver') || rawButtonText.contains('Complete')) {
        buttonText = t('Complete Delivery', 'डिलीवरी पूरी करें', 'Delivery Complete Karein');
      }
    }

    return ElevatedButton.icon(
      onPressed: () async {
        HapticFeedback.mediumImpact();
        try {
          OrderStateMachine.assertValidTransition(currentStatus, nextStatus);

          if (nextStatus == OrderStatus.delivered) {
            _showDeliveryVerificationDialog(context, orderId, data, nextStatus);
          } else if (nextStatus == OrderStatus.outForDelivery) {
            _showDispatchDialog(context, orderId, data, nextStatus);
          } else {
            await FirebaseUtils.firestore
                .collection('orders')
                .doc(orderId)
                .update({
                  'status': nextStatus,
                  if (nextStatus == OrderStatus.accepted)
                    'accepted_at': FieldValue.serverTimestamp(),
                  if (nextStatus == OrderStatus.packing)
                    'packing_started_at': FieldValue.serverTimestamp(),
                  if (nextStatus == OrderStatus.ready)
                    'ready_at': FieldValue.serverTimestamp(),
                });
            NotificationService.dispatchOrderStatusNotification(
              orderId: orderId,
              newStatus: nextStatus,
              customerPhone: data['phone_number']?.toString() ?? '',
              customerUid: data['customer_uid']?.toString(),
              shopId: data['shop_id']?.toString() ?? '',
              orderTotal: (data['total_amount'] as num?)?.toDouble(),
            );
            SoundService().statusUpdated();
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                content: Text(
                  e
                      .toString()
                      .replaceAll('Exception: ', '')
                      .replaceAll('StateError: ', ''),
                ),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      },
      icon: Icon(buttonIcon, size: 18),
      label: Text(
        buttonText,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        foregroundColor: AppColors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }

  Widget _buildCancelButton(
    BuildContext context,
    String orderId,
    double totalAmount,
    Map<String, dynamic> data, {
    String label = 'Cancel',
  }) {
    final currentStatus = data['status']?.toString() ?? OrderStatus.pending;
    final isRejection = currentStatus == OrderStatus.pending;

    return TextButton.icon(
      onPressed: () {
        HapticFeedback.lightImpact();
        _showCancelDialog(
          context,
          orderId,
          totalAmount,
          data,
          isRejection: isRejection,
        );
      },
      icon: Icon(
        isRejection ? Icons.thumb_down_alt_outlined : Icons.close_rounded,
        size: 16,
      ),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
      style: TextButton.styleFrom(
        backgroundColor: AppColors.error.withValues(alpha: 0.1),
        foregroundColor: AppColors.error,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    } else if (data['payment_method'] == 'Cash on Delivery') {
      selectedPayment = 'Cash';
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
                      style: AppTextStyles.captionMedium(
                        color: AppColors.error,
                      ),
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
                                  ? AppColors.primaryLight.withValues(
                                      alpha: 0.2,
                                    )
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
                              if (nextStatus == 'Delivered' &&
                                  selectedPayment != 'Khata')
                                'payment_status': PaymentStatus.paid,
                            });

                            if (nextStatus == 'Delivered' &&
                                selectedPayment == 'Khata') {
                              final phone = data['phone_number'] as String?;
                              final total =
                                  (data['total_amount'] as num?)?.toDouble() ??
                                  0.0;
                              if (phone != null && total > 0) {
                                final customerQuery = await FirebaseUtils
                                    .firestore
                                    .collection('customers')
                                    .where('mobile', isEqualTo: phone)
                                    .limit(1)
                                    .get();
                                if (customerQuery.docs.isNotEmpty) {
                                  final customerRef =
                                      customerQuery.docs.first.reference;
                                  batch.update(customerRef, {
                                    'shop_balances.${data['shop_id']}':
                                        FieldValue.increment(total),
                                    'total_udhaar': FieldValue.increment(total),
                                    'shop_ids': FieldValue.arrayUnion([
                                      data['shop_id'],
                                    ]),
                                  });
                                  batch.set(
                                    customerRef
                                        .collection('khata_transactions')
                                        .doc(),
                                    {
                                      'amount': total,
                                      'type': 'debit',
                                      'shop_id': data['shop_id'],
                                      'description':
                                          'Order Delivered (#${orderId.substring(0, 5)})',
                                      'timestamp': FieldValue.serverTimestamp(),
                                    },
                                  );
                                }
                              }
                            }

                            await batch.commit();
                            NotificationService.dispatchOrderStatusNotification(
                              orderId: orderId,
                              newStatus: nextStatus,
                              customerPhone:
                                  data['phone_number']?.toString() ?? '',
                              customerUid: data['customer_uid']?.toString(),
                              shopId: data['shop_id']?.toString() ?? '',
                              orderTotal: (data['total_amount'] as num?)
                                  ?.toDouble(),
                            );
                            SoundService().orderDelivered();
                          },
                          child: Text(
                            'Skip PIN',
                            style: AppTextStyles.bodySemiBold(
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(
                          'Cancel',
                          style: AppTextStyles.bodySemiBold(
                            color: AppColors.textMid,
                          ),
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
                              if (nextStatus == 'Delivered' &&
                                  selectedPayment != 'Khata')
                                'payment_status': PaymentStatus.paid,
                            });

                            // Add Khata update to SAME batch if delivered via Khata
                            if (nextStatus == 'Delivered' &&
                                selectedPayment == 'Khata') {
                              final phone = data['phone_number'] as String?;
                              final total =
                                  (data['total_amount'] as num?)?.toDouble() ??
                                  0.0;
                              if (phone != null && total > 0) {
                                final customerQuery = await FirebaseUtils
                                    .firestore
                                    .collection('customers')
                                    .where('mobile', isEqualTo: phone)
                                    .limit(1)
                                    .get();
                                if (customerQuery.docs.isNotEmpty) {
                                  final customerRef =
                                      customerQuery.docs.first.reference;
                                  batch.update(customerRef, {
                                    'shop_balances.${data['shop_id']}':
                                        FieldValue.increment(total),
                                    'total_udhaar': FieldValue.increment(total),
                                    'shop_ids': FieldValue.arrayUnion([
                                      data['shop_id'],
                                    ]),
                                  });
                                  batch.set(
                                    customerRef
                                        .collection('khata_transactions')
                                        .doc(),
                                    {
                                      'amount': total,
                                      'type': 'debit',
                                      'shop_id': data['shop_id'],
                                      'description':
                                          'Order Delivered (#${orderId.substring(0, 5)})',
                                      'timestamp': FieldValue.serverTimestamp(),
                                    },
                                  );
                                }
                              }
                            }

                            await batch.commit();
                            NotificationService.dispatchOrderStatusNotification(
                              orderId: orderId,
                              newStatus: nextStatus,
                              customerPhone:
                                  data['phone_number']?.toString() ?? '',
                              customerUid: data['customer_uid']?.toString(),
                              shopId: data['shop_id']?.toString() ?? '',
                              orderTotal: (data['total_amount'] as num?)
                                  ?.toDouble(),
                            );
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
    final assigned = await AssignDeliveryPartnerDialog.show(
      context: context,
      orderId: orderId,
      shopId: data['shop_id']?.toString() ?? '',
      orderData: data,
      nextStatus: nextStatus,
    );

    if (assigned == true) return;

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
                  const SnackBar(
                    behavior: SnackBarBehavior.floating,
                    content: Text('Please enter a name.'),
                  ),
                );
                return;
              }

              await prefs.setString('last_delivery_boy_name', name);
              await prefs.setString('last_delivery_boy_phone', phone);

              await FirebaseUtils.firestore
                  .collection('orders')
                  .doc(orderId)
                  .update({
                    'status': nextStatus,
                    'delivery_boy_name': name,
                    'delivery_boy_phone': phone,
                  });
              NotificationService.dispatchOrderStatusNotification(
                orderId: orderId,
                newStatus: nextStatus,
                customerPhone: data['phone_number']?.toString() ?? '',
                customerUid: data['customer_uid']?.toString(),
                shopId: data['shop_id']?.toString() ?? '',
                orderTotal: (data['total_amount'] as num?)?.toDouble(),
                deliveryBoyName: name,
              );
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
    Map<String, dynamic> data, {
    bool isRejection = false,
  }) {
    String selectedReason = isRejection ? 'Item Out of Stock' : 'Out of Stock';

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
                isRejection ? 'Reject Order' : 'Cancel Order',
                style: AppTextStyles.heading2(color: AppColors.textDark),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isRejection
                    ? 'Select a reason for rejecting order:'
                    : 'Select a reason for cancellation:',
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
                      'Customer Requested',
                      'Other',
                    ].map((reason) {
                      return RadioListTile<String>(
                        title: Text(
                          reason,
                          style: AppTextStyles.bodyMedium(
                            color: AppColors.textDark,
                          ),
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
                  targetStatus: isRejection
                      ? OrderStatus.rejected
                      : OrderStatus.cancelled,
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
              child: Text(isRejection ? 'Reject Order' : 'Cancel Order'),
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
    double finalTotal, {
    String targetStatus = OrderStatus.cancelled,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: ModernLoader(color: AppColors.primaryDark)),
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

        final currentStatus =
            orderSnapshot.data()?['status'] as String? ?? OrderStatus.pending;

        // Assert valid state machine transition (terminal protection)
        OrderStateMachine.assertValidTransition(currentStatus, targetStatus);

        final items = data['items'] as List<dynamic>? ?? [];

        // --- 1. PERFORM ALL READS FIRST ---
        final Map<DocumentReference, DocumentSnapshot> productDocs = {};
        for (var item in items) {
          final String? itemId = item['id']?.toString();
          if (itemId != null) {
            final productRef = FirebaseUtils.firestore
                .collection('products')
                .doc(itemId);
            productDocs[productRef] = await transaction.get(productRef);
          }
        }

        // --- 2. PERFORM ALL WRITES ---
        final isKhataPayment = (data['payment_method'] as String?) == 'Khata';
        if (currentStatus == OrderStatus.delivered && customerRef != null && isKhataPayment) {
          transaction.update(customerRef, {
            'shop_balances.${data['shop_id']}': FieldValue.increment(
              -finalTotal,
            ),
            'total_udhaar': FieldValue.increment(
              -finalTotal,
            ),
          });
          transaction.set(customerRef.collection('khata_transactions').doc(), {
            'amount': finalTotal,
            'type': 'credit',
            'shop_id': data['shop_id'],
            'description': 'Order Cancelled #${orderId.substring(0, 5)}',
            'timestamp': FieldValue.serverTimestamp(),
          });
        }

        final orderUpdates = <String, dynamic>{
          'status': targetStatus,
          'cancellation_reason': selectedReason,
        };
        if (targetStatus == OrderStatus.rejected) {
          orderUpdates['rejection_reason'] = selectedReason;
        }

        final currentPaymentStatus = data['payment_status'] as String?;
        final wasPaid = currentPaymentStatus == PaymentStatus.paid;
        if (wasPaid) {
          final refundId = PaymentService.generateRefundId();
          orderUpdates['payment_status'] = PaymentStatus.refunded;
          orderUpdates['refund_id'] = refundId;
          orderUpdates['refund_amount'] = finalTotal;
          orderUpdates['refund_reason'] = selectedReason;
          orderUpdates['refunded_at'] = FieldValue.serverTimestamp();
          orderUpdates['refunded_by'] = 'merchant';
        }

        transaction.update(orderDocRef, orderUpdates);

        for (var item in items) {
          final String? itemId = item['id']?.toString();
          if (itemId != null) {
            final double qty = (item['quantity'] as num).toDouble();
            final productRef = FirebaseUtils.firestore
                .collection('products')
                .doc(itemId);

            final productDoc = productDocs[productRef];
            if (productDoc != null && productDoc.exists) {
              transaction.update(productRef, {
                'stock_quantity': FieldValue.increment(qty),
              });
            }
          }
        }
      });

      NotificationService.dispatchOrderStatusNotification(
        orderId: orderId,
        newStatus: targetStatus,
        customerPhone: data['phone_number']?.toString() ?? '',
        customerUid: data['customer_uid']?.toString(),
        shopId: data['shop_id']?.toString() ?? '',
        orderTotal: finalTotal,
        failureReason: selectedReason,
      );

      if (context.mounted) {
        Navigator.pop(context); // Close loading indicator
        SoundService().play('cancel.mp3');
        final wasPaid =
            (data['payment_status'] as String?) == PaymentStatus.paid;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              wasPaid
                  ? 'Order Cancelled & Refund Initiated'
                  : 'Order Cancelled',
            ),
            content: Text(
              wasPaid
                  ? 'The order has been cancelled, stock restored, and a refund of ₹${finalTotal.toStringAsFixed(0)} has been recorded.'
                  : 'The order has been cancelled and stock has been restored successfully.',
            ),
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
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Error: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    return OrderStateMachine.getStatusColor(status);
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.pending_actions_rounded;
      case OrderStatus.accepted:
        return Icons.check_circle_outline_rounded;
      case OrderStatus.packing:
      case OrderStatus.packed:
        return Icons.inventory_2_rounded;
      case OrderStatus.ready:
        return Icons.storefront_rounded;
      case OrderStatus.outForDelivery:
        return Icons.moped_rounded;
      case OrderStatus.delivered:
        return Icons.check_circle_rounded;
      case OrderStatus.deliveryFailed:
        return Icons.report_problem_rounded;
      case OrderStatus.rejected:
      case OrderStatus.cancelled:
        return Icons.cancel_rounded;
      default:
        return Icons.info_rounded;
    }
  }
}
