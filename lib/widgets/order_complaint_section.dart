import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../complaint_model.dart';
import '../complaint_service.dart';
import '../app_theme.dart';
import 'raise_complaint_dialog.dart';
import 'complaint_status_card.dart';

/// Interactive customer widget displaying complaint status or the "Report Issue / Return" action
class OrderComplaintSection extends StatefulWidget {
  final String orderId;
  final String shopId;
  final String customerPhone;
  final String customerName;
  final List<dynamic> orderItems;
  final String orderStatus;
  final Map<String, dynamic> orderData;
  final ComplaintService? complaintService;
  final VoidCallback? onComplaintUpdated;

  const OrderComplaintSection({
    super.key,
    required this.orderId,
    required this.shopId,
    required this.customerPhone,
    required this.customerName,
    required this.orderItems,
    required this.orderStatus,
    required this.orderData,
    this.complaintService,
    this.onComplaintUpdated,
  });

  @override
  State<OrderComplaintSection> createState() => _OrderComplaintSectionState();
}

class _OrderComplaintSectionState extends State<OrderComplaintSection> {
  late final ComplaintService _service;
  Future<ComplaintModel?>? _complaintFuture;

  @override
  void initState() {
    super.initState();
    _service = widget.complaintService ?? ComplaintService();
    _loadComplaintIfNeeded();
  }

  @override
  void didUpdateWidget(covariant OrderComplaintSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId ||
        oldWidget.orderData['has_complaint'] != widget.orderData['has_complaint'] ||
        oldWidget.orderData['complaint_status'] != widget.orderData['complaint_status']) {
      _loadComplaintIfNeeded();
    }
  }

  void _loadComplaintIfNeeded() {
    final hasComplaint = widget.orderData['has_complaint'] == true ||
        widget.orderData['complaint_id'] != null;
    if (hasComplaint) {
      _complaintFuture = _service.getComplaintForOrder(widget.orderId);
    } else {
      _complaintFuture = null;
    }
  }

  Future<void> _raiseComplaint() async {
    HapticFeedback.lightImpact();
    final result = await RaiseComplaintDialog.show(
      context,
      orderId: widget.orderId,
      shopId: widget.shopId,
      customerPhone: widget.customerPhone,
      customerName: widget.customerName,
      orderItems: widget.orderItems,
      complaintService: _service,
    );

    if (result != null) {
      setState(() {
        _complaintFuture = Future.value(result);
      });
      widget.onComplaintUpdated?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasComplaint = widget.orderData['has_complaint'] == true ||
        widget.orderData['complaint_id'] != null ||
        _complaintFuture != null;

    if (hasComplaint) {
      return FutureBuilder<ComplaintModel?>(
        future: _complaintFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryDark),
                ),
              ),
            );
          }

          final complaint = snapshot.data;
          if (complaint != null) {
            return ComplaintStatusCard(
              complaint: complaint,
              complaintService: _service,
              onCancelled: () {
                setState(() {
                  _loadComplaintIfNeeded();
                });
                widget.onComplaintUpdated?.call();
              },
            );
          }

          // Fallback if complaint model loading failed but metadata exists
          final statusStr = widget.orderData['complaint_status']?.toString() ?? 'Pending';
          return Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.report_problem_rounded, color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Complaint status: $statusStr',
                    style: AppTextStyles.captionMedium(color: Colors.orange.shade900),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    // Only allow raising complaints for delivered orders
    final isDelivered = widget.orderStatus.toLowerCase() == 'delivered';
    if (!isDelivered) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      child: OutlinedButton.icon(
        onPressed: _raiseComplaint,
        icon: const Icon(Icons.report_problem_outlined, size: 16, color: AppColors.textMid),
        label: Text(
          'Wrong or Damaged Item? Report Issue',
          style: AppTextStyles.caption(color: AppColors.textDark).copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.bgTint, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: AppColors.surface,
        ),
      ),
    );
  }
}
