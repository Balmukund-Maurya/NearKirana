import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'complaint_model.dart';
import 'complaint_service.dart';
import 'shop_provider.dart';
import 'language_provider.dart';
import 'sound_service.dart';

/// Zepto/Blinkit merchant dispute resolution desk for Returns, Refunds & Complaints
class AdminComplaintsScreen extends StatefulWidget {
  final ComplaintService? complaintService;

  const AdminComplaintsScreen({super.key, this.complaintService});

  @override
  State<AdminComplaintsScreen> createState() => _AdminComplaintsScreenState();
}

class _AdminComplaintsScreenState extends State<AdminComplaintsScreen> {
  late final ComplaintService _service;
  String _selectedFilter = 'all'; // 'all', 'pending', 'in_review', 'resolved', 'rejected'

  @override
  void initState() {
    super.initState();
    _service = widget.complaintService ?? ComplaintService();
  }

  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      }
    } catch (_) {}
  }

  void _openResolutionDialog(BuildContext context, ComplaintModel complaint, String Function(String, String, String) t) {
    ResolutionType selectedResolution = ResolutionType.refund;
    RefundMethod selectedRefundMethod = RefundMethod.khataCredit;
    final refundAmountController = TextEditingController(
      text: complaint.estimatedClaimAmount > 0
          ? complaint.estimatedClaimAmount.toStringAsFixed(0)
          : '',
    );
    final notesController = TextEditingController();
    final replacementController = TextEditingController(
      text: t(
        'Replacement item will be sent with your next delivery.',
        'अगली डिलीवरी के साथ बदला हुआ सामान भेजा जाएगा।',
        'Next delivery ke sath replacement item bhej diya jayega.',
      ),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C831F).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.gavel_rounded, color: Color(0xFF0C831F), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t('Resolve Dispute', 'शिकायत समाधान', 'Resolve Dispute'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            '${complaint.id} • ${complaint.customerName}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(dialogCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 16),

                Text(
                  t('Resolution Action', 'समाधान का प्रकार चुनें', 'Resolution Action Select Karein'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 8),

                SegmentedButton<ResolutionType>(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.selected)) {
                        return const Color(0xFF0C831F);
                      }
                      return Colors.white;
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.white;
                      }
                      return const Color(0xFF334155);
                    }),
                  ),
                  segments: [
                    ButtonSegment(
                      value: ResolutionType.refund,
                      label: Text(t('Refund', 'रिफंड', 'Refund')),
                      icon: const Icon(Icons.currency_rupee_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: ResolutionType.replacement,
                      label: Text(t('Replace', 'बदलें', 'Replace')),
                      icon: const Icon(Icons.sync_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: ResolutionType.noAction,
                      label: Text(t('Reject', 'खारिज', 'Reject')),
                      icon: const Icon(Icons.close_rounded, size: 16),
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
                      labelText: t('Refund Amount (₹)', 'रिफंड राशि (₹)', 'Refund Amount (₹)'),
                      prefixText: '₹ ',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<RefundMethod>(
                    initialValue: selectedRefundMethod,
                    decoration: InputDecoration(
                      labelText: t('Refund Method', 'रिफंड का तरीका', 'Refund Method'),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: RefundMethod.khataCredit,
                        child: Text(t('Credit to Khata Balance', 'खाता में जमा करें (उधार कम करें)', 'Credit to Khata Balance')),
                      ),
                      DropdownMenuItem(
                        value: RefundMethod.cash,
                        child: Text(t('Cash Handover', 'नकद वापस दिया', 'Cash Handover')),
                      ),
                      DropdownMenuItem(
                        value: RefundMethod.upi,
                        child: Text(t('UPI Transfer', 'UPI ट्रांसफर', 'UPI Transfer')),
                      ),
                    ],
                    onChanged: (m) {
                      if (m != null) setDialogState(() => selectedRefundMethod = m);
                    },
                  ),
                  if (selectedRefundMethod == RefundMethod.khataCredit) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF2563EB)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t(
                                'Will automatically credit customer\'s Khata balance in real time.',
                                'ग्राहक के खाते में यह राशि तुरंत क्रेडिट कर दी जाएगी।',
                                'Customer ke khata balance me yeh amount turant credit ho jayega.',
                              ),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
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
                      labelText: t('Replacement Details', 'सामान बदलने का विवरण', 'Replacement Details'),
                      hintText: t('e.g. Dispatched new packet', 'उदा. नया पैकेट भेज दिया गया', 'e.g. New packet dispatch kar diya'),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: t('Resolution Note / Reason', 'टिप्पणी या कारण दर्ज करें', 'Resolution Note / Reason'),
                    hintText: selectedResolution == ResolutionType.noAction
                        ? t('State why complaint is rejected', 'खारिज करने का कारण लिखें', 'Reject karne ka reason likhein')
                        : t('Notes for customer & records', 'ग्राहक और रिकॉर्ड के लिए नोट', 'Customer aur audit ke liye notes'),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedResolution == ResolutionType.noAction
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF0C831F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      final notes = notesController.text.trim();
                      final double? refund = double.tryParse(refundAmountController.text.trim());

                      if (selectedResolution == ResolutionType.noAction && notes.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(t('Please enter a rejection reason', 'कृपया खारिज करने का कारण लिखें', 'Please rejection reason enter karein')),
                            backgroundColor: const Color(0xFFDC2626),
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
                          resolutionNotes: notes.isNotEmpty ? notes : 'Resolved by store partner',
                          resolvedBy: 'Store Partner',
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
                              content: Text(t(
                                'Complaint ${complaint.id} resolved successfully',
                                'शिकायत ${complaint.id} का समाधान हो गया',
                                'Complaint ${complaint.id} resolve ho gaya',
                              )),
                              backgroundColor: const Color(0xFF0C831F),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: const Color(0xFFDC2626),
                            ),
                          );
                        }
                      }
                    },
                    child: Text(
                      selectedResolution == ResolutionType.noAction
                          ? t('Confirm Rejection', 'खारिज करें', 'Confirm Rejection')
                          : t('Confirm Resolution', 'समाधान दर्ज करें', 'Confirm Resolution'),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showProofPhoto(BuildContext context, String imageUrl, String Function(String, String, String) t) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: Colors.black,
                child: imageUrl.startsWith('data:image')
                    ? Image.memory(
                        base64Decode(imageUrl.split(',').last),
                        fit: BoxFit.contain,
                      )
                    : Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.cancel_rounded, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    String t(String en, String hi, String hinglish) {
      if (lang.isHindi) return hi;
      if (lang.isHinglish) return hinglish;
      return en;
    }

    final shopId = Provider.of<ShopProvider>(context).currentShopId ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('Complaints & Returns', 'शिकायतें व सामान वापसी', 'Complaints & Returns'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            Text(
              t('Dispute Resolution Desk', 'ग्राहक समस्या निवारण केंद्र', 'Dispute Resolution Desk'),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: Color(0xFF64748B)),
            tooltip: t('Help & Guidelines', 'नियम व जानकारी', 'Help & Guidelines'),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  title: Row(
                    children: [
                      const Icon(Icons.verified_outlined, color: Color(0xFF0C831F)),
                      const SizedBox(width: 8),
                      Text(
                        t('Dispute Resolution', 'समाधान प्रक्रिया', 'Dispute Resolution'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  content: Text(
                    t(
                      'Manage returns, damaged goods, or missing items reported by customers.\n\n'
                      '• Mark ticket in review while checking shop stock.\n'
                      '• Approve instant refund directly to Khata balance or cash.\n'
                      '• Replaces messy WhatsApp arguments with clear store audit records.',
                      'ग्राहकों द्वारा रिपोर्ट किए गए खराब सामान, मिसिंग आइटम या रिटर्न का समाधान करें।\n\n'
                      '• रिव्यू मार्क करें और स्टॉक चेक करें।\n'
                      '• ग्राहक के खाते में तुरंत रिफंड जमा करें या नकद दें।\n'
                      '• दुकान का पेशेवर रिकॉर्ड बनाए रखें।',
                      'Customers ke damaged ya missing items disputes ko manage karein.\n\n'
                      '• Ticket ko In Review mark karein.\n'
                      '• Khata balance me instant refund ya replacement provide karein.\n'
                      '• Transparent store records maintain karein.',
                    ),
                    style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF334155)),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(t('Close', 'बंद करें', 'Close'), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
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
            return const Center(child: CircularProgressIndicator(color: Color(0xFF0C831F)));
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error loading complaints: ${snapshot.error}',
                  style: const TextStyle(color: Color(0xFFDC2626)),
                ),
              ),
            );
          }

          final allComplaints = snapshot.data ?? [];

          // Counts
          final pendingCount = allComplaints.where((c) => c.status == ComplaintStatus.pending).length;
          final inReviewCount = allComplaints.where((c) => c.status == ComplaintStatus.inReview).length;
          final resolvedCount = allComplaints.where((c) => c.isResolved).length;

          // Filtered list
          final filtered = allComplaints.where((c) {
            if (_selectedFilter == 'pending') return c.status == ComplaintStatus.pending;
            if (_selectedFilter == 'in_review') return c.status == ComplaintStatus.inReview;
            if (_selectedFilter == 'resolved') return c.isResolved;
            if (_selectedFilter == 'rejected') return c.status == ComplaintStatus.rejected;
            return true;
          }).toList();

          return Column(
            children: [
              // 4 Zepto/Blinkit KPI Cards
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    _buildKpiCard(
                      label: t('All', 'सभी', 'All'),
                      count: allComplaints.length,
                      icon: Icons.inventory_2_outlined,
                      color: const Color(0xFF2563EB),
                      isSelected: _selectedFilter == 'all',
                      onTap: () => setState(() => _selectedFilter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    _buildKpiCard(
                      label: t('Action Needed', 'नया केस', 'Action Needed'),
                      count: pendingCount,
                      icon: Icons.error_outline_rounded,
                      color: const Color(0xFFEA580C),
                      isSelected: _selectedFilter == 'pending',
                      onTap: () => setState(() => _selectedFilter = 'pending'),
                    ),
                    const SizedBox(width: 8),
                    _buildKpiCard(
                      label: t('In Review', 'जांच जारी', 'In Review'),
                      count: inReviewCount,
                      icon: Icons.manage_search_rounded,
                      color: const Color(0xFF7C3AED),
                      isSelected: _selectedFilter == 'in_review',
                      onTap: () => setState(() => _selectedFilter = 'in_review'),
                    ),
                    const SizedBox(width: 8),
                    _buildKpiCard(
                      label: t('Resolved', 'हल हुआ', 'Resolved'),
                      count: resolvedCount,
                      icon: Icons.check_circle_outline_rounded,
                      color: const Color(0xFF0C831F),
                      isSelected: _selectedFilter == 'resolved',
                      onTap: () => setState(() => _selectedFilter = 'resolved'),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Complaint Tickets List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF0C831F).withValues(alpha: 0.1),
                              ),
                              child: const Icon(Icons.verified_rounded, size: 48, color: Color(0xFF0C831F)),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              t('All Clear! No Disputes', 'कोई लंबित शिकायत नहीं है', 'All Clear! No Disputes'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t(
                                'Great job maintaining customer satisfaction.',
                                'आपकी दुकान पर सभी ग्राहक संतुष्ट हैं।',
                                'Customer satisfaction is excellent.',
                              ),
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final complaint = filtered[index];
                          return _buildComplaintCard(complaint, t);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildKpiCard({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.12) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? color : const Color(0xFF0F172A),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? color : const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComplaintCard(ComplaintModel complaint, String Function(String, String, String) t) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (complaint.status) {
      case ComplaintStatus.pending:
        statusColor = const Color(0xFFEA580C);
        statusText = t('Needs Review', 'समीक्षा आवश्यक', 'Needs Review');
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case ComplaintStatus.inReview:
        statusColor = const Color(0xFF2563EB);
        statusText = t('Under Investigation', 'जांच जारी', 'Under Investigation');
        statusIcon = Icons.search_rounded;
        break;
      case ComplaintStatus.resolvedRefund:
        statusColor = const Color(0xFF0C831F);
        statusText = t('Refunded', 'रिफंड दिया गया', 'Refunded');
        statusIcon = Icons.currency_rupee_rounded;
        break;
      case ComplaintStatus.resolvedReplacement:
        statusColor = const Color(0xFF0C831F);
        statusText = t('Replaced', 'बदल दिया गया', 'Replaced');
        statusIcon = Icons.sync_rounded;
        break;
      case ComplaintStatus.rejected:
        statusColor = const Color(0xFFDC2626);
        statusText = t('Dispute Rejected', 'खारिज किया गया', 'Dispute Rejected');
        statusIcon = Icons.cancel_outlined;
        break;
      case ComplaintStatus.cancelled:
        statusColor = const Color(0xFF64748B);
        statusText = t('Cancelled', 'रद्द किया गया', 'Cancelled');
        statusIcon = Icons.block_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Ticket ID + Status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C831F).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.receipt_rounded, size: 16, color: Color(0xFF0C831F)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      complaint.id,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Customer Info Row + Call Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xFF0C831F).withValues(alpha: 0.12),
                    child: Text(
                      complaint.customerName.isNotEmpty ? complaint.customerName[0].toUpperCase() : 'C',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0C831F)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          complaint.customerName,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          complaint.customerPhone,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => _makePhoneCall(complaint.customerPhone),
                    icon: const Icon(Icons.call_rounded, size: 16, color: Color(0xFF0C831F)),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF0C831F).withValues(alpha: 0.1),
                      padding: const EdgeInsets.all(6),
                      minimumSize: const Size(32, 32),
                    ),
                    tooltip: t('Call Customer', 'ग्राहक को कॉल करें', 'Call Customer'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Issue Tag & Order ID
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Order #${complaint.orderId.length > 6 ? complaint.orderId.substring(0, 6) : complaint.orderId}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.report_problem_rounded, size: 11, color: Color(0xFFD97706)),
                      const SizedBox(width: 4),
                      Text(
                        complaint.type.label,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Complaint Description
            Text(
              complaint.description,
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.3),
            ),

            // Affected Items (if any)
            if (complaint.affectedItems.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: complaint.affectedItems.map((item) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '• ${item.name} (${item.quantityAffected}x)',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                        Text(
                          '₹${item.totalAffectedValue.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],

            // Proof Photo preview
            if (complaint.imageUrl != null && complaint.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _showProofPhoto(context, complaint.imageUrl!, t),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: complaint.imageUrl!.startsWith('data:image')
                            ? Image.memory(
                                base64Decode(complaint.imageUrl!.split(',').last),
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                              )
                            : Image.network(
                                complaint.imageUrl!,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                              ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t('Tap to inspect proof photo', 'फोटो सबूत देखने के लिए टैप करें', 'Tap to inspect proof photo'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0C831F),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Resolution Note Banner
            if (complaint.resolutionNotes != null && complaint.resolutionNotes!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${t('Resolution Note', 'समाधान विवरण', 'Resolution Note')}: ${complaint.resolutionNotes}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action Buttons
            if (complaint.status == ComplaintStatus.pending || complaint.status == ComplaintStatus.inReview) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (complaint.status == ComplaintStatus.pending) ...[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.manage_search_rounded, size: 15, color: Color(0xFF2563EB)),
                      label: Text(
                        t('Mark In Review', 'जांच शुरू करें', 'Mark In Review'),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        await _service.markInReview(complaint.id);
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  ElevatedButton.icon(
                    icon: const Icon(Icons.gavel_rounded, size: 15),
                    label: Text(
                      t('Resolve Case', 'समाधान करें', 'Resolve Case'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0C831F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      elevation: 0,
                    ),
                    onPressed: () => _openResolutionDialog(context, complaint, t),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
