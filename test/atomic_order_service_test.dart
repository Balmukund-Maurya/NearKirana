import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:near_kirana/atomic_order_service.dart';
import 'package:near_kirana/payment_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      'free_delivery_threshold': 500.0,
      'delivery_fee': 20.0,
    });
  });

  group('Atomic Orders & Stock Reservation (Feature 40)', () {
    test('1. Example Scenario: Only 1 milk packet in store, simultaneous checkout', () async {
      // Store has only 1 packet of milk
      await fakeFirestore.collection('products').doc('milk_amul_1').set({
        'name': 'Amul Taaza Milk 500ml',
        'price': 27.0,
        'stock_quantity': 1.0,
        'shop_id': 'shop_123',
      });

      // Customer 1 attempts to checkout 1 packet
      final paramsCustomer1 = OrderPlacementParams(
        shopId: 'shop_123',
        customerName: 'Aarav Sharma',
        customerPhone: '9876500001',
        deliveryType: 'Pickup',
        idempotencyKey: 'cust1_checkout_milk',
        items: [
          const OrderItemRequest(
            productId: 'milk_amul_1',
            name: 'Amul Taaza Milk 500ml',
            price: 27.0,
            quantity: 1.0,
          ),
        ],
      );

      // Customer 2 attempts to checkout 1 packet
      final paramsCustomer2 = OrderPlacementParams(
        shopId: 'shop_123',
        customerName: 'Priya Verma',
        customerPhone: '9876500002',
        deliveryType: 'Pickup',
        idempotencyKey: 'cust2_checkout_milk',
        items: [
          const OrderItemRequest(
            productId: 'milk_amul_1',
            name: 'Amul Taaza Milk 500ml',
            price: 27.0,
            quantity: 1.0,
          ),
        ],
      );

      // Customer 1 completes order first
      final result1 = await atomicService.placeOrderAtomic(paramsCustomer1);
      expect(result1.isDuplicate, isFalse);
      expect(result1.status, 'Pending');
      expect(result1.reservedStocks['milk_amul_1'], 0.0);

      // Verify product stock in Firestore is now 0.0
      final productDocAfterCust1 = await fakeFirestore.collection('products').doc('milk_amul_1').get();
      expect(productDocAfterCust1.data()?['stock_quantity'], 0.0);

      // Customer 2 attempts to checkout the same milk packet (now 0 available)
      expect(
        () async => await atomicService.placeOrderAtomic(paramsCustomer2),
        throwsA(isA<InsufficientStockException>().having(
          (e) => e.availableStock,
          'availableStock',
          0.0,
        ).having(
          (e) => e.requestedQuantity,
          'requestedQuantity',
          1.0,
        )),
      );

      // CRITICAL INVARIANT: Stock remains 0.0 and never becomes negative!
      final productDocFinal = await fakeFirestore.collection('products').doc('milk_amul_1').get();
      expect(productDocFinal.data()?['stock_quantity'], 0.0);

      // Verify only 1 order exists in database
      final ordersSnapshot = await fakeFirestore.collection('orders').get();
      expect(ordersSnapshot.docs.length, 1);
      expect(ordersSnapshot.docs.first.data()['customer_name'], 'Aarav Sharma');
    });

    test('2. Safety Invariant: stock_quantity can NEVER become negative', () async {
      await fakeFirestore.collection('products').doc('sugar_1kg').set({
        'name': 'Madhur Sugar 1kg',
        'price': 44.0,
        'stock_quantity': 2.0,
        'shop_id': 'shop_123',
      });

      // Customer requests 3.0 kg (only 2.0 available)
      final params = OrderPlacementParams(
        shopId: 'shop_123',
        customerName: 'Sunil Kumar',
        customerPhone: '9876543210',
        deliveryType: 'Pickup',
        idempotencyKey: 'req_excess_stock',
        items: [
          const OrderItemRequest(
            productId: 'sugar_1kg',
            name: 'Madhur Sugar 1kg',
            price: 44.0,
            quantity: 3.0,
          ),
        ],
      );

      expect(
        () async => await atomicService.placeOrderAtomic(params),
        throwsA(isA<InsufficientStockException>()),
      );

      // Stock remains exactly 2.0
      final doc = await fakeFirestore.collection('products').doc('sugar_1kg').get();
      expect(doc.data()?['stock_quantity'], 2.0);
    });

    test('3. All-or-Nothing Atomicity: Multi-item cart aborts without partial deductions', () async {
      // Product A has ample stock
      await fakeFirestore.collection('products').doc('item_a').set({
        'name': 'Tata Salt 1kg',
        'price': 25.0,
        'stock_quantity': 10.0,
        'shop_id': 'shop_123',
      });

      // Product B is completely out of stock
      await fakeFirestore.collection('products').doc('item_b').set({
        'name': 'Brown Bread 400g',
        'price': 50.0,
        'stock_quantity': 0.0,
        'shop_id': 'shop_123',
      });

      final params = OrderPlacementParams(
        shopId: 'shop_123',
        customerName: 'Kavita Roy',
        customerPhone: '9876543210',
        deliveryType: 'Pickup',
        idempotencyKey: 'multi_item_fail',
        items: [
          const OrderItemRequest(productId: 'item_a', name: 'Tata Salt 1kg', price: 25.0, quantity: 2.0),
          const OrderItemRequest(productId: 'item_b', name: 'Brown Bread 400g', price: 50.0, quantity: 1.0),
        ],
      );

      expect(
        () async => await atomicService.placeOrderAtomic(params),
        throwsA(isA<InsufficientStockException>().having((e) => e.productId, 'productId', 'item_b')),
      );

      // CRITICAL: Item A was NOT deducted!
      final docA = await fakeFirestore.collection('products').doc('item_a').get();
      expect(docA.data()?['stock_quantity'], 10.0);

      // No order document created
      final orders = await fakeFirestore.collection('orders').get();
      expect(orders.docs.isEmpty, isTrue);
    });

    test('4. Fractional Quantity Support for loose items (grains/vegetables)', () async {
      await fakeFirestore.collection('products').doc('potatoes').set({
        'name': 'Fresh Potatoes (Aloo)',
        'price': 30.0,
        'stock_quantity': 10.5,
        'shop_id': 'shop_123',
      });

      final params = OrderPlacementParams(
        shopId: 'shop_123',
        customerName: 'Manish Singh',
        customerPhone: '9876543210',
        deliveryType: 'Pickup',
        idempotencyKey: 'fractional_potatoes_1',
        items: [
          const OrderItemRequest(
            productId: 'potatoes',
            name: 'Fresh Potatoes (Aloo)',
            price: 30.0,
            quantity: 2.75, // 2.75 kg
            isLoose: true,
            unit: 'kg',
          ),
        ],
      );

      final result = await atomicService.placeOrderAtomic(params);
      expect(result.isDuplicate, isFalse);
      expect(result.reservedStocks['potatoes'], 7.75); // 10.5 - 2.75 = 7.75

      final doc = await fakeFirestore.collection('products').doc('potatoes').get();
      expect(doc.data()?['stock_quantity'], 7.75);
    });

    test('5. Idempotency Mechanism: Network retry does NOT double-deduct stock or duplicate orders', () async {
      await fakeFirestore.collection('products').doc('oil_mustard').set({
        'name': 'Fortune Mustard Oil 1L',
        'price': 150.0,
        'stock_quantity': 5.0,
        'shop_id': 'shop_123',
      });

      const uniqueIdempotencyKey = 'client_checkout_session_abc123';

      final params = OrderPlacementParams(
        shopId: 'shop_123',
        customerName: 'Vikram Mehta',
        customerPhone: '9876543210',
        deliveryType: 'Pickup',
        idempotencyKey: uniqueIdempotencyKey,
        items: [
          const OrderItemRequest(
            productId: 'oil_mustard',
            name: 'Fortune Mustard Oil 1L',
            price: 150.0,
            quantity: 1.0,
          ),
        ],
      );

      // Attempt 1: First submission succeeds
      final firstResult = await atomicService.placeOrderAtomic(params);
      expect(firstResult.isDuplicate, isFalse);
      expect(firstResult.totalAmount, 150.0);

      // Stock decremented from 5 to 4
      final docAfterFirst = await fakeFirestore.collection('products').doc('oil_mustard').get();
      expect(docAfterFirst.data()?['stock_quantity'], 4.0);

      // Attempt 2: Network retry with the SAME idempotency key
      final retryResult = await atomicService.placeOrderAtomic(params);
      expect(retryResult.isDuplicate, isTrue);
      expect(retryResult.orderId, firstResult.orderId);
      expect(retryResult.deliveryPin, firstResult.deliveryPin);
      expect(retryResult.totalAmount, 150.0);

      // CRITICAL: Stock is STILL 4.0 (NOT decremented again to 3.0!)
      final docAfterRetry = await fakeFirestore.collection('products').doc('oil_mustard').get();
      expect(docAfterRetry.data()?['stock_quantity'], 4.0);

      // CRITICAL: Exactly 1 order in the database
      final orders = await fakeFirestore.collection('orders').get();
      expect(orders.docs.length, 1);
    });

    test('6. Minimum Order threshold is enforced on Delivery orders', () async {
      await fakeFirestore.collection('products').doc('biscuit_10').set({
        'name': 'Parle-G 100g',
        'price': 10.0,
        'stock_quantity': 50.0,
        'shop_id': 'shop_123',
      });

      final deliveryParams = OrderPlacementParams(
        shopId: 'shop_123',
        customerName: 'Anita Devi',
        customerPhone: '9876543210',
        deliveryType: 'Delivery',
        minOrder: 100.0,
        idempotencyKey: 'under_min_order',
        items: [
          const OrderItemRequest(productId: 'biscuit_10', name: 'Parle-G 100g', price: 10.0, quantity: 2.0),
        ],
      );

      expect(
        () async => await atomicService.placeOrderAtomic(deliveryParams),
        throwsA(isA<MinimumOrderViolationException>()),
      );

      // Self-pickup orders can checkout even below min order threshold
      final pickupParams = OrderPlacementParams(
        shopId: 'shop_123',
        customerName: 'Anita Devi',
        customerPhone: '9876543210',
        deliveryType: 'Pickup',
        minOrder: 100.0,
        idempotencyKey: 'pickup_under_min_order',
        items: [
          const OrderItemRequest(productId: 'biscuit_10', name: 'Parle-G 100g', price: 10.0, quantity: 2.0),
        ],
      );

      final pickupResult = await atomicService.placeOrderAtomic(pickupParams);
      expect(pickupResult.isDuplicate, isFalse);
      expect(pickupResult.totalAmount, 20.0);
    });

    test('7. Store closed check aborts checkout when enforceStoreOpen is true', () async {
      await fakeFirestore.collection('settings').doc('app_config').set({
        'is_store_open': false,
      });

      await fakeFirestore.collection('products').doc('item_open_test').set({
        'name': 'Test Item',
        'price': 50.0,
        'stock_quantity': 10.0,
        'shop_id': 'shop_123',
      });

      final params = OrderPlacementParams(
        shopId: 'shop_123',
        customerName: 'Test Customer',
        customerPhone: '9876543210',
        deliveryType: 'Pickup',
        idempotencyKey: 'store_closed_key',
        enforceStoreOpen: true,
        items: [
          const OrderItemRequest(productId: 'item_open_test', name: 'Test Item', price: 50.0, quantity: 1.0),
        ],
      );

      expect(
        () async => await atomicService.placeOrderAtomic(params),
        throwsA(isA<StoreClosedException>()),
      );
    });

    test('8. Order cancellation restores reserved stock atomically', () async {
      await fakeFirestore.collection('products').doc('oil_bottle').set({
        'name': 'Sunflower Oil 1L',
        'price': 140.0,
        'stock_quantity': 5.0,
        'shop_id': 'shop_123',
      });

      // 1. Place order for 2 bottles
      final orderResult = await atomicService.placeOrderAtomic(
        OrderPlacementParams(
          shopId: 'shop_123',
          customerName: 'Rahul Joshi',
          customerPhone: '9876543210',
          deliveryType: 'Pickup',
          paymentMethod: 'Cash on Delivery',
          idempotencyKey: 'order_to_cancel',
          items: [
            const OrderItemRequest(productId: 'oil_bottle', name: 'Sunflower Oil 1L', price: 140.0, quantity: 2.0),
          ],
        ),
      );

      // Stock is reduced from 5 to 3
      var productDoc = await fakeFirestore.collection('products').doc('oil_bottle').get();
      expect(productDoc.data()?['stock_quantity'], 3.0);

      // 2. Cancel order
      final cancelled = await atomicService.cancelOrderAtomic(
        orderId: orderResult.orderId,
        cancelledBy: 'customer',
        reason: 'Changed mind',
      );
      expect(cancelled, isTrue);

      // Stock is restored back to 5.0!
      productDoc = await fakeFirestore.collection('products').doc('oil_bottle').get();
      expect(productDoc.data()?['stock_quantity'], 5.0);

      // Order status is Cancelled
      final orderDoc = await fakeFirestore.collection('orders').doc(orderResult.orderId).get();
      expect(orderDoc.data()?['status'], 'Cancelled');
      expect(orderDoc.data()?['cancellation_reason'], 'Changed mind');

      // 3. Idempotent re-cancel does NOT restore stock again
      final secondCancel = await atomicService.cancelOrderAtomic(
        orderId: orderResult.orderId,
        cancelledBy: 'customer',
      );
      expect(secondCancel, isFalse);

      productDoc = await fakeFirestore.collection('products').doc('oil_bottle').get();
      expect(productDoc.data()?['stock_quantity'], 5.0); // Not 7.0!
    });

    test('9. Paid order cancellation initiates traceable refund record', () async {
      await fakeFirestore.collection('products').doc('ghee_500g').set({
        'name': 'Desi Ghee 500g',
        'price': 350.0,
        'stock_quantity': 10.0,
        'shop_id': 'shop_123',
      });

      final orderResult = await atomicService.placeOrderAtomic(
        OrderPlacementParams(
          shopId: 'shop_123',
          customerName: 'Sunita Sharma',
          customerPhone: '9876543210',
          deliveryType: 'Pickup',
          paymentMethod: 'UPI',
          paymentStatus: PaymentStatus.paid,
          idempotencyKey: 'paid_order_refund',
          items: [
            const OrderItemRequest(productId: 'ghee_500g', name: 'Desi Ghee 500g', price: 350.0, quantity: 1.0),
          ],
        ),
      );

      // Cancel paid order
      await atomicService.cancelOrderAtomic(
        orderId: orderResult.orderId,
        cancelledBy: 'admin',
        reason: 'Out of stock at merchant',
      );

      final orderDoc = await fakeFirestore.collection('orders').doc(orderResult.orderId).get();
      final data = orderDoc.data()!;
      expect(data['status'], 'Cancelled');
      expect(data['payment_status'], PaymentStatus.refunded);
      expect(data['refund_amount'], 350.0);
      expect(data['refund_id'], isNotNull);
      expect(data['refund_reason'], 'Out of stock at merchant');
      expect(data['refunded_by'], 'admin');
    });

    test('10. Terminal state protection prevents cancellation of delivered orders', () async {
      await fakeFirestore.collection('orders').doc('delivered_order_1').set({
        'status': 'Delivered',
        'shop_id': 'shop_123',
        'items': [
          {'id': 'item_1', 'quantity': 1.0},
        ],
      });

      expect(
        () async => await atomicService.cancelOrderAtomic(
          orderId: 'delivered_order_1',
          cancelledBy: 'customer',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'error',
          contains('Cannot cancel order in terminal state'),
        )),
      );
    });
  });
}
