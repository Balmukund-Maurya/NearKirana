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
import 'package:near_kirana/widgets/digital_receipt_dialog.dart';
import 'shop_provider.dart';

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

                const SizedBox(height: 10),

                // Bill / Receipt & Store Counter Item Modification Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          DigitalReceiptDialog.showForOrder(
                            context,
                            orderData: data,
                            orderId: orderDoc.id,
                          );
                        },
                        icon: const Icon(Icons.receipt_long_rounded, size: 15, color: Color(0xFF0C831F)),
                        label: Text(
                          t('View / Print Bill', 'बिल / रसीद देखें', 'View / Print Bill'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0C831F),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF0C831F), width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          backgroundColor: const Color(0xFF0C831F).withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    if (status != OrderStatus.cancelled &&
                        status != OrderStatus.rejected &&
                        status != OrderStatus.delivered) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            _showModifyOrderItemsDialog(context, orderDoc.id, data);
                          },
                          icon: const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF2563EB)),
                          label: Text(
                            t('Modify Items', 'सामान बदलें', 'Modify Items'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF93C5FD), width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            backgroundColor: const Color(0xFFEFF6FF),
                          ),
                        ),
                      ),
                    ],
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
    final focusNode = FocusNode();
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

    final lang = Provider.of<LanguageProvider>(context, listen: false);
    String t(String en, String hi, String hinglish) {
      if (lang.isHindi) return hi;
      if (lang.isHinglish) return hinglish;
      return en;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header with green check badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: Color(0xFF0C831F),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t('Verify & Complete Delivery', 'डिलीवरी सत्यापित व पूर्ण करें', 'Delivery Verify & Complete Karein'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${t('Order', 'ऑर्डर', 'Order')} #${orderId.length > 8 ? orderId.substring(0, 8) : orderId}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 4-Digit Security PIN Section
                  if (expectedPin != null && expectedPin.isNotEmpty) ...[
                    Text(
                      t('Ask customer for 4-digit PIN', 'ग्राहक से 4 अंकों का सुरक्षा पिन पूछें', 'Customer se 4-digit security PIN maangein'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Invisible real input + 4 styled boxes
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity: 0.0,
                          child: TextField(
                            controller: pinController,
                            focusNode: focusNode,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            autofocus: true,
                            onChanged: (v) {
                              setState(() {
                                if (showError) showError = false;
                              });
                            },
                          ),
                        ),
                        GestureDetector(
                          onTap: () => focusNode.requestFocus(),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(4, (index) {
                              final text = pinController.text;
                              final isFilled = text.length > index;
                              final isCurrent = text.length == index;
                              final char = isFilled ? text[index] : '';

                              final Color borderColor;
                              final Color bgColor;
                              if (showError) {
                                borderColor = const Color(0xFFEF4444);
                                bgColor = const Color(0xFFFEF2F2);
                              } else if (isCurrent) {
                                borderColor = const Color(0xFF0C831F);
                                bgColor = const Color(0xFFF0FDF4);
                              } else if (isFilled) {
                                borderColor = const Color(0xFF0C831F);
                                bgColor = Colors.white;
                              } else {
                                borderColor = const Color(0xFFCBD5E1);
                                bgColor = const Color(0xFFF8FAFC);
                              }

                              return Container(
                                width: 54,
                                height: 58,
                                margin: const EdgeInsets.symmetric(horizontal: 6),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: borderColor, width: isCurrent ? 2.0 : 1.5),
                                  boxShadow: isCurrent
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF0C831F).withValues(alpha: 0.15),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : [],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  char.isNotEmpty ? char : '•',
                                  style: TextStyle(
                                    fontSize: char.isNotEmpty ? 24 : 18,
                                    fontWeight: FontWeight.w800,
                                    color: char.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                    if (showError)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 14, color: Color(0xFFEF4444)),
                            const SizedBox(width: 4),
                            Text(
                              t('Invalid PIN. Please check with customer.', 'गलत पिन दर्ज किया गया। कृपया दोबारा जांचें।', 'Invalid PIN. Customer se dobara poochein.'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],

                  // Payment method selector
                  Text(
                    t('Payment Received Via:', 'भुगतान का माध्यम:', 'Payment Received Via:'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (showPaymentError)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        t('* Please select a payment mode', '* कृपया भुगतान का तरीका चुनें', '* Payment mode select karein'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),

                  // 3 Selectable Modern Payment Pills
                  Row(
                    children: [
                      ('Cash', Icons.payments_outlined, t('Cash', 'नकद', 'Cash')),
                      ('UPI', Icons.qr_code_2_rounded, t('UPI', 'यूपीआई', 'UPI')),
                      ('Khata', Icons.account_balance_wallet_outlined, t('Khata', 'खाता', 'Khata')),
                    ].map((item) {
                      final key = item.$1;
                      final icon = item.$2;
                      final label = item.$3;
                      final isSelected = selectedPayment == key;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                selectedPayment = key;
                                showPaymentError = false;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF0C831F) : const Color(0xFFE2E8F0),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    icon,
                                    size: 20,
                                    color: isSelected ? const Color(0xFF0C831F) : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected ? const Color(0xFF0C831F) : const Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Actions: Skip PIN & Cancel row, and big Confirm button
                  if (expectedPin != null && expectedPin.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: () async {
                              if (selectedPayment == null) {
                                setState(() => showPaymentError = true);
                                return;
                              }
                              HapticFeedback.lightImpact();
                              Navigator.pop(dialogContext);

                              final batch = FirebaseUtils.firestore.batch();
                              final orderRef = FirebaseUtils.firestore.collection('orders').doc(orderId);

                              batch.update(orderRef, {
                                'status': nextStatus,
                                'payment_method': selectedPayment,
                                'pin_bypassed': true,
                                if (nextStatus == 'Delivered' && selectedPayment != 'Khata')
                                  'payment_status': PaymentStatus.paid,
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
                                    batch.set(
                                      customerRef.collection('khata_transactions').doc(),
                                      {
                                        'amount': total,
                                        'type': 'debit',
                                        'shop_id': data['shop_id'],
                                        'description': 'Order Delivered (#${orderId.substring(0, 5)})',
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
                                customerPhone: data['phone_number']?.toString() ?? '',
                                customerUid: data['customer_uid']?.toString(),
                                shopId: data['shop_id']?.toString() ?? '',
                                orderTotal: (data['total_amount'] as num?)?.toDouble(),
                              );
                              SoundService().orderDelivered();
                            },
                            icon: const Icon(Icons.lock_open_rounded, size: 16, color: Color(0xFFEF4444)),
                            label: Text(
                              t('Bypass / Skip PIN', 'पिन छोड़ें (आपातकालीन)', 'Skip PIN (Emergency)'),
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: Text(
                              t('Cancel', 'रद्द करें', 'Cancel'),
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Full-width Confirm Delivery Button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (selectedPayment == null) {
                          setState(() => showPaymentError = true);
                          return;
                        }
                        if (expectedPin == null ||
                            expectedPin.isEmpty ||
                            pinController.text.trim() == expectedPin) {
                          Navigator.pop(dialogContext);

                          final batch = FirebaseUtils.firestore.batch();
                          final orderRef = FirebaseUtils.firestore.collection('orders').doc(orderId);

                          batch.update(orderRef, {
                            'status': nextStatus,
                            'payment_method': selectedPayment,
                            if (nextStatus == 'Delivered' && selectedPayment != 'Khata')
                              'payment_status': PaymentStatus.paid,
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
                                batch.set(
                                  customerRef.collection('khata_transactions').doc(),
                                  {
                                    'amount': total,
                                    'type': 'debit',
                                    'shop_id': data['shop_id'],
                                    'description': 'Order Delivered (#${orderId.substring(0, 5)})',
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
                            customerPhone: data['phone_number']?.toString() ?? '',
                            customerUid: data['customer_uid']?.toString(),
                            shopId: data['shop_id']?.toString() ?? '',
                            orderTotal: (data['total_amount'] as num?)?.toDouble(),
                          );
                          SoundService().orderDelivered();
                        } else {
                          HapticFeedback.heavyImpact();
                          setState(() => showError = true);
                        }
                      },
                      icon: const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
                      label: Text(
                        t('Confirm & Complete Delivery', 'डिलीवरी कन्फर्म करें', 'Delivery Confirm Karein'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0C831F),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  if (expectedPin == null || expectedPin.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(
                          t('Cancel', 'रद्द करें', 'Cancel'),
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                      ),
                    ),
                ],
              ),
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

  void _showModifyOrderItemsDialog(
    BuildContext context,
    String orderId,
    Map<String, dynamic> data,
  ) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    String t(String en, String hi, String hinglish) {
      if (lang.isHindi) return hi;
      if (lang.isHinglish) return hinglish;
      return en;
    }

    final rawItems = data['items'] as List? ?? [];
    List<Map<String, dynamic>> currentItems = rawItems
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final shopId = data['shop_id']?.toString() ??
        Provider.of<ShopProvider>(context, listen: false).currentShopId ??
        '';

    final deliveryFee = ((data['delivery_fee'] ?? 0.0) as num).toDouble();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          double subtotal = 0.0;
          int totalItemUnits = 0;
          for (final item in currentItems) {
            final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
            final price = (item['price'] as num?)?.toDouble() ?? 0.0;
            subtotal += qty * price;
            totalItemUnits += qty.toInt();
          }
          final grandTotal = subtotal + deliveryFee;

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 16,
              left: 18,
              right: 18,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top drag pill
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB), size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t('Modify Items / Bill', 'सामान बदलें / बिल अपडेट', 'Items Modify Karein / Bill Update'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            t('For Store Pickup or counter changes', 'काउंटर पिकअप या सामान बदलने पर', 'Store pickup ya counter modification ke liye'),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                const Divider(height: 20, color: Color(0xFFF1F5F9)),

                // Item List
                Expanded(
                  child: currentItems.isEmpty
                      ? Center(
                          child: Text(
                            t('No items in order. Please add products below.', 'ऑर्डर में कोई सामान नहीं है। कृपया नीचे से सामान जोड़ें।', 'Order me koi item nahi hai. Niche se add karein.'),
                            style: const TextStyle(color: Color(0xFF64748B)),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: currentItems.length,
                          separatorBuilder: (context, index) => const Divider(height: 14, color: Color(0xFFF8FAFC)),
                          itemBuilder: (context, index) {
                            final item = currentItems[index];
                            final name = item['name']?.toString() ?? 'Item';
                            final price = ((item['price'] ?? 0.0) as num).toDouble();
                            final qty = ((item['quantity'] ?? 1) as num).toDouble();

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '₹${price.toStringAsFixed(0)} / ${item['unit'] ?? 'pc'} • Total: ₹${(price * qty).toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF0C831F),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Stepper (- Qty +)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            HapticFeedback.lightImpact();
                                            setModalState(() {
                                              if (qty > 1) {
                                                item['quantity'] = qty - 1;
                                              } else {
                                                currentItems.removeAt(index);
                                              }
                                            });
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            child: Icon(Icons.remove_rounded, size: 16, color: Color(0xFF0F172A)),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                          child: Text(
                                            qty.toInt().toString(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () {
                                            HapticFeedback.lightImpact();
                                            setModalState(() {
                                              item['quantity'] = qty + 1;
                                            });
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            child: Icon(Icons.add_rounded, size: 16, color: Color(0xFF0C831F)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      setModalState(() {
                                        currentItems.removeAt(index);
                                      });
                                    },
                                    tooltip: t('Remove', 'हटाएं', 'Remove'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                const SizedBox(height: 10),

                // Button to Add Product from Store
                OutlinedButton.icon(
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    // Open product picker sheet
                    final selected = await showModalBottomSheet<Map<String, dynamic>>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (pickerCtx) => _buildAddProductPicker(pickerCtx, shopId, t),
                    );

                    if (selected != null) {
                      setModalState(() {
                        final existingIdx = currentItems.indexWhere(
                          (i) => i['name'] == selected['name'] || (selected['id'] != null && i['product_id'] == selected['id']),
                        );
                        if (existingIdx != -1) {
                          currentItems[existingIdx]['quantity'] =
                              ((currentItems[existingIdx]['quantity'] ?? 1) as num).toDouble() + 1.0;
                        } else {
                          currentItems.add({
                            'name': selected['name'],
                            'price': ((selected['price'] ?? 0.0) as num).toDouble(),
                            'quantity': 1.0,
                            'product_id': selected['id'],
                            'image_url': selected['image_url'] ?? '',
                            'unit': selected['unit'] ?? (selected['is_loose'] == true ? 'kg' : 'pc'),
                          });
                        }
                      });
                    }
                  },
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: Color(0xFF0C831F)),
                  label: Text(
                    t('+ Add Item from Store Catalog', '+ दुकान से नया सामान जोड़ें', '+ Add Item from Store'),
                    style: const TextStyle(
                      color: Color(0xFF0C831F),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF86EFAC), width: 1.2),
                    backgroundColor: const Color(0xFFF0FDF4),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),

                const SizedBox(height: 12),

                // Bill Summary Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${t('New Subtotal', 'नया सामान योग', 'New Subtotal')}: ₹${subtotal.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                          ),
                          Text(
                            '${t('Total Bill', 'नया कुल बिल', 'New Total Bill')}: ₹${grandTotal.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: currentItems.isEmpty
                            ? null
                            : () async {
                                HapticFeedback.mediumImpact();
                                Navigator.pop(sheetContext);

                                // Commit update in Firestore batch
                                final batch = FirebaseUtils.firestore.batch();
                                final orderRef = FirebaseUtils.firestore.collection('orders').doc(orderId);

                                final oldTotal = ((data['total_amount'] ?? 0.0) as num).toDouble();
                                final totalDiff = grandTotal - oldTotal;

                                batch.update(orderRef, {
                                  'items': currentItems,
                                  'items_count': totalItemUnits,
                                  'subtotal': subtotal,
                                  'total_amount': grandTotal,
                                  'updated_at': FieldValue.serverTimestamp(),
                                  'status_history': FieldValue.arrayUnion([
                                    {
                                      'status': data['status'],
                                      'timestamp': Timestamp.now(),
                                      'note': 'Order items updated on counter by merchant. New Total: ₹${grandTotal.toStringAsFixed(0)}',
                                    }
                                  ]),
                                });

                                // If order was paid via Khata and already delivered, adjust customer khata balance
                                if (data['payment_method'] == 'Khata' && data['status'] == OrderStatus.delivered && totalDiff != 0) {
                                  final phone = data['phone_number'] as String?;
                                  if (phone != null) {
                                    final cq = await FirebaseUtils.firestore
                                        .collection('customers')
                                        .where('mobile', isEqualTo: phone)
                                        .limit(1)
                                        .get();
                                    if (cq.docs.isNotEmpty) {
                                      final custRef = cq.docs.first.reference;
                                      batch.update(custRef, {
                                        'shop_balances.$shopId': FieldValue.increment(totalDiff),
                                        'total_udhaar': FieldValue.increment(totalDiff),
                                      });
                                    }
                                  }
                                }

                                await batch.commit();
                                SoundService().success();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: const Color(0xFF0C831F),
                                      content: Text(
                                        t(
                                          'Order items and bill updated successfully! (₹${grandTotal.toStringAsFixed(0)})',
                                          'ऑर्डर का सामान व नया बिल सफलतापूर्वक अपडेट हुआ! (₹${grandTotal.toStringAsFixed(0)})',
                                          'Order items aur new bill successfully update ho gaya! (₹${grandTotal.toStringAsFixed(0)})',
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                        label: Text(
                          t('Update Bill', 'बिल अपडेट करें', 'Update Bill'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0C831F),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    );
  }

  Widget _buildAddProductPicker(
    BuildContext pickerCtx,
    String shopId,
    String Function(String, String, String) t,
  ) {
    String searchFilter = '';
    return StatefulBuilder(
      builder: (context, setPickerState) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t('Select Product to Add', 'जोड़ने के लिए सामान चुनें', 'Add karne ke liye product chunein'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(pickerCtx),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              autofocus: false,
              onChanged: (val) => setPickerState(() => searchFilter = val.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: t('Search product name...', 'सामान का नाम खोजें...', 'Product search karein...'),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseUtils.firestore
                    .collection('products')
                    .where('shop_id', isEqualTo: shopId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: ModernLoader(color: AppColors.primaryDark));
                  }
                  final docs = snapshot.data!.docs.where((d) {
                    if (searchFilter.isEmpty) return true;
                    final name = (d.get('name') ?? '').toString().toLowerCase();
                    return name.contains(searchFilter);
                  }).toList();

                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        t('No matching products found', 'कोई सामान नहीं मिला', 'No product found'),
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final name = data['name'] ?? 'Product';
                      final price = ((data['price'] ?? 0.0) as num).toDouble();
                      final stock = ((data['stock_quantity'] ?? 0) as num).toDouble();

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: Text('₹$price • ${t('In Stock', 'स्टॉक', 'Stock')}: $stock', style: const TextStyle(fontSize: 12, color: Color(0xFF0C831F))),
                        trailing: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(pickerCtx, {
                              'id': doc.id,
                              'name': name,
                              'price': price,
                              'unit': data['unit'],
                              'is_loose': data['is_loose'],
                              'image_url': data['image_url'],
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0C831F),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(t('+ Add', '+ जोड़ें', '+ Add'), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
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
    String selectedReason = isRejection ? 'Out of Stock' : 'Out of Stock';
    final otherReasonController = TextEditingController();

    final lang = Provider.of<LanguageProvider>(context, listen: false);
    String t(String en, String hi, String hinglish) {
      if (lang.isHindi) return hi;
      if (lang.isHinglish) return hinglish;
      return en;
    }

    final reasonOptions = [
      ('Out of Stock', Icons.remove_shopping_cart_outlined, t('Out of Stock', 'सामान का स्टॉक खत्म हो गया', 'Item Out of Stock')),
      ('Shop is Closed', Icons.storefront_outlined, t('Shop is Closed', 'दुकान बंद है', 'Shop Closed Hai')),
      ('Outside Delivery Area', Icons.near_me_disabled_outlined, t('Outside Delivery Area', 'डिलीवरी क्षेत्र से बाहर है', 'Delivery Area se Bahar')),
      ('Customer Requested', Icons.person_remove_outlined, t('Customer Requested', 'ग्राहक ने मना किया', 'Customer Requested')),
      ('Other', Icons.edit_note_rounded, t('Other Reason', 'अन्य कारण', 'Other Reason')),
    ];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Warning Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: const Icon(
                          Icons.cancel_rounded,
                          color: Color(0xFFDC2626),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isRejection
                                  ? t('Reject Order', 'ऑर्डर अस्वीकार करें', 'Order Reject Karein')
                                  : t('Cancel Order', 'ऑर्डर रद्द करें', 'Order Cancel Karein'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${t('Order', 'ऑर्डर', 'Order')} #${orderId.length > 8 ? orderId.substring(0, 8) : orderId}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Text(
                    isRejection
                        ? t('Select reason for rejecting order:', 'ऑर्डर अस्वीकार करने का कारण चुनें:', 'Reject karne ka reason chunein:')
                        : t('Select reason for cancellation:', 'ऑर्डर रद्द करने का कारण चुनें:', 'Cancel karne ka reason chunein:'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Reason Selectable Cards
                  Column(
                    children: reasonOptions.map((item) {
                      final key = item.$1;
                      final icon = item.$2;
                      final label = item.$3;
                      final isSelected = selectedReason == key;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => selectedReason = key);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0),
                                width: isSelected ? 1.8 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  icon,
                                  size: 18,
                                  color: isSelected ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected ? const Color(0xFF991B1B) : const Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFFDC2626) : const Color(0xFFCBD5E1),
                                      width: isSelected ? 5.5 : 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  // Optional Text Input if "Other" is selected
                  if (selectedReason == 'Other') ...[
                    const SizedBox(height: 6),
                    TextField(
                      controller: otherReasonController,
                      decoration: InputDecoration(
                        hintText: t('Type custom reason here...', 'यहाँ अपना कारण लिखें...', 'Yahan custom reason likhein...'),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  const SizedBox(height: 16),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            t('Keep Order', 'ऑर्डर रखें', 'Order Rakhein'),
                            style: const TextStyle(
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final finalReason = selectedReason == 'Other' &&
                                    otherReasonController.text.trim().isNotEmpty
                                ? otherReasonController.text.trim()
                                : selectedReason;

                            Navigator.pop(dialogContext);
                            _executeCancellation(
                              context,
                              orderId,
                              data,
                              finalReason,
                              totalAmount,
                              targetStatus: isRejection
                                  ? OrderStatus.rejected
                                  : OrderStatus.cancelled,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                          ),
                          child: Text(
                            isRejection
                                ? t('Reject Order', 'अस्वीकार करें', 'Reject Karein')
                                : t('Cancel Order', 'रद्द करें', 'Cancel Karein'),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
