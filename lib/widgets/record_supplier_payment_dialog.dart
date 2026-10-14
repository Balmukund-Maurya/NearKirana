import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../supplier_models.dart';
import '../supplier_service.dart';
import '../utils/snackbar_helper.dart';

/// Modal dialog to record a payment made to a Wholesaler / Supplier
class RecordSupplierPaymentDialog extends StatefulWidget {
  final String shopId;
  final SupplierModel supplier;
  final String? purchaseOrderId;
  final double? suggestedAmount;
  final SupplierService? service;

  const RecordSupplierPaymentDialog({
    super.key,
    required this.shopId,
    required this.supplier,
    this.purchaseOrderId,
    this.suggestedAmount,
    this.service,
  });

  static Future<SupplierPaymentModel?> show(
    BuildContext context, {
    required String shopId,
    required SupplierModel supplier,
    String? purchaseOrderId,
    double? suggestedAmount,
    SupplierService? service,
  }) {
    return showDialog<SupplierPaymentModel?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RecordSupplierPaymentDialog(
        shopId: shopId,
        supplier: supplier,
        purchaseOrderId: purchaseOrderId,
        suggestedAmount: suggestedAmount,
        service: service,
      ),
    );
  }

  @override
  State<RecordSupplierPaymentDialog> createState() =>
      _RecordSupplierPaymentDialogState();
}

class _RecordSupplierPaymentDialogState
    extends State<RecordSupplierPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _refNumberController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _paymentDate = DateTime.now();
  PurchasePaymentMethod _paymentMethod = PurchasePaymentMethod.upi;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final defaultAmt = widget.suggestedAmount ?? widget.supplier.balanceDue;
    if (defaultAmt > 0) {
      _amountController.text = defaultAmt.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _refNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _paymentDate = picked);
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      SnackbarHelper.showErrorSnackBar(context, 'Amount must be greater than zero');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final service = widget.service ?? SupplierService();
      final payment = await service.recordSupplierPayment(
        shopId: widget.shopId,
        supplierId: widget.supplier.id,
        supplierName: widget.supplier.name,
        purchaseOrderId: widget.purchaseOrderId,
        amount: amount,
        paymentDate: _paymentDate,
        paymentMethod: _paymentMethod,
        referenceNumber: _refNumberController.text.isNotEmpty
            ? _refNumberController.text
            : null,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      if (mounted) {
        HapticFeedback.mediumImpact();
        SnackbarHelper.showSuccessSnackBar(
          context,
          'Payment of ₹${amount.toStringAsFixed(2)} recorded for ${widget.supplier.name}',
        );
        Navigator.pop(context, payment);
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showErrorSnackBar(context, 'Error recording payment: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = widget.supplier.balanceDue;
    final dateFormat = DateFormat('dd MMM yyyy');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.payment_rounded, color: Colors.green.shade700),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Record Supplier Payment',
                              style: AppTextStyles.heading2(color: AppColors.textDark)),
                          Text(widget.supplier.name,
                              style: AppTextStyles.caption(color: AppColors.textMid),
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textLight),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Current Outstanding Balance Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: balance > 0 ? Colors.red.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: balance > 0 ? Colors.red.shade200 : Colors.green.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Outstanding Due (बाकी उधारी)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: balance > 0 ? Colors.red.shade800 : Colors.green.shade800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '₹${balance.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: balance > 0 ? Colors.red.shade900 : Colors.green.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (balance > 0) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            ActionChip(
                              visualDensity: VisualDensity.compact,
                              label: const Text('Pay Full', style: TextStyle(fontSize: 11)),
                              onPressed: () {
                                setState(() {
                                  _amountController.text = balance.toStringAsFixed(0);
                                });
                              },
                            ),
                            ActionChip(
                              visualDensity: VisualDensity.compact,
                              label: const Text('Pay Half', style: TextStyle(fontSize: 11)),
                              onPressed: () {
                                setState(() {
                                  _amountController.text = (balance / 2).toStringAsFixed(0);
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Amount to Pay
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Payment Amount (₹) *',
                    prefixIcon: const Icon(Icons.currency_rupee),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter amount';
                    final n = double.tryParse(v);
                    if (n == null || n <= 0) return 'Enter valid amount > 0';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Payment Method & Date
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<PurchasePaymentMethod>(
                        initialValue: _paymentMethod,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Mode',
                          prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: const [
                          DropdownMenuItem(value: PurchasePaymentMethod.upi, child: Text('UPI / QR')),
                          DropdownMenuItem(value: PurchasePaymentMethod.cash, child: Text('Cash (नकद)')),
                          DropdownMenuItem(value: PurchasePaymentMethod.bankTransfer, child: Text('Bank Transfer')),
                          DropdownMenuItem(value: PurchasePaymentMethod.cheque, child: Text('Cheque')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _paymentMethod = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Date',
                            prefixIcon: const Icon(Icons.calendar_today_outlined),
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(dateFormat.format(_paymentDate), style: const TextStyle(fontSize: 13)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Reference Number / UTR / Cheque Number
                TextFormField(
                  controller: _refNumberController,
                  decoration: InputDecoration(
                    labelText: 'Reference # / UPI UTR / Cheque (Optional)',
                    hintText: 'e.g., UTR 3829104829',
                    prefixIcon: const Icon(Icons.tag_rounded),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),

                // Notes
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: 'Notes / Remarks (Optional)',
                    hintText: 'e.g., Cleared invoice INV-5821',
                    prefixIcon: const Icon(Icons.notes_rounded),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isLoading ? null : _handleSubmit,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.check_circle_rounded),
                        label: const Text('Record Payment', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
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
