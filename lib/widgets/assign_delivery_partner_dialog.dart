import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';
import '../delivery_partner_models.dart';
import '../delivery_partner_service.dart';
import '../sound_service.dart';

/// Modal dialog allowing a shopkeeper to assign an eligible order to a delivery partner
class AssignDeliveryPartnerDialog extends StatefulWidget {
  final String orderId;
  final String shopId;
  final Map<String, dynamic> orderData;
  final String? nextStatus;
  final DeliveryPartnerService? service;

  const AssignDeliveryPartnerDialog({
    super.key,
    required this.orderId,
    required this.shopId,
    required this.orderData,
    this.nextStatus,
    this.service,
  });

  static Future<bool?> show({
    required BuildContext context,
    required String orderId,
    required String shopId,
    required Map<String, dynamic> orderData,
    String? nextStatus,
    DeliveryPartnerService? service,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AssignDeliveryPartnerDialog(
        orderId: orderId,
        shopId: shopId,
        orderData: orderData,
        nextStatus: nextStatus,
        service: service,
      ),
    );
  }

  @override
  State<AssignDeliveryPartnerDialog> createState() =>
      _AssignDeliveryPartnerDialogState();
}

class _AssignDeliveryPartnerDialogState
    extends State<AssignDeliveryPartnerDialog> {
  late final DeliveryPartnerService _service;
  DeliveryPartner? _selectedPartner;
  final TextEditingController _notesController = TextEditingController();
  bool _isAssigning = false;
  bool _showAddPartnerForm = false;

  // New partner form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _vehicleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? DeliveryPartnerService();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _vehicleController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveNewPartner() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final vehicle = _vehicleController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter delivery partner name')),
      );
      return;
    }
    if (phone.isEmpty || phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit phone number')),
      );
      return;
    }

    setState(() => _isAssigning = true);
    try {
      final newPartner = DeliveryPartner(
        id: '',
        shopId: widget.shopId,
        name: name,
        phone: phone,
        vehicleNumber: vehicle,
        status: DeliveryPartnerStatus.available,
        createdAt: DateTime.now(),
      );

      final saved = await _service.registerOrUpdatePartner(newPartner);
      if (mounted) {
        setState(() {
          _selectedPartner = saved;
          _showAddPartnerForm = false;
          _isAssigning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delivery partner ${saved.name} added!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAssigning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding partner: $e')),
        );
      }
    }
  }

  Future<void> _handleAssignOrder() async {
    if (_selectedPartner == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a delivery partner')),
      );
      return;
    }

    setState(() => _isAssigning = true);
    HapticFeedback.mediumImpact();

    try {
      await _service.assignOrderToPartner(
        shopId: widget.shopId,
        orderId: widget.orderId,
        partner: _selectedPartner!,
        notes: _notesController.text.trim(),
      );

      try {
        SoundService().orderDispatched();
      } catch (_) {}

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primaryDark,
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Order assigned to ${_selectedPartner!.name} successfully!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAssigning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to assign delivery: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerName = widget.orderData['customer_name']?.toString() ??
        widget.orderData['name']?.toString() ??
        'Customer';
    final customerAddress = widget.orderData['delivery_address']?.toString() ??
        widget.orderData['address']?.toString() ??
        'Address not provided';
    final totalAmount =
        (widget.orderData['total_amount'] as num?)?.toDouble() ?? 0.0;
    final orderShortId = widget.orderId.length > 8
        ? widget.orderId.substring(widget.orderId.length - 8)
        : widget.orderId;

    final dialogHeight = MediaQuery.of(context).size.height * 0.85;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520, maxHeight: dialogHeight),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.delivery_dining_rounded,
                      color: AppColors.primaryDark,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assign Delivery Partner',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          'डिलीवरी पार्टनर असाइन करें (Order #$orderShortId)',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textMid,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMid),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Order Summary Badge
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 20, color: Colors.deepOrange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$customerName • ₹${totalAmount.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          Text(
                            customerAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Partner Selector Header + Add New Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Select Partner (पार्टनर चुनें)',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showAddPartnerForm = !_showAddPartnerForm;
                      });
                    },
                    icon: Icon(
                      _showAddPartnerForm ? Icons.list_rounded : Icons.person_add_rounded,
                      size: 18,
                      color: AppColors.primaryDark,
                    ),
                    label: Text(
                      _showAddPartnerForm ? 'View List' : '+ Add New',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Content Area: Either Add Partner Form or Partners List
              Expanded(
                child: _showAddPartnerForm
                    ? _buildAddPartnerInlineForm()
                    : _buildPartnersListStream(),
              ),

              const SizedBox(height: 12),

              // Optional Notes Input
              TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  hintText: 'Delivery instruction (e.g. Call before coming)',
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textLight),
                  prefixIcon: const Icon(Icons.note_alt_outlined, size: 20),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Assign Action Button
              ElevatedButton(
                onPressed: _isAssigning ? null : _handleAssignOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isAssigning
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        _selectedPartner != null
                            ? 'Assign to ${_selectedPartner!.name}'
                            : 'Select a Partner to Assign',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartnersListStream() {
    return StreamBuilder<List<DeliveryPartner>>(
      stream: _service.streamShopPartners(widget.shopId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final partners = snapshot.data ?? [];
        if (partners.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sports_motorsports_rounded, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  'No delivery partners registered yet',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textDark),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add Rahul, Raju or other delivery boys to get started',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textLight),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _showAddPartnerForm = true),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Delivery Partner'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    side: const BorderSide(color: AppColors.primaryDark),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: partners.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final p = partners[index];
            final isSelected = _selectedPartner?.id == p.id;

            return InkWell(
              onTap: () {
                setState(() => _selectedPartner = p);
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryLight.withValues(alpha: 0.15)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? AppColors.primaryDark : Colors.black12,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isSelected
                          ? AppColors.primaryDark
                          : const Color(0xFFF1F5F9),
                      child: Icon(
                        Icons.two_wheeler_rounded,
                        size: 20,
                        color: isSelected ? Colors.white : AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  p.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildStatusBadge(p.status),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${p.phone}${p.vehicleNumber.isNotEmpty ? ' • ${p.vehicleNumber}' : ''}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textMid,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${p.activeOrdersCount} active',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: p.activeOrdersCount > 0 ? Colors.orange.shade800 : Colors.green.shade800,
                          ),
                        ),
                        Text(
                          '${p.totalDeliveredCount} delivered',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusBadge(DeliveryPartnerStatus status) {
    Color bg;
    Color fg;
    switch (status) {
      case DeliveryPartnerStatus.available:
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        break;
      case DeliveryPartnerStatus.onDelivery:
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        break;
      case DeliveryPartnerStatus.offline:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade700;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Widget _buildAddPartnerInlineForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Partner Name (e.g. Rahul Sharma)',
              labelStyle: GoogleFonts.inter(fontSize: 13),
              prefixIcon: const Icon(Icons.person_outline, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Phone Number (10 digits)',
              labelStyle: GoogleFonts.inter(fontSize: 13),
              prefixIcon: const Icon(Icons.phone_outlined, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _vehicleController,
            decoration: InputDecoration(
              labelText: 'Vehicle Number (Optional, e.g. MP04 AB 1234)',
              labelStyle: GoogleFonts.inter(fontSize: 13),
              prefixIcon: const Icon(Icons.two_wheeler_outlined, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _showAddPartnerForm = false),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _handleSaveNewPartner,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save & Select'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
