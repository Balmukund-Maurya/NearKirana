import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'complaint_model.dart';
import 'complaint_service.dart';
import 'shop_provider.dart';
import 'app_theme.dart';
import 'sound_service.dart';

/// Screen for shopkeeper/admin to manage Returns, Refunds & Complaints (Feature 51)
class AdminComplaintsScreen extends StatefulWidget {
  final ComplaintService? complaintService;

  const AdminComplaintsScreen({super.key, this.complaintService});

  @override
  State<AdminComplaintsScreen> createState() => _AdminComplaintsScreenState();
}

class _AdminComplaintsScreenState extends State<AdminComplaintsScreen> {
  late final ComplaintService _service;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _service = widget.complaintService ?? ComplaintService();
  }


  void _openResolutionDialog(BuildContext context, ComplaintModel complaint) {
    ResolutionType selectedResolution = ResolutionType.refund;
    RefundMethod selectedRefundMethod = RefundMethod.khataCredit;
    final refundAmountController = TextEditingController(
      text: complaint.estimatedClaimAmount > 0
          ? complaint.estimatedClaimAmount.toStringAsFixed(0)
          : '',
    );
    final notesController = TextEditingController();
    final replacementController = TextEditingController(
      text: 'Replacement item will be sent with your next delivery.',
    );

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.gavel_rounded, color: AppColors.primaryDark),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Resolve ${complaint.id}',
                  style: AppTextStyles.heading2(color: AppColors.textDark),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Resolution Action',
                    style: AppTextStyles.captionMedium(color: AppColors.textMid),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<ResolutionType>(
                    segments: const [
                      ButtonSegment(
                        value: ResolutionType.refund,
                        label: Text('Refund'),
                        icon: Icon(Icons.currency_rupee_rounded, size: 16),
                      ),
                      ButtonSegment(
                        value: ResolutionType.replacement,
                        label: Text('Replace'),
                        icon: Icon(Icons.sync_rounded, size: 16),
                      ),
                      ButtonSegment(
                        value: ResolutionType.noAction,
                        label: Text('Reject'),
                        icon: Icon(Icons.close_rounded, size: 16),
                      ),
                    ],
                    selected: {selectedResolution},
                    onSelectionChanged: (val) {
                      setDialogState(() => selectedResolution = val.first);
                    },
                  ),
                  const SizedBox(height: 16),

                  if (selectedResolution == ResolutionType.refund) ...[
                    TextField(
                      controller: refundAmountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Refund Amount (₹)',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<RefundMethod>(
                      initialValue: selectedRefundMethod,
                      decoration: InputDecoration(
                        labelText: 'Refund Method',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: RefundMethod.values.map((method) {
                        return DropdownMenuItem(
                          value: method,
                          child: Text(method.label),
                        );
                      }).toList(),
                      onChanged: (m) {
                        if (m != null) setDialogState(() => selectedRefundMethod = m);
                      },
                    ),
                    if (selectedRefundMethod == RefundMethod.khataCredit) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Will automatically credit customer\'s Khata balance.',
                                style: AppTextStyles.caption(color: Colors.blue.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ] else if (selectedResolution == ResolutionType.replacement) ...[
                    TextField(
                      controller: replacementController,
                      decoration: InputDecoration(
                        labelText: 'Replacement Details',
                        hintText: 'e.g. Dispatched replacement packet',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Resolution Note / Reason',
                      hintText: selectedResolution == ResolutionType.noAction
                          ? 'State why complaint is rejected'
                          : 'Notes for the customer and audit log',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedResolution == ResolutionType.noAction
                    ? AppColors.error
                    : AppColors.primaryDark,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final notes = notesController.text.trim();
                final double? refund = double.tryParse(refundAmountController.text.trim());

                if (selectedResolution == ResolutionType.noAction && notes.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a rejection reason'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogCtx);
                HapticFeedback.mediumImpact();

                try {
                  await _service.resolveComplaint(
                    complaintId: complaint.id,
                    resolutionType: selectedResolution,
                    resolutionNotes: notes.isNotEmpty ? notes : 'Resolved by shopkeeper',
                    resolvedBy: 'Shop Owner',
                    refundAmount: selectedResolution == ResolutionType.refund ? refund : null,
                    refundMethod: selectedResolution == ResolutionType.refund ? selectedRefundMethod : null,
                    replacementDetails: selectedResolution == ResolutionType.replacement
                        ? replacementController.text.trim()
                        : null,
                  );

                  if (context.mounted) {
                    SoundService().success();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Complaint ${complaint.id} resolved successfully!'),
                        backgroundColor: AppColors.primaryDark,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to resolve complaint: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              child: Text(
                selectedResolution == ResolutionType.noAction ? 'Confirm Reject' : 'Confirm Resolution',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shopId = Provider.of<ShopProvider>(context).currentShopId ?? '';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Complaints & Returns'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'About Disputes',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Complaints & Returns Workflow'),
                  content: const Text(
                    'Track customer reports for damaged, missing, or wrong items.\n\n'
                    '• Review photos and affected item claims.\n'
                    '• Approve Khata or cash refunds, dispatch replacements, or reject disputes.\n'
                    '• Replaces messy WhatsApp chats with trackable resolutions.',
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it')),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<ComplaintModel>>(
        stream: _service.streamShopComplaints(shopId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryDark));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading complaints: ${snapshot.error}'));
          }

          final allComplaints = snapshot.data ?? [];

          // Filter
          final filtered = allComplaints.where((c) {
            if (_selectedFilter == 'All') return true;
            if (_selectedFilter == 'Pending') return c.status == ComplaintStatus.pending;
            if (_selectedFilter == 'In Review') return c.status == ComplaintStatus.inReview;
            if (_selectedFilter == 'Resolved') return c.isResolved;
            if (_selectedFilter == 'Rejected') return c.status == ComplaintStatus.rejected;
            return true;
          }).toList();

          // KPI Stats
          final pendingCount = allComplaints.where((c) => c.status == ComplaintStatus.pending).length;
          final inReviewCount = allComplaints.where((c) => c.status == ComplaintStatus.inReview).length;
          final resolvedCount = allComplaints.where((c) => c.isResolved).length;
          final rejectedCount = allComplaints.where((c) => c.status == ComplaintStatus.rejected).length;

          return Column(
            children: [
              // KPI stats cards
              Container(
                color: AppColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    _buildStatCard('Pending', '$pendingCount', Colors.orange),
                    const SizedBox(width: 8),
                    _buildStatCard('In Review', '$inReviewCount', Colors.blue),
                    const SizedBox(width: 8),
                    _buildStatCard('Resolved', '$resolvedCount', Colors.green),
                    const SizedBox(width: 8),
                    _buildStatCard('Rejected', '$rejectedCount', Colors.red),
                  ],
                ),
              ),

              // Filter Chips
              Container(
                color: AppColors.white,
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Pending', 'In Review', 'Resolved', 'Rejected'].map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: isSelected,
                          selectedColor: AppColors.primaryDark,
                          backgroundColor: AppColors.surface,
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.white : AppColors.textDark,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _selectedFilter = filter);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const Divider(height: 1),

              // List of Complaints
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.thumb_up_alt_outlined, size: 64, color: AppColors.bgTint),
                            const SizedBox(height: 12),
                            Text(
                              _selectedFilter == 'All'
                                  ? 'No complaints lodged'
                                  : 'No $_selectedFilter complaints',
                              style: AppTextStyles.bodyMedium(color: AppColors.textMid),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final complaint = filtered[index];
                          return _buildComplaintCard(complaint);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String count, MaterialColor color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                color: color.shade900,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: color.shade900,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplaintCard(ComplaintModel complaint) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgTint),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: complaint.status.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(complaint.type.icon, size: 16, color: complaint.status.color.shade900),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      complaint.id,
                      style: AppTextStyles.bodySemiBold(color: AppColors.textDark),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: complaint.status.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    complaint.status.label,
                    style: TextStyle(
                      color: complaint.status.color.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Customer Info & Order reference
            Row(
              children: [
                const Icon(Icons.person_outline, size: 14, color: AppColors.textMid),
                const SizedBox(width: 4),
                Text(
                  '${complaint.customerName} (${complaint.customerPhone})',
                  style: AppTextStyles.captionMedium(color: AppColors.textDark),
                ),
                const Spacer(),
                Text(
                  'Order #${complaint.orderId.length > 5 ? complaint.orderId.substring(0, 5) : complaint.orderId}',
                  style: AppTextStyles.caption(color: AppColors.primaryDark),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Issue description
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${complaint.type.label}:',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    complaint.description,
                    style: AppTextStyles.caption(color: AppColors.textDark),
                  ),
                ],
              ),
            ),

            // Affected Items
            if (complaint.affectedItems.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...complaint.affectedItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '• ${item.name} (${item.quantityAffected}x)',
                        style: AppTextStyles.caption(color: AppColors.textMid),
                      ),
                      Text(
                        '₹${item.totalAffectedValue.toStringAsFixed(0)}',
                        style: AppTextStyles.captionMedium(color: AppColors.textDark),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Photo preview if available
            if (complaint.imageUrl != null && complaint.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => Dialog(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: complaint.imageUrl!.startsWith('data:image')
                            ? Image.memory(
                                base64Decode(complaint.imageUrl!.split(',').last),
                                fit: BoxFit.contain,
                              )
                            : Image.network(complaint.imageUrl!, fit: BoxFit.contain),
                      ),
                    ),
                  );
                },
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: complaint.imageUrl!.startsWith('data:image')
                          ? Image.memory(
                              base64Decode(complaint.imageUrl!.split(',').last),
                              height: 50,
                              width: 50,
                              fit: BoxFit.cover,
                            )
                          : Image.network(
                              complaint.imageUrl!,
                              height: 50,
                              width: 50,
                              fit: BoxFit.cover,
                            ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Tap to view attached proof photo',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primaryDark,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Resolution Info if resolved/rejected
            if (complaint.resolutionNotes != null && complaint.resolutionNotes!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Resolution Note: ${complaint.resolutionNotes}',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (complaint.status == ComplaintStatus.pending) ...[
                  TextButton.icon(
                    icon: const Icon(Icons.search_rounded, size: 16),
                    label: const Text('Mark In Review'),
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      await _service.markInReview(complaint.id);
                    },
                  ),
                  const SizedBox(width: 8),
                ],
                if (complaint.status == ComplaintStatus.pending ||
                    complaint.status == ComplaintStatus.inReview) ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Resolve Case'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: () => _openResolutionDialog(context, complaint),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
