import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../invoice_model.dart';
import '../invoice_service.dart';
import 'package:near_kirana/l10n/app_localizations.dart';

/// Digital Receipt & Invoice Modal Dialog (Feature 50).
/// Provides an interactive, beautiful receipt card with itemized breakdown,
/// tax details, QR verification code, and instant PDF download/print/WhatsApp share actions.
class DigitalReceiptDialog extends StatefulWidget {
  final InvoiceModel invoice;
  final InvoiceService? invoiceService;

  const DigitalReceiptDialog({
    super.key,
    required this.invoice,
    this.invoiceService,
  });

  /// Displays the digital receipt modal given an [InvoiceModel].
  static Future<void> show(
    BuildContext context, {
    required InvoiceModel invoice,
    InvoiceService? invoiceService,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DigitalReceiptDialog(
        invoice: invoice,
        invoiceService: invoiceService,
      ),
    );
  }

  /// Convenience helper to construct and show the invoice directly from order raw data.
  static Future<void> showForOrder(
    BuildContext context, {
    required Map<String, dynamic> orderData,
    String? orderId,
    Map<String, dynamic>? shopData,
    InvoiceService? invoiceService,
  }) {
    final invoice = InvoiceModel.fromOrder(
      orderData,
      orderId: orderId,
      shopData: shopData,
    );
    return show(
      context,
      invoice: invoice,
      invoiceService: invoiceService,
    );
  }

  @override
  State<DigitalReceiptDialog> createState() => _DigitalReceiptDialogState();
}

class _DigitalReceiptDialogState extends State<DigitalReceiptDialog> {
  late final InvoiceService _invoiceService;
  bool _isProcessingAction = false;

  @override
  void initState() {
    super.initState();
    _invoiceService = widget.invoiceService ?? InvoiceService();
  }

  Future<void> _handleDownloadPdf() async {
    setState(() => _isProcessingAction = true);
    try {
      await _invoiceService.sharePdfInvoice(widget.invoice);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not generate PDF: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _handlePrint() async {
    setState(() => _isProcessingAction = true);
    try {
      await _invoiceService.printInvoice(widget.invoice);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print error: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _handleShareWhatsApp() async {
    setState(() => _isProcessingAction = true);
    try {
      await _invoiceService.shareViaWhatsApp(widget.invoice);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sharing failed: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  void _copyInvoiceNumber() {
    Clipboard.setData(ClipboardData(text: widget.invoice.invoiceNumber));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invoice number copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;
    final primaryColor = const Color(0xFF047857);
    final l10n = AppLocalizations.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 12,
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 820),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Green Banner & Store Title
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inv.shop.shopName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          inv.shop.address,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white, size: 22),
                    tooltip: 'Close Receipt',
                  ),
                ],
              ),
            ),

            // Scrollable Receipt Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Invoice Badge & Meta Row
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        inv.invoiceNumber,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF1F2937),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: _copyInvoiceNumber,
                                      child: Icon(Icons.copy, size: 14, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: inv.paymentStatus.toLowerCase() == 'paid'
                                      ? const Color(0xFFDCFCE7)
                                      : const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  inv.paymentStatus.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: inv.paymentStatus.toLowerCase() == 'paid'
                                        ? const Color(0xFF166534)
                                        : const Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Order: #${inv.orderId}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                inv.formattedDate,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          if (inv.shop.gstin != null && inv.shop.gstin!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'GSTIN: ${inv.shop.gstin}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Customer Details Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.person_pin_circle_outlined, size: 20, color: primaryColor),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Billed To: ${inv.customer.customerName}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Phone: ${inv.customer.customerPhone}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                                Text(
                                  'Address: ${inv.customer.deliveryAddress}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                                if (inv.customer.deliveryPin != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Delivery PIN: ${inv.customer.deliveryPin}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Items Table Title
                    Text(
                      l10n?.order_summary ?? 'Items Purchased',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                    ),
                    const SizedBox(height: 8),

                    // Items List
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          // Table Header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Text(l10n?.item_col ?? 'Item', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(l10n?.qty_col ?? 'Qty', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(l10n?.rate_col ?? 'Rate', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(l10n?.amt_col ?? 'Amount', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                          // Items Rows
                          ...inv.items.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;
                            final qtyStr = item.isLoose || item.quantity % 1 != 0
                                ? '${item.quantity.toStringAsFixed(1)} ${item.unit}'
                                : '${item.quantity.toInt()} ${item.unit}';

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: idx % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA),
                                border: idx < inv.items.length - 1
                                    ? Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.8))
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: Text(
                                      item.name,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      qtyStr,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '₹${item.unitPrice.toStringAsFixed(2)}',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '₹${item.totalPrice.toStringAsFixed(2)}',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Financial Calculations Breakdown
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          _buildCostRow(l10n?.subtotal ?? 'Subtotal', '₹${inv.subtotal.toStringAsFixed(2)}'),
                          if (inv.discount > 0) ...[
                            const SizedBox(height: 6),
                            _buildCostRow(
                              '${l10n?.coupon_discount ?? "Discount"} (${inv.couponCode ?? "Offer"})',
                              '-₹${inv.discount.toStringAsFixed(2)}',
                              textColor: const Color(0xFF16A34A),
                              isBold: true,
                            ),
                          ],
                          const SizedBox(height: 6),
                          _buildCostRow(
                            l10n?.delivery_fee ?? 'Delivery Fee',
                            inv.deliveryFee == 0 ? (l10n?.free_delivery_label ?? 'FREE') : '₹${inv.deliveryFee.toStringAsFixed(2)}',
                            textColor: inv.deliveryFee == 0 ? const Color(0xFF16A34A) : null,
                          ),
                          const SizedBox(height: 6),
                          _buildCostRow(
                            'Taxes (GST ${inv.taxRate.toStringAsFixed(0)}% incl.)',
                            '₹${inv.taxAmount.toStringAsFixed(2)}',
                            subtitle: 'CGST: ₹${inv.cgstAmount.toStringAsFixed(2)} | SGST: ₹${inv.sgstAmount.toStringAsFixed(2)}',
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(height: 1),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n?.grand_total_lbl ?? 'Grand Total',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              Text(
                                inv.formattedTotal,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // QR Code & Verification
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: QrImageView(
                              data: 'INVOICE:${inv.invoiceNumber};ORDER:${inv.orderId};TOTAL:${inv.finalTotal}',
                              version: QrVersions.auto,
                              size: 110.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Scan QR to verify invoice authenticity',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Actions Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: _isProcessingAction
                  ? const Center(
                      child: SizedBox(
                        height: 32,
                        width: 32,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  : Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Print Button
                        OutlinedButton.icon(
                          onPressed: _handlePrint,
                          icon: const Icon(Icons.print_outlined, size: 16),
                          label: Text(l10n?.print_receipt_btn ?? 'Print'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF374151),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        // Share WhatsApp Button
                        ElevatedButton.icon(
                          onPressed: _handleShareWhatsApp,
                          icon: const Icon(Icons.share, size: 16, color: Colors.white),
                          label: Text(l10n?.share_invoice_btn ?? 'Share WhatsApp', style: const TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        // Download PDF Button
                        ElevatedButton.icon(
                          onPressed: _handleDownloadPdf,
                          icon: const Icon(Icons.picture_as_pdf, size: 16, color: Colors.white),
                          label: Text(l10n?.download_pdf_btn ?? 'Download PDF', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostRow(
    String label,
    String value, {
    Color? textColor,
    bool isBold = false,
    String? subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: textColor ?? const Color(0xFF1F2937),
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 1),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          ),
        ],
      ],
    );
  }
}
