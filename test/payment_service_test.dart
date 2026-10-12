import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:near_kirana/payment_service.dart';
import 'package:near_kirana/firebase_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PaymentService Unit & Integration Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late PaymentService paymentService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      FirebaseUtils.setFirestore(fakeFirestore);
      paymentService = PaymentService();
    });

    test('generateUpiPaymentUrl creates standard NPCI URI with order tracking', () {
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
    });

    test('isValidUtr correctly validates UTR and gateway references', () {
      // Valid UTRs
      expect(paymentService.isValidUtr('423948291039'), isTrue); // 12-digit standard UTR
      expect(paymentService.isValidUtr('pay_N83ndKs9102'), isTrue); // Gateway payment ID
      expect(paymentService.isValidUtr('UTR-99182-ABCD'), isTrue);

      // Invalid UTRs
      expect(paymentService.isValidUtr(null), isFalse);
      expect(paymentService.isValidUtr(''), isFalse);
      expect(paymentService.isValidUtr('123'), isFalse); // Too short (< 8 chars)
      expect(paymentService.isValidUtr('a' * 50), isFalse); // Too long (> 35 chars)
      expect(paymentService.isValidUtr('invalid UTR with space'), isFalse);
      expect(paymentService.isValidUtr('utr@#\$%^&*'), isFalse);
    });

    test('Customer order lifecycle: Pending_Verification -> Merchant Verified Paid', () async {
      final orderRef = fakeFirestore.collection('orders').doc('ORDER_UPI_1');
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
        orderId: 'ORDER_UPI_1',
        utr: '423948291039',
      );

      var doc = await orderRef.get();
      expect(doc.data()!['payment_status'], equals(PaymentStatus.pendingVerification));
      expect(doc.data()!['upi_ref_id'], equals('423948291039'));

      // 2. Reject verification if unauthorized shopkeeper attempts it
      expect(
        () async => await paymentService.verifyAndMarkPaid(
          orderId: 'ORDER_UPI_1',
          shopId: 'DIFFERENT_SHOP_999',
          utrRef: '423948291039',
        ),
        throwsA(isA<Exception>()),
      );

      // 3. Authorized shopkeeper verifies UTR and marks as Paid
      final verified = await paymentService.verifyAndMarkPaid(
        orderId: 'ORDER_UPI_1',
        shopId: 'SHOP_101',
        utrRef: '423948291039',
        verifiedBy: 'Shopkeeper Ramesh',
      );

      expect(verified, isTrue);
      doc = await orderRef.get();
      expect(doc.data()!['payment_status'], equals(PaymentStatus.paid));
      expect(doc.data()!['verified_by'], equals('Shopkeeper Ramesh'));
    });

    test('Merchant marks invalid UTR as Failed with audit reason', () async {
      final orderRef = fakeFirestore.collection('orders').doc('ORDER_UPI_FAKE');
      await orderRef.set({
        'shop_id': 'SHOP_101',
        'customer_name': 'Fake User',
        'phone_number': '9876543210',
        'total_amount': 200.0,
        'payment_method': 'UPI',
        'payment_status': PaymentStatus.pendingVerification,
        'upi_ref_id': '000000000000',
        'status': 'Pending',
      });

      await paymentService.markPaymentFailed(
        orderId: 'ORDER_UPI_FAKE',
        shopId: 'SHOP_101',
        reason: 'Payment not received in merchant bank account',
      );

      final doc = await orderRef.get();
      expect(doc.data()!['payment_status'], equals(PaymentStatus.failed));
      expect(
        doc.data()!['payment_failure_reason'],
        equals('Payment not received in merchant bank account'),
      );
    });

    test('Cancellation of Paid order initiates verified Refund with audit trail', () async {
      final orderRef = fakeFirestore.collection('orders').doc('ORDER_REFUND_1');
      await orderRef.set({
        'shop_id': 'SHOP_101',
        'customer_name': 'Priya Singh',
        'phone_number': '9876543210',
        'total_amount': 650.0,
        'payment_method': 'UPI',
        'payment_status': PaymentStatus.paid,
        'status': 'Pending',
      });

      final refundId = await paymentService.processRefund(
        orderId: 'ORDER_REFUND_1',
        amount: 650.0,
        reason: 'Customer cancelled order before packing',
        initiatedBy: 'customer',
      );

      expect(refundId.startsWith('REF_'), isTrue);

      final doc = await orderRef.get();
      expect(doc.data()!['payment_status'], equals(PaymentStatus.refunded));
      expect(doc.data()!['refund_id'], equals(refundId));
      expect(doc.data()!['refund_amount'], equals(650.0));
      expect(doc.data()!['refund_initiated_by'], equals('customer'));
    });

    test('Firestore rules enforce payment verification and prevent self-marking Paid', () {
      final rules = File('firestore.rules').readAsStringSync();

      // Enforce order create rule prevents customer setting 'Paid'
      expect(
        rules.contains("(!('payment_status' in request.resource.data) || request.resource.data.payment_status in ['Unpaid', 'Payment_Pending', 'Pending_Verification'])"),
        isTrue,
      );

      // Enforce order update rule prevents customer setting 'Paid'
      expect(
        rules.contains("request.resource.data.payment_status != 'Paid'"),
        isTrue,
      );

      // Enforce customer can submit UTR only transitioning to Pending_Verification or Payment_Pending
      expect(
        rules.contains("request.resource.data.payment_status in ['Pending_Verification', 'Payment_Pending']"),
        isTrue,
      );
    });
  });
}
