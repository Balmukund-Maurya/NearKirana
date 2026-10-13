import 'package:flutter/material.dart';
import 'package:near_kirana/sound_service.dart';
import 'package:near_kirana/substitution_model.dart';
import 'package:near_kirana/product_substitution_service.dart';

/// Modal dialog allowing the merchant/shopkeeper to propose an alternative product
/// when an ordered item is out of stock.
class ProposeSubstitutionDialog extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> item;

  const ProposeSubstitutionDialog({
    super.key,
    required this.orderId,
    required this.item,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String orderId,
    required Map<String, dynamic> item,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => ProposeSubstitutionDialog(orderId: orderId, item: item),
    );
  }

  @override
  State<ProposeSubstitutionDialog> createState() =>
      _ProposeSubstitutionDialogState();
}

class _ProposeSubstitutionDialogState extends State<ProposeSubstitutionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _quantityController;
  late final TextEditingController _reasonController;

  bool _isSubmitting = false;

  late final double _origPrice;
  late final double _origQty;
  late final String _origName;
  late final String _origId;

  @override
  void initState() {
    super.initState();
    _origName = widget.item['name']?.toString() ?? 'Item';
    _origId = widget.item['id']?.toString() ?? widget.item['productId']?.toString() ?? '';
    _origPrice = (widget.item['price'] as num?)?.toDouble() ?? 0.0;
    _origQty = (widget.item['quantity'] as num?)?.toDouble() ?? 1.0;

    _nameController = TextEditingController(text: _origName);
    _priceController = TextEditingController(text: _origPrice.toStringAsFixed(0));
    _quantityController = TextEditingController(text: _origQty.toStringAsFixed(0));
    _reasonController = TextEditingController(text: 'Currently out of stock. Proposing fresh alternative.');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  double get _originalTotal => _origPrice * _origQty;
  double get _substitutePrice => double.tryParse(_priceController.text) ?? 0.0;
  double get _substituteQty => double.tryParse(_quantityController.text) ?? 0.0;
  double get _substituteTotal => _substitutePrice * _substituteQty;
  double get _difference => _substituteTotal - _originalTotal;

  Future<void> _submitProposal() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      await ProductSubstitutionService.instance.proposeSubstitution(
        orderId: widget.orderId,
        originalProductId: _origId,
        originalProductName: _origName,
        originalPrice: _origPrice,
        originalQuantity: _origQty,
        originalUnit: widget.item['unit']?.toString(),
        originalImageUrl: widget.item['image_url']?.toString() ?? widget.item['image']?.toString(),
        substituteProductName: _nameController.text.trim(),
        substitutePrice: _substitutePrice,
        substituteQuantity: _substituteQty,
        substituteUnit: widget.item['unit']?.toString(),
        reason: _reasonController.text.trim(),
        proposedBy: 'merchant',
      );

      if (mounted) {
        SoundService().success();
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Alternative proposal for "$_origName" sent to customer.'),
            backgroundColor: const Color(0xFF047857),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll("StateError: ", "")}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.swap_horiz_rounded,
                        color: Colors.amber,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Propose Product Substitute',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827),
                            ),
                          ),
                          Text(
                            'Item out of stock? Propose an alternative for customer approval.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Original Item Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.remove_shopping_cart_outlined, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Original (Out of Stock): $_origName',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            Text(
                              '₹${_origPrice.toStringAsFixed(0)} × ${_origQty.toStringAsFixed(0)} = ₹${_originalTotal.toStringAsFixed(0)}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Unavailable',
                          style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Replacement Product Name
                const Text(
                  'Replacement Product Name *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Dhara Mustard Oil 1 Litre',
                    prefixIcon: const Icon(Icons.shopping_bag_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Please enter replacement product name' : null,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),

                // Price and Quantity Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Unit Price (₹) *',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _priceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              prefixText: '₹ ',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            validator: (v) {
                              final p = double.tryParse(v ?? '');
                              return (p == null || p < 0) ? 'Enter valid price' : null;
                            },
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quantity *',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _quantityController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            validator: (v) {
                              final q = double.tryParse(v ?? '');
                              return (q == null || q <= 0) ? 'Enter valid quantity' : null;
                            },
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Reason / Explanation
                const Text(
                  'Reason for Substitution (Optional)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _reasonController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'e.g. Brand unavailable, offering premium equal alternative',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 18),

                // Live Summary Calculation Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _difference > 0
                        ? Colors.orange.shade50
                        : (_difference < 0 ? const Color(0xFFECFDF5) : Colors.blue.shade50),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _difference > 0
                          ? Colors.orange.shade200
                          : (_difference < 0 ? const Color(0xFFA7F3D0) : Colors.blue.shade200),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _difference > 0
                            ? Icons.trending_up_rounded
                            : (_difference < 0 ? Icons.trending_down_rounded : Icons.check_circle_outline),
                        color: _difference > 0
                            ? Colors.orange.shade800
                            : (_difference < 0 ? const Color(0xFF047857) : Colors.blue.shade800),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Proposed Total: ₹${_substituteTotal.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              _difference.abs() < 0.01
                                  ? 'No price change for customer.'
                                  : (_difference > 0
                                      ? 'Customer will pay +₹${_difference.toStringAsFixed(0)} extra upon approval.'
                                      : 'Customer order will be discounted by -₹${_difference.abs().toStringAsFixed(0)}.'),
                              style: TextStyle(
                                fontSize: 12,
                                color: _difference > 0
                                    ? Colors.orange.shade900
                                    : (_difference < 0 ? const Color(0xFF065F46) : Colors.blue.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(_isSubmitting ? 'Sending...' : 'Send Substitution Proposal'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isSubmitting ? null : _submitProposal,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Interactive banner for Customer UI displaying pending substitution proposals.
/// Allows customer to approve or reject proposed alternative products.
class SubstitutionApprovalBanner extends StatefulWidget {
  final String orderId;
  final List<ProductSubstitutionProposal> proposals;
  final VoidCallback? onResolved;

  const SubstitutionApprovalBanner({
    super.key,
    required this.orderId,
    required this.proposals,
    this.onResolved,
  });

  @override
  State<SubstitutionApprovalBanner> createState() => _SubstitutionApprovalBannerState();
}

class _SubstitutionApprovalBannerState extends State<SubstitutionApprovalBanner> {
  final Set<String> _processingIds = {};

  Future<void> _handleResponse({
    required ProductSubstitutionProposal proposal,
    required bool isAccepted,
    required String rejectionAction,
  }) async {
    setState(() => _processingIds.add(proposal.id));

    try {
      await ProductSubstitutionService.instance.respondToSubstitution(
        orderId: widget.orderId,
        proposalId: proposal.id,
        isAccepted: isAccepted,
        rejectionAction: rejectionAction,
      );

      if (mounted) {
        if (isAccepted) {
          SoundService().success();
        }
        widget.onResolved?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAccepted
                ? 'Substitution approved! Order items and total updated.'
                : 'Alternative declined. ${rejectionAction == SubstitutionRejectionAction.removeItem ? "Item removed from order." : "Item marked out-of-stock."}'),
            backgroundColor: isAccepted ? const Color(0xFF047857) : Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll("StateError: ", "")}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(proposal.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = widget.proposals.where((p) => p.isPending).toList();
    if (pending.isEmpty) return const SizedBox.shrink();

    return Column(
      children: pending.map((proposal) {
        final isBusy = _processingIds.contains(proposal.id);
        final diff = proposal.priceDifference;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFFFBEB),
                Colors.amber.shade50.withValues(alpha: 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.shade300, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.swap_horiz_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Action Required: Item Substitution Proposed',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF92400E),
                            ),
                          ),
                          Text(
                            'The shopkeeper proposed a replacement for an unavailable item.',
                            style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Comparison Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Column(
                    children: [
                      // Original Item
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.close_rounded, color: Colors.red, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    proposal.originalProductName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      decoration: TextDecoration.lineThrough,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₹${proposal.originalPrice.toStringAsFixed(0)} × ${proposal.originalQuantity.toStringAsFixed(0)}',
                            style: TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey.shade500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1),
                      ),
                      // Substitute Item
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF047857), size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    proposal.substituteProductName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₹${proposal.substitutePrice.toStringAsFixed(0)} × ${proposal.substituteQuantity.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Price difference pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: diff > 0
                              ? Colors.orange.shade50
                              : (diff < 0 ? const Color(0xFFDCFCE7) : Colors.blue.shade50),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: diff > 0
                                ? Colors.orange.shade200
                                : (diff < 0 ? const Color(0xFF86EFAC) : Colors.blue.shade200),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              diff > 0
                                  ? 'Difference: +₹${diff.toStringAsFixed(0)} (Extra to pay)'
                                  : (diff < 0
                                      ? 'Difference: -₹${diff.abs().toStringAsFixed(0)} (Discounted)'
                                      : 'Difference: Same price'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: diff > 0
                                    ? Colors.orange.shade900
                                    : (diff < 0 ? const Color(0xFF166534) : Colors.blue.shade900),
                              ),
                            ),
                            Text(
                              'Rev. Total: ₹${proposal.substituteItemTotal.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                if (proposal.reason != null && proposal.reason!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Colors.amber.shade900),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Note: "${proposal.reason}"',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.close, size: 16, color: Colors.red),
                      label: const Text('Decline & Remove', style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: isBusy
                          ? null
                          : () => _handleResponse(
                                proposal: proposal,
                                isAccepted: false,
                                rejectionAction: SubstitutionRejectionAction.removeItem,
                              ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      icon: isBusy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check, size: 16),
                      label: Text(isBusy ? 'Processing...' : 'Approve Alternative'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: isBusy
                          ? null
                          : () => _handleResponse(
                                proposal: proposal,
                                isAccepted: true,
                                rejectionAction: SubstitutionRejectionAction.removeItem,
                              ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Small visual badge denoting that an item in the order was substituted
class SubstitutedItemBadge extends StatelessWidget {
  final String originalName;

  const SubstitutedItemBadge({super.key, required this.originalName});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.swap_horiz_rounded, size: 12, color: Color(0xFF047857)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'Substituted (was: $originalName)',
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF047857),
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
