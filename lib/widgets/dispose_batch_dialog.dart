import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../batch_models.dart';
import '../batch_service.dart';
import '../utils/snackbar_helper.dart';

/// Modal dialog for writing off / disposing expired or damaged batch stock
class DisposeBatchDialog extends StatefulWidget {
  final String shopId;
  final BatchModel batch;
  final BatchService? service;

  const DisposeBatchDialog({
    super.key,
    required this.shopId,
    required this.batch,
    this.service,
  });

  static Future<BatchDisposalRecord?> show(
    BuildContext context, {
    required String shopId,
    required BatchModel batch,
    BatchService? service,
  }) {
    return showDialog<BatchDisposalRecord>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DisposeBatchDialog(
        shopId: shopId,
        batch: batch,
        service: service,
      ),
    );
  }

  @override
  State<DisposeBatchDialog> createState() => _DisposeBatchDialogState();
}

class _DisposeBatchDialogState extends State<DisposeBatchDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _qtyController;
  late TextEditingController _lossAmountController;
  late TextEditingController _notesController;

  DisposalReason _reason = DisposalReason.expired;
  bool _syncProductStock = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(
      text: widget.batch.quantity.toStringAsFixed(0),
    );

    final initialLoss = widget.batch.quantity * widget.batch.costPrice;
    _lossAmountController = TextEditingController(
      text: initialLoss.toStringAsFixed(2),
    );

    _notesController = TextEditingController();

    // Default reason according to expiry
    if (widget.batch.isExpired()) {
      _reason = DisposalReason.expired;
    } else {
      _reason = DisposalReason.damaged;
    }

    _qtyController.addListener(_recalcLoss);
  }

  void _recalcLoss() {
    final qty = double.tryParse(_qtyController.text) ?? 0.0;
    final loss = qty * widget.batch.costPrice;
    _lossAmountController.text = loss.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _qtyController.removeListener(_recalcLoss);
    _qtyController.dispose();
    _lossAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final qty = double.tryParse(_qtyController.text) ?? 0.0;
    if (qty <= 0) {
      SnackbarHelper.showErrorSnackBar(context, 'Enter a valid disposal quantity > 0');
      return;
    }

    if (qty > widget.batch.quantity) {
      SnackbarHelper.showErrorSnackBar(
        context,
        'Cannot dispose more than available stock (${widget.batch.quantity} ${widget.batch.unit})',
      );
      return;
    }

    final lossAmount = double.tryParse(_lossAmountController.text) ?? (qty * widget.batch.costPrice);

    setState(() => _isLoading = true);

    try {
      final service = widget.service ?? BatchService();

      final record = await service.disposeBatchStock(
        shopId: widget.shopId,
        batchId: widget.batch.id,
        quantityDisposed: qty,
        reason: _reason,
        customLossAmount: lossAmount,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        syncProductStock: _syncProductStock,
      );

      if (!mounted) return;
      SnackbarHelper.showSuccessSnackBar(
        context,
        'Disposal recorded: $qty ${widget.batch.unit} written off (Loss: ₹${lossAmount.toStringAsFixed(2)})',
      );
      Navigator.pop(context, record);
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showErrorSnackBar(context, 'Error recording disposal: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.batch;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.delete_sweep_rounded, color: Colors.red.shade800, size: 22),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Write-off / Dispose Stock\n(नुकसान दर्ज करें)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
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

                  // Batch Summary Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.productName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Batch: ${b.batchNumber}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                            Text(
                              'Available: ${b.quantity} ${b.unit}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: b.quantity > 0 ? Colors.green.shade800 : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Cost Rate: ₹${b.costPrice.toStringAsFixed(2)} / ${b.unit}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                            Text(
                              b.isExpired()
                                  ? 'Status: Expired'
                                  : 'Expires in ${b.daysUntilExpiry()}d',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: b.isExpired() ? Colors.red.shade800 : Colors.orange.shade800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quantity to Dispose with Presets
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Quantity to Dispose *',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Row(
                        children: [
                          ActionChip(
                            visualDensity: VisualDensity.compact,
                            label: const Text('All', style: TextStyle(fontSize: 11)),
                            onPressed: () {
                              setState(() {
                                _qtyController.text = b.quantity.toStringAsFixed(0);
                              });
                            },
                          ),
                          const SizedBox(width: 4),
                          ActionChip(
                            visualDensity: VisualDensity.compact,
                            label: const Text('Half', style: TextStyle(fontSize: 11)),
                            onPressed: () {
                              setState(() {
                                _qtyController.text = (b.quantity / 2).toStringAsFixed(0);
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _qtyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: 'Enter quantity to discard',
                      suffixText: b.unit,
                      prefixIcon: const Icon(Icons.remove_circle_outline_rounded),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter quantity';
                      final n = double.tryParse(v);
                      if (n == null || n <= 0) return 'Invalid quantity';
                      if (n > b.quantity) return 'Exceeds batch stock';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Reason Dropdown
                  DropdownButtonFormField<DisposalReason>(
                    initialValue: _reason,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Reason for Disposal (कारण) *',
                      prefixIcon: const Icon(Icons.help_outline_rounded),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: DisposalReason.values.map((r) {
                      return DropdownMenuItem(
                        value: r,
                        child: Text(r.displayName),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _reason = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Loss Amount (Cost Calculation Banner)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Calculated Financial Loss (नुकसान)',
                              style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${(double.tryParse(_lossAmountController.text) ?? 0).toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade900,
                              ),
                            ),
                          ],
                        ),
                        Icon(Icons.trending_down_rounded, color: Colors.red.shade700, size: 28),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Notes / Remarks
                  TextFormField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: 'Remarks / Notes (Optional)',
                      hintText: 'e.g. Mold detected on seals, written off',
                      prefixIcon: const Icon(Icons.notes_rounded),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Sync product stock toggle
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Update Store Product Stock', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text(
                      'Deducts disposed units from store inventory count',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: _syncProductStock,
                    activeThumbColor: Colors.red.shade700,
                    onChanged: (val) => setState(() => _syncProductStock = val),
                  ),
                  const SizedBox(height: 16),

                  // Action Buttons
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.delete_forever_rounded),
                    label: Text(
                      _isLoading ? 'Recording...' : 'Confirm Write-Off (नुकसान दर्ज करें)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
