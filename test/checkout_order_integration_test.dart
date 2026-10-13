import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:near_kirana/cart_calculator.dart';
import 'package:near_kirana/atomic_order_service.dart';
import 'package:near_kirana/payment_service.dart';
import 'package:near_kirana/order_state_machine.dart';
import 'package:near_kirana/crash_reporting_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeFirestore;
  late AtomicOrderService atomicService;
  late PaymentService paymentService;
  late CrashReportingService crashService;

  const String shopId = 'SHOP_KIRANA_01';
  const String customerPhone = '9876543210';
  const String customerName = 'Rahul Verma';

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    atomicService = AtomicOrderService(firestore: fakeFirestore);
    paymentService = PaymentService();
    crashService = CrashReportingService();
    crashService.reset();
    crashService.init();

    // 1. Setup Shop Document
    await fakeFirestore.collection('shops').doc(shopId).set({
      'shop_id': shopId,
      'shop_name': 'Sharma Kirana Store',
      'owner_name': 'Ramesh Sharma',
      'mobile': '9811122233',
      'is_active': true,
      'status': 'approved',
      'min_order_amount': 100.0,
      'free_delivery_threshold': 500.0,
      'delivery_fee': 30.0,
      'is_open': true,
      'service_radius_km': 5.0,
    });

    // 2. Setup Products in Inventory
    // Product A: ₹50 each, initial stock = 10
    await fakeFirestore.collection('products').doc('PROD_OIL_50').set({
      'name': 'Mustard Oil Pouch 500ml',
      'price': 50.0,
      'stock_quantity': 10.0,
      'shop_id': shopId,
      'is_loose': false,
    });

    // Product B: ₹30 each, initial stock = 5
    await fakeFirestore.collection('products').doc('PROD_SUGAR_30').set({
      'name': 'Sugar 500g',
      'price': 30.0,
      'stock_quantity': 5.0,
      'shop_id': shopId,
      'is_loose': false,
    });
  });

  group(
    'Automated Workflow Integration: Cart -> Validation -> Checkout -> Order -> State Machine',
    () {
      test('Complete end-to-end checkout and order creation lifecycle', () async {
        // Step 1: Customer browses & adds items to Cart (recorded in crash monitoring telemetry)
        crashService.setUser(
          uid: 'cust_uid_44',
          role: 'customer',
          phone: customerPhone,
        );
        crashService.recordAction(
          'Customer added 2x Oil (₹50) to cart',
          category: 'cart',
        );
        crashService.recordAction(
          'Customer added 1x Sugar (₹30) to cart',
          category: 'cart',
        );

        final cartItems = [
          const CartCalculationItem(
            id: 'PROD_OIL_50',
            name: 'Mustard Oil Pouch 500ml',
            price: 50.0,
            quantity: 2.0,
          ),
          const CartCalculationItem(
            id: 'PROD_SUGAR_30',
            name: 'Sugar 500g',
            price: 30.0,
            quantity: 1.0,
          ),
        ];

        // Step 2: Automated Cart Calculations
        // 2 * 50 + 1 * 30 = 130.0 (User specification example)
        final subtotal = CartCalculator.calculateSubtotal(cartItems);
        expect(subtotal, equals(130.0));

        final deliveryFee = CartCalculator.calculateDeliveryFee(
          subtotal: subtotal,
          minOrder: 100.0,
          freeDeliveryThreshold: 500.0,
          standardFee: 30.0,
          isDelivery: true,
        );
        expect(deliveryFee, equals(30.0));

        final discount = CartCalculator.calculateDiscount(
          subtotal,
          coupon: const Coupon(
            code: 'SAVE10',
            type: 'flat',
            value: 10.0,
            minOrder: 100.0,
          ),
        );
        expect(discount, equals(10.0));

        final finalTotal = CartCalculator.calculateFinalTotal(
          subtotal: subtotal,
          deliveryFee: deliveryFee,
          discount: discount,
        );
        // 130 + 30 - 10 = 150.0
        expect(finalTotal, equals(150.0));

        // Step 3: Pre-flight Order Placement Validation
        final validationResult = CartCalculator.validateOrderPlacement(
          items: cartItems,
          subtotal: subtotal,
          minOrder: 100.0,
          isDelivery: true,
          isStoreOpen: true,
          isWithinDeliveryRange: true,
        );
        expect(validationResult.isValid, isTrue);

        // Step 4: Atomic Order Placement & Inventory Deduction
        crashService.recordAction(
          'Customer initiated checkout with total ₹150',
          category: 'checkout',
        );

        final orderParams = OrderPlacementParams(
          shopId: shopId,
          customerName: customerName,
          customerPhone: customerPhone,
          deliveryType: 'Delivery',
          deliveryAddress: 'House 14, Main Bazaar, Varanasi',
          paymentMethod: PaymentMethod.upi,
          idempotencyKey: 'IDEMP_CHECKOUT_44_01',
          items: [
            const OrderItemRequest(
              productId: 'PROD_OIL_50',
              name: 'Mustard Oil Pouch 500ml',
              price: 50.0,
              quantity: 2.0,
            ),
            const OrderItemRequest(
              productId: 'PROD_SUGAR_30',
              name: 'Sugar 500g',
              price: 30.0,
              quantity: 1.0,
            ),
          ],
        );

        final orderPlacementResult = await atomicService.placeOrderAtomic(
          orderParams,
        );
        expect(orderPlacementResult.isDuplicate, isFalse);
        expect(orderPlacementResult.status, equals(OrderStatus.pending));
        final String orderId = orderPlacementResult.orderId;
        expect(orderId.isNotEmpty, isTrue);

        // Verify Stock was safely deducted in database
        final oilDoc = await fakeFirestore
            .collection('products')
            .doc('PROD_OIL_50')
            .get();
        final sugarDoc = await fakeFirestore
            .collection('products')
            .doc('PROD_SUGAR_30')
            .get();
        expect(oilDoc.data()?['stock_quantity'], equals(8.0)); // 10 - 2 = 8
        expect(sugarDoc.data()?['stock_quantity'], equals(4.0)); // 5 - 1 = 4

        // Step 5: Duplicate Prevention via Idempotency Key
        final retryPlacement = await atomicService.placeOrderAtomic(
          orderParams,
        );
        expect(retryPlacement.isDuplicate, isTrue);
        expect(retryPlacement.orderId, equals(orderId));
        // Verify stock was NOT double deducted!
        final oilDocAfterRetry = await fakeFirestore
            .collection('products')
            .doc('PROD_OIL_50')
            .get();
        expect(oilDocAfterRetry.data()?['stock_quantity'], equals(8.0));

        // Step 6: Online Payment Processing & Reconciliation
        final session = await paymentService.initiateOnlinePayment(
          orderId: orderId,
          shopId: shopId,
          amount: finalTotal,
          customerPhone: customerPhone,
          customerName: customerName,
          paymentMethod: PaymentMethod.upi,
          firestore: fakeFirestore,
        );
        expect(session.status, equals('pending'));
        expect(session.orderId, equals(orderId));

        final verification = await paymentService.verifyOnlinePayment(
          orderId: orderId,
          transactionId: session.transactionId,
          gatewayReference: 'pay_20261013_gateway_verified',
          gatewaySignature: 'sig_hmac256_verified_token_9918234857',
          firestore: fakeFirestore,
        );
        expect(verification.success, isTrue);

        // Verify order payment status is marked paid in Firestore
        final orderSnap = await fakeFirestore
            .collection('orders')
            .doc(orderId)
            .get();
        expect(orderSnap.data()?['payment_status'], equals(PaymentStatus.paid));
        expect(orderSnap.data()?['status'], equals(OrderStatus.pending));

        // Step 7: Order State Machine Lifecycle Progression
        // Pending -> Accepted
        await OrderStateMachine.transitionOrder(
          orderId: orderId,
          targetStatus: OrderStatus.accepted,
          updatedBy: 'sharma_kirana_owner',
          firestore: fakeFirestore,
        );
        var currentOrder = await fakeFirestore
            .collection('orders')
            .doc(orderId)
            .get();
        expect(currentOrder.data()?['status'], equals(OrderStatus.accepted));
        expect(currentOrder.data()?['accepted_at'], isNotNull);

        // Accepted -> Packing
        await OrderStateMachine.transitionOrder(
          orderId: orderId,
          targetStatus: OrderStatus.packing,
          updatedBy: 'packer_boy',
          firestore: fakeFirestore,
        );
        currentOrder = await fakeFirestore
            .collection('orders')
            .doc(orderId)
            .get();
        expect(currentOrder.data()?['status'], equals(OrderStatus.packing));

        // Packing -> Ready
        await OrderStateMachine.transitionOrder(
          orderId: orderId,
          targetStatus: OrderStatus.ready,
          updatedBy: 'packer_boy',
          firestore: fakeFirestore,
        );
        currentOrder = await fakeFirestore
            .collection('orders')
            .doc(orderId)
            .get();
        expect(currentOrder.data()?['status'], equals(OrderStatus.ready));

        // Ready -> Out for Delivery
        await OrderStateMachine.transitionOrder(
          orderId: orderId,
          targetStatus: OrderStatus.outForDelivery,
          updatedBy: 'delivery_partner_mohan',
          firestore: fakeFirestore,
        );
        currentOrder = await fakeFirestore
            .collection('orders')
            .doc(orderId)
            .get();
        expect(
          currentOrder.data()?['status'],
          equals(OrderStatus.outForDelivery),
        );

        // Out for Delivery -> Delivered
        await OrderStateMachine.transitionOrder(
          orderId: orderId,
          targetStatus: OrderStatus.delivered,
          updatedBy: 'delivery_partner_mohan',
          firestore: fakeFirestore,
        );
        currentOrder = await fakeFirestore
            .collection('orders')
            .doc(orderId)
            .get();
        expect(currentOrder.data()?['status'], equals(OrderStatus.delivered));
        expect(currentOrder.data()?['delivered_at'], isNotNull);

        // Step 8: Terminal State Protection Invariance
        // Delivered order CANNOT be moved back to Packing by normal operators
        expect(
          () => OrderStateMachine.assertValidTransition(
            OrderStatus.delivered,
            OrderStatus.packing,
          ),
          throwsA(isA<StateError>()),
        );

        // Super Admin Authorized Correction Workflow
        final correction = await OrderStateMachine.applyAuthorizedCorrection(
          orderId: orderId,
          targetStatus: OrderStatus.packing,
          authorizedBy: 'super_admin_balmukund',
          correctionReason: 'Wrong bag handed over, corrected by super admin',
          isSuperAdmin: true,
          firestore: fakeFirestore,
        );
        expect(correction.success, isTrue);
        expect(correction.newStatus, equals(OrderStatus.packing));

        // Step 9: Crash Monitoring Telemetry Validation
        final breadcrumbs = crashService.getBreadcrumbs();
        expect(breadcrumbs.any((b) => b.message.contains('Oil (₹50)')), isTrue);
        expect(
          breadcrumbs.any((b) => b.message.contains('Sugar (₹30)')),
          isTrue,
        );
        expect(
          breadcrumbs.any((b) => b.message.contains('initiated checkout')),
          isTrue,
        );
      });

      test(
        'Overselling Invariant: Order creation is rejected when stock is insufficient',
        () async {
          // Sugar only has 5.0 in stock; customer attempts to buy 8.0
          final overLimitParams = OrderPlacementParams(
            shopId: shopId,
            customerName: customerName,
            customerPhone: customerPhone,
            deliveryType: 'Pickup',
            idempotencyKey: 'cust_oversell_attempt',
            items: [
              const OrderItemRequest(
                productId: 'PROD_SUGAR_30',
                name: 'Sugar 500g',
                price: 30.0,
                quantity: 8.0,
              ),
            ],
          );

          expect(
            () async => await atomicService.placeOrderAtomic(overLimitParams),
            throwsA(
              isA<InsufficientStockException>()
                  .having((e) => e.availableStock, 'availableStock', 5.0)
                  .having((e) => e.requestedQuantity, 'requestedQuantity', 8.0),
            ),
          );

          // Sugar stock remains intact at 5.0
          final sugarDoc = await fakeFirestore
              .collection('products')
              .doc('PROD_SUGAR_30')
              .get();
          expect(sugarDoc.data()?['stock_quantity'], equals(5.0));
        },
      );
    },
  );
}
