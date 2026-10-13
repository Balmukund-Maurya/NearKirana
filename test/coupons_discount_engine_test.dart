import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:near_kirana/coupon_model.dart';
import 'package:near_kirana/coupon_service.dart';
import 'package:near_kirana/atomic_order_service.dart';
import 'package:near_kirana/cart_calculator.dart';
import 'package:near_kirana/widgets/coupon_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feature 49: CouponModel Calculations & Validation Logic', () {
    test('1. Flat Discount: SAVE50 gives ₹50 discount on ₹500 cart', () {
      final coupon = CouponModel(
        id: 'coup_1',
        code: 'SAVE50',
        description: 'Flat ₹50 off on ₹500',
        type: CouponDiscountType.flat,
        discountValue: 50.0,
        minOrderValue: 500.0,
        startDate: DateTime.now().subtract(const Duration(days: 1)),
        endDate: DateTime.now().add(const Duration(days: 10)),
        isActive: true,
      );

      final discount = coupon.calculateDiscount(subtotal: 500.0);
      expect(discount, 50.0);
    });

    test('2. Flat Discount Safety: discount is capped at subtotal (never negative cart)', () {
      final coupon = CouponModel(
        id: 'coup_flat_large',
        code: 'FLAT100',
        type: CouponDiscountType.flat,
        discountValue: 100.0,
        minOrderValue: 0.0,
        startDate: DateTime.now().subtract(const Duration(days: 1)),
        endDate: DateTime.now().add(const Duration(days: 10)),
      );

      final discount = coupon.calculateDiscount(subtotal: 45.0);
      expect(discount, 45.0);
    });

    test('3. Percentage Discount: 10% on ₹500 cart gives ₹50 discount', () {
      final coupon = CouponModel(
        id: 'coup_pct',
        code: 'SAVE10',
        type: CouponDiscountType.percentage,
        discountValue: 10.0,
        minOrderValue: 200.0,
        startDate: DateTime.now().subtract(const Duration(days: 1)),
        endDate: DateTime.now().add(const Duration(days: 10)),
      );

      final discount = coupon.calculateDiscount(subtotal: 500.0);
      expect(discount, 50.0);
    });

    test('4. Percentage Discount Capping: 20% on ₹1000 with maxDiscount ₹100 gives ₹100', () {
      final coupon = CouponModel(
        id: 'coup_cap',
        code: 'FESTIVE20',
        type: CouponDiscountType.percentage,
        discountValue: 20.0,
        minOrderValue: 500.0,
        maxDiscount: 100.0,
        startDate: DateTime.now().subtract(const Duration(days: 1)),
        endDate: DateTime.now().add(const Duration(days: 10)),
      );

      // 20% of 1000 is 200, but capped at 100
      final discount = coupon.calculateDiscount(subtotal: 1000.0);
      expect(discount, 100.0);
    });

    test('5. Free Delivery Discount: discounts delivery fee', () {
      final coupon = CouponModel(
        id: 'coup_ship',
        code: 'FREESHIP',
        type: CouponDiscountType.freeDelivery,
        discountValue: 0.0,
        minOrderValue: 300.0,
        startDate: DateTime.now().subtract(const Duration(days: 1)),
        endDate: DateTime.now().add(const Duration(days: 10)),
      );

      final discount = coupon.calculateDiscount(subtotal: 400.0, deliveryFee: 30.0);
      expect(discount, 30.0);
    });

    test('6. Below Minimum Cart Value gives ₹0 discount', () {
      final coupon = CouponModel(
        id: 'coup_min',
        code: 'MIN500',
        type: CouponDiscountType.flat,
        discountValue: 50.0,
        minOrderValue: 500.0,
        startDate: DateTime.now().subtract(const Duration(days: 1)),
        endDate: DateTime.now().add(const Duration(days: 10)),
      );

      final discount = coupon.calculateDiscount(subtotal: 450.0);
      expect(discount, 0.0);
    });

    test('7. Expiration & Usage Limits logic', () {
      final expiredCoupon = CouponModel(
        id: 'c_exp',
        code: 'EXPIRED',
        startDate: DateTime.now().subtract(const Duration(days: 10)),
        endDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(expiredCoupon.isExpired(), isTrue);

      final fullyClaimed = CouponModel(
        id: 'c_limit',
        code: 'CLAIMED',
        usageLimit: 50,
        usedCount: 50,
        startDate: DateTime.now().subtract(const Duration(days: 1)),
        endDate: DateTime.now().add(const Duration(days: 5)),
      );
      expect(fullyClaimed.isFullyClaimed(), isTrue);
    });

    test('8. Serialization: toMap and fromMap round-trip', () {
      final original = CouponModel(
        id: 'test_123',
        code: 'TESTCODE',
        description: 'Test coupon roundtrip',
        type: CouponDiscountType.percentage,
        discountValue: 15.0,
        minOrderValue: 350.0,
        maxDiscount: 75.0,
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 12, 31),
        usageLimit: 500,
        usedCount: 42,
        perUserLimit: 2,
        shopId: 'shop_abc',
        isActive: true,
      );

      final map = original.toMap();
      final revived = CouponModel.fromMap(map, id: original.id);

      expect(revived.id, original.id);
      expect(revived.code, original.code);
      expect(revived.type, original.type);
      expect(revived.discountValue, original.discountValue);
      expect(revived.minOrderValue, original.minOrderValue);
      expect(revived.maxDiscount, original.maxDiscount);
      expect(revived.usageLimit, original.usageLimit);
      expect(revived.usedCount, original.usedCount);
      expect(revived.perUserLimit, original.perUserLimit);
      expect(revived.shopId, original.shopId);
      expect(revived.isActive, original.isActive);
    });
  });

  group('Feature 49: CouponService Rule Validation Engine', () {
    late FakeFirebaseFirestore fakeFirestore;
    late CouponService couponService;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      couponService = CouponService(firestore: fakeFirestore);

      // Seed active valid coupon SAVE50
      await fakeFirestore.collection('coupons').doc('coup_SAVE50').set({
        'code': 'SAVE50',
        'description': 'Save ₹50 on orders above ₹500',
        'type': 'flat',
        'discount_value': 50.0,
        'min_order_value': 500.0,
        'start_date': DateTime.now().subtract(const Duration(days: 2)),
        'end_date': DateTime.now().add(const Duration(days: 10)),
        'usage_limit': 100,
        'used_count': 10,
        'per_user_limit': 1,
        'is_active': true,
        'shop_id': null,
      });

      // Seed inactive coupon INACTIVE20
      await fakeFirestore.collection('coupons').doc('coup_INACTIVE20').set({
        'code': 'INACTIVE20',
        'type': 'percentage',
        'discount_value': 20.0,
        'min_order_value': 100.0,
        'start_date': DateTime.now().subtract(const Duration(days: 2)),
        'end_date': DateTime.now().add(const Duration(days: 10)),
        'is_active': false,
      });

      // Seed expired coupon EXPIRED10
      await fakeFirestore.collection('coupons').doc('coup_EXPIRED10').set({
        'code': 'EXPIRED10',
        'type': 'percentage',
        'discount_value': 10.0,
        'min_order_value': 100.0,
        'start_date': DateTime.now().subtract(const Duration(days: 20)),
        'end_date': DateTime.now().subtract(const Duration(days: 5)),
        'is_active': true,
      });

      // Seed exhausted coupon EXHAUSTED
      await fakeFirestore.collection('coupons').doc('coup_EXHAUSTED').set({
        'code': 'EXHAUSTED',
        'type': 'flat',
        'discount_value': 50.0,
        'min_order_value': 100.0,
        'start_date': DateTime.now().subtract(const Duration(days: 2)),
        'end_date': DateTime.now().add(const Duration(days: 10)),
        'usage_limit': 20,
        'used_count': 20,
        'is_active': true,
      });

      // Seed shop-specific coupon SHOPOFFER
      await fakeFirestore.collection('coupons').doc('coup_SHOPOFFER').set({
        'code': 'SHOPOFFER',
        'type': 'flat',
        'discount_value': 30.0,
        'min_order_value': 200.0,
        'start_date': DateTime.now().subtract(const Duration(days: 2)),
        'end_date': DateTime.now().add(const Duration(days: 10)),
        'shop_id': 'shop_special',
        'is_active': true,
      });
    });

    test('1. Valid coupon passes validation and calculates accurate discount', () async {
      final res = await couponService.validateCoupon(
        code: 'SAVE50',
        subtotal: 600.0,
        customerPhone: '9876543210',
      );

      expect(res.isValid, isTrue);
      expect(res.discountAmount, 50.0);
      expect(res.totalSavings, 50.0);
      expect(res.coupon?.code, 'SAVE50');
    });

    test('2. Case-insensitivity & whitespace trimming: "  save50  " resolves properly', () async {
      final res = await couponService.validateCoupon(
        code: '  save50  ',
        subtotal: 550.0,
        customerPhone: '9876543210',
      );

      expect(res.isValid, isTrue);
      expect(res.discountAmount, 50.0);
    });

    test('3. Non-existent coupon code returns clear error', () async {
      final res = await couponService.validateCoupon(
        code: 'NO_SUCH_CODE',
        subtotal: 500.0,
      );

      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('invalid or does not exist'));
    });

    test('4. Inactive coupon returns disabled error', () async {
      final res = await couponService.validateCoupon(
        code: 'INACTIVE20',
        subtotal: 500.0,
      );

      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('currently inactive'));
    });

    test('5. Expired coupon returns expired error', () async {
      final res = await couponService.validateCoupon(
        code: 'EXPIRED10',
        subtotal: 500.0,
      );

      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('expired'));
    });

    test('6. Below minimum cart value returns descriptive requirement', () async {
      final res = await couponService.validateCoupon(
        code: 'SAVE50',
        subtotal: 400.0, // Required is 500
      );

      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('Min order value of ₹500 required'));
      expect(res.errorMessage, contains('Add ₹100 more'));
    });

    test('7. Global usage limit exhausted returns claimed error', () async {
      final res = await couponService.validateCoupon(
        code: 'EXHAUSTED',
        subtotal: 500.0,
      );

      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('maximum global usage limit'));
    });

    test('8. Per-user usage limit restricts repeat redemption', () async {
      // Record a prior redemption for phone 9998887776
      await fakeFirestore.collection('coupon_usages').doc('usage_order1_SAVE50').set({
        'coupon_id': 'coup_SAVE50',
        'order_id': 'order1',
        'customer_phone': '9998887776',
        'discount_applied': 50.0,
      });

      final res = await couponService.validateCoupon(
        code: 'SAVE50',
        subtotal: 600.0,
        customerPhone: '9998887776',
      );

      expect(res.isValid, isFalse);
      expect(res.errorMessage, contains('maximum allowed times (1)'));

      // Different customer phone can still use it
      final res2 = await couponService.validateCoupon(
        code: 'SAVE50',
        subtotal: 600.0,
        customerPhone: '1112223334',
      );
      expect(res2.isValid, isTrue);
    });

    test('9. Store-scoping prevents cross-store redemption', () async {
      // Trying SHOPOFFER on other store fails
      final resWrong = await couponService.validateCoupon(
        code: 'SHOPOFFER',
        subtotal: 300.0,
        shopId: 'shop_other',
      );
      expect(resWrong.isValid, isFalse);
      expect(resWrong.errorMessage, contains('not valid for this store'));

      // Trying on shop_special succeeds
      final resCorrect = await couponService.validateCoupon(
        code: 'SHOPOFFER',
        subtotal: 300.0,
        shopId: 'shop_special',
      );
      expect(resCorrect.isValid, isTrue);
    });

    test('10. Admin CRUD operations', () async {
      // Create new coupon
      final newCoupon = CouponModel(
        id: '',
        code: 'NEWBIE10',
        description: 'New user discount',
        type: CouponDiscountType.percentage,
        discountValue: 10.0,
        minOrderValue: 250.0,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
      );

      final docId = await couponService.createCoupon(newCoupon);
      expect(docId, 'coup_NEWBIE10');

      final createdDoc = await fakeFirestore.collection('coupons').doc(docId).get();
      expect(createdDoc.exists, isTrue);
      expect(createdDoc.data()?['code'], 'NEWBIE10');

      // Toggle status
      await couponService.toggleCouponStatus(docId, false);
      final toggledDoc = await fakeFirestore.collection('coupons').doc(docId).get();
      expect(toggledDoc.data()?['is_active'], isFalse);

      // Delete coupon
      await couponService.deleteCoupon(docId);
      final deletedDoc = await fakeFirestore.collection('coupons').doc(docId).get();
      expect(deletedDoc.exists, isFalse);
    });
  });

  group('Feature 49: AtomicOrderService Server-Side Verification', () {
    late FakeFirebaseFirestore fakeFirestore;
    late AtomicOrderService atomicService;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      atomicService = AtomicOrderService(firestore: fakeFirestore);

      // Seed shop
      await fakeFirestore.collection('shops').doc('shop_123').set({
        'shop_name': 'Gupta Kirana Store',
        'mobile': '9876543210',
        'is_active': true,
        'status': 'approved',
      });

      // Seed global settings
      await fakeFirestore.collection('settings').doc('app_config').set({
        'is_store_open': true,
        'minimum_order': 100.0,
        'free_delivery_threshold': 1000.0,
        'delivery_fee': 20.0,
      });

      // Seed product with plenty of stock
      await fakeFirestore.collection('products').doc('rice_1kg').set({
        'name': 'Basmati Rice 1kg',
        'price': 100.0,
        'stock_quantity': 50.0,
        'shop_id': 'shop_123',
      });

      // Seed coupon SAVE50 (Flat ₹50 off on min ₹500)
      await fakeFirestore.collection('coupons').doc('coup_SAVE50').set({
        'code': 'SAVE50',
        'description': 'Flat ₹50 off',
        'type': 'flat',
        'discount_value': 50.0,
        'min_order_value': 500.0,
        'start_date': DateTime.now().subtract(const Duration(days: 1)),
        'end_date': DateTime.now().add(const Duration(days: 10)),
        'usage_limit': 100,
        'used_count': 5,
        'per_user_limit': 1,
        'is_active': true,
      });
    });

    test('1. Example: Customer orders 5kg rice (₹500), applies SAVE50 -> Server deducts ₹50 and records usage', () async {
      final params = OrderPlacementParams(
        shopId: 'shop_123',
        customerName: 'Rahul Verma',
        customerPhone: '9876511111',
        deliveryType: 'Delivery',
        deliveryFee: 20.0,
        freeDeliveryThreshold: 1000.0,
        couponCode: 'SAVE50',
        idempotencyKey: 'order_with_coupon_1',
        items: [
          const OrderItemRequest(
            productId: 'rice_1kg',
            name: 'Basmati Rice 1kg',
            price: 100.0,
            quantity: 5.0, // Subtotal = ₹500
          ),
        ],
      );

      final result = await atomicService.placeOrderAtomic(params);

      // Verify result discounts: Subtotal (500) + DeliveryFee (20) - Discount (50) = 470
      expect(result.discount, 50.0);
      expect(result.couponCode, 'SAVE50');
      expect(result.totalAmount, 470.0);

      // Check order document in firestore
      final orderDoc = await fakeFirestore.collection('orders').doc(result.orderId).get();
      expect(orderDoc.exists, isTrue);
      expect(orderDoc.data()?['coupon_code'], 'SAVE50');
      expect(orderDoc.data()?['discount'], 50.0);
      expect(orderDoc.data()?['total_amount'], 470.0);

      // Check coupon doc used_count incremented from 5 to 6
      final couponDoc = await fakeFirestore.collection('coupons').doc('coup_SAVE50').get();
      expect(couponDoc.data()?['used_count'], 6);

      // Check coupon_usages collection recorded
      final usages = await fakeFirestore
          .collection('coupon_usages')
          .where('coupon_id', isEqualTo: 'coup_SAVE50')
          .where('customer_phone', isEqualTo: '9876511111')
          .get();
      expect(usages.docs.length, 1);
      expect(usages.docs.first.data()['discount_applied'], 50.0);
      expect(usages.docs.first.data()['order_id'], result.orderId);
    });

    test('2. Server rejects invalid coupon (e.g. Below min cart value)', () async {
      final params = OrderPlacementParams(
        shopId: 'shop_123',
        customerName: 'Rahul Verma',
        customerPhone: '9876511111',
        deliveryType: 'Delivery',
        couponCode: 'SAVE50',
        idempotencyKey: 'order_with_insufficient_cart',
        items: [
          const OrderItemRequest(
            productId: 'rice_1kg',
            name: 'Basmati Rice 1kg',
            price: 100.0,
            quantity: 2.0, // Subtotal = ₹200 (Min order is 500)
          ),
        ],
      );

      expect(
        () => atomicService.placeOrderAtomic(params),
        throwsA(isA<InvalidCouponException>()),
      );
    });

    test('3. Server rejects coupon if customer exceeds per-user usage limit', () async {
      // Place first order successfully
      final params1 = OrderPlacementParams(
        shopId: 'shop_123',
        customerName: 'Aarav Gupta',
        customerPhone: '9876522222',
        deliveryType: 'Delivery',
        deliveryFee: 20.0,
        couponCode: 'SAVE50',
        idempotencyKey: 'order_aarav_1',
        items: [
          const OrderItemRequest(
            productId: 'rice_1kg',
            name: 'Basmati Rice 1kg',
            price: 100.0,
            quantity: 5.0,
          ),
        ],
      );
      await atomicService.placeOrderAtomic(params1);

      // Second attempt by the same customer with perUserLimit = 1 should fail
      final params2 = OrderPlacementParams(
        shopId: 'shop_123',
        customerName: 'Aarav Gupta',
        customerPhone: '9876522222',
        deliveryType: 'Delivery',
        deliveryFee: 20.0,
        couponCode: 'SAVE50',
        idempotencyKey: 'order_aarav_2',
        items: [
          const OrderItemRequest(
            productId: 'rice_1kg',
            name: 'Basmati Rice 1kg',
            price: 100.0,
            quantity: 5.0,
          ),
        ],
      );

      expect(
        () => atomicService.placeOrderAtomic(params2),
        throwsA(isA<InvalidCouponException>()),
      );
    });
  });

  group('Feature 49: CartCalculator Interoperability', () {
    test('calculateDiscount works with CouponModel', () {
      final couponModel = CouponModel(
        id: 'coup_1',
        code: 'PERC10',
        type: CouponDiscountType.percentage,
        discountValue: 10.0,
        minOrderValue: 200.0,
        startDate: DateTime.now().subtract(const Duration(days: 1)),
        endDate: DateTime.now().add(const Duration(days: 10)),
      );

      final discount = CartCalculator.calculateDiscount(
        600.0,
        couponModel: couponModel,
      );
      expect(discount, 60.0);
    });
  });

  group('Feature 49: Coupon UI Widgets', () {
    testWidgets('CouponInputCard renders input field and apply button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CouponInputCard(
              subtotal: 500.0,
              onCouponApplied: (_) {},
              onCouponRemoved: () {},
            ),
          ),
        ),
      );

      expect(find.text('Coupons & Offers'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
      expect(find.text('View Coupons'), findsOneWidget);
    });

    testWidgets('CouponInputCard displays applied coupon card and remove action', (tester) async {
      final coupon = CouponModel(
        id: 'c1',
        code: 'SAVE50',
        description: 'Flat ₹50 savings',
        type: CouponDiscountType.flat,
        discountValue: 50.0,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 10)),
      );

      final result = CouponValidationResult(
        isValid: true,
        coupon: coupon,
        discountAmount: 50.0,
      );

      bool removed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CouponInputCard(
              subtotal: 500.0,
              appliedResult: result,
              onCouponApplied: (_) {},
              onCouponRemoved: () {
                removed = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('SAVE50'), findsOneWidget);
      expect(find.text('Applied • Save ₹50'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(removed, isTrue);
    });
  });
}
