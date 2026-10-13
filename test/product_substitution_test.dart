import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:near_kirana/substitution_model.dart';
import 'package:near_kirana/product_substitution_service.dart';
import 'package:near_kirana/widgets/substitution_widgets.dart';
import 'firebase_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    setupFirebaseAuthMocks();
    SharedPreferences.setMockInitialValues({});
    FirebaseUtils.setFirestore(FakeFirebaseFirestore());
  });

  group('Feature 47 - ProductSubstitutionProposal Model Tests', () {
    test('calculates correct totals, net price differences, and formatted tags', () {
      final now = DateTime(2026, 10, 13, 15, 0);

      // Case 1: Proposed substitute is more expensive (+₹20)
      final costlier = ProductSubstitutionProposal(
        id: 'sub_1',
        orderId: 'ord_101',
        originalProductId: 'prod_oil_fortune',
        originalProductName: 'Fortune Mustard Oil 1L',
        originalPrice: 130.0,
        originalQuantity: 1.0,
        substituteProductId: 'prod_oil_dhara',
        substituteProductName: 'Dhara Mustard Oil 1L',
        substitutePrice: 150.0,
        substituteQuantity: 1.0,
        status: SubstitutionStatus.pending,
        reason: 'Fortune out of stock, offering premium Dhara',
        proposedAt: now,
      );

      expect(costlier.originalItemTotal, 130.0);
      expect(costlier.substituteItemTotal, 150.0);
      expect(costlier.priceDifference, 20.0);
      expect(costlier.formattedDifference, '+₹20');
      expect(costlier.isPending, isTrue);
      expect(costlier.isAccepted, isFalse);
      expect(costlier.isRejected, isFalse);

      // Case 2: Proposed substitute is cheaper (-₹15)
      final cheaper = ProductSubstitutionProposal(
        id: 'sub_2',
        orderId: 'ord_101',
        originalProductId: 'prod_atta_aashirvaad',
        originalProductName: 'Aashirvaad Atta 5kg',
        originalPrice: 240.0,
        originalQuantity: 1.0,
        substituteProductId: 'prod_atta_fortune',
        substituteProductName: 'Fortune Chakki Fresh Atta 5kg',
        substitutePrice: 225.0,
        substituteQuantity: 1.0,
        status: SubstitutionStatus.pending,
        proposedAt: now,
      );

      expect(cheaper.originalItemTotal, 240.0);
      expect(cheaper.substituteItemTotal, 225.0);
      expect(cheaper.priceDifference, -15.0);
      expect(cheaper.formattedDifference, '-₹15');

      // Case 3: Same price
      final samePrice = ProductSubstitutionProposal(
        id: 'sub_3',
        orderId: 'ord_101',
        originalProductId: 'prod_soap_lux',
        originalProductName: 'Lux Soap 100g',
        originalPrice: 35.0,
        originalQuantity: 2.0,
        substituteProductName: 'Dettol Soap 100g',
        substitutePrice: 35.0,
        substituteQuantity: 2.0,
        status: SubstitutionStatus.pending,
        proposedAt: now,
      );

      expect(samePrice.priceDifference, 0.0);
      expect(samePrice.formattedDifference, 'Same price');
    });

    test('serializes to and from Map without data loss', () {
      final now = DateTime(2026, 10, 13, 16, 30);
      final original = ProductSubstitutionProposal(
        id: 'sub_serialization',
        orderId: 'ord_202',
        originalProductId: 'prod_tea_redlabel',
        originalProductName: 'Brooke Bond Red Label Tea 500g',
        originalPrice: 260.0,
        originalQuantity: 2.0,
        originalUnit: '500g',
        substituteProductId: 'prod_tea_tajmahal',
        substituteProductName: 'Taj Mahal Tea 500g',
        substitutePrice: 290.0,
        substituteQuantity: 2.0,
        substituteUnit: '500g',
        status: SubstitutionStatus.accepted,
        reason: 'Red Label out of stock',
        proposedBy: 'merchant',
        proposedAt: now,
        respondedAt: now.add(const Duration(minutes: 5)),
        rejectionAction: SubstitutionRejectionAction.removeItem,
        customerNote: 'Agreed, please send Taj Mahal',
      );

      final map = original.toMap();
      final reconstituted = ProductSubstitutionProposal.fromMap(map);

      expect(reconstituted.id, original.id);
      expect(reconstituted.orderId, original.orderId);
      expect(reconstituted.originalProductName, original.originalProductName);
      expect(reconstituted.substituteProductName, original.substituteProductName);
      expect(reconstituted.originalItemTotal, 520.0);
      expect(reconstituted.substituteItemTotal, 580.0);
      expect(reconstituted.priceDifference, 60.0);
      expect(reconstituted.status, SubstitutionStatus.accepted);
      expect(reconstituted.customerNote, 'Agreed, please send Taj Mahal');
    });
  });

  group('Feature 47 - ProductSubstitutionService Engine', () {
    late FakeFirebaseFirestore fakeFirestore;
    late ProductSubstitutionService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = ProductSubstitutionService(firestore: fakeFirestore);
    });

    Future<String> createSampleOrder({
      String status = 'Accepted',
      double deliveryFee = 20.0,
      double discount = 0.0,
    }) async {
      final orderRef = fakeFirestore.collection('orders').doc('ord_test_sub_101');
      await orderRef.set({
        'shop_id': 'shop_bhopal_1',
        'customer_name': 'Rohit Sharma',
        'phone_number': '9876543210',
        'status': status,
        'delivery_type': 'Delivery',
        'delivery_fee': deliveryFee,
        'discount': discount,
        'subtotal': 380.0,
        'total_amount': 400.0, // 380 + 20
        'items': [
          {
            'id': 'prod_oil_fortune',
            'name': 'Fortune Mustard Oil 1L',
            'price': 130.0,
            'quantity': 1.0,
            'unit': '1L',
          },
          {
            'id': 'prod_rice_basmati',
            'name': 'India Gate Basmati Rice 1kg',
            'price': 125.0,
            'quantity': 2.0,
            'unit': '1kg',
          },
        ],
        'substitution_proposals': [],
        'has_pending_substitution': false,
        'timeline': [],
      });
      return orderRef.id;
    }

    test('proposes substitution successfully and records audit timeline', () async {
      final orderId = await createSampleOrder();

      final proposal = await service.proposeSubstitution(
        orderId: orderId,
        originalProductId: 'prod_oil_fortune',
        originalProductName: 'Fortune Mustard Oil 1L',
        originalPrice: 130.0,
        originalQuantity: 1.0,
        substituteProductId: 'prod_oil_dhara',
        substituteProductName: 'Dhara Mustard Oil 1L',
        substitutePrice: 150.0,
        substituteQuantity: 1.0,
        reason: 'Fortune 1L is currently out of stock.',
      );

      expect(proposal.id, isNotEmpty);
      expect(proposal.isPending, isTrue);

      final orderDoc = await fakeFirestore.collection('orders').doc(orderId).get();
      final data = orderDoc.data()!;

      expect(data['has_pending_substitution'], isTrue);
      final rawProposals = data['substitution_proposals'] as List;
      expect(rawProposals.length, 1);
      expect(rawProposals.first['substitute_product_name'], 'Dhara Mustard Oil 1L');
      expect(rawProposals.first['status'], 'pending');

      final timeline = data['timeline'] as List;
      expect(timeline.length, 1);
      expect(timeline.first['action'], 'substitution_proposed');
      expect(timeline.first['description'], contains('Dhara Mustard Oil 1L'));
    });

    test('rejects proposing substitution if a proposal is already pending for that item', () async {
      final orderId = await createSampleOrder();

      await service.proposeSubstitution(
        orderId: orderId,
        originalProductId: 'prod_oil_fortune',
        originalProductName: 'Fortune Mustard Oil 1L',
        originalPrice: 130.0,
        originalQuantity: 1.0,
        substituteProductName: 'Dhara Mustard Oil 1L',
        substitutePrice: 150.0,
        substituteQuantity: 1.0,
      );

      // Attempt second proposal for same item
      expect(
        () => service.proposeSubstitution(
          orderId: orderId,
          originalProductId: 'prod_oil_fortune',
          originalProductName: 'Fortune Mustard Oil 1L',
          originalPrice: 130.0,
          originalQuantity: 1.0,
          substituteProductName: 'Patanjali Mustard Oil 1L',
          substitutePrice: 140.0,
          substituteQuantity: 1.0,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects proposing substitution for terminal orders (Delivered, Cancelled)', () async {
      final orderId = await createSampleOrder(status: 'Delivered');

      expect(
        () => service.proposeSubstitution(
          orderId: orderId,
          originalProductId: 'prod_oil_fortune',
          originalProductName: 'Fortune Mustard Oil 1L',
          originalPrice: 130.0,
          originalQuantity: 1.0,
          substituteProductName: 'Dhara Mustard Oil 1L',
          substitutePrice: 150.0,
          substituteQuantity: 1.0,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('customer accepts substitution: updates item and revises order subtotal and total', () async {
      final orderId = await createSampleOrder();

      // Original subtotal = 130 + (125*2) = 380, deliveryFee = 20, total = 400
      final proposal = await service.proposeSubstitution(
        orderId: orderId,
        originalProductId: 'prod_oil_fortune',
        originalProductName: 'Fortune Mustard Oil 1L',
        originalPrice: 130.0,
        originalQuantity: 1.0,
        substituteProductId: 'prod_oil_dhara',
        substituteProductName: 'Dhara Mustard Oil 1L',
        substitutePrice: 150.0, // +₹20 difference
        substituteQuantity: 1.0,
      );

      final result = await service.respondToSubstitution(
        orderId: orderId,
        proposalId: proposal.id,
        isAccepted: true,
        customerNote: 'Looks good, send Dhara',
      );

      expect(result['isAccepted'], isTrue);
      // New subtotal: 150 + 250 = 400. New total: 400 + 20 = 420.
      expect(result['revisedSubtotal'], 400.0);
      expect(result['revisedTotal'], 420.0);
      expect(result['hasPending'], isFalse);

      final orderDoc = await fakeFirestore.collection('orders').doc(orderId).get();
      final data = orderDoc.data()!;

      expect(data['subtotal'], 400.0);
      expect(data['total_amount'], 420.0);
      expect(data['has_pending_substitution'], isFalse);

      final items = data['items'] as List;
      final substitutedItem = items.firstWhere((i) => i['name'] == 'Dhara Mustard Oil 1L');
      expect(substitutedItem['is_substituted'], isTrue);
      expect(substitutedItem['substituted_from'], 'Fortune Mustard Oil 1L');
      expect(substitutedItem['price'], 150.0);

      final timeline = data['timeline'] as List;
      expect(timeline.last['action'], 'substitution_accepted');
    });

    test('customer rejects substitution with removeItem: removes item and reduces total', () async {
      final orderId = await createSampleOrder();

      // Original subtotal = 380, items = 2, total = 400 (380 + 20 fee)
      final proposal = await service.proposeSubstitution(
        orderId: orderId,
        originalProductId: 'prod_oil_fortune',
        originalProductName: 'Fortune Mustard Oil 1L',
        originalPrice: 130.0,
        originalQuantity: 1.0,
        substituteProductName: 'Dhara Mustard Oil 1L',
        substitutePrice: 150.0,
        substituteQuantity: 1.0,
      );

      final result = await service.respondToSubstitution(
        orderId: orderId,
        proposalId: proposal.id,
        isAccepted: false,
        rejectionAction: SubstitutionRejectionAction.removeItem,
      );

      expect(result['isAccepted'], isFalse);
      // Removed 130 oil item -> remaining items: Rice 2x ₹125 = ₹250.
      // Revised subtotal = 250, Revised total = 250 + 20 fee = 270.
      expect(result['revisedSubtotal'], 250.0);
      expect(result['revisedTotal'], 270.0);
      expect(result['itemCount'], 1);

      final orderDoc = await fakeFirestore.collection('orders').doc(orderId).get();
      final data = orderDoc.data()!;

      expect(data['subtotal'], 250.0);
      expect(data['total_amount'], 270.0);
      final items = data['items'] as List;
      expect(items.length, 1);
      expect(items.first['id'], 'prod_rice_basmati');

      final timeline = data['timeline'] as List;
      expect(timeline.last['action'], 'substitution_rejected');
    });

    test('merchant can cancel pending substitution proposal', () async {
      final orderId = await createSampleOrder();

      final proposal = await service.proposeSubstitution(
        orderId: orderId,
        originalProductId: 'prod_oil_fortune',
        originalProductName: 'Fortune Mustard Oil 1L',
        originalPrice: 130.0,
        originalQuantity: 1.0,
        substituteProductName: 'Dhara Mustard Oil 1L',
        substitutePrice: 150.0,
        substituteQuantity: 1.0,
      );

      await service.cancelSubstitutionProposal(
        orderId: orderId,
        proposalId: proposal.id,
        reason: 'Original Fortune oil stock found in store storage',
      );

      final orderDoc = await fakeFirestore.collection('orders').doc(orderId).get();
      final data = orderDoc.data()!;
      expect(data['has_pending_substitution'], isFalse);

      final rawProposals = data['substitution_proposals'] as List;
      expect(rawProposals.first['status'], 'cancelled');
    });
  });

  group('Feature 47 - UI Widgets Presentation Tests', () {
    testWidgets('SubstitutionApprovalBanner renders proposed items, difference pill and action buttons', (tester) async {
      final proposal = ProductSubstitutionProposal(
        id: 'sub_test_banner',
        orderId: 'ord_ui_101',
        originalProductId: 'prod_oil_fortune',
        originalProductName: 'Fortune Mustard Oil 1L',
        originalPrice: 130.0,
        originalQuantity: 1.0,
        substituteProductName: 'Dhara Mustard Oil 1L',
        substitutePrice: 150.0,
        substituteQuantity: 1.0,
        status: SubstitutionStatus.pending,
        reason: 'Fresh batch of Dhara is available',
        proposedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubstitutionApprovalBanner(
              orderId: 'ord_ui_101',
              proposals: [proposal],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check title and item names
      expect(find.text('Action Required: Item Substitution Proposed'), findsOneWidget);
      expect(find.text('Fortune Mustard Oil 1L'), findsOneWidget);
      expect(find.text('Dhara Mustard Oil 1L'), findsOneWidget);
      expect(find.textContaining('Difference: +₹20'), findsOneWidget);
      expect(find.text('Approve Alternative'), findsOneWidget);
      expect(find.text('Decline & Remove'), findsOneWidget);
    });

    testWidgets('SubstitutedItemBadge renders visual tag correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SubstitutedItemBadge(originalName: 'Fortune Oil 1L'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Substituted (was: Fortune Oil 1L)'), findsOneWidget);
    });
  });
}
