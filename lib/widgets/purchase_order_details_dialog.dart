import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../supplier_models.dart';
import '../supplier_service.dart';
import '../utils/snackbar_helper.dart';
import 'record_supplier_payment_dialog.dart';

/// Interactive modal sheet displaying full Purchase Invoice details,
/// line items, financial breakdown, stock reception status, and payment actions.
class PurchaseOrderDetailsDialog extends StatefulWidget {
  final String shopId;
  final PurchaseOrderModel purchaseOrder;
  final SupplierModel? supplier;
  final SupplierService? service;
  final VoidCallback? onUpdated;

  const PurchaseOrderDetailsDialog({
    super.key,
    required this.shopId,
    required this.purchaseOrder,
    this.supplier,
    this.service,
    this.onUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required String shopId,
    required PurchaseOrderModel purchaseOrder,
    SupplierModel? supplier,
    SupplierService? service,
    VoidCallback? onUpdated,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => PurchaseOrderDetailsDialog(
        shopId: shopId,
        purchaseOrder: purchaseOrder,
        supplier: supplier,
        service: service,
        onUpdated: onUpdated,
      ),
    );
  }

  @override
  State<PurchaseOrderDetailsDialog> createState() =>
      _PurchaseOrderDetailsDialogState();
}

class _PurchaseOrderDetailsDialogState
    extends State<PurchaseOrderDetailsDialog> {
  late PurchaseOrderModel _po;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _po = widget.purchaseOrder;
  }

  Future<void> _handleMarkReceived() async {
    setState(() => _isProcessing = true);
    try {
      final service = widget.service ?? SupplierService();
      await service.receivePurchaseOrder(_po.id);

      final updated = _po.copyWith(
        status: PurchaseOrderStatus.received,
        stockUpdated: true,
      );

      if (mounted) {
        setState(() => _po = updated);
        HapticFeedback.mediumImpact();
        SnackbarHelper.showSuccessSnackBar(
          context,
          'Items marked received! Stock added to store inventory.',
        );
        widget.onUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showErrorSnackBar(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleRecordPayment() async {
    final service = widget.service ?? SupplierService();
    SupplierModel? sup = widget.supplier;
    sup ??= await service.getSupplier(_po.supplierId);
    if (!mounted) return;
    if (sup == null) {
      SnackbarHelper.showErrorSnackBar(context, 'Supplier information not found');
      return;
    }

    final payment = await RecordSupplierPaymentDialog.show(
      context,
      shopId: widget.shopId,
      supplier: sup,
      purchaseOrderId: _po.id,
      suggestedAmount: _po.balanceDue,
      service: service,
    );

    if (payment != null && mounted) {
      final newPaid = _po.paidAmount + payment.amount;
      final newBalance = (_po.totalAmount - newPaid).clamp(0.0, double.infinity);
      setState(() {
        _po = _po.copyWith(
          paidAmount: newPaid,
          balanceDue: newBalance,
          paymentStatus: newBalance <= 0.01 ? PaymentStatus.paid : PaymentStatus.partial,
        );
      });
      widget.onUpdated?.call();
    }
  }

  void _shareWhatsAppSummary() {
    final dateFormat = DateFormat('dd MMM yyyy');
    final buffer = StringBuffer();
    buffer.writeln('🧾 *PURCHASE INVOICE SUMMARY*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('📋 *Bill No:* ${_po.invoiceNumber}');
    buffer.writeln('🏢 *Supplier:* ${_po.supplierName}');
    buffer.writeln('📅 *Date:* ${dateFormat.format(_po.purchaseDate)}');
    buffer.writeln('📦 *Total Items:* ${_po.items.length} products (${_po.totalItemUnits} units)');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');

    for (int i = 0; i < _po.items.length; i++) {
      final it = _po.items[i];
      buffer.writeln('${i + 1}. *${it.productName}*');
      buffer.writeln('   ${it.receivedQuantity.toStringAsFixed(0)} ${it.unit} @ ₹${it.costPrice.toStringAsFixed(2)} = ₹${it.subtotal.toStringAsFixed(2)}');
    }

    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('💰 *Items Total:* ₹${_po.subtotal.toStringAsFixed(2)}');
    if (_po.transportCharges > 0) {
      buffer.writeln('🚚 *Transport:* ₹${_po.transportCharges.toStringAsFixed(2)}');
    }
    if (_po.discount > 0) {
      buffer.writeln('🏷️ *Discount:* -₹${_po.discount.toStringAsFixed(2)}');
    }
    buffer.writeln('💵 *Final Bill Amount:* ₹${_po.totalAmount.toStringAsFixed(2)}');
    buffer.writeln('✅ *Paid:* ₹${_po.paidAmount.toStringAsFixed(2)}');
    buffer.writeln('⏳ *Balance Due:* ₹${_po.balanceDue.toStringAsFixed(2)}');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('_Managed via NearKirana Store Management_');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    SnackbarHelper.showSuccessSnackBar(context, 'Invoice summary copied to clipboard!');
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 800),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: AppColors.primaryDark),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Purchase Invoice #${_po.invoiceNumber}',
                            style: AppTextStyles.heading2(color: AppColors.textDark)),
                        Text('${_po.supplierName} • ${dateFormat.format(_po.purchaseDate)}',
                            style: AppTextStyles.caption(color: AppColors.textMid)),
                      ],
                    ),
                  ),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(_po.status.colorValue).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Color(_po.status.colorValue)),
                    ),
                    child: Text(
                      _po.status.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(_po.status.colorValue),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textLight),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Content Body
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Stock Inventory Status Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _po.stockUpdated ? Colors.green.shade50 : Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _po.stockUpdated ? Colors.green.shade200 : Colors.amber.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _po.stockUpdated ? Icons.check_circle_rounded : Icons.pending_rounded,
                              color: _po.stockUpdated ? Colors.green.shade800 : Colors.amber.shade900,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _po.stockUpdated
                                    ? 'Stock successfully added to store inventory.'
                                    : 'Stock has not been added to inventory yet.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _po.stockUpdated ? Colors.green.shade900 : Colors.amber.shade900,
                                ),
                              ),
                            ),
                            if (!_po.stockUpdated && _po.status != PurchaseOrderStatus.cancelled)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryDark,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                onPressed: _isProcessing ? null : _handleMarkReceived,
                                child: _isProcessing
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : const Text('Add to Stock'),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Items Table Header
                      Text(
                        'Purchased Items (${_po.items.length})',
                        style: AppTextStyles.bodySemiBold(color: AppColors.textDark),
                      ),
                      const SizedBox(height: 8),

                      // Items Table
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Table(
                            columnWidths: const {
                              0: FlexColumnWidth(4),
                              1: FlexColumnWidth(2),
                              2: FlexColumnWidth(2),
                              3: FlexColumnWidth(2.5),
                            },
                            children: [
                              TableRow(
                                decoration: BoxDecoration(color: Colors.grey.shade100),
                                children: const [
                                  Padding(
                                    padding: EdgeInsets.all(10.0),
                                    child: Text('Product', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.all(10.0),
                                    child: Text('Received', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.all(10.0),
                                    child: Text('Rate (₹)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.all(10.0),
                                    child: Text('Total (₹)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                ],
                              ),
                              ..._po.items.map((it) {
                                return TableRow(
                                  decoration: BoxDecoration(
                                    border: Border(top: BorderSide(color: Colors.grey.shade100)),
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(10.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(it.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                          if (it.sellingPrice > 0)
                                            Text(
                                              'MRP ₹${it.sellingPrice.toStringAsFixed(0)} • ${it.estimatedMarginPercent.toStringAsFixed(0)}% margin',
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(10.0),
                                      child: Text(
                                        '${it.receivedQuantity.toStringAsFixed(0)} ${it.unit}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(10.0),
                                      child: Text(
                                        '₹${it.costPrice.toStringAsFixed(2)}',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(10.0),
                                      child: Text(
                                        '₹${it.subtotal.toStringAsFixed(2)}',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Financial Breakdown Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            _buildSummaryRow('Items Subtotal', '₹${_po.subtotal.toStringAsFixed(2)}'),
                            if (_po.transportCharges > 0)
                              _buildSummaryRow('Transport / Freight', '+ ₹${_po.transportCharges.toStringAsFixed(2)}'),
                            if (_po.discount > 0)
                              _buildSummaryRow('Discount', '- ₹${_po.discount.toStringAsFixed(2)}', color: Colors.green.shade800),
                            const Divider(height: 14),
                            _buildSummaryRow('Final Bill Amount', '₹${_po.totalAmount.toStringAsFixed(2)}', isBold: true, fontSize: 16),
                            const SizedBox(height: 6),
                            _buildSummaryRow('Paid Amount', '₹${_po.paidAmount.toStringAsFixed(2)}', color: Colors.teal.shade800),
                            _buildSummaryRow(
                              'Outstanding Due (उधारी)',
                              '₹${_po.balanceDue.toStringAsFixed(2)}',
                              isBold: true,
                              color: _po.balanceDue > 0 ? Colors.red.shade800 : Colors.green.shade800,
                            ),
                          ],
                        ),
                      ),
                      if (_po.notes != null && _po.notes!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.notes_rounded, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('Notes: ${_po.notes}', style: const TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Bottom Actions
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _shareWhatsAppSummary,
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('Copy / Share'),
                  ),
                  const Spacer(),
                  if (_po.balanceDue > 0.01) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _handleRecordPayment,
                      icon: const Icon(Icons.payment_rounded, size: 18),
                      label: Text('Pay Due (₹${_po.balanceDue.toStringAsFixed(0)})'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value,
      {bool isBold = false, double fontSize = 13, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: AppColors.textMid,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
