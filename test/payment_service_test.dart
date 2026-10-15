import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:near_kirana/payment_service.dart';
import 'package:near_kirana/firebase_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Online Payments & Reconciliation (Feature 42)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late PaymentService paymentService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      FirebaseUtils.setFirestore(fakeFirestore);
      paymentService = PaymentService();
    });

    test(
      '1. generateUpiPaymentUrl creates standard NPCI URI with order tracking',
      () {
        final url = paymentService.generateUpiPaymentUrl(
          upiId: 'merchant@upi',
          payeeName: 'Sharma General Store',
          amount: 350.50,
          orderId: 'ORD_99182',
          note: 'Order Payment',
        );

        expect(url.startsWith('upi://pay?'), isTrue);
        expect(url.contains('pa=merchant@upi'), isTrue);
        expect(url.contains('am=350.50'), isTrue);
        expect(url.contains('cu=INR'), isTrue);
        expect(url.contains('tr=ORD_99182'), isTrue);
        expect(url.contains('pn=Sharma%20General%20Store'), isTrue);
      },
    );

    test(
      '2. isValidUtr & isValidSignature validate bank UTRs and gateway signatures',
      () {
        // Valid UTRs
        expect(
          paymentService.isValidUtr('423948291039'),
          isTrue,
        ); // 12-digit standard UTR
        expect(
          paymentService.isValidUtr('pay_N83ndKs9102'),
          isTrue,
        ); // Gateway payment ID
        expect(paymentService.isValidUtr('UTR-99182-ABCD'), isTrue);

        // Invalid UTRs
        expect(paymentService.isValidUtr(null), isFalse);
        expect(paymentService.isValidUtr(''), isFalse);
        expect(
          paymentService.isValidUtr('123'),
          isFalse,
        ); // Too short (< 8 chars)
        expect(
          paymentService.isValidUtr('a' * 50),
          isFalse,
        ); // Too long (> 35 chars)
        expect(paymentService.isValidUtr('invalid UTR with space'), isFalse);
        expect(paymentService.isValidUtr('utr@#\$%^&*'), isFalse);

        // Valid Signatures
        expect(
          paymentService.isValidSignature('sig_a1b2c3d4e5f6g7h8i9j0'),
          isTrue,
        );
        expect(
          paymentService.isValidSignature(
            '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08',
          ),
          isTrue,
        );

        // Invalid Signatures
        expect(paymentService.isValidSignature(null), isFalse);
        expect(paymentService.isValidSignature(''), isFalse);
        expect(paymentService.isValidSignature('short'), isFalse);
        expect(
          paymentService.isValidSignature('sig with space inside'),
          isFalse,
        );
      },
    );

    test('3. PaymentSession model serializes and deserializes correctly', () {
      final now = DateTime.now();
      final expires = now.add(const Duration(minutes: 15));
      final session = PaymentSession(
        sessionId: 'SESS_123',
        transactionId: 'TXN_456',
        orderId: 'ORD_789',
        shopId: 'SHOP_001',
        amount: 520.0,
        paymentMethod: PaymentMethod.card,
        customerPhone: '9876543210',
        customerName: 'Rahul Verma',
        createdAt: now,
        expiresAt: expires,
        gatewayOrderId: 'GW_ORD_789',
        paymentToken: 'TOKEN_XYZ',
      );

      final map = session.toMap();
      expect(map['session_id'], 'SESS_123');
      expect(map['transaction_id'], 'TXN_456');
      expect(map['amount'], 520.0);
      expect(map['payment_method'], PaymentMethod.card);

      final reconstituted = PaymentSession.fromMap(map);
      expect(reconstituted.sessionId, 'SESS_123');
      expect(reconstituted.transactionId, 'TXN_456');
      expect(reconstituted.amount, 520.0);
      expect(reconstituted.paymentMethod, PaymentMethod.card);
      expect(reconstituted.customerName, 'Rahul Verma');
    });

    test(
      '4. initiateOnlinePayment creates checkout session and enqueues ledger transaction',
      () async {
        final orderRef = fakeFirestore
            .collection('orders')
            .doc('ORD_GATEWAY_1');
        await orderRef.set({
          'shop_id': 'SHOP_101',
          'customer_name': 'Meera Sen',
          'phone_number': '9876500001',
          'total_amount': 420.0,
          'payment_method': PaymentMethod.upi,
          'payment_status': PaymentStatus.unpaid,
          'status': 'Pending',
        });

        final session = await paymentService.initiateOnlinePayment(
          orderId: 'ORD_GATEWAY_1',
          shopId: 'SHOP_101',
          amount: 420.0,
          customerPhone: '9876500001',
          customerName: 'Meera Sen',
          paymentMethod: PaymentMethod.upi,
          upiId: 'sharma_kirana@okaxis',
          payeeName: 'Sharma Kirana',
          firestore: fakeFirestore,
        );

        expect(session.orderId, 'ORD_GATEWAY_1');
        expect(session.status, 'pending');
        expect(session.amount, 420.0);
        expect(session.upiDeepLink, contains('pa=sharma_kirana@okaxis'));

        // Check payment_transactions collection
        final txnDoc = await fakeFirestore
            .collection('payment_transactions')
            .doc(session.transactionId)
            .get();
        expect(txnDoc.exists, isTrue);
        expect(txnDoc.data()!['status'], 'pending');
        expect(txnDoc.data()!['amount'], 420.0);

        // Check order document was transitioned to payment_pending
        final updatedOrder = await orderRef.get();
        expect(
          updatedOrder.data()!['payment_status'],
          PaymentStatus.paymentPending,
        );
        expect(
          updatedOrder.data()!['active_transaction_id'],
          session.transactionId,
        );
      },
    );

    test(
      '5. Example Scenario: Customer pays with UPI/Gateway, trusted verification marks Paid',
      () async {
        final orderRef = fakeFirestore
            .collection('orders')
            .doc('ORD_UPI_GATEWAY');
        await orderRef.set({
          'shop_id': 'SHOP_101',
          'customer_name': 'Aman Gupta',
          'phone_number': '9876543210',
          'total_amount': 750.0,
          'payment_method': PaymentMethod.upi,
          'payment_status': PaymentStatus.paymentPending,
          'status': 'Pending',
        });

        // Initiate session
        final session = await paymentService.initiateOnlinePayment(
          orderId: 'ORD_UPI_GATEWAY',
          shopId: 'SHOP_101',
          amount: 750.0,
          customerPhone: '9876543210',
          firestore: fakeFirestore,
        );

        // Gateway webhook callback or trusted backend verifies signature
        const gatewayRef = 'pay_20261013998811';
        const signature = 'sig_hmac256_verified_token_9918234857';

        final verification = await paymentService.verifyOnlinePayment(
          orderId: 'ORD_UPI_GATEWAY',
          transactionId: session.transactionId,
          gatewayReference: gatewayRef,
          gatewaySignature: signature,
          verifiedBy: 'Razorpay Webhook Callback',
          firestore: fakeFirestore,
        );

        expect(verification.success, isTrue);
        expect(verification.status, PaymentStatus.paid);
        expect(verification.gatewayRef, gatewayRef);

        // Order must now be Paid
        final updatedOrder = await orderRef.get();
        expect(updatedOrder.data()!['payment_status'], PaymentStatus.paid);
        expect(updatedOrder.data()!['upi_ref_id'], gatewayRef);
        expect(
          updatedOrder.data()!['verified_by'],
          'Razorpay Webhook Callback',
        );

        // Transaction ledger record must be completed
        final txnDoc = await fakeFirestore
            .collection('payment_transactions')
            .doc(session.transactionId)
            .get();
        expect(txnDoc.data()!['status'], 'completed');

        // Verification is idempotent: re-calling verifyOnlinePayment succeeds without error
        final secondVerify = await paymentService.verifyOnlinePayment(
          orderId: 'ORD_UPI_GATEWAY',
          transactionId: session.transactionId,
          gatewayReference: gatewayRef,
          gatewaySignature: signature,
          firestore: fakeFirestore,
        );
        expect(secondVerify.success, isTrue);
        expect(secondVerify.status, PaymentStatus.paid);
      },
    );

    test(
      '6. Gateway payment failure workflow records failure reason and allows retry',
      () async {
        final orderRef = fakeFirestore
            .collection('orders')
            .doc('ORD_FAIL_TEST');
        await orderRef.set({
          'shop_id': 'SHOP_101',
          'customer_name': 'Ramesh Kumar',
          'phone_number': '9876543210',
          'total_amount': 300.0,
          'payment_method': PaymentMethod.card,
          'payment_status': PaymentStatus.paymentPending,
          'status': 'Pending',
        });

        final session = await paymentService.initiateOnlinePayment(
          orderId: 'ORD_FAIL_TEST',
          shopId: 'SHOP_101',
          amount: 300.0,
          customerPhone: '9876543210',
          paymentMethod: PaymentMethod.card,
          firestore: fakeFirestore,
        );

        await paymentService.handlePaymentFailure(
          orderId: 'ORD_FAIL_TEST',
          transactionId: session.transactionId,
          failureReason: 'Card issuer declined transaction: Insufficient funds',
          firestore: fakeFirestore,
        );

        final updatedOrder = await orderRef.get();
        expect(updatedOrder.data()!['payment_status'], PaymentStatus.failed);
        expect(
          updatedOrder.data()!['payment_failure_reason'],
          'Card issuer declined transaction: Insufficient funds',
        );

        final txnDoc = await fakeFirestore
            .collection('payment_transactions')
            .doc(session.transactionId)
            .get();
        expect(txnDoc.data()!['status'], 'failed');
      },
    );

    test(
      '7. Pending transaction reconciliation times out stale sessions',
      () async {
        final staleDate = DateTime.now().subtract(const Duration(minutes: 30));

        // Seed order with stale payment session
        await fakeFirestore.collection('orders').doc('ORD_STALE_1').set({
          'shop_id': 'SHOP_101',
          'payment_status': PaymentStatus.paymentPending,
        });

        await fakeFirestore
            .collection('payment_transactions')
            .doc('TXN_STALE_1')
            .set({
              'order_id': 'ORD_STALE_1',
              'status': 'pending',
              'amount': 250.0,
              'created_at': staleDate.toIso8601String(),
            });

        // Seed recent active session (5 minutes old)
        final recentDate = DateTime.now().subtract(const Duration(minutes: 5));
        await fakeFirestore
            .collection('payment_transactions')
            .doc('TXN_RECENT_2')
            .set({
              'order_id': 'ORD_RECENT_2',
              'status': 'pending',
              'amount': 150.0,
              'created_at': recentDate.toIso8601String(),
            });

        final expiredCount = await paymentService.reconcilePendingPayments(
          timeoutThreshold: const Duration(minutes: 15),
          firestore: fakeFirestore,
        );

        expect(expiredCount, 1);

        // Stale transaction should be timed_out
        final staleTxn = await fakeFirestore
            .collection('payment_transactions')
            .doc('TXN_STALE_1')
            .get();
        expect(staleTxn.data()!['status'], 'timed_out');

        // Stale order should be marked failed
        final staleOrder = await fakeFirestore
            .collection('orders')
            .doc('ORD_STALE_1')
            .get();
        expect(staleOrder.data()!['payment_status'], PaymentStatus.failed);

        // Recent transaction should remain pending
        final recentTxn = await fakeFirestore
            .collection('payment_transactions')
            .doc('TXN_RECENT_2')
            .get();
        expect(recentTxn.data()!['status'], 'pending');
      },
    );

    test(
      '8. Cancellation of Paid order initiates verified Refund with audit trail',
      () async {
        final orderRef = fakeFirestore
            .collection('orders')
            .doc('ORDER_REFUND_1');
        await orderRef.set({
          'shop_id': 'SHOP_101',
          'customer_name': 'Priya Singh',
          'phone_number': '9876543210',
          'total_amount': 650.0,
          'payment_method': PaymentMethod.upi,
          'payment_status': PaymentStatus.paid,
          'status': 'Pending',
        });

        final refundId = await paymentService.processRefund(
          orderId: 'ORDER_REFUND_1',
          amount: 650.0,
          reason: 'Customer cancelled order before packing',
          initiatedBy: 'customer',
          firestore: fakeFirestore,
        );

        expect(refundId.startsWith('REF_'), isTrue);

        final doc = await orderRef.get();
        expect(doc.data()!['payment_status'], equals(PaymentStatus.refunded));
        expect(doc.data()!['refund_id'], equals(refundId));
        expect(doc.data()!['refund_amount'], equals(650.0));
        expect(doc.data()!['refund_initiated_by'], equals('customer'));

        // Check payment_transactions refund ledger
        final refundTxn = await fakeFirestore
            .collection('payment_transactions')
            .doc(refundId)
            .get();
        expect(refundTxn.exists, isTrue);
        expect(refundTxn.data()!['transaction_type'], 'refund');
        expect(refundTxn.data()!['status'], 'refunded');

        // Refuse refund if order was not paid
        await orderRef.update({'payment_status': PaymentStatus.unpaid});
        expect(
          () => paymentService.processRefund(
            orderId: 'ORDER_REFUND_1',
            amount: 650.0,
            reason: 'Attempt invalid refund',
            initiatedBy: 'customer',
            firestore: fakeFirestore,
          ),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      '9. Customer order manual UTR submission & Shopkeeper verification',
      () async {
        final orderRef = fakeFirestore
            .collection('orders')
            .doc('ORDER_UPI_MANUAL');
        await orderRef.set({
          'shop_id': 'SHOP_101',
          'customer_name': 'Aman Gupta',
          'phone_number': '9876543210',
          'total_amount': 450.0,
          'payment_method': 'UPI',
          'payment_status': PaymentStatus.paymentPending,
          'status': 'Pending',
        });

        // 1. Customer submits UTR
        await paymentService.submitCustomerUtr(
          orderId: 'ORDER_UPI_MANUAL',
          utr: '423948291039',
          firestore: fakeFirestore,
        );

        var doc = await orderRef.get();
        expect(
          doc.data()!['payment_status'],
          equals(PaymentStatus.pendingVerification),
        );
        expect(doc.data()!['upi_ref_id'], equals('423948291039'));

        // 2. Reject verification if unauthorized shopkeeper attempts it
        expect(
          () async => await paymentService.verifyAndMarkPaid(
            orderId: 'ORDER_UPI_MANUAL',
            shopId: 'DIFFERENT_SHOP_999',
            utrRef: '423948291039',
            firestore: fakeFirestore,
          ),
          throwsA(isA<Exception>()),
        );

        // 3. Authorized shopkeeper verifies UTR and marks as Paid
        final verified = await paymentService.verifyAndMarkPaid(
          orderId: 'ORDER_UPI_MANUAL',
          shopId: 'SHOP_101',
          utrRef: '423948291039',
          verifiedBy: 'Shopkeeper Ramesh',
          firestore: fakeFirestore,
        );

        expect(verified, isTrue);
        doc = await orderRef.get();
        expect(doc.data()!['payment_status'], equals(PaymentStatus.paid));
        expect(doc.data()!['verified_by'], equals('Shopkeeper Ramesh'));
      },
    );

    test(
      '10. Firestore rules enforce payment verification and protect ledger',
      () {
        final rules = File('firestore.rules').readAsStringSync();

        // Enforce order create rule prevents customer setting 'Paid'
        expect(
          rules.contains(
            "(!('payment_status' in request.resource.data) || request.resource.data.payment_status in ['Unpaid', 'Payment_Pending', 'Pending_Verification'])",
          ),
          isTrue,
        );

        // Enforce order update rule prevents customer setting 'Paid'
        expect(
          rules.contains("request.resource.data.payment_status != 'Paid'"),
          isTrue,
        );

        // Enforce payment_transactions collection exists with RBAC rules
        expect(rules.contains("match /payment_transactions/{txnId}"), isTrue);
      },
    );

    test(
      '11. verifyAndConfirmGatewayPayment updates order to paid and writes ledger audit record',
      () async {
        final orderRef = fakeFirestore.collection('orders').doc('ORDER_GATEWAY_101');
        await orderRef.set({
          'shop_id': 'SHOP_101',
          'total_amount': 299.0,
          'payment_method': PaymentMethod.upi,
          'payment_status': PaymentStatus.paymentPending,
          'created_at': DateTime.now().toIso8601String(),
        });

        final result = await paymentService.verifyAndConfirmGatewayPayment(
          orderId: 'ORDER_GATEWAY_101',
          transactionId: 'TXN_GATEWAY_101',
          gatewayPaymentRef: 'pay_N99281734891',
          gatewaySignature: 'sig_valid_hash_9918237',
          verifiedBy: 'Razorpay Gateway',
          firestore: fakeFirestore,
        );

        expect(result.success, isTrue);

        final orderDoc = await orderRef.get();
        expect(orderDoc.data()!['payment_status'], equals(PaymentStatus.paid));
        expect(orderDoc.data()!['upi_ref_id'], equals('pay_N99281734891'));
        expect(orderDoc.data()!['verified_by'], equals('Razorpay Gateway'));

        final txSnapshot = await fakeFirestore
            .collection('payment_transactions')
            .where('order_id', isEqualTo: 'ORDER_GATEWAY_101')
            .get();
        expect(txSnapshot.docs.length, equals(1));
        final txData = txSnapshot.docs.first.data();
        expect(txData['status'], equals('completed'));
        expect(txData['gateway_reference'], equals('pay_N99281734891'));
      },
    );
  });
}
