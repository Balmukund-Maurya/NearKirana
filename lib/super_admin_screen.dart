import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'app_theme.dart';
import 'modern_loader.dart';

class SuperAdminScreen extends StatelessWidget {
  const SuperAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Super Admin — Shop Verification'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseUtils.firestore
            .collection('shops')
            .orderBy('created_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: ModernLoader(color: Colors.black));
          }

          final shops = snapshot.data!.docs;
          if (shops.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.store_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Koi shop registered nahi hai', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          // Sort: pending first
          final sorted = [...shops];
          sorted.sort((a, b) {
            final aActive = (a.data() as Map)['is_active'] ?? false;
            final bActive = (b.data() as Map)['is_active'] ?? false;
            return aActive == bActive ? 0 : (aActive ? 1 : -1);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final doc = sorted[index];
              final data = doc.data() as Map<String, dynamic>;
              final isActive = data['is_active'] ?? false;
              final status = data['status'] ?? 'pending';

              return _ShopReviewCard(
                docId: doc.id,
                data: data,
                isActive: isActive,
                status: status,
              );
            },
          );
        },
      ),
    );
  }
}

class _ShopReviewCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool isActive;
  final String status;

  const _ShopReviewCard({
    required this.docId,
    required this.data,
    required this.isActive,
    required this.status,
  });

  @override
  State<_ShopReviewCard> createState() => _ShopReviewCardState();
}

class _ShopReviewCardState extends State<_ShopReviewCard> {
  bool _expanded = false;

  void _approve() async {
    await FirebaseUtils.firestore.collection('shops').doc(widget.docId).update({
      'is_active': true,
      'status': 'approved',
      'rejection_reason': FieldValue.delete(),
    });
  }

  void _reject() async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject karne ki wajah?'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Reason likhein (owner ko dikhega)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (reason == null) return;
    await FirebaseUtils.firestore.collection('shops').doc(widget.docId).update({
      'is_active': false,
      'status': 'rejected',
      'rejection_reason': reason,
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final shopImage64 = d['shop_image_base64'] as String?;
    final docImage64 = d['shop_doc_image_base64'] as String?;
    final gstin = d['gstin_fssai'] as String? ?? '';
    final rejectionReason = d['rejection_reason'] as String?;

    Color statusColor;
    IconData statusIcon;
    String statusLabel;
    switch (widget.status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.verified_rounded;
        statusLabel = 'Approved';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel_rounded;
        statusLabel = 'Rejected';
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_top_rounded;
        statusLabel = 'Pending';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row — tap to expand
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Shop photo thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: shopImage64 != null && shopImage64.isNotEmpty
                        ? Image.memory(
                            base64Decode(shopImage64),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.store_rounded, color: Colors.grey),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d['shop_name'] ?? 'Unknown',
                            style: AppTextStyles.heading2(color: AppColors.textDark)),
                        Text(d['owner_name'] ?? 'N/A',
                            style: AppTextStyles.bodyMedium(color: AppColors.textMid)),
                        Text(d['mobile'] ?? 'N/A',
                            style: AppTextStyles.bodyMedium(color: AppColors.textMid)),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 14, color: statusColor),
                            const SizedBox(width: 4),
                            Text(statusLabel,
                                style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                          color: AppColors.textMid),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expanded details
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow(Icons.location_on_rounded, 'Address', d['address'] ?? 'N/A'),
                  const SizedBox(height: 8),
                  _infoRow(
                    Icons.receipt_long_rounded,
                    'GSTIN/FSSAI',
                    gstin.isNotEmpty ? gstin : 'Nahi diya',
                    valueColor: gstin.isNotEmpty ? Colors.green.shade700 : Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),

                  // Verification Document
                  Text('Verification Document:',
                      style: AppTextStyles.bodySemiBold(color: AppColors.textDark)),
                  const SizedBox(height: 8),
                  if (docImage64 != null && docImage64.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        base64Decode(docImage64),
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.contain,
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          gstin.isNotEmpty
                              ? 'GSTIN/FSSAI provided — document upload optional'
                              : 'Koi document upload nahi kiya',
                          style: TextStyle(color: Colors.grey.shade500),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                  // Shop Live Photo
                  const SizedBox(height: 16),
                  Text('Shop Live Photo:',
                      style: AppTextStyles.bodySemiBold(color: AppColors.textDark)),
                  const SizedBox(height: 8),
                  if (shopImage64 != null && shopImage64.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        base64Decode(shopImage64),
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    ),

                  // Rejection reason
                  if (rejectionReason != null && rejectionReason.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Reject Reason: $rejectionReason',
                                style: const TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Action buttons
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.cancel_rounded, color: Colors.red),
                          label: const Text('Reject', style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: widget.status == 'rejected' ? null : _reject,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.verified_rounded, color: Colors.white),
                          label: const Text('Approve', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: widget.status == 'approved' ? null : _approve,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textMid),
        const SizedBox(width: 6),
        Text('$label: ', style: AppTextStyles.bodyMedium(color: AppColors.textMid)),
        Expanded(
          child: Text(value,
              style: AppTextStyles.bodySemiBold(color: valueColor ?? AppColors.textDark)),
        ),
      ],
    );
  }
}
