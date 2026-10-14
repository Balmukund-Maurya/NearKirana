import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../batch_models.dart';
import '../batch_service.dart';
import '../utils/snackbar_helper.dart';
import 'add_batch_dialog.dart';
import 'dispose_batch_dialog.dart';

/// Modal dialog showing full batch lifecycle, timeline, financials and management actions
class BatchDetailsDialog extends StatefulWidget {
  final String shopId;
  final BatchModel batch;
  final BatchService? service;
  final VoidCallback? onUpdated;

  const BatchDetailsDialog({
    super.key,
    required this.shopId,
    required this.batch,
    this.service,
    this.onUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required String shopId,
    required BatchModel batch,
    BatchService? service,
    VoidCallback? onUpdated,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => BatchDetailsDialog(
        shopId: shopId,
        batch: batch,
        service: service,
        onUpdated: onUpdated,
      ),
    );
  }

  @override
  State<BatchDetailsDialog> createState() => _BatchDetailsDialogState();
}

class _BatchDetailsDialogState extends State<BatchDetailsDialog> {
  late BatchModel _batch;

  @override
  void initState() {
    super.initState();
    _batch = widget.batch;
  }

  void _handleShareClearancePromo() {
    final discountPrice = (_batch.sellingPrice * 0.7).toStringAsFixed(0);
    final text = '🚨 *CLEARANCE SALE / भारी छूट!* 🚨\n\n'
        'Dukaan: Near Kirana Store\n'
        'Item: *${_batch.productName}*\n'
        'Batch: ${_batch.batchNumber}\n'
        'Original MRP: ₹${_batch.sellingPrice.toStringAsFixed(0)}\n'
        '💥 *Special Clearance Offer: ₹$discountPrice only!* (30% OFF)\n'
        'Best Before / Expiry: ${DateFormat('dd MMM yyyy').format(_batch.expiryDate)}\n'
        'Limited Stock: ${_batch.quantity} ${_batch.unit} remaining!\n\n'
        'Dukaan par aakar ya turant order karein!';

    Clipboard.setData(ClipboardData(text: text));
    SnackbarHelper.showSuccessSnackBar(context, 'Clearance promo text copied to clipboard!');
  }

  Future<void> _handleEditBatch() async {
    final updated = await AddBatchDialog.show(
      context,
      shopId: widget.shopId,
      initialBatch: _batch,
      service: widget.service,
    );

    if (updated != null && mounted) {
      setState(() => _batch = updated);
      widget.onUpdated?.call();
    }
  }

  Future<void> _handleDisposeBatch() async {
    final record = await DisposeBatchDialog.show(
      context,
      shopId: widget.shopId,
      batch: _batch,
      service: widget.service,
    );

    if (record != null && mounted) {
      final service = widget.service ?? BatchService();
      final refreshed = await service.getBatch(_batch.id);
      if (refreshed != null && mounted) {
        setState(() => _batch = refreshed);
      }
      widget.onUpdated?.call();
    }
  }

  Future<void> _handleQuickAdjustStock() async {
    final controller = TextEditingController(text: _batch.quantity.toStringAsFixed(0));
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adjust Batch Stock', style: TextStyle(fontSize: 16)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Current Stock Quantity',
              suffixText: _batch.unit,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter quantity';
              final n = double.tryParse(v);
              if (n == null || n < 0) return 'Invalid quantity';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final newQty = double.parse(controller.text);
                Navigator.pop(ctx, newQty);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      final service = widget.service ?? BatchService();
      final delta = result - _batch.quantity;
      await service.adjustBatchStock(_batch.id, delta);
      final refreshed = await service.getBatch(_batch.id);
      if (refreshed != null && mounted) {
        setState(() => _batch = refreshed);
      }
      widget.onUpdated?.call();
      if (mounted) {
        SnackbarHelper.showSuccessSnackBar(context, 'Batch stock updated to $result ${_batch.unit}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final b = _batch;

    final today = DateTime.now();
    final todayClean = DateTime(today.year, today.month, today.day);
    final expiryClean = DateTime(b.expiryDate.year, b.expiryDate.month, b.expiryDate.day);
    final daysRemaining = expiryClean.difference(todayClean).inDays;

    final urgency = b.urgency(today);

    Color statusBadgeColor;
    String statusBadgeText;
    if (daysRemaining < 0) {
      statusBadgeColor = Colors.red.shade700;
      statusBadgeText = 'Expired (${-daysRemaining}d ago)';
    } else if (daysRemaining <= 7) {
      statusBadgeColor = Colors.red.shade600;
      statusBadgeText = 'Critical: $daysRemaining days left';
    } else if (daysRemaining <= 15) {
      statusBadgeColor = Colors.orange.shade800;
      statusBadgeText = 'Near Expiry: $daysRemaining days left';
    } else if (daysRemaining <= 30) {
      statusBadgeColor = Colors.amber.shade900;
      statusBadgeText = 'Expiring in $daysRemaining days';
    } else {
      statusBadgeColor = Colors.green.shade700;
      statusBadgeText = 'Fresh: $daysRemaining days left';
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Color(urgency.colorValue).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.qr_code_2_rounded,
                          color: Color(urgency.colorValue),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Batch #${b.batchNumber}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            b.status.displayName,
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(b.status.colorValue),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textLight),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Scrollable Details
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Title
                      Text(
                        b.productName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      if (b.productId.isNotEmpty)
                        Text(
                          'Product ID / Barcode: ${b.productId}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      const SizedBox(height: 14),

                      // Urgency / Expiry Alert Banner
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: statusBadgeColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: statusBadgeColor.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(Icons.access_time_filled_rounded, color: statusBadgeColor, size: 20),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'Best Before / Expiry',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: statusBadgeColor,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: statusBadgeColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    statusBadgeText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              dateFormat.format(b.expiryDate),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: statusBadgeColor,
                              ),
                            ),
                            if (b.mfgDate != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Manufactured On: ${dateFormat.format(b.mfgDate!)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Stock & Valuation Grid
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoItem(
                                    'Remaining Stock',
                                    '${b.quantity} ${b.unit}',
                                    isHighlighted: true,
                                  ),
                                ),
                                Expanded(
                                  child: _buildInfoItem(
                                    'Initial Received',
                                    '${b.initialQuantity} ${b.unit}',
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoItem(
                                    'Cost Rate',
                                    '₹${b.costPrice.toStringAsFixed(2)}',
                                  ),
                                ),
                                Expanded(
                                  child: _buildInfoItem(
                                    'Selling Rate',
                                    '₹${b.sellingPrice.toStringAsFixed(2)}',
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoItem(
                                    'Locked Cost (लागत)',
                                    '₹${b.inventoryCostValue.toStringAsFixed(2)}',
                                    textColor: Colors.red.shade800,
                                  ),
                                ),
                                Expanded(
                                  child: _buildInfoItem(
                                    'Est. Margin %',
                                    '${b.grossMarginPercent.toStringAsFixed(1)}%',
                                    textColor: Colors.green.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Storage & Notes
                      if (b.storageLocation != null && b.storageLocation!.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(Icons.shelves, size: 16, color: AppColors.primaryDark),
                            const SizedBox(width: 6),
                            Text(
                              'Location: ${b.storageLocation}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (b.notes != null && b.notes!.isNotEmpty) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.notes_rounded, size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                b.notes!,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Supplier info if linked
                      if (b.supplierName != null && b.supplierName!.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(Icons.storefront_rounded, size: 16, color: Colors.indigo),
                            const SizedBox(width: 6),
                            Text(
                              'Supplier: ${b.supplierName}',
                              style: const TextStyle(fontSize: 12, color: Colors.indigo),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              // Action Buttons Row
              Column(
                children: [
                  // Primary Action Buttons
                  Row(
                    children: [
                      // Write off / Dispose
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(color: Colors.red.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: b.quantity > 0 ? _handleDisposeBatch : null,
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          label: const Text('Write-off', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Quick stock adjust
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _handleQuickAdjustStock,
                          icon: const Icon(Icons.edit_note_rounded, size: 18),
                          label: const Text('Adjust Qty'),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Edit Batch
                      IconButton.filledTonal(
                        tooltip: 'Edit Batch Details',
                        onPressed: _handleEditBatch,
                        icon: const Icon(Icons.edit_rounded, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // WhatsApp Clearance Sale Button
                  if (b.quantity > 0 && !b.isExpired())
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _handleShareClearancePromo,
                        icon: const Icon(Icons.percent_rounded, size: 18),
                        label: const Text(
                          'Share Clearance Promo (सस्ता बेचें)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, {bool isHighlighted = false, Color? textColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlighted ? 15 : 13,
            fontWeight: FontWeight.bold,
            color: textColor ?? AppColors.textDark,
          ),
        ),
      ],
    );
  }
}
