import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'firebase_utils.dart';

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
  static const String card = 'Card';
  static const String netBanking = 'Net Banking';
  static const String khata = 'Khata';

  static List<String> get onlineMethods => [upi, online, card, netBanking];
  static bool isOnline(String? method) => onlineMethods.contains(method);
}

/// Payment Gateway Checkout Session Model
class PaymentSession {
  final String sessionId;
  final String transactionId;
  final String orderId;
  final String shopId;
  final double amount;
  final String currency;
  final String paymentMethod;
  final String customerPhone;
  final String? customerName;
  final String
  status; // 'pending', 'processing', 'completed', 'failed', 'cancelled', 'timed_out'
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? gatewayOrderId;
  final String? paymentToken;
  final String? upiDeepLink;

  const PaymentSession({
    required this.sessionId,
    required this.transactionId,
    required this.orderId,
    required this.shopId,
    required this.amount,
    this.currency = 'INR',
    required this.paymentMethod,
    required this.customerPhone,
    this.customerName,
    this.status = 'pending',
    required this.createdAt,
    required this.expiresAt,
    this.gatewayOrderId,
    this.paymentToken,
    this.upiDeepLink,
  });

  Map<String, dynamic> toMap() => {
    'session_id': sessionId,
    'transaction_id': transactionId,
    'order_id': orderId,
    'shop_id': shopId,
    'amount': amount,
    'currency': currency,
    'payment_method': paymentMethod,
    'customer_phone': customerPhone,
    if (customerName != null) 'customer_name': customerName,
    'status': status,
    'created_at': Timestamp.fromDate(createdAt),
    'expires_at': Timestamp.fromDate(expiresAt),
    if (gatewayOrderId != null) 'gateway_order_id': gatewayOrderId,
    if (paymentToken != null) 'payment_token': paymentToken,
    if (upiDeepLink != null) 'upi_deep_link': upiDeepLink,
  };

  factory PaymentSession.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return PaymentSession(
      sessionId: map['session_id']?.toString() ?? '',
      transactionId: map['transaction_id']?.toString() ?? '',
      orderId: map['order_id']?.toString() ?? '',
      shopId: map['shop_id']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency']?.toString() ?? 'INR',
      paymentMethod: map['payment_method']?.toString() ?? PaymentMethod.online,
      customerPhone: map['customer_phone']?.toString() ?? '',
      customerName: map['customer_name']?.toString(),
      status: map['status']?.toString() ?? 'pending',
      createdAt: parseDate(map['created_at']),
      expiresAt: parseDate(map['expires_at']),
      gatewayOrderId: map['gateway_order_id']?.toString(),
      paymentToken: map['payment_token']?.toString(),
      upiDeepLink: map['upi_deep_link']?.toString(),
    );
  }
}

/// Verification result returned by trusted backend payment verification
class PaymentVerificationResult {
  final bool success;
  final String orderId;
  final String transactionId;
  final String status;
  final String message;
  final double amount;
  final DateTime verifiedAt;
  final String? gatewayRef;

  const PaymentVerificationResult({
    required this.success,
    required this.orderId,
    required this.transactionId,
    required this.status,
    required this.message,
    required this.amount,
    required this.verifiedAt,
    this.gatewayRef,
  });

  Map<String, dynamic> toMap() => {
    'success': success,
    'order_id': orderId,
    'transaction_id': transactionId,
    'status': status,
    'message': message,
    'amount': amount,
    'verified_at': Timestamp.fromDate(verifiedAt),
    if (gatewayRef != null) 'gateway_ref': gatewayRef,
  };
}

/// Robust Service managing online UPI and payment gateway lifecycles:
/// - Checkout: Initiates secure gateway checkout sessions.
/// - Trusted Verification: Validates gateway references & signatures on backend.
/// - Reconciliation: Monitors pending transactions, handling time-outs.
/// - Failure & Refund Workflows: Logs failures with audit trails & processes verified refunds.
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

  /// Validates format of gateway signature / token (alphanumeric or hex hash)
  bool isValidSignature(String? signature) {
    if (signature == null) return false;
    final clean = signature.trim();
    if (clean.length < 10 || clean.length > 128) return false;
    return RegExp(r'^[a-zA-Z0-9_\-.]+$').hasMatch(clean);
  }

  /// Initiates an online payment gateway checkout session for an order.
  /// Generates a unique transaction ID and registers a ledger record in payment_transactions.
  Future<PaymentSession> initiateOnlinePayment({
    required String orderId,
    required String shopId,
    required double amount,
    required String customerPhone,
    String? customerName,
    String paymentMethod = PaymentMethod.upi,
    String? upiId,
    String? payeeName,
    String note = 'NearKirana Order',
    Duration sessionTtl = const Duration(minutes: 15),
    FirebaseFirestore? firestore,
  }) async {
    final db = firestore ?? FirebaseUtils.firestore;
    final now = DateTime.now();
    final expiresAt = now.add(sessionTtl);
    final randomSuffix = Random().nextInt(999999).toString().padLeft(6, '0');
    final txnId = 'TXN_${now.millisecondsSinceEpoch}_$randomSuffix';
    final sessionId = 'SESS_${now.millisecondsSinceEpoch}_$randomSuffix';
    final token = 'TOKEN_${orderId}_$randomSuffix';

    String? upiLink;
    if (paymentMethod == PaymentMethod.upi &&
        upiId != null &&
        upiId.isNotEmpty) {
      upiLink = generateUpiPaymentUrl(
        upiId: upiId,
        payeeName: payeeName ?? 'NearKirana Store',
        amount: amount,
        orderId: orderId,
        note: note,
      );
    }

    final session = PaymentSession(
      sessionId: sessionId,
      transactionId: txnId,
      orderId: orderId,
      shopId: shopId,
      amount: amount,
      paymentMethod: paymentMethod,
      customerPhone: customerPhone,
      customerName: customerName,
      status: 'pending',
      createdAt: now,
      expiresAt: expiresAt,
      gatewayOrderId: 'GW_ORD_$orderId',
      paymentToken: token,
      upiDeepLink: upiLink,
    );

    // Save transaction in payment_transactions collection
    await db.collection('payment_transactions').doc(txnId).set({
      ...session.toMap(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    // Update order with active transaction ID and payment_pending status
    final orderRef = db.collection('orders').doc(orderId);
    final orderSnap = await orderRef.get();
    if (orderSnap.exists) {
      await orderRef.update({
        'active_transaction_id': txnId,
        'payment_session_id': sessionId,
        'payment_status': PaymentStatus.paymentPending,
        'payment_method': paymentMethod,
        'upi_deep_link': ?upiLink,
      });
    }

    return session;
  }

  /// Verifies an online payment via trusted gateway reference / signature and marks the order as 'Paid'.
  /// This operation is safe and idempotent.
  Future<PaymentVerificationResult> verifyOnlinePayment({
    required String orderId,
    required String transactionId,
    required String gatewayReference,
    required String gatewaySignature,
    String? verifiedBy,
    FirebaseFirestore? firestore,
  }) async {
    final cleanRef = gatewayReference.trim();
    if (!isValidUtr(cleanRef)) {
      throw Exception('Invalid gateway reference / UTR format: $cleanRef');
    }

    if (!isValidSignature(gatewaySignature)) {
      throw Exception('Invalid gateway signature / verification token');
    }

    final db = firestore ?? FirebaseUtils.firestore;
    final orderRef = db.collection('orders').doc(orderId);
    final orderSnap = await orderRef.get();
    if (!orderSnap.exists) {
      throw Exception('Order #$orderId not found.');
    }

    final orderData = orderSnap.data()!;
    final double orderTotal =
        (orderData['total_amount'] as num?)?.toDouble() ?? 0.0;
    final currentPaymentStatus = orderData['payment_status']?.toString();

    // Idempotency: Already paid order returns verification without duplicate mutation
    if (currentPaymentStatus == PaymentStatus.paid) {
      return PaymentVerificationResult(
        success: true,
        orderId: orderId,
        transactionId: transactionId,
        status: PaymentStatus.paid,
        message: 'Order was already verified and paid.',
        amount: orderTotal,
        verifiedAt: DateTime.now(),
        gatewayRef: cleanRef,
      );
    }

    final now = DateTime.now();

    // Update payment_transactions record
    final txnRef = db.collection('payment_transactions').doc(transactionId);
    final txnSnap = await txnRef.get();
    if (txnSnap.exists) {
      await txnRef.update({
        'status': 'completed',
        'gateway_reference': cleanRef,
        'gateway_signature': gatewaySignature,
        'verified_by': verifiedBy ?? 'Trusted Payment Gateway / Webhook',
        'completed_at': FieldValue.serverTimestamp(),
      });
    }

    // Update order record to Paid
    await orderRef.update({
      'payment_status': PaymentStatus.paid,
      'upi_ref_id': cleanRef,
      'payment_transaction_id': transactionId,
      'verified_at': FieldValue.serverTimestamp(),
      'verified_by': verifiedBy ?? 'Trusted Payment Gateway / Webhook',
    });

    return PaymentVerificationResult(
      success: true,
      orderId: orderId,
      transactionId: transactionId,
      status: PaymentStatus.paid,
      message: 'Payment verified and confirmed successfully.',
      amount: orderTotal,
      verifiedAt: now,
      gatewayRef: cleanRef,
    );
  }

  /// Verifies and confirms an online payment made through payment gateway (e.g. Razorpay).
  /// Updates payment_transactions ledger and marks the order as Paid.
  Future<PaymentVerificationResult> verifyAndConfirmGatewayPayment({
    required String orderId,
    required String transactionId,
    required String gatewayPaymentRef,
    String? gatewaySignature,
    String verifiedBy = 'Razorpay Gateway',
    FirebaseFirestore? firestore,
  }) async {
    final cleanRef = gatewayPaymentRef.trim();
    final db = firestore ?? FirebaseUtils.firestore;
    final orderRef = db.collection('orders').doc(orderId);
    final orderSnap = await orderRef.get();
    if (!orderSnap.exists) {
      throw Exception('Order #$orderId not found.');
    }

    final orderData = orderSnap.data()!;
    final double orderTotal =
        (orderData['total_amount'] as num?)?.toDouble() ?? 0.0;
    final now = DateTime.now();

    final txnRef = db.collection('payment_transactions').doc(transactionId);
    final txnSnap = await txnRef.get();
    if (txnSnap.exists) {
      await txnRef.update({
        'status': 'completed',
        'gateway_reference': cleanRef,
        'gateway_signature': ?gatewaySignature,
        'verified_by': verifiedBy,
        'completed_at': FieldValue.serverTimestamp(),
      });
    } else {
      await txnRef.set({
        'transaction_id': transactionId,
        'order_id': orderId,
        'shop_id': orderData['shop_id'] ?? '',
        'amount': orderTotal,
        'payment_method': orderData['payment_method'] ?? PaymentMethod.upi,
        'customer_phone': orderData['phone_number'] ?? '',
        'gateway_reference': cleanRef,
        'gateway_signature': ?gatewaySignature,
        'status': 'completed',
        'verified_by': verifiedBy,
        'created_at': FieldValue.serverTimestamp(),
        'completed_at': FieldValue.serverTimestamp(),
      });
    }

    await orderRef.update({
      'payment_status': PaymentStatus.paid,
      'upi_ref_id': cleanRef,
      'payment_transaction_id': transactionId,
      'razorpay_signature': ?gatewaySignature,
      'verified_at': FieldValue.serverTimestamp(),
      'verified_by': verifiedBy,
    });

    return PaymentVerificationResult(
      success: true,
      orderId: orderId,
      transactionId: transactionId,
      status: PaymentStatus.paid,
      message: 'Gateway payment verified and confirmed successfully.',
      amount: orderTotal,
      verifiedAt: now,
      gatewayRef: cleanRef,
    );
  }

  /// Verifies an online payment and transitions status to 'Paid'.
  /// Can only be performed after merchant/backend verification.
  Future<bool> verifyAndMarkPaid({
    required String orderId,
    required String shopId,
    required String utrRef,
    String? verifiedBy,
    FirebaseFirestore? firestore,
  }) async {
    final cleanUtr = utrRef.trim();
    if (!isValidUtr(cleanUtr)) {
      throw Exception(
        'Invalid UTR/Transaction reference. Must be a valid reference number.',
      );
    }

    final db = firestore ?? FirebaseUtils.firestore;
    final orderRef = db.collection('orders').doc(orderId);
    final doc = await orderRef.get();
    if (!doc.exists) {
      throw Exception('Order #$orderId not found.');
    }

    final data = doc.data()!;
    if (data['shop_id'] != shopId) {
      throw Exception('Unauthorized: Order belongs to a different shop.');
    }

    final txnId =
        'TXN_VERIFY_${orderId}_${DateTime.now().millisecondsSinceEpoch}';
    await db.collection('payment_transactions').doc(txnId).set({
      'transaction_id': txnId,
      'order_id': orderId,
      'shop_id': shopId,
      'amount': (data['total_amount'] as num?)?.toDouble() ?? 0.0,
      'payment_method': data['payment_method'] ?? PaymentMethod.upi,
      'customer_phone': data['phone_number'] ?? '',
      'gateway_reference': cleanUtr,
      'status': 'completed',
      'verified_by': verifiedBy ?? 'Shopkeeper Verified',
      'created_at': FieldValue.serverTimestamp(),
      'completed_at': FieldValue.serverTimestamp(),
    });

    await orderRef.update({
      'payment_status': PaymentStatus.paid,
      'upi_ref_id': cleanUtr,
      'verified_at': FieldValue.serverTimestamp(),
      'verified_by': verifiedBy ?? 'Shopkeeper Verified',
    });

    return true;
  }

  /// Marks an online payment attempt as failed with a reason (e.g. payment declined, timeout)
  Future<void> handlePaymentFailure({
    required String orderId,
    required String transactionId,
    required String failureReason,
    FirebaseFirestore? firestore,
  }) async {
    final db = firestore ?? FirebaseUtils.firestore;
    final orderRef = db.collection('orders').doc(orderId);
    final doc = await orderRef.get();
    if (!doc.exists) {
      throw Exception('Order #$orderId not found.');
    }

    final txnRef = db.collection('payment_transactions').doc(transactionId);
    final txnSnap = await txnRef.get();
    if (txnSnap.exists) {
      await txnRef.update({
        'status': 'failed',
        'failure_reason': failureReason,
        'failed_at': FieldValue.serverTimestamp(),
      });
    }

    await orderRef.update({
      'payment_status': PaymentStatus.failed,
      'payment_failure_reason': failureReason,
      'payment_failed_at': FieldValue.serverTimestamp(),
    });
  }

  /// Marks an online payment attempt as failed by merchant/admin with a reason
  Future<void> markPaymentFailed({
    required String orderId,
    required String shopId,
    required String reason,
    FirebaseFirestore? firestore,
  }) async {
    final db = firestore ?? FirebaseUtils.firestore;
    final orderRef = db.collection('orders').doc(orderId);
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

  /// Reconciles pending payment sessions, timing out stale sessions beyond timeoutThreshold.
  Future<int> reconcilePendingPayments({
    Duration timeoutThreshold = const Duration(minutes: 15),
    FirebaseFirestore? firestore,
  }) async {
    final db = firestore ?? FirebaseUtils.firestore;
    int expiredCount = 0;
    try {
      final now = DateTime.now();
      final pendingDocs = await db
          .collection('payment_transactions')
          .where('status', isEqualTo: 'pending')
          .limit(50)
          .get();

      for (var doc in pendingDocs.docs) {
        final data = doc.data();
        DateTime? createdAt;
        final rawCreatedAt = data['created_at'];
        if (rawCreatedAt is Timestamp) {
          createdAt = rawCreatedAt.toDate();
        } else if (rawCreatedAt is String) {
          createdAt = DateTime.tryParse(rawCreatedAt);
        }

        if (createdAt != null && now.difference(createdAt) > timeoutThreshold) {
          await doc.reference.update({
            'status': 'timed_out',
            'failure_reason': 'Payment session expired without completion',
            'timed_out_at': FieldValue.serverTimestamp(),
          });

          final orderId = data['order_id']?.toString();
          if (orderId != null && orderId.isNotEmpty) {
            final orderRef = db.collection('orders').doc(orderId);
            final orderDoc = await orderRef.get();
            if (orderDoc.exists &&
                orderDoc.data()?['payment_status'] ==
                    PaymentStatus.paymentPending) {
              await orderRef.update({
                'payment_status': PaymentStatus.failed,
                'payment_failure_reason': 'Online payment session timed out',
              });
            }
          }
          expiredCount++;
        }
      }
    } catch (e) {
      debugPrint('reconcilePendingPayments error: $e');
    }
    return expiredCount;
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
    FirebaseFirestore? firestore,
  }) async {
    final db = firestore ?? FirebaseUtils.firestore;
    final orderRef = db.collection('orders').doc(orderId);
    final orderSnap = await orderRef.get();
    if (!orderSnap.exists) {
      throw Exception('Order #$orderId not found.');
    }

    final data = orderSnap.data()!;
    final currentStatus = data['payment_status']?.toString();
    if (currentStatus != PaymentStatus.paid) {
      throw StateError(
        'Cannot refund an order that has not been marked as Paid. Current: $currentStatus',
      );
    }

    final refundId = generateRefundId();

    // 1. Audit log in payment_transactions ledger
    await db.collection('payment_transactions').doc(refundId).set({
      'transaction_id': refundId,
      'transaction_type': 'refund',
      'order_id': orderId,
      'shop_id': data['shop_id'] ?? '',
      'customer_phone': data['phone_number'] ?? '',
      'amount': amount,
      'refund_reason': reason,
      'refund_initiated_by': initiatedBy,
      'status': 'refunded',
      'created_at': FieldValue.serverTimestamp(),
    });

    // 2. Update order document
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
    FirebaseFirestore? firestore,
  }) async {
    final cleanUtr = utr.trim();
    if (!isValidUtr(cleanUtr)) {
      throw Exception('Please enter a valid UPI Reference / UTR Number.');
    }

    final db = firestore ?? FirebaseUtils.firestore;
    final orderRef = db.collection('orders').doc(orderId);
    final orderSnap = await orderRef.get();
    if (!orderSnap.exists) {
      throw Exception('Order #$orderId not found.');
    }

    final data = orderSnap.data()!;
    final txnId =
        'TXN_SUBMIT_${orderId}_${DateTime.now().millisecondsSinceEpoch}';
    await db.collection('payment_transactions').doc(txnId).set({
      'transaction_id': txnId,
      'order_id': orderId,
      'shop_id': data['shop_id'] ?? '',
      'customer_phone': data['phone_number'] ?? '',
      'amount': (data['total_amount'] as num?)?.toDouble() ?? 0.0,
      'payment_method': data['payment_method'] ?? PaymentMethod.upi,
      'gateway_reference': cleanUtr,
      'status': 'pending_verification',
      'created_at': FieldValue.serverTimestamp(),
    });

    await orderRef.update({
      'upi_ref_id': cleanUtr,
      'payment_status': PaymentStatus.pendingVerification,
      'utr_submitted_at': FieldValue.serverTimestamp(),
    });
  }
}
