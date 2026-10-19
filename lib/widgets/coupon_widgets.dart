import 'package:flutter/material.dart';
import 'package:near_kirana/sound_service.dart';
import 'package:near_kirana/coupon_model.dart';
import 'package:near_kirana/coupon_service.dart';

/// Interactive coupon code entry and applied discount card for checkout screens
class CouponInputCard extends StatefulWidget {
  final double subtotal;
  final double deliveryFee;
  final String? customerPhone;
  final String? shopId;
  final CouponModel? initialCoupon;
  final CouponValidationResult? appliedResult;
  final ValueChanged<CouponValidationResult?>? onCouponChanged;
  final ValueChanged<CouponValidationResult>? onCouponApplied;
  final VoidCallback? onCouponRemoved;

  const CouponInputCard({
    super.key,
    required this.subtotal,
    this.deliveryFee = 0.0,
    this.customerPhone,
    this.shopId,
    this.initialCoupon,
    this.appliedResult,
    this.onCouponChanged,
    this.onCouponApplied,
    this.onCouponRemoved,
  });

  @override
  State<CouponInputCard> createState() => _CouponInputCardState();
}

class _CouponInputCardState extends State<CouponInputCard> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  CouponModel? _appliedCoupon;
  double _appliedDiscount = 0.0;
  double _appliedDeliveryDiscount = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.appliedResult != null && widget.appliedResult!.isValid && widget.appliedResult!.coupon != null) {
      _appliedCoupon = widget.appliedResult!.coupon;
      _controller.text = widget.appliedResult!.coupon!.code;
      _appliedDiscount = widget.appliedResult!.discountAmount;
      _appliedDeliveryDiscount = widget.appliedResult!.deliveryDiscount;
    } else if (widget.initialCoupon != null) {
      _appliedCoupon = widget.initialCoupon;
      _controller.text = widget.initialCoupon!.code;
      _appliedDiscount = widget.initialCoupon!.calculateDiscount(
        subtotal: widget.subtotal,
        deliveryFee: widget.deliveryFee,
      );
    }
  }

  void _notifyChanged(CouponValidationResult? res) {
    widget.onCouponChanged?.call(res);
    if (res != null && res.isValid) {
      widget.onCouponApplied?.call(res);
    } else {
      widget.onCouponRemoved?.call();
    }
  }

  @override
  void didUpdateWidget(covariant CouponInputCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If subtotal changed, re-validate applied coupon
    if (oldWidget.subtotal != widget.subtotal && _appliedCoupon != null) {
      _revalidateAppliedCoupon();
    }
  }

  Future<void> _revalidateAppliedCoupon() async {
    if (_appliedCoupon == null) return;
    final res = await CouponService.instance.validateCoupon(
      code: _appliedCoupon!.code,
      subtotal: widget.subtotal,
      deliveryFee: widget.deliveryFee,
      customerPhone: widget.customerPhone,
      shopId: widget.shopId,
    );

    if (mounted) {
      if (!res.isValid) {
        setState(() {
          _errorMessage = res.errorMessage;
          _appliedCoupon = null;
          _appliedDiscount = 0.0;
          _appliedDeliveryDiscount = 0.0;
        });
        _notifyChanged(null);
      } else {
        setState(() {
          _appliedDiscount = res.discountAmount;
          _appliedDeliveryDiscount = res.deliveryDiscount;
          _errorMessage = null;
        });
        _notifyChanged(res);
      }
    }
  }

  Future<void> _applyCoupon([String? explicitCode]) async {
    final code = (explicitCode ?? _controller.text).toUpperCase().trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter a coupon code');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await CouponService.instance.validateCoupon(
      code: code,
      subtotal: widget.subtotal,
      deliveryFee: widget.deliveryFee,
      customerPhone: widget.customerPhone,
      shopId: widget.shopId,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (res.isValid && res.coupon != null) {
      SoundService().success();
      setState(() {
        _appliedCoupon = res.coupon;
        _appliedDiscount = res.discountAmount;
        _appliedDeliveryDiscount = res.deliveryDiscount;
        _errorMessage = null;
      });
      _notifyChanged(res);
    } else {
      setState(() {
        _errorMessage = res.errorMessage ?? 'Invalid coupon';
        _appliedCoupon = null;
        _appliedDiscount = 0.0;
        _appliedDeliveryDiscount = 0.0;
      });
      _notifyChanged(null);
    }
  }

  void _removeCoupon() {
    setState(() {
      _appliedCoupon = null;
      _appliedDiscount = 0.0;
      _appliedDeliveryDiscount = 0.0;
      _errorMessage = null;
      _controller.clear();
    });
    _notifyChanged(null);
  }

  void _showAvailableCouponsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => AvailableCouponsSheet(
        shopId: widget.shopId,
        subtotal: widget.subtotal,
        onCouponSelected: (coupon) {
          Navigator.pop(ctx);
          _controller.text = coupon.code;
          _applyCoupon(coupon.code);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSavings = _appliedDiscount + _appliedDeliveryDiscount;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _appliedCoupon != null
              ? const Color(0xFF10B981)
              : Colors.grey.shade200,
          width: _appliedCoupon != null ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.discount_outlined,
                        color: Color(0xFF047857),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'Coupons & Offers',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF111827),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _showAvailableCouponsSheet,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: const Color(0xFF047857),
                ),
                child: const Text(
                  'View Coupons',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_appliedCoupon != null) ...[
            // Applied coupon banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF047857),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              _appliedCoupon!.code,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF065F46),
                                letterSpacing: 0.5,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF047857),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Applied • Save ₹${totalSavings.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_appliedCoupon!.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            _appliedCoupon!.description,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                    tooltip: 'Remove Coupon',
                    onPressed: _removeCoupon,
                  ),
                ],
              ),
            ),
          ] else ...[
            // Input field and Apply button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Enter coupon code (e.g. SAVE50)',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF047857), width: 1.5),
                      ),
                    ),
                    onSubmitted: (val) => _applyCoupon(val),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isLoading ? null : () => _applyCoupon(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Apply',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.error_outline, size: 14, color: Colors.red),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Bottom sheet displaying all available promotional coupons
class AvailableCouponsSheet extends StatelessWidget {
  final String? shopId;
  final double subtotal;
  final ValueChanged<CouponModel> onCouponSelected;

  const AvailableCouponsSheet({
    super.key,
    this.shopId,
    required this.subtotal,
    required this.onCouponSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Available Coupons & Offers',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<CouponModel>>(
              stream: CouponService.instance.getAvailableCouponsStream(shopId: shopId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final coupons = snapshot.data ?? [];

                if (coupons.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.sentiment_dissatisfied_rounded,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No active coupons available right now',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: coupons.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final c = coupons[index];
                    final isEligible = subtotal >= c.minOrderValue;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isEligible
                              ? const Color(0xFFD1FAE5)
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF047857),
                                width: 1,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Text(
                              c.code,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF047857),
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.formattedDiscountText,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                if (c.description.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    c.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  c.minOrderValue > 0
                                      ? 'On orders above ₹${c.minOrderValue.toStringAsFixed(0)}'
                                      : 'No minimum order required',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isEligible
                                        ? const Color(0xFF047857)
                                        : Colors.red.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: isEligible
                                ? () => onCouponSelected(c)
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF047857),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'APPLY',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Admin dialog to create or edit promotional coupons in Firestore
class AdminCouponDialog extends StatefulWidget {
  final CouponModel? existingCoupon;
  final String? shopId;

  const AdminCouponDialog({
    super.key,
    this.existingCoupon,
    this.shopId,
  });

  static Future<bool?> show(
    BuildContext context, {
    CouponModel? existingCoupon,
    CouponModel? coupon,
    String? shopId,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AdminCouponDialog(
        existingCoupon: coupon ?? existingCoupon,
        shopId: shopId,
      ),
    );
  }

  @override
  State<AdminCouponDialog> createState() => _AdminCouponDialogState();
}

class _AdminCouponDialogState extends State<AdminCouponDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeController;
  late TextEditingController _descController;
  late TextEditingController _valueController;
  late TextEditingController _minOrderController;
  late TextEditingController _maxDiscountController;
  late TextEditingController _usageLimitController;
  late TextEditingController _perUserLimitController;
  CouponDiscountType _selectedType = CouponDiscountType.flat;
  bool _isActive = true;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.existingCoupon;
    _codeController = TextEditingController(text: c?.code ?? '');
    _descController = TextEditingController(text: c?.description ?? '');
    _valueController =
        TextEditingController(text: c != null ? c.discountValue.toStringAsFixed(0) : '50');
    _minOrderController =
        TextEditingController(text: c != null ? c.minOrderValue.toStringAsFixed(0) : '299');
    _maxDiscountController = TextEditingController(
      text: c?.maxDiscount != null ? c!.maxDiscount!.toStringAsFixed(0) : '',
    );
    _usageLimitController = TextEditingController(
      text: c?.usageLimit != null ? c!.usageLimit.toString() : '100',
    );
    _perUserLimitController = TextEditingController(
      text: c != null ? c.perUserLimit.toString() : '1',
    );
    _selectedType = c?.type ?? CouponDiscountType.flat;
    _isActive = c?.isActive ?? true;
    _startDate = c?.startDate;
    _endDate = c?.endDate ?? DateTime.now().add(const Duration(days: 30));
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final coupon = CouponModel(
        id: widget.existingCoupon?.id ?? 'coup_${_codeController.text.toUpperCase().trim()}',
        code: _codeController.text.toUpperCase().trim(),
        description: _descController.text.trim(),
        type: _selectedType,
        discountValue: double.tryParse(_valueController.text) ?? 0.0,
        minOrderValue: double.tryParse(_minOrderController.text) ?? 0.0,
        maxDiscount: double.tryParse(_maxDiscountController.text),
        startDate: _startDate,
        endDate: _endDate,
        usageLimit: int.tryParse(_usageLimitController.text),
        perUserLimit: int.tryParse(_perUserLimitController.text) ?? 1,
        shopId: widget.shopId,
        isActive: _isActive,
        createdAt: widget.existingCoupon?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.existingCoupon == null) {
        await CouponService.instance.createCoupon(coupon);
      } else {
        await CouponService.instance.updateCoupon(coupon);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingCoupon == null
                  ? 'Coupon "${coupon.code}" created successfully!'
                  : 'Coupon "${coupon.code}" updated successfully!',
            ),
            backgroundColor: const Color(0xFF047857),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.existingCoupon == null ? 'Create New Coupon' : 'Edit Coupon',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Coupon Code
                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Coupon Code (e.g. SAVE50)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Coupon code is required' : null,
                ),
                const SizedBox(height: 14),

                // Description
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(
                    labelText: 'Offer Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),

                // Discount Type Dropdown
                DropdownButtonFormField<CouponDiscountType>(
                  initialValue: _selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Discount Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: CouponDiscountType.flat,
                      child: Text('Flat Rupee Discount (₹ OFF)'),
                    ),
                    DropdownMenuItem(
                      value: CouponDiscountType.percentage,
                      child: Text('Percentage Discount (% OFF)'),
                    ),
                    DropdownMenuItem(
                      value: CouponDiscountType.freeDelivery,
                      child: Text('Free Delivery (Waives Delivery Fee)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedType = val);
                  },
                ),
                const SizedBox(height: 14),

                // Value and Min Order in Row
                Row(
                  children: [
                    if (_selectedType != CouponDiscountType.freeDelivery) ...[
                      Expanded(
                        child: TextFormField(
                          controller: _valueController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: _selectedType == CouponDiscountType.percentage
                                ? 'Discount (%)'
                                : 'Discount (₹)',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              double.tryParse(v ?? '') == null ? 'Valid number required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: TextFormField(
                        controller: _minOrderController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Min Cart Value (₹)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_selectedType == CouponDiscountType.percentage) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _maxDiscountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max Discount Cap (₹) (Optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // Limits: Usage Limit and Per User Limit
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _usageLimitController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Global Usage Limit',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _perUserLimitController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Per User Limit',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Active toggle
                SwitchListTile(
                  title: const Text('Coupon Active Status'),
                  subtitle: Text(_isActive ? 'Active and redeemable' : 'Disabled'),
                  value: _isActive,
                  onChanged: (val) => setState(() => _isActive = val),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 20),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF047857),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(widget.existingCoupon == null ? 'Create Coupon' : 'Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
