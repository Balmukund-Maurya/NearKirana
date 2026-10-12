import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:near_kirana/firebase_utils.dart';

/// Standard payment status constants for NearKirana orders
class PaymentStatus {
  static const String unpaid = 'Unpaid';
  static const String paymentPending = 'Payment_Pending';
  static const String pendingVerification = 'Pending_Verification';
  static const String paid = 'Paid';
  static const String failed = 'Failed';
  static const String refunded = 'Refunded';

  static bool isPaid(String? status) => status == paid;
  static bool isPending(String? status) =>
      status == pendingVerification || status == paymentPending;
  static bool isFailed(String? status) => status == failed;
  static bool isRefunded(String? status) => status == refunded;
  static bool isUnpaid(String? status) => status == unpaid || status == null;
}

/// Standard payment method constants
class PaymentMethod {
  static const String cod = 'Cash on Delivery';
  static const String upi = 'UPI';
  static const String online = 'Online Gateway';
}

/// Robust Service managing online UPI and payment gateway lifecycles:
/// - Verification: Prevents unverified self-marking as Paid.
/// - Status tracking: Unpaid -> Pending_Verification -> Paid / Failed -> Refunded.
/// - Refund processing: Generates traceable refund IDs with audit trails.
class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  /// Generates NPCI-compliant UPI deep link URL
  String generateUpiPaymentUrl({
    required String upiId,
    required String payeeName,
    required double amount,
    required String orderId,
    String note = 'NearKirana Order',
  }) {
    final encodedName = Uri.encodeComponent(payeeName);
    final encodedNote = Uri.encodeComponent('$note #$orderId');
    return 'upi://pay?pa=$upiId&pn=$encodedName&am=${amount.toStringAsFixed(2)}&cu=INR&tn=$encodedNote&tr=$orderId';
  }

  /// Validates format of bank UTR / Gateway reference (12 digits or alphanumeric gateway reference)
  bool isValidUtr(String? utr) {
    if (utr == null) return false;
    final clean = utr.trim();
    if (clean.length < 8 || clean.length > 35) return false;
    return RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(clean);
  }

  /// Verifies an online payment and transitions status to 'Paid'.
  /// Can only be performed after merchant/backend verification.
  Future<bool> verifyAndMarkPaid({
    required String orderId,
    required String shopId,
    required String utrRef,
    String? verifiedBy,
  }) async {
    final cleanUtr = utrRef.trim();
    if (!isValidUtr(cleanUtr)) {
      throw Exception(
        'Invalid UTR/Transaction reference. Must be a valid reference number.',
      );
    }

    final orderRef = FirebaseUtils.firestore.collection('orders').doc(orderId);
    final doc = await orderRef.get();
    if (!doc.exists) {
      throw Exception('Order #$orderId not found.');
    }

    final data = doc.data()!;
    if (data['shop_id'] != shopId) {
      throw Exception('Unauthorized: Order belongs to a different shop.');
    }

    await orderRef.update({
      'payment_status': PaymentStatus.paid,
      'upi_ref_id': cleanUtr,
      'verified_at': FieldValue.serverTimestamp(),
      'verified_by': verifiedBy ?? 'Shopkeeper Verified',
    });

    return true;
  }

  /// Marks an online payment attempt as failed with a reason (e.g. invalid UTR, payment declined)
  Future<void> markPaymentFailed({
    required String orderId,
    required String shopId,
    required String reason,
  }) async {
    final orderRef = FirebaseUtils.firestore.collection('orders').doc(orderId);
    final doc = await orderRef.get();
    if (!doc.exists) {
      throw Exception('Order #$orderId not found.');
    }

    final data = doc.data()!;
    if (data['shop_id'] != shopId) {
      throw Exception('Unauthorized: Order belongs to a different shop.');
    }

    await orderRef.update({
      'payment_status': PaymentStatus.failed,
      'payment_failure_reason': reason,
      'failed_at': FieldValue.serverTimestamp(),
    });
  }

  /// Generates a standardized refund ID with timestamp and randomness
  static String generateRefundId() {
    return 'REF_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
  }

  /// Processes refund for an order that was paid online, generating a unique audit refund ID.
  Future<String> processRefund({
    required String orderId,
    required double amount,
    required String reason,
    required String initiatedBy,
  }) async {
    final orderRef = FirebaseUtils.firestore.collection('orders').doc(orderId);
    final refundId = generateRefundId();

    await orderRef.update({
      'payment_status': PaymentStatus.refunded,
      'refund_id': refundId,
      'refund_amount': amount,
      'refund_reason': reason,
      'refund_initiated_by': initiatedBy,
      'refunded_at': FieldValue.serverTimestamp(),
    });

    return refundId;
  }

  /// Customer submits or updates their UPI UTR / Reference after completing payment
  Future<void> submitCustomerUtr({
    required String orderId,
    required String utr,
  }) async {
    final cleanUtr = utr.trim();
    if (!isValidUtr(cleanUtr)) {
      throw Exception('Please enter a valid UPI Reference / UTR Number.');
    }

    final orderRef = FirebaseUtils.firestore.collection('orders').doc(orderId);
    await orderRef.update({
      'upi_ref_id': cleanUtr,
      'payment_status': PaymentStatus.pendingVerification,
      'utr_submitted_at': FieldValue.serverTimestamp(),
    });
  }
}
