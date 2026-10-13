import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'invoice_model.dart';

/// Service responsible for generating digital PDF invoices,
/// handling printing, and generating shareable text receipts (Feature 50).
class InvoiceService {
  final FirebaseFirestore? _firestore;

  InvoiceService({FirebaseFirestore? firestore})
      : _firestore = firestore;

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  /// Generates clean, production-ready vector PDF document bytes for the given [invoice].
  /// Uses pure Dart font rendering to guarantee offline reliability and fast generation.
  Future<Uint8List> generatePdfBytes(InvoiceModel invoice) async {
    final pdf = pw.Document(
      title: 'Invoice_${invoice.invoiceNumber}',
      author: invoice.shop.shopName,
    );

    final primaryColor = PdfColor.fromInt(0xFF047857); // Kirana green
    final darkTextColor = PdfColor.fromInt(0xFF1F2937);
    final mutedTextColor = PdfColor.fromInt(0xFF4B5563);
    final lightBgColor = PdfColor.fromInt(0xFFF9FAFB);
    final borderColor = PdfColor.fromInt(0xFFE5E7EB);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 1. TOP HEADER: Store Name & Invoice Badge
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          invoice.shop.shopName,
                          style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          invoice.shop.address,
                          style: pw.TextStyle(fontSize: 10, color: mutedTextColor),
                        ),
                        pw.Text(
                          'Phone: ${invoice.shop.phone}',
                          style: pw.TextStyle(fontSize: 10, color: mutedTextColor),
                        ),
                        if (invoice.shop.gstin != null && invoice.shop.gstin!.isNotEmpty)
                          pw.Text(
                            'GSTIN: ${invoice.shop.gstin}',
                            style: pw.TextStyle(fontSize: 9, color: mutedTextColor),
                          ),
                        if (invoice.shop.fssai != null && invoice.shop.fssai!.isNotEmpty)
                          pw.Text(
                            'FSSAI Lic: ${invoice.shop.fssai}',
                            style: pw.TextStyle(fontSize: 9, color: mutedTextColor),
                          ),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: primaryColor,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        ),
                        child: pw.Text(
                          'TAX INVOICE / CASH MEMO',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Invoice #: ${invoice.invoiceNumber}',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: darkTextColor,
                        ),
                      ),
                      pw.Text(
                        'Date: ${invoice.formattedDate}',
                        style: pw.TextStyle(fontSize: 9, color: mutedTextColor),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 16),
              pw.Divider(color: borderColor, thickness: 1),
              pw.SizedBox(height: 12),

              // 2. ORDER & CUSTOMER METADATA SECTION
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Bill To / Customer
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: lightBgColor,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(color: borderColor),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'BILLED TO:',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: mutedTextColor,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            invoice.customer.customerName,
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: darkTextColor,
                            ),
                          ),
                          pw.Text(
                            'Phone: ${invoice.customer.customerPhone}',
                            style: pw.TextStyle(fontSize: 9, color: mutedTextColor),
                          ),
                          pw.Text(
                            'Address: ${invoice.customer.deliveryAddress}',
                            style: pw.TextStyle(fontSize: 9, color: mutedTextColor),
                          ),
                          if (invoice.customer.deliveryPin != null)
                            pw.Text(
                              'Delivery PIN: ${invoice.customer.deliveryPin}',
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 16),

                  // Order & Payment Summary
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: lightBgColor,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(color: borderColor),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'ORDER DETAILS:',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: mutedTextColor,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Order ID:', style: pw.TextStyle(fontSize: 9, color: mutedTextColor)),
                              pw.Text('#${invoice.orderId}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            ],
                          ),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Delivery Type:', style: pw.TextStyle(fontSize: 9, color: mutedTextColor)),
                              pw.Text(invoice.deliveryType, style: pw.TextStyle(fontSize: 9)),
                            ],
                          ),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Payment Mode:', style: pw.TextStyle(fontSize: 9, color: mutedTextColor)),
                              pw.Text(invoice.paymentMethod, style: pw.TextStyle(fontSize: 9)),
                            ],
                          ),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Payment Status:', style: pw.TextStyle(fontSize: 9, color: mutedTextColor)),
                              pw.Text(
                                invoice.paymentStatus.toUpperCase(),
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: invoice.paymentStatus.toLowerCase() == 'paid'
                                      ? primaryColor
                                      : PdfColor.fromInt(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 16),

              // 3. ITEM DETAILS TABLE
              pw.Text(
                'ITEMIZED BREAKDOWN',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: darkTextColor,
                ),
              ),
              pw.SizedBox(height: 6),

              // Table Header
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  children: [
                    pw.SizedBox(
                      width: 28,
                      child: pw.Text('#', style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Expanded(
                      flex: 5,
                      child: pw.Text('Item Description', style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text('Qty / Unit', textAlign: pw.TextAlign.right, style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text('Rate (Rs.)', textAlign: pw.TextAlign.right, style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text('Amount (Rs.)', textAlign: pw.TextAlign.right, style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
              ),

              // Table Body Rows
              ...List.generate(invoice.items.length, (index) {
                final item = invoice.items[index];
                final isEven = index % 2 == 0;
                final qtyDisplay = item.isLoose || item.quantity % 1 != 0
                    ? '${item.quantity.toStringAsFixed(1)} ${item.unit}'
                    : '${item.quantity.toInt()} ${item.unit}';

                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  decoration: pw.BoxDecoration(
                    color: isEven ? PdfColors.white : lightBgColor,
                    border: pw.Border(
                      bottom: pw.BorderSide(color: borderColor, width: 0.5),
                    ),
                  ),
                  child: pw.Row(
                    children: [
                      pw.SizedBox(
                        width: 28,
                        child: pw.Text('${index + 1}', style: pw.TextStyle(fontSize: 9, color: mutedTextColor)),
                      ),
                      pw.Expanded(
                        flex: 5,
                        child: pw.Text(
                          item.name,
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: darkTextColor),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(qtyDisplay, textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, color: mutedTextColor)),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          'Rs. ${item.unitPrice.toStringAsFixed(2)}',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(fontSize: 9, color: mutedTextColor),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          'Rs. ${item.totalPrice.toStringAsFixed(2)}',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: darkTextColor),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 16),

              // 4. FINANCIAL SUMMARY & TAX BREAKDOWN
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Tax Note / UPI Payment info
                  pw.Expanded(
                    flex: 3,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: lightBgColor,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(color: borderColor),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'GST & TAX DETAILS:',
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: darkTextColor),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            '- Applicable GST Rate: ${invoice.taxRate.toStringAsFixed(1)}% (Inclusive)',
                            style: pw.TextStyle(fontSize: 8, color: mutedTextColor),
                          ),
                          pw.Text(
                            '- CGST (${(invoice.taxRate / 2).toStringAsFixed(1)}%): Rs. ${invoice.cgstAmount.toStringAsFixed(2)}',
                            style: pw.TextStyle(fontSize: 8, color: mutedTextColor),
                          ),
                          pw.Text(
                            '- SGST (${(invoice.taxRate / 2).toStringAsFixed(1)}%): Rs. ${invoice.sgstAmount.toStringAsFixed(2)}',
                            style: pw.TextStyle(fontSize: 8, color: mutedTextColor),
                          ),
                          pw.SizedBox(height: 6),
                          if (invoice.shop.upiId != null) ...[
                            pw.Text(
                              'Pay via UPI: ${invoice.shop.upiId}',
                              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  pw.SizedBox(width: 24),

                  // Calculation block
                  pw.Expanded(
                    flex: 3,
                    child: pw.Column(
                      children: [
                        _buildSummaryRow('Items Subtotal', 'Rs. ${invoice.subtotal.toStringAsFixed(2)}'),
                        if (invoice.discount > 0)
                          _buildSummaryRow(
                            'Discount (${invoice.couponCode ?? "Coupon"})',
                            '-Rs. ${invoice.discount.toStringAsFixed(2)}',
                            isNegative: true,
                          ),
                        _buildSummaryRow(
                          'Delivery Fee',
                          invoice.deliveryFee == 0 ? 'FREE' : 'Rs. ${invoice.deliveryFee.toStringAsFixed(2)}',
                        ),
                        pw.Divider(color: borderColor, thickness: 1),
                        // Grand Total Box
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromInt(0xFFECFDF5),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                            border: pw.Border.all(color: primaryColor, width: 1.2),
                          ),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                'GRAND TOTAL',
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                              pw.Text(
                                'Rs. ${invoice.finalTotal.toStringAsFixed(2)}',
                                style: pw.TextStyle(
                                  fontSize: 13,
                                  fontWeight: pw.FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // 5. FOOTER & POLICIES
              pw.Divider(color: borderColor, thickness: 1),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'Thank you for supporting ${invoice.shop.shopName}! Ghar ka rashan, vishwas ke saath.',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  'This is a computer-generated digital tax receipt. Return policy: within 24 hours with this receipt.',
                  style: pw.TextStyle(fontSize: 8, color: mutedTextColor),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSummaryRow(String label, String value, {bool isNegative = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF4B5563))),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: isNegative ? PdfColor.fromInt(0xFF16A34A) : PdfColor.fromInt(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  /// Share PDF invoice directly to apps (WhatsApp, Drive, Email, etc.)
  Future<void> sharePdfInvoice(InvoiceModel invoice, {String? filename}) async {
    final pdfBytes = await generatePdfBytes(invoice);
    final fname = filename ?? 'Invoice_${invoice.invoiceNumber}.pdf';
    await Printing.sharePdf(bytes: pdfBytes, filename: fname);
  }

  /// Print invoice using the system print dialog or thermal printer
  Future<void> printInvoice(InvoiceModel invoice) async {
    await Printing.layoutPdf(
      name: 'Invoice_${invoice.invoiceNumber}',
      onLayout: (PdfPageFormat format) async => await generatePdfBytes(invoice),
    );
  }

  /// Generates a customer-friendly, structured text receipt formatted for WhatsApp and SMS.
  String generateShareableText(InvoiceModel invoice) {
    final buffer = StringBuffer();
    buffer.writeln('🧾 *TAX INVOICE & CASH RECEIPT*');
    buffer.writeln('🏪 *${invoice.shop.shopName}*');
    buffer.writeln('📍 ${invoice.shop.address}');
    buffer.writeln('📞 Contact: ${invoice.shop.phone}');
    if (invoice.shop.gstin != null && invoice.shop.gstin!.isNotEmpty) {
      buffer.writeln('🏛️ GSTIN: ${invoice.shop.gstin}');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('📄 *Invoice No:* ${invoice.invoiceNumber}');
    buffer.writeln('🆔 *Order ID:* #${invoice.orderId}');
    buffer.writeln('📅 *Date:* ${invoice.formattedDate}');
    buffer.writeln('👤 *Customer:* ${invoice.customer.customerName} (${invoice.customer.customerPhone})');
    buffer.writeln('📍 *Delivery:* ${invoice.customer.deliveryAddress}');
    if (invoice.customer.deliveryPin != null) {
      buffer.writeln('🔑 *Delivery PIN:* ${invoice.customer.deliveryPin}');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('🛒 *ITEMS ORDERED:*');

    for (int i = 0; i < invoice.items.length; i++) {
      final item = invoice.items[i];
      final qtyStr = item.isLoose || item.quantity % 1 != 0
          ? '${item.quantity.toStringAsFixed(1)} ${item.unit}'
          : '${item.quantity.toInt()} ${item.unit}';
      buffer.writeln('${i + 1}. ${item.name} ($qtyStr) - ₹${item.totalPrice.toStringAsFixed(2)}');
    }

    buffer.writeln('--------------------------------');
    buffer.writeln('💰 Subtotal: ₹${invoice.subtotal.toStringAsFixed(2)}');
    if (invoice.discount > 0) {
      buffer.writeln('🏷️ Discount (${invoice.couponCode ?? "Coupon"}): -₹${invoice.discount.toStringAsFixed(2)}');
    }
    buffer.writeln('🚚 Delivery Fee: ${invoice.deliveryFee == 0 ? "FREE" : "₹${invoice.deliveryFee.toStringAsFixed(2)}"}');
    buffer.writeln('🏛️ Taxes (GST ${invoice.taxRate.toStringAsFixed(0)}% incl.): ₹${invoice.taxAmount.toStringAsFixed(2)}');
    buffer.writeln('--------------------------------');
    buffer.writeln('💳 *GRAND TOTAL: ₹${invoice.finalTotal.toStringAsFixed(2)}*');
    buffer.writeln('💵 Payment: ${invoice.paymentMethod} (${invoice.paymentStatus.toUpperCase()})');
    buffer.writeln('--------------------------------');
    buffer.writeln('🙏 *Thank you for shopping local with ${invoice.shop.shopName}!*');

    return buffer.toString();
  }

  /// Share invoice text directly via WhatsApp or standard share sheet
  Future<void> shareViaWhatsApp(InvoiceModel invoice) async {
    final text = generateShareableText(invoice);
    final encodedText = Uri.encodeComponent(text);
    final whatsappUrl = Uri.parse('whatsapp://send?text=$encodedText');

    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } else {
      // Fallback to general system share sheet
      await SharePlus.instance.share(
        ShareParams(
          text: text,
        ),
      );
    }
  }

  /// Optionally save or audit digital invoice in Cloud Firestore
  Future<void> saveInvoiceRecord(InvoiceModel invoice) async {
    try {
      await firestore
          .collection('invoices')
          .doc(invoice.invoiceNumber)
          .set(invoice.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to save invoice record: $e');
    }
  }
}
