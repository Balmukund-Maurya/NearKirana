import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../complaint_model.dart';
import '../complaint_service.dart';
import '../app_theme.dart';
import '../sound_service.dart';

/// Card displayed on an order in customer view if a complaint has been raised
class ComplaintStatusCard extends StatelessWidget {
  final ComplaintModel complaint;
  final VoidCallback? onCancelled;
  final ComplaintService? complaintService;

  const ComplaintStatusCard({
    super.key,
    required this.complaint,
    this.onCancelled,
    this.complaintService,
  });

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ComplaintDetailsModal(
        complaint: complaint,
        onCancelled: onCancelled,
        complaintService: complaintService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color textColor;
    IconData icon;

    switch (complaint.status) {
      case ComplaintStatus.pending:
        bg = Colors.orange.withValues(alpha: 0.08);
        border = Colors.orange.withValues(alpha: 0.35);
        textColor = Colors.orange.shade900;
        icon = Icons.hourglass_top_rounded;
        break;
      case ComplaintStatus.inReview:
        bg = Colors.blue.withValues(alpha: 0.08);
        border = Colors.blue.withValues(alpha: 0.35);
        textColor = Colors.blue.shade900;
        icon = Icons.search_rounded;
        break;
      case ComplaintStatus.resolvedRefund:
        bg = Colors.purple.withValues(alpha: 0.08);
        border = Colors.purple.withValues(alpha: 0.35);
        textColor = Colors.purple.shade900;
        icon = Icons.currency_rupee_rounded;
        break;
      case ComplaintStatus.resolvedReplacement:
        bg = Colors.green.withValues(alpha: 0.08);
        border = Colors.green.withValues(alpha: 0.35);
        textColor = Colors.green.shade900;
        icon = Icons.check_circle_rounded;
        break;
      case ComplaintStatus.rejected:
        bg = AppColors.error.withValues(alpha: 0.08);
        border = AppColors.error.withValues(alpha: 0.35);
        textColor = AppColors.error;
        icon = Icons.cancel_rounded;
        break;
      case ComplaintStatus.cancelled:
        bg = Colors.grey.withValues(alpha: 0.08);
        border = Colors.grey.withValues(alpha: 0.35);
        textColor = AppColors.textMid;
        icon = Icons.block_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: textColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Complaint ${complaint.id}: ${complaint.status.label}',
                  style: AppTextStyles.bodySemiBold(color: textColor).copyWith(fontSize: 13),
                ),
              ),
              InkWell(
                onTap: () => _showDetails(context),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    'Details',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Issue: ${complaint.type.label} • ${complaint.description}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.captionMedium(color: textColor.withValues(alpha: 0.85)),
          ),
          if (complaint.status == ComplaintStatus.resolvedRefund && complaint.refundAmount != null) ...[
            const SizedBox(height: 4),
            Text(
              'Refund of ₹${complaint.refundAmount!.toStringAsFixed(0)} processed (${complaint.refundMethod?.label ?? 'Khata Credit'})',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
          if (complaint.status == ComplaintStatus.resolvedReplacement) ...[
            const SizedBox(height: 4),
            Text(
              'Replacement dispatched by store: ${complaint.replacementDetails ?? 'On next delivery'}',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComplaintDetailsModal extends StatefulWidget {
  final ComplaintModel complaint;
  final VoidCallback? onCancelled;
  final ComplaintService? complaintService;

  const _ComplaintDetailsModal({
    required this.complaint,
    this.onCancelled,
    this.complaintService,
  });

  @override
  State<_ComplaintDetailsModal> createState() => _ComplaintDetailsModalState();
}

class _ComplaintDetailsModalState extends State<_ComplaintDetailsModal> {
  bool _isCancelling = false;

  Future<void> _cancelComplaint() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Complaint?'),
        content: const Text('Are you sure you want to cancel this complaint?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);
    HapticFeedback.lightImpact();

    try {
      final service = widget.complaintService ?? ComplaintService();
      await service.cancelComplaint(widget.complaint.id, widget.complaint.orderId);
      if (mounted) {
        SoundService().success();
        Navigator.pop(context);
        widget.onCancelled?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complaint cancelled successfully'),
            backgroundColor: AppColors.primaryDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel complaint: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.complaint;
    final media = MediaQuery.of(context);

    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: media.size.height * 0.85,
        ),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Complaint Details (${c.id})',
                          style: AppTextStyles.heading2(color: AppColors.textDark),
                        ),
                        Text(
                          'Order #${c.orderId.length > 7 ? c.orderId.substring(0, 7) : c.orderId}',
                          style: AppTextStyles.caption(color: AppColors.textMid),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Status:', style: AppTextStyles.bodyMedium(color: AppColors.textMid)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: c.status.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            c.status.label,
                            style: TextStyle(
                              color: c.status.color.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Issue Type:', style: AppTextStyles.bodyMedium(color: AppColors.textMid)),
                        Text(c.type.label, style: AppTextStyles.bodySemiBold(color: AppColors.textDark)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Requested Resolution:', style: AppTextStyles.bodyMedium(color: AppColors.textMid)),
                        Text(c.requestedResolution.label, style: AppTextStyles.bodySemiBold(color: AppColors.textDark)),
                      ],
                    ),

                    const SizedBox(height: 16),
                    Text('Customer Note:', style: AppTextStyles.captionMedium(color: AppColors.textMid)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        c.description,
                        style: AppTextStyles.bodyMedium(color: AppColors.textDark),
                      ),
                    ),

                    if (c.affectedItems.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text('Affected Items:', style: AppTextStyles.captionMedium(color: AppColors.textMid)),
                      const SizedBox(height: 6),
                      ...c.affectedItems.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${item.name} (${item.quantityAffected}x affected)',
                                  style: AppTextStyles.bodyMedium(color: AppColors.textDark)),
                              Text('₹${item.totalAffectedValue.toStringAsFixed(0)}',
                                  style: AppTextStyles.bodySemiBold(color: AppColors.primaryDark)),
                            ],
                          ),
                        ),
                      ),
                    ],

                    if (c.imageUrl != null && c.imageUrl!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text('Attached Photo:', style: AppTextStyles.captionMedium(color: AppColors.textMid)),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: c.imageUrl!.startsWith('data:image')
                            ? Image.memory(
                                base64Decode(c.imageUrl!.split(',').last),
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : Image.network(
                                c.imageUrl!,
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ],

                    if (c.resolutionNotes != null && c.resolutionNotes!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text('Store Resolution Note:', style: AppTextStyles.captionMedium(color: AppColors.textMid)),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          c.resolutionNotes!,
                          style: AppTextStyles.bodyMedium(color: Colors.green.shade900),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            if (c.status == ComplaintStatus.pending) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton(
                    onPressed: _isCancelling ? null : _cancelComplaint,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isCancelling
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error),
                          )
                        : const Text('Cancel This Complaint'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
