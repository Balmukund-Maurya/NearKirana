import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../complaint_model.dart';
import '../complaint_service.dart';
import '../app_theme.dart';
import '../sound_service.dart';

/// Modal dialog for customers to submit a structured complaint / return request
class RaiseComplaintDialog extends StatefulWidget {
  final String orderId;
  final String shopId;
  final String customerPhone;
  final String customerName;
  final List<dynamic> orderItems;
  final ComplaintService? complaintService;

  const RaiseComplaintDialog({
    super.key,
    required this.orderId,
    required this.shopId,
    required this.customerPhone,
    required this.customerName,
    required this.orderItems,
    this.complaintService,
  });

  static Future<ComplaintModel?> show(
    BuildContext context, {
    required String orderId,
    required String shopId,
    required String customerPhone,
    required String customerName,
    required List<dynamic> orderItems,
    ComplaintService? complaintService,
  }) {
    return showModalBottomSheet<ComplaintModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RaiseComplaintDialog(
        orderId: orderId,
        shopId: shopId,
        customerPhone: customerPhone,
        customerName: customerName,
        orderItems: orderItems,
        complaintService: complaintService,
      ),
    );
  }

  @override
  State<RaiseComplaintDialog> createState() => _RaiseComplaintDialogState();
}

class _RaiseComplaintDialogState extends State<RaiseComplaintDialog> {
  late final ComplaintService _service;
  final _descriptionController = TextEditingController();

  ComplaintType _selectedType = ComplaintType.damaged;
  ResolutionType _selectedResolution = ResolutionType.refund;

  // Selected item tracking: itemId -> affected quantity
  final Map<String, int> _selectedItemQuantities = {};
  String? _photoBase64;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _service = widget.complaintService ?? ComplaintService();

    // Default select the first item if available
    if (widget.orderItems.isNotEmpty) {
      final firstItem = widget.orderItems.first as Map<String, dynamic>;
      final id = firstItem['id']?.toString() ?? firstItem['name']?.toString() ?? 'item_0';
      _selectedItemQuantities[id] = 1;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _photoBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        });
      }
    } catch (e) {
      debugPrint('Error picking complaint photo: $e');
    }
  }

  double _calculateClaimAmount() {
    double total = 0.0;
    for (var item in widget.orderItems) {
      final itemMap = item as Map<String, dynamic>;
      final id = itemMap['id']?.toString() ?? itemMap['name']?.toString() ?? '';
      final qtyAffected = _selectedItemQuantities[id] ?? 0;
      if (qtyAffected > 0) {
        final price = (itemMap['price'] as num?)?.toDouble() ?? 0.0;
        total += price * qtyAffected;
      }
    }
    return total;
  }

  List<ComplaintItem> _buildAffectedItems() {
    final list = <ComplaintItem>[];
    for (var item in widget.orderItems) {
      final itemMap = item as Map<String, dynamic>;
      final id = itemMap['id']?.toString() ?? itemMap['name']?.toString() ?? '';
      final qtyAffected = _selectedItemQuantities[id] ?? 0;
      if (qtyAffected > 0) {
        final orderedQty = (itemMap['quantity'] as num?)?.toInt() ?? 1;
        final price = (itemMap['price'] as num?)?.toDouble() ?? 0.0;
        list.add(
          ComplaintItem(
            itemId: id,
            name: itemMap['name']?.toString() ?? 'Item',
            quantityOrdered: orderedQty,
            quantityAffected: qtyAffected,
            pricePerUnit: price,
          ),
        );
      }
    }
    return list;
  }

  Future<void> _submitComplaint() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe the issue with your product'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final affected = _buildAffectedItems();
    if (affected.isEmpty && widget.orderItems.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one affected item'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final complaint = await _service.createComplaint(
        orderId: widget.orderId,
        shopId: widget.shopId,
        customerPhone: widget.customerPhone,
        customerName: widget.customerName,
        type: _selectedType,
        description: description,
        imageUrl: _photoBase64,
        affectedItems: affected,
        requestedResolution: _selectedResolution,
      );

      if (mounted) {
        SoundService().success();
        Navigator.pop(context, complaint);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Complaint submitted successfully! Tracking ID: ${complaint.id}',
            ),
            backgroundColor: AppColors.primaryDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit complaint: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDesktop = media.size.width > 800;
    final claimAmount = _calculateClaimAmount();

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 650 : double.infinity,
            maxHeight: media.size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(bottom: BorderSide(color: AppColors.bgTint)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.report_problem_rounded,
                        color: AppColors.error,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Report Issue / Return Item',
                            style: AppTextStyles.heading2(color: AppColors.textDark),
                          ),
                          Text(
                            'Order #${widget.orderId.length > 7 ? widget.orderId.substring(0, 7) : widget.orderId}',
                            style: AppTextStyles.caption(color: AppColors.textMid),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textMid),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Content Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Issue Type
                      Text(
                        'What issue did you face?',
                        style: AppTextStyles.bodySemiBold(color: AppColors.textDark),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ComplaintType.values.map((type) {
                          final isSelected = _selectedType == type;
                          return ChoiceChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  type.icon,
                                  size: 16,
                                  color: isSelected
                                      ? AppColors.white
                                      : AppColors.textDark,
                                ),
                                const SizedBox(width: 6),
                                Text(type.label),
                              ],
                            ),
                            selected: isSelected,
                            selectedColor: AppColors.primaryDark,
                            backgroundColor: AppColors.surface,
                            labelStyle: TextStyle(
                              color: isSelected ? AppColors.white : AppColors.textDark,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 12,
                            ),
                            onSelected: (val) {
                              if (val) {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedType = type);
                              }
                            },
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 20),

                      // 2. Select affected items
                      if (widget.orderItems.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Select Affected Item(s)',
                              style: AppTextStyles.bodySemiBold(color: AppColors.textDark),
                            ),
                            if (claimAmount > 0)
                              Text(
                                'Est. Claim: ₹${claimAmount.toStringAsFixed(0)}',
                                style: AppTextStyles.captionMedium(
                                  color: AppColors.primaryDark,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                        Material(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.bgTint),
                            ),
                            child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: widget.orderItems.length,
                            separatorBuilder: (_, _) => Divider(
                              height: 1,
                              color: AppColors.bgTint,
                            ),
                            itemBuilder: (context, idx) {
                              final item = widget.orderItems[idx] as Map<String, dynamic>;
                              final id = item['id']?.toString() ?? item['name']?.toString() ?? 'item_$idx';
                              final name = item['name']?.toString() ?? 'Item';
                              final orderedQty = (item['quantity'] as num?)?.toInt() ?? 1;
                              final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                              final affectedQty = _selectedItemQuantities[id] ?? 0;
                              final isSelected = affectedQty > 0;

                              return CheckboxListTile(
                                value: isSelected,
                                dense: true,
                                activeColor: AppColors.primaryDark,
                                title: Text(
                                  name,
                                  style: AppTextStyles.bodyMedium(color: AppColors.textDark),
                                ),
                                subtitle: Text(
                                  'Ordered: $orderedQty x ₹$price',
                                  style: AppTextStyles.caption(color: AppColors.textMid),
                                ),
                                secondary: isSelected
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle_outline, size: 18),
                                            color: AppColors.textMid,
                                            onPressed: affectedQty > 1
                                                ? () {
                                                    setState(() {
                                                      _selectedItemQuantities[id] = affectedQty - 1;
                                                    });
                                                  }
                                                : null,
                                          ),
                                          Text(
                                            '$affectedQty',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add_circle_outline, size: 18),
                                            color: AppColors.primaryDark,
                                            onPressed: affectedQty < orderedQty
                                                ? () {
                                                    setState(() {
                                                      _selectedItemQuantities[id] = affectedQty + 1;
                                                    });
                                                  }
                                                : null,
                                          ),
                                        ],
                                      )
                                    : null,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedItemQuantities[id] = 1;
                                    } else {
                                      _selectedItemQuantities.remove(id);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ],

                      // 3. Description
                      Text(
                        'Describe the issue in detail',
                        style: AppTextStyles.bodySemiBold(color: AppColors.textDark),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'e.g. 1 packet of milk was leaking, or only 4 packets delivered instead of 5...',
                          hintStyle: AppTextStyles.caption(color: AppColors.textLight),
                          fillColor: AppColors.surface,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.bgTint),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.bgTint),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 4. Photo Proof (Optional)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Attach Photo (Optional)',
                            style: AppTextStyles.bodySemiBold(color: AppColors.textDark),
                          ),
                          if (_photoBase64 != null)
                            TextButton.icon(
                              onPressed: () => setState(() => _photoBase64 = null),
                              icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                              label: const Text('Remove', style: TextStyle(color: AppColors.error, fontSize: 12)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_photoBase64 != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              Image.memory(
                                base64Decode(_photoBase64!.split(',').last),
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Proof Attached',
                                    style: TextStyle(color: Colors.white, fontSize: 11),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        InkWell(
                          onTap: _pickPhoto,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.bgTint,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.add_a_photo_outlined,
                                  color: AppColors.primaryDark,
                                  size: 28,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Tap to capture or upload damaged packet photo',
                                  style: AppTextStyles.captionMedium(color: AppColors.textMid),
                                ),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 20),

                      // 5. Preferred Resolution
                      Text(
                        'Preferred Resolution',
                        style: AppTextStyles.bodySemiBold(color: AppColors.textDark),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<ResolutionType>(
                        segments: const [
                          ButtonSegment(
                            value: ResolutionType.refund,
                            label: Text('Refund Amount'),
                            icon: Icon(Icons.currency_rupee_rounded, size: 16),
                          ),
                          ButtonSegment(
                            value: ResolutionType.replacement,
                            label: Text('Send Replacement'),
                            icon: Icon(Icons.sync_rounded, size: 16),
                          ),
                        ],
                        selected: {_selectedResolution},
                        onSelectionChanged: (val) {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedResolution = val.first);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Submit Bar
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                  border: Border(top: BorderSide(color: AppColors.bgTint)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitComplaint,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.white,
                            ),
                          )
                        : Text(
                            'Submit Complaint',
                            style: AppTextStyles.button(),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
