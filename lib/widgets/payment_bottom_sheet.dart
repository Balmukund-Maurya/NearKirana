import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:near_kirana/payment_service.dart';
import 'package:near_kirana/razorpay_service.dart';
import 'package:near_kirana/app_theme.dart';

/// Result returned by the payment bottom sheet.
sealed class PaymentSheetResult {
  const PaymentSheetResult();
}

class PaymentSheetRazorpaySuccess extends PaymentSheetResult {
  final String paymentMethod;
  final String paymentStatus;
  final String? razorpayPaymentId;
  final String? razorpayOrderId;
  final String? razorpaySignature;
  final Map<String, dynamic> extraData;
  const PaymentSheetRazorpaySuccess({
    required this.paymentMethod,
    required this.paymentStatus,
    this.razorpayPaymentId,
    this.razorpayOrderId,
    this.razorpaySignature,
    this.extraData = const {},
  });
}

class PaymentSheetCodSelected extends PaymentSheetResult {
  final String paymentMethod;
  final String paymentStatus;
  const PaymentSheetCodSelected({required this.paymentMethod, required this.paymentStatus});
}

class PaymentSheetKhataSelected extends PaymentSheetResult {
  final String paymentMethod;
  final String paymentStatus;
  const PaymentSheetKhataSelected({required this.paymentMethod, required this.paymentStatus});
}

class PaymentSheetUpiQrPending extends PaymentSheetResult {
  final String paymentMethod;
  final String paymentStatus;
  final Map<String, dynamic> extraData;
  const PaymentSheetUpiQrPending({
    required this.paymentMethod,
    required this.paymentStatus,
    this.extraData = const {},
  });
}

class PaymentSheetCancelled extends PaymentSheetResult {
  const PaymentSheetCancelled();
}

/// Zepto/Blinkit-style payment bottom sheet.
class PaymentBottomSheet extends StatefulWidget {
  final double amount;
  final String shopUpiId;
  final String shopName;
  final String razorpayKeyId;
  final String customerPhone;
  final String customerName;
  final String shopId;
  final bool khataEligible;

  const PaymentBottomSheet({
    super.key,
    required this.amount,
    required this.shopUpiId,
    required this.shopName,
    required this.razorpayKeyId,
    required this.customerPhone,
    required this.customerName,
    required this.shopId,
    this.khataEligible = false,
  });

  static Future<PaymentSheetResult?> show(
    BuildContext context, {
    required double amount,
    required String shopUpiId,
    required String shopName,
    required String razorpayKeyId,
    required String customerPhone,
    required String customerName,
    required String shopId,
    bool khataEligible = false,
  }) {
    return showModalBottomSheet<PaymentSheetResult>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaymentBottomSheet(
        amount: amount,
        shopUpiId: shopUpiId,
        shopName: shopName,
        razorpayKeyId: razorpayKeyId,
        customerPhone: customerPhone,
        customerName: customerName,
        shopId: shopId,
        khataEligible: khataEligible,
      ),
    );
  }

  @override
  State<PaymentBottomSheet> createState() => _PaymentBottomSheetState();
}

class _PaymentBottomSheetState extends State<PaymentBottomSheet>
    with SingleTickerProviderStateMixin {
  int _selectedMethod = 0; // 0:UPI, 1:COD, 2:Khata
  bool _isProcessing = false;
  bool _showQr = false;
  bool _upiPaidConfirmed = false;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;

  static const Color _green = Color(0xFF047857);
  static const Color _greenLight = Color(0xFFF0FDF4);
  static const Color _greenBorder = Color(0xFF22C55E);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300))
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ── PAYMENT HANDLERS ──

  Future<void> _handleUpiGateway() async {
    setState(() => _isProcessing = true);
    try {
      final result = await RazorpayService().checkout(
        keyId: widget.razorpayKeyId,
        amount: widget.amount,
        shopName: widget.shopName,
        customerPhone: widget.customerPhone,
        customerName: widget.customerName,
        description: 'Order from ${widget.shopName}',
        notes: {'shop_id': widget.shopId, 'customer_phone': widget.customerPhone},
      );
      if (!mounted) return;
      if (result is RazorpaySuccessResult) {
        Navigator.pop(
          context,
          PaymentSheetRazorpaySuccess(
            paymentMethod: PaymentMethod.upi,
            paymentStatus: PaymentStatus.paid,
            razorpayPaymentId: result.paymentId,
            razorpayOrderId: result.orderId,
            razorpaySignature: result.signature,
            extraData: {
              'razorpay_payment_id': result.paymentId,
              if (result.orderId != null) 'razorpay_order_id': result.orderId,
              if (result.signature != null) 'razorpay_signature': result.signature,
              'verified_by': 'Razorpay Gateway',
              'verified_at': FieldValue.serverTimestamp(),
            },
          ),
        );
      } else if (result is RazorpayFailureResult) {
        setState(() => _isProcessing = false);
        _showError(result.message.isNotEmpty
            ? 'Payment cancel/fail: ${result.message}'
            : 'Payment complete nahi hua. Dobara try karein.');
      } else {
        setState(() => _isProcessing = false);
        _showError('Payment interrupted. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError('Error: $e');
      }
    }
  }

  void _handlePrimaryAction() {
    HapticFeedback.lightImpact();
    if (_selectedMethod == 0) {
      if (widget.razorpayKeyId.isNotEmpty) {
        _handleUpiGateway();
      } else if (widget.shopUpiId.isNotEmpty) {
        if (_showQr && _upiPaidConfirmed) {
          // User confirmed payment via QR
          Navigator.pop(
            context,
            PaymentSheetUpiQrPending(
              paymentMethod: PaymentMethod.upi,
              paymentStatus: PaymentStatus.pendingVerification,
              extraData: {
                'payment_type': 'Store UPI QR - Customer Confirmed',
                'store_upi_vpa': widget.shopUpiId,
              },
            ),
          );
        } else {
          setState(() => _showQr = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('QR scan ya UPI app se payment karein, phir checkbox tick karein.'),
              backgroundColor: _green,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        _showError('Online payment set up nahi hai. Cash on Delivery chunein.');
      }
    } else if (_selectedMethod == 1) {
      Navigator.pop(context, const PaymentSheetCodSelected(
        paymentMethod: PaymentMethod.cod,
        paymentStatus: PaymentStatus.unpaid,
      ));
    } else if (_selectedMethod == 2) {
      Navigator.pop(context, const PaymentSheetKhataSelected(
        paymentMethod: PaymentMethod.khata,
        paymentStatus: PaymentStatus.unpaid,
      ));
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _launchUpiApp() async {
    HapticFeedback.lightImpact();
    final url =
        'upi://pay?pa=${widget.shopUpiId}&pn=${Uri.encodeComponent(widget.shopName)}'
        '&am=${widget.amount.toStringAsFixed(2)}&cu=INR'
        '&tn=${Uri.encodeComponent("NearKirana Order")}';
    try {
      final launched = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        setState(() => _showQr = true);
        _showError('UPI app nahi mila. QR scan karke pay karein.');
      }
    } catch (_) {
      if (mounted) setState(() => _showQr = true);
    }
  }

  // ── BUILD ──

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Payment', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
                            Text('Total amount to pay', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: _greenLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _greenBorder.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '₹${widget.amount.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 20, color: _green),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                const SizedBox(height: 14),

                // Payment Method Tiles
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _methodTile(
                        index: 0,
                        icon: Icons.bolt_rounded,
                        title: 'UPI / Online Payment',
                        subtitle: 'GPay, PhonePe, Paytm, QR Code',
                        badge: '⚡ INSTANT',
                        badgeColor: _green,
                        iconBg: const Color(0xFFECFDF5),
                        iconColor: _green,
                      ),
                      const SizedBox(height: 8),
                      _methodTile(
                        index: 1,
                        icon: Icons.payments_outlined,
                        title: 'Cash on Delivery',
                        subtitle: 'Pay in cash when order arrives',
                        badge: 'POPULAR',
                        badgeColor: const Color(0xFF2563EB),
                        iconBg: const Color(0xFFEFF6FF),
                        iconColor: const Color(0xFF2563EB),
                      ),
                      if (widget.khataEligible) ...[
                        const SizedBox(height: 8),
                        _methodTile(
                          index: 2,
                          icon: Icons.menu_book_rounded,
                          title: 'Kirana Khata (Pay Later)',
                          subtitle: 'Add to monthly store ledger',
                          badge: '0% INTEREST',
                          badgeColor: const Color(0xFFD97706),
                          iconBg: const Color(0xFFFFFBEB),
                          iconColor: const Color(0xFFD97706),
                        ),
                      ],
                    ],
                  ),
                ),

                // Contextual UPI section
                if (_selectedMethod == 0) ...[
                  const SizedBox(height: 12),
                  _buildUpiSection(),
                ],

                const SizedBox(height: 14),

                // Trust strip
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.verified_user_rounded, size: 13, color: _green),
                    const SizedBox(width: 6),
                    Text('100% Safe & Secure • NPCI UPI Certified',
                        style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
                const SizedBox(height: 12),

                // Primary Action Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _handlePrimaryAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedMethod == 1
                            ? const Color(0xFF2563EB)
                            : _selectedMethod == 2
                                ? const Color(0xFFD97706)
                                : _green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _isProcessing
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : Text(_buttonLabel(),
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _buttonLabel() {
    if (_selectedMethod == 0) {
      if (widget.razorpayKeyId.isNotEmpty) return 'Pay ₹${widget.amount.toStringAsFixed(0)} Securely →';
      if (_showQr && _upiPaidConfirmed) return 'Confirm & Place Order →';
      if (widget.shopUpiId.isNotEmpty) return 'Show QR & Pay ₹${widget.amount.toStringAsFixed(0)}';
      return 'UPI Not Available';
    }
    if (_selectedMethod == 1) return 'Place Order (Pay on Delivery) →';
    return 'Place Order via Khata →';
  }

  Widget _buildUpiSection() {
    if (widget.shopUpiId.isEmpty && widget.razorpayKeyId.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline, color: Colors.orange, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('Online payment abhi set up nahi hai. Cash on Delivery chunein.',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.amber.shade900))),
          ]),
        ),
      );
    }

    if (widget.razorpayKeyId.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _greenLight, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.lock_rounded, color: _green, size: 16),
              const SizedBox(width: 6),
              Text('Secure Payment Gateway', style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 13, color: const Color(0xFF065F46))),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _chip('GPay', const Color(0xFFE8F0FE), const Color(0xFF1A73E8)),
              _chip('PhonePe', const Color(0xFFF3E8FF), const Color(0xFF5F259F)),
              _chip('Paytm', const Color(0xFFE0F2FE), const Color(0xFF002E6E)),
              _chip('BHIM / Any UPI', const Color(0xFFFFF7ED), const Color(0xFFC2410C)),
            ]),
            const SizedBox(height: 8),
            Text('Gateway will open. Complete payment securely inside your UPI app.',
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600)),
          ]),
        ),
      );
    }

    // QR-based UPI payment
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: Column(children: [
          // UPI ID row
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Store UPI ID', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              Text(widget.shopUpiId, style: GoogleFonts.jetBrainsMono(
                  fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF111827))),
            ])),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: widget.shopUpiId));
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('UPI ID copied!'), duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(6)),
                child: const Row(children: [
                  Icon(Icons.copy_rounded, size: 14, color: _green),
                  SizedBox(width: 4),
                  Text('Copy', style: TextStyle(fontSize: 12, color: _green, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          // Action buttons
          Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: _launchUpiApp,
              icon: const Icon(Icons.open_in_new_rounded, size: 15),
              label: Text('Open UPI App', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 11), elevation: 0,
              ),
            )),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () { HapticFeedback.lightImpact(); setState(() => _showQr = !_showQr); },
              icon: Icon(_showQr ? Icons.visibility_off_outlined : Icons.qr_code_2_rounded, size: 15),
              label: Text(_showQr ? 'Hide QR' : 'Scan QR'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _green, side: const BorderSide(color: _green),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
              ),
            ),
          ]),
          // QR code
          if (_showQr) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200)),
              child: Column(children: [
                QrImageView(
                  data: 'upi://pay?pa=${widget.shopUpiId}&pn=${Uri.encodeComponent(widget.shopName)}'
                      '&am=${widget.amount.toStringAsFixed(2)}&cu=INR'
                      '&tn=${Uri.encodeComponent("NearKirana Order")}',
                  version: QrVersions.auto, size: 160,
                ),
                const SizedBox(height: 6),
                Text('Scan to Pay ₹${widget.amount.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: _green)),
                Text('GPay • PhonePe • Paytm • BHIM',
                    style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade500)),
              ]),
            ),
            const SizedBox(height: 12),
            // Confirmation checkbox
            GestureDetector(
              onTap: () { HapticFeedback.lightImpact(); setState(() => _upiPaidConfirmed = !_upiPaidConfirmed); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _upiPaidConfirmed ? const Color(0xFFECFDF5) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _upiPaidConfirmed ? _greenBorder : Colors.grey.shade300),
                ),
                child: Row(children: [
                  Icon(_upiPaidConfirmed ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: _upiPaidConfirmed ? _green : Colors.grey.shade400, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    'Maine ₹${widget.amount.toStringAsFixed(0)} UPI se pay kar diya ✓',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500,
                        color: _upiPaidConfirmed ? const Color(0xFF065F46) : Colors.grey.shade700),
                  )),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _methodTile({
    required int index, required IconData icon, required String title,
    required String subtitle, required String badge, required Color badgeColor,
    required Color iconBg, required Color iconColor,
  }) {
    final isSelected = _selectedMethod == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedMethod = index;
          if (index != 0) { _showQr = false; _upiPaidConfirmed = false; }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _greenLight : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? _greenBorder : Colors.grey.shade200,
              width: isSelected ? 1.5 : 1.0),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: isSelected ? _greenLight : iconBg,
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: isSelected ? _green : iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13.5,
                color: isSelected ? const Color(0xFF065F46) : const Color(0xFF111827))),
            Text(subtitle, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
          ])),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6)),
            child: Text(badge, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                color: badgeColor, letterSpacing: 0.3)),
          ),
          const SizedBox(width: 8),
          Container(
            width: 18, height: 18,
            decoration: BoxDecoration(shape: BoxShape.circle,
                border: Border.all(color: isSelected ? _greenBorder : Colors.grey.shade300, width: 2)),
            alignment: Alignment.center,
            child: isSelected ? Container(width: 8, height: 8,
                decoration: const BoxDecoration(color: _greenBorder, shape: BoxShape.circle)) : null,
          ),
        ]),
      ),
    );
  }

  Widget _chip(String name, Color bg, Color text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6),
        border: Border.all(color: text.withValues(alpha: 0.2))),
    child: Text(name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: text)),
  );
}
