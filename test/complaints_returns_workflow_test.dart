import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:near_kirana/complaint_model.dart';
import 'package:near_kirana/complaint_service.dart';
import 'package:near_kirana/widgets/raise_complaint_dialog.dart';
import 'package:near_kirana/widgets/complaint_status_card.dart';
import 'package:near_kirana/widgets/order_complaint_section.dart';
import 'package:near_kirana/admin_complaints_screen.dart';
import 'package:near_kirana/shop_provider.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'firebase_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feature 51: Domain Models - ComplaintModel & ComplaintItem', () {
    test('Enum conversion and fallback tests', () {
      expect(ComplaintType.fromString('damaged'), ComplaintType.damaged);
      expect(ComplaintType.fromString('missing_item'), ComplaintType.missingItem);
      expect(ComplaintType.fromString('wrong_item'), ComplaintType.wrongItem);
      expect(ComplaintType.fromString('expired_quality'), ComplaintType.expiredOrQuality);
      expect(ComplaintType.fromString('billing_issue'), ComplaintType.billingIssue);
      expect(ComplaintType.fromString('unknown_val'), ComplaintType.other);

      expect(ComplaintStatus.fromString('pending'), ComplaintStatus.pending);
      expect(ComplaintStatus.fromString('in_review'), ComplaintStatus.inReview);
      expect(ComplaintStatus.fromString('resolved_refund'), ComplaintStatus.resolvedRefund);
      expect(ComplaintStatus.fromString('resolved_replacement'), ComplaintStatus.resolvedReplacement);
      expect(ComplaintStatus.fromString('rejected'), ComplaintStatus.rejected);
      expect(ComplaintStatus.fromString('cancelled'), ComplaintStatus.cancelled);
      expect(ComplaintStatus.fromString('unknown'), ComplaintStatus.pending);

      expect(ResolutionType.fromString('refund'), ResolutionType.refund);
      expect(ResolutionType.fromString('replacement'), ResolutionType.replacement);
      expect(ResolutionType.fromString('no_action'), ResolutionType.noAction);
      expect(ResolutionType.fromString('invalid'), ResolutionType.noAction);

      expect(RefundMethod.fromString('khata_credit'), RefundMethod.khataCredit);
      expect(RefundMethod.fromString('cash'), RefundMethod.cash);
      expect(RefundMethod.fromString('upi'), RefundMethod.upi);
      expect(RefundMethod.fromString(null), isNull);
    });

    test('ComplaintItem calculations and serialization', () {
      const item = ComplaintItem(
        itemId: 'prod_1',
        name: 'Amul Taaza Milk 500ml',
        quantityOrdered: 5,
        quantityAffected: 2,
        pricePerUnit: 30.0,
        notes: 'Leaking pack',
      );

      expect(item.totalAffectedValue, 60.0);

      final map = item.toMap();
      expect(map['item_id'], 'prod_1');
      expect(map['name'], 'Amul Taaza Milk 500ml');
      expect(map['quantity_ordered'], 5);
      expect(map['quantity_affected'], 2);
      expect(map['price_per_unit'], 30.0);
      expect(map['notes'], 'Leaking pack');

      final fromMap = ComplaintItem.fromMap(map);
      expect(fromMap.itemId, item.itemId);
      expect(fromMap.name, item.name);
      expect(fromMap.quantityOrdered, item.quantityOrdered);
      expect(fromMap.quantityAffected, item.quantityAffected);
      expect(fromMap.pricePerUnit, item.pricePerUnit);
      expect(fromMap.totalAffectedValue, 60.0);
    });

    test('ComplaintModel estimatedClaimAmount, copyWith and serialization', () {
      final now = DateTime(2026, 10, 13, 10, 0);
      final model = ComplaintModel(
        id: 'CMP-1001',
        orderId: 'ORD-999',
        shopId: 'SHOP_1',
        customerPhone: '9876543210',
        customerName: 'Rahul Sharma',
        type: ComplaintType.missingItem,
        status: ComplaintStatus.pending,
        description: 'Received 4 packets instead of 5',
        affectedItems: const [
          ComplaintItem(
            itemId: 'item_1',
            name: 'Biscuits',
            quantityOrdered: 5,
            quantityAffected: 1,
            pricePerUnit: 25.0,
          ),
          ComplaintItem(
            itemId: 'item_2',
            name: 'Butter',
            quantityOrdered: 2,
            quantityAffected: 1,
            pricePerUnit: 55.0,
          ),
        ],
        requestedResolution: ResolutionType.refund,
        createdAt: now,
        updatedAt: now,
      );

      expect(model.estimatedClaimAmount, 80.0); // 1*25 + 1*55
      expect(model.isPending, isTrue);
      expect(model.isResolved, isFalse);

      final map = model.toMap();
      expect(map['order_id'], 'ORD-999');
      expect(map['shop_id'], 'SHOP_1');
      expect(map['type'], 'missing_item');
      expect(map['status'], 'pending');

      final reconstructed = ComplaintModel.fromMap('CMP-1001', map);
      expect(reconstructed.id, 'CMP-1001');
      expect(reconstructed.estimatedClaimAmount, 80.0);
      expect(reconstructed.customerName, 'Rahul Sharma');

      final copied = model.copyWith(
        status: ComplaintStatus.resolvedRefund,
        refundAmount: 80.0,
        refundMethod: RefundMethod.khataCredit,
      );
      expect(copied.status, ComplaintStatus.resolvedRefund);
      expect(copied.isResolved, isTrue);
      expect(copied.refundAmount, 80.0);
      expect(copied.refundMethod, RefundMethod.khataCredit);
    });
  });

  group('Feature 51: ComplaintService Backend Operations', () {
    late FakeFirebaseFirestore fakeFirestore;
    late ComplaintService service;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      service = ComplaintService(firestore: fakeFirestore);

      // Seed an order
      await fakeFirestore.collection('orders').doc('ORD-001').set({
        'shop_id': 'SHOP_KIRANA_1',
        'phone_number': '9876543210',
        'customer_name': 'Aarav Patel',
        'status': 'Delivered',
        'total_amount': 250.0,
        'items': [
          {'id': 'p1', 'name': 'Milk 1L', 'quantity': 2, 'price': 60.0},
          {'id': 'p2', 'name': 'Bread', 'quantity': 1, 'price': 40.0},
        ],
      });
    });

    test('createComplaint persists complaint and updates order metadata', () async {
      final complaint = await service.createComplaint(
        orderId: 'ORD-001',
        shopId: 'SHOP_KIRANA_1',
        customerPhone: '9876543210',
        customerName: 'Aarav Patel',
        type: ComplaintType.damaged,
        description: '1 packet was torn and leaking',
        affectedItems: const [
          ComplaintItem(
            itemId: 'p1',
            name: 'Milk 1L',
            quantityOrdered: 2,
            quantityAffected: 1,
            pricePerUnit: 60.0,
          ),
        ],
        requestedResolution: ResolutionType.refund,
      );

      expect(complaint.id.startsWith('CMP-'), isTrue);
      expect(complaint.estimatedClaimAmount, 60.0);

      // Verify Firestore record in complaints collection
      final compDoc = await fakeFirestore.collection('complaints').doc(complaint.id).get();
      expect(compDoc.exists, isTrue);
      expect(compDoc.data()?['type'], 'damaged');
      expect(compDoc.data()?['status'], 'pending');

      // Verify order metadata updated
      final orderDoc = await fakeFirestore.collection('orders').doc('ORD-001').get();
      expect(orderDoc.data()?['has_complaint'], isTrue);
      expect(orderDoc.data()?['complaint_id'], complaint.id);
      expect(orderDoc.data()?['complaint_status'], 'pending');
    });

    test('streamShopComplaints streams complaints filtered by shopId', () async {
      await service.createComplaint(
        orderId: 'ORD-001',
        shopId: 'SHOP_KIRANA_1',
        customerPhone: '9876543210',
        customerName: 'Aarav Patel',
        type: ComplaintType.missingItem,
        description: 'Missing bread',
      );

      await service.createComplaint(
        orderId: 'ORD-OTHER',
        shopId: 'SHOP_OTHER_SHOP',
        customerPhone: '9123456789',
        customerName: 'Other Person',
        type: ComplaintType.damaged,
        description: 'Other shop complaint',
      );

      final list = await service.streamShopComplaints('SHOP_KIRANA_1').firstWhere((l) => l.isNotEmpty);
      expect(list.length, 1);
      expect(list.first.shopId, 'SHOP_KIRANA_1');
      expect(list.first.customerName, 'Aarav Patel');
    });

    test('markInReview updates complaint status to in_review', () async {
      final complaint = await service.createComplaint(
        orderId: 'ORD-001',
        shopId: 'SHOP_KIRANA_1',
        customerPhone: '9876543210',
        customerName: 'Aarav Patel',
        type: ComplaintType.billingIssue,
        description: 'Extra amount charged',
      );

      await service.markInReview(complaint.id, notes: 'Shopkeeper checking with delivery staff');

      final updated = await fakeFirestore.collection('complaints').doc(complaint.id).get();
      expect(updated.data()?['status'], 'in_review');
      expect(updated.data()?['resolution_notes'], 'Shopkeeper checking with delivery staff');
    });

    test('resolveComplaint with Khata credit updates complaint and customer Khata ledger', () async {
      // Seed customer with existing Khata balance (150 owed)
      await fakeFirestore.collection('customers').doc('9876543210').set({
        'name': 'Aarav Patel',
        'mobile': '9876543210',
        'shop_balances': {'SHOP_KIRANA_1': 150.0},
        'shop_ids': ['SHOP_KIRANA_1'],
      });

      final complaint = await service.createComplaint(
        orderId: 'ORD-001',
        shopId: 'SHOP_KIRANA_1',
        customerPhone: '9876543210',
        customerName: 'Aarav Patel',
        type: ComplaintType.damaged,
        description: 'Milk pack damaged',
        affectedItems: const [
          ComplaintItem(
            itemId: 'p1',
            name: 'Milk 1L',
            quantityOrdered: 2,
            quantityAffected: 1,
            pricePerUnit: 60.0,
          ),
        ],
      );

      // Resolve with ₹60 Khata credit
      await service.resolveComplaint(
        complaintId: complaint.id,
        resolutionType: ResolutionType.refund,
        resolutionNotes: 'Refund credited to Khata ledger',
        resolvedBy: 'Shop Owner',
        refundAmount: 60.0,
        refundMethod: RefundMethod.khataCredit,
      );

      // Verify complaint doc
      final compDoc = await fakeFirestore.collection('complaints').doc(complaint.id).get();
      expect(compDoc.data()?['status'], 'resolved_refund');
      expect(compDoc.data()?['refund_amount'], 60.0);
      expect(compDoc.data()?['refund_method'], 'khata_credit');

      // Verify order doc
      final orderDoc = await fakeFirestore.collection('orders').doc('ORD-001').get();
      expect(orderDoc.data()?['complaint_status'], 'resolved_refund');
      expect(orderDoc.data()?['complaint_refund_amount'], 60.0);

      // Verify Khata balance decremented (150 - 60 = 90)
      final custDoc = await fakeFirestore.collection('customers').doc('9876543210').get();
      expect(custDoc.data()?['shop_balances']['SHOP_KIRANA_1'], 90.0);

      // Verify Khata transaction credit entry recorded
      final txs = await fakeFirestore
          .collection('customers')
          .doc('9876543210')
          .collection('khata_transactions')
          .get();
      expect(txs.docs.isNotEmpty, isTrue);
      final tx = txs.docs.first.data();
      expect(tx['amount'], 60.0);
      expect(tx['type'], 'credit');
      expect(tx['complaint_id'], complaint.id);
    });

    test('resolveComplaint with Replacement and with Reject', () async {
      final complaint1 = await service.createComplaint(
        orderId: 'ORD-001',
        shopId: 'SHOP_KIRANA_1',
        customerPhone: '9876543210',
        customerName: 'Aarav Patel',
        type: ComplaintType.wrongItem,
        description: 'Wrong bread brand',
      );

      // Replacement
      await service.resolveComplaint(
        complaintId: complaint1.id,
        resolutionType: ResolutionType.replacement,
        resolutionNotes: 'Replacement sent with morning delivery',
        replacementDetails: '1x Harvest Gold Brown Bread',
      );

      var compDoc = await fakeFirestore.collection('complaints').doc(complaint1.id).get();
      expect(compDoc.data()?['status'], 'resolved_replacement');
      expect(compDoc.data()?['replacement_details'], '1x Harvest Gold Brown Bread');

      // Reject
      final complaint2 = await service.createComplaint(
        orderId: 'ORD-001',
        shopId: 'SHOP_KIRANA_1',
        customerPhone: '9876543210',
        customerName: 'Aarav Patel',
        type: ComplaintType.other,
        description: 'Changed mind after consuming',
      );

      await service.resolveComplaint(
        complaintId: complaint2.id,
        resolutionType: ResolutionType.noAction,
        resolutionNotes: 'Cannot return consumed perishable product',
      );

      compDoc = await fakeFirestore.collection('complaints').doc(complaint2.id).get();
      expect(compDoc.data()?['status'], 'rejected');
      expect(compDoc.data()?['resolution_notes'], 'Cannot return consumed perishable product');
    });

    test('cancelComplaint allows customer to cancel pending complaint', () async {
      final complaint = await service.createComplaint(
        orderId: 'ORD-001',
        shopId: 'SHOP_KIRANA_1',
        customerPhone: '9876543210',
        customerName: 'Aarav Patel',
        type: ComplaintType.damaged,
        description: 'Accidental report',
      );

      await service.cancelComplaint(complaint.id, 'ORD-001');

      final compDoc = await fakeFirestore.collection('complaints').doc(complaint.id).get();
      expect(compDoc.data()?['status'], 'cancelled');

      final orderDoc = await fakeFirestore.collection('orders').doc('ORD-001').get();
      expect(orderDoc.data()?['complaint_status'], 'cancelled');
    });
  });

  group('Feature 51: Customer UI Widget Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late ComplaintService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = ComplaintService(firestore: fakeFirestore);
    });

    testWidgets('RaiseComplaintDialog renders items, validates description, and submits', (tester) async {
      await fakeFirestore.collection('orders').doc('ORD-WIDGET-1').set({
        'shop_id': 'SHOP_TEST',
        'status': 'Delivered',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RaiseComplaintDialog(
              orderId: 'ORD-WIDGET-1',
              shopId: 'SHOP_TEST',
              customerPhone: '9876543210',
              customerName: 'Kavita',
              orderItems: const [
                {'id': 'item1', 'name': 'Fortune Sunflower Oil 1L', 'quantity': 2, 'price': 140.0},
                {'id': 'item2', 'name': 'Tata Salt 1kg', 'quantity': 1, 'price': 28.0},
              ],
              complaintService: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header and options check
      expect(find.text('Report Issue / Return Item'), findsOneWidget);
      expect(find.text('Fortune Sunflower Oil 1L'), findsOneWidget);
      expect(find.text('Tata Salt 1kg'), findsOneWidget);
      expect(find.text('Damaged Item'), findsOneWidget);
      expect(find.text('Missing Item'), findsOneWidget);

      // Attempt to submit without description should show snackbar
      await tester.tap(find.text('Submit Complaint'));
      await tester.pumpAndSettle();
      expect(find.text('Please describe the issue with your product'), findsOneWidget);

      // Enter description
      await tester.enterText(
        find.byType(TextField).first,
        'Oil packet was torn and spilled in carry bag',
      );
      await tester.pumpAndSettle();

      // Submit complaint
      await tester.tap(find.text('Submit Complaint'));
      await tester.pumpAndSettle();

      // Verify Firestore has the new complaint
      final snapshot = await fakeFirestore.collection('complaints').get();
      expect(snapshot.docs.length, 1);
      final data = snapshot.docs.first.data();
      expect(data['order_id'], 'ORD-WIDGET-1');
      expect(data['description'], 'Oil packet was torn and spilled in carry bag');
    });

    testWidgets('ComplaintStatusCard renders status badge and opens details modal', (tester) async {
      final now = DateTime.now();
      final complaint = ComplaintModel(
        id: 'CMP-8877',
        orderId: 'ORD-WIDGET-2',
        shopId: 'SHOP_TEST',
        customerPhone: '9876543210',
        customerName: 'Kavita',
        type: ComplaintType.damaged,
        status: ComplaintStatus.pending,
        description: 'Packet was broken',
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComplaintStatusCard(
              complaint: complaint,
              complaintService: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Complaint CMP-8877: Pending Review'), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);

      // Tap details
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();

      expect(find.text('Complaint Details (CMP-8877)'), findsOneWidget);
      expect(find.text('Packet was broken'), findsOneWidget);
      expect(find.text('Cancel This Complaint'), findsOneWidget);
    });

    testWidgets('OrderComplaintSection renders report button for delivered order and handles click', (tester) async {
      await fakeFirestore.collection('orders').doc('ORD-DELIVERED').set({
        'shop_id': 'SHOP_TEST',
        'status': 'Delivered',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrderComplaintSection(
              orderId: 'ORD-DELIVERED',
              shopId: 'SHOP_TEST',
              customerPhone: '9876543210',
              customerName: 'Customer Test',
              orderItems: const [
                {'id': 'p1', 'name': 'Milk', 'quantity': 1, 'price': 30.0},
              ],
              orderStatus: 'Delivered',
              orderData: const {'has_complaint': false},
              complaintService: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Wrong or Damaged Item? Report Issue'), findsOneWidget);

      // Click Report Issue button
      await tester.tap(find.text('Wrong or Damaged Item? Report Issue'));
      await tester.pumpAndSettle();

      expect(find.text('Report Issue / Return Item'), findsOneWidget);
    });
  });

  group('Feature 51: Admin Complaints Screen Widget Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late ComplaintService service;
    late ShopProvider shopProvider;

    setUp(() async {
      setupFirebaseAuthMocks();
      SharedPreferences.setMockInitialValues({'current_shop_id': 'SHOP_ADMIN_1'});
      fakeFirestore = FakeFirebaseFirestore();
      FirebaseUtils.setFirestore(fakeFirestore);
      service = ComplaintService(firestore: fakeFirestore);
      shopProvider = ShopProvider();
      await shopProvider.loadCurrentShop();
    });

    testWidgets('AdminComplaintsScreen renders KPI cards, filter chips, and complaint list', (tester) async {
      // Seed complaints
      await service.createComplaint(
        orderId: 'ORD-101',
        shopId: 'SHOP_ADMIN_1',
        customerPhone: '9876543210',
        customerName: 'Sunita Verma',
        type: ComplaintType.damaged,
        description: 'Broken container',
        affectedItems: const [
          ComplaintItem(
            itemId: 'p1',
            name: 'Ghee 500ml',
            quantityOrdered: 1,
            quantityAffected: 1,
            pricePerUnit: 350.0,
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ShopProvider>.value(value: shopProvider),
          ],
          child: MaterialApp(
            home: AdminComplaintsScreen(complaintService: service),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Complaints & Returns'), findsOneWidget);
      expect(find.text('Pending'), findsWidgets);
      expect(find.text('Sunita Verma (9876543210)'), findsOneWidget);
      expect(find.text('Broken container'), findsOneWidget);
      expect(find.text('• Ghee 500ml (1x)'), findsOneWidget);
      expect(find.text('Mark In Review'), findsOneWidget);
      expect(find.text('Resolve Case'), findsOneWidget);

      // Tap Mark in Review
      await tester.tap(find.text('Mark In Review'));
      await tester.pumpAndSettle();

      // Tap Resolve Case
      await tester.tap(find.text('Resolve Case'));
      await tester.pumpAndSettle();

      expect(find.text('Select Resolution Action'), findsOneWidget);
      expect(find.text('Refund Amount (₹)'), findsOneWidget);
      expect(find.text('Confirm Resolution'), findsOneWidget);
    });
  });
}
