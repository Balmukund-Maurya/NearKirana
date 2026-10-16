import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:near_kirana/user_provider.dart';
import 'package:near_kirana/cart_provider.dart';
import 'package:near_kirana/shop_provider.dart';
import 'package:near_kirana/saved_address_model.dart';
import 'package:near_kirana/delivery_estimate_model.dart';
import 'package:near_kirana/delivery_estimation_service.dart';
import 'package:near_kirana/atomic_order_service.dart';
import 'package:near_kirana/desktop_checkout_view.dart';
import 'firebase_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    setupFirebaseAuthMocks();
    SharedPreferences.setMockInitialValues({});
    FirebaseUtils.setFirestore(FakeFirebaseFirestore());
  });

  group('Feature 46 - DeliveryEstimate Model Tests', () {
    test('creates DeliveryEstimate with accurate window, breakdown, and disclaimer', () {
      final now = DateTime(2026, 10, 13, 14, 0); // 2:00 PM
      final estimate = DeliveryEstimate(
        minMinutes: 35,
        maxMinutes: 50,
        prepTimeMinutes: 15,
        transitTimeMinutes: 14,
        queueDelayMinutes: 5,
        distanceKm: 2.2,
        isStoreOpen: true,
        deliveryType: 'Delivery',
        estimatedArrivalStart: DateTime(2026, 10, 13, 14, 35),
        estimatedArrivalEnd: DateTime(2026, 10, 13, 14, 50),
        calculatedAt: now,
      );

      expect(estimate.minMinutes, 35);
      expect(estimate.maxMinutes, 50);
      expect(estimate.formattedWindow, '35–50 mins');
      expect(estimate.formattedTimeRange, contains('PM'));
      expect(estimate.distanceKm, 2.2);
      expect(estimate.prepTimeMinutes, 15);
      expect(estimate.transitTimeMinutes, 14);
      expect(estimate.queueDelayMinutes, 5);
      expect(estimate.isStoreOpen, isTrue);
      // Non-guarantee disclaimer must always be explicit
      expect(estimate.disclaimer, contains('Not a strict guarantee'));
    });

    test('serializes to and from Map without data loss', () {
      final now = DateTime(2026, 10, 13, 18, 30);
      final original = DeliveryEstimate(
        minMinutes: 30,
        maxMinutes: 45,
        prepTimeMinutes: 15,
        transitTimeMinutes: 12,
        queueDelayMinutes: 0,
        distanceKm: 1.8,
        isStoreOpen: true,
        deliveryType: 'Delivery',
        estimatedArrivalStart: now.add(const Duration(minutes: 30)),
        estimatedArrivalEnd: now.add(const Duration(minutes: 45)),
        calculatedAt: now,
        disclaimer: 'Custom disclaimer note',
      );

      final map = original.toMap();
      final reconstituted = DeliveryEstimate.fromMap(map);

      expect(reconstituted.minMinutes, original.minMinutes);
      expect(reconstituted.maxMinutes, original.maxMinutes);
      expect(reconstituted.prepTimeMinutes, original.prepTimeMinutes);
      expect(reconstituted.transitTimeMinutes, original.transitTimeMinutes);
      expect(reconstituted.distanceKm, original.distanceKm);
      expect(reconstituted.formattedWindow, original.formattedWindow);
      expect(reconstituted.disclaimer, 'Custom disclaimer note');
    });

    test('handles closed store state gracefully', () {
      final now = DateTime(2026, 10, 13, 23, 0); // 11:00 PM
      final estimate = DeliveryEstimate(
        minMinutes: 60,
        maxMinutes: 120,
        prepTimeMinutes: 15,
        transitTimeMinutes: 15,
        queueDelayMinutes: 0,
        distanceKm: 2.0,
        isStoreOpen: false,
        deliveryType: 'Delivery',
        estimatedArrivalStart: now.add(const Duration(minutes: 60)),
        estimatedArrivalEnd: now.add(const Duration(minutes: 120)),
        calculatedAt: now,
      );

      expect(estimate.isStoreOpen, isFalse);
      expect(estimate.formattedWindow, 'Store Closed');
      expect(estimate.formattedTimeRange, 'Upon store opening');
      expect(estimate.fullDescription, contains('currently closed'));
    });
  });

  group('Feature 46 - DeliveryEstimationService Calculation Engine', () {
    final service = DeliveryEstimationService.instance;
    final testTime = DateTime(2026, 10, 13, 12, 0); // 12:00 PM

    test('calculates realistic delivery window for normal local distance (2-3 km)', () {
      final estimate = service.calculateEstimate(
        storeLat: 23.259933,
        storeLng: 77.412615,
        customerLat: 23.275000,
        customerLng: 77.425000,
        deliveryType: 'Delivery',
        basePrepMinutes: 15,
        pendingOrdersCount: 1,
        currentTime: testTime,
      );

      expect(estimate.isStoreOpen, isTrue);
      expect(estimate.prepTimeMinutes, 15);
      expect(estimate.queueDelayMinutes, 0);
      expect(estimate.distanceKm, greaterThan(1.5));
      expect(estimate.distanceKm, lessThan(4.0));
      expect(estimate.minMinutes, inInclusiveRange(25, 40));
      expect(estimate.maxMinutes, inInclusiveRange(35, 55));
      expect(estimate.maxMinutes, greaterThan(estimate.minMinutes));
      expect(estimate.disclaimer, isNotEmpty);
    });

    test('increases estimate dynamically when kitchen/store is under heavy load (rush factor)', () {
      // Normal load (1 order)
      final normalEstimate = service.calculateEstimate(
        customDistanceKm: 2.5,
        deliveryType: 'Delivery',
        basePrepMinutes: 15,
        pendingOrdersCount: 1,
        currentTime: testTime,
      );

      // Moderate rush (4 orders) -> +5 mins queue delay
      final moderateRush = service.calculateEstimate(
        customDistanceKm: 2.5,
        deliveryType: 'Delivery',
        basePrepMinutes: 15,
        pendingOrdersCount: 4,
        currentTime: testTime,
      );

      // Heavy rush (8 orders) -> +10 mins queue delay
      final heavyRush = service.calculateEstimate(
        customDistanceKm: 2.5,
        deliveryType: 'Delivery',
        basePrepMinutes: 15,
        pendingOrdersCount: 8,
        currentTime: testTime,
      );

      expect(normalEstimate.queueDelayMinutes, 0);
      expect(moderateRush.queueDelayMinutes, 5);
      expect(heavyRush.queueDelayMinutes, 10);

      expect(moderateRush.maxMinutes, greaterThanOrEqualTo(normalEstimate.maxMinutes));
      expect(heavyRush.maxMinutes, greaterThan(normalEstimate.maxMinutes));
    });

    test('calculates pickup orders without transit time buffer', () {
      final pickupEstimate = service.calculateEstimate(
        customDistanceKm: 5.0, // Customer might be far away
        deliveryType: 'Pickup',
        basePrepMinutes: 15,
        pendingOrdersCount: 2,
        currentTime: testTime,
      );

      expect(pickupEstimate.deliveryType, 'Pickup');
      expect(pickupEstimate.transitTimeMinutes, 0);
      expect(pickupEstimate.minMinutes, inInclusiveRange(10, 15));
      expect(pickupEstimate.maxMinutes, inInclusiveRange(20, 30));
      expect(pickupEstimate.summary, contains('Ready in ~'));
    });

    test('supports custom base prep time configured by merchant', () {
      final quickShopEstimate = service.calculateEstimate(
        customDistanceKm: 1.0,
        deliveryType: 'Delivery',
        basePrepMinutes: 10,
        pendingOrdersCount: 0,
        currentTime: testTime,
      );

      final artisanShopEstimate = service.calculateEstimate(
        customDistanceKm: 1.0,
        deliveryType: 'Delivery',
        basePrepMinutes: 35,
        pendingOrdersCount: 0,
        currentTime: testTime,
      );

      expect(quickShopEstimate.prepTimeMinutes, 10);
      expect(artisanShopEstimate.prepTimeMinutes, 35);
      expect(artisanShopEstimate.minMinutes, greaterThan(quickShopEstimate.minMinutes));
    });
  });

  group('Feature 46 - UserProvider Integration', () {
    test('getEstimatedDeliveryTime uses user coordinates and active address', () async {
      final provider = UserProvider();
      provider.setStoreLocation(23.259933, 77.412615);

      final address = SavedAddress(
        id: 'addr_test',
        title: 'Home',
        address: 'Bhopal Market',
        houseNo: '10',
        latitude: 23.270000,
        longitude: 77.420000,
        label: 'Home',
      );

      await provider.saveAddressModel(address);
      await provider.selectAddressForCheckout(address);

      final estimate = provider.getEstimatedDeliveryTime(deliveryType: 'Delivery');

      expect(estimate.distanceKm, greaterThan(0.5));
      expect(estimate.minMinutes, greaterThanOrEqualTo(20));
      expect(estimate.maxMinutes, greaterThan(estimate.minMinutes));
      expect(estimate.disclaimer, contains('Not a strict guarantee'));
    });
  });

  group('Feature 46 - AtomicOrderService Storage & Order Retrieval', () {
    test('placeOrderAtomic stores estimated delivery window and metadata in order document', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final orderService = AtomicOrderService(firestore: fakeFirestore);

      // Populate product stock
      final productRef = fakeFirestore.collection('products').doc('prod_rice');
      await productRef.set({
        'name': 'Basmati Rice 1kg',
        'price': 120.0,
        'stock_quantity': 50.0,
      });

      final estimate = DeliveryEstimationService.instance.calculateEstimate(
        customDistanceKm: 2.0,
        basePrepMinutes: 15,
        pendingOrdersCount: 2,
      );

      final params = OrderPlacementParams(
        shopId: 'shop_bhopal_1',
        customerName: 'Aman Verma',
        customerPhone: '9876543210',
        deliveryAddress: 'Flat 302, Arera Hills',
        deliveryType: 'Delivery',
        deliveryFee: 20.0,
        paymentMethod: 'Cash on Delivery',
        idempotencyKey: 'idem_test_delivery_est_101',
        items: [
          OrderItemRequest(
            productId: 'prod_rice',
            name: 'Basmati Rice 1kg',
            quantity: 2.0,
            price: 120.0,
          ),
        ],
        extraData: {
          'estimated_delivery_window': estimate.formattedWindow,
          'estimated_delivery_min_minutes': estimate.minMinutes,
          'estimated_delivery_max_minutes': estimate.maxMinutes,
          'estimated_delivery_arrival_range': estimate.formattedTimeRange,
          'estimated_delivery_disclaimer': estimate.disclaimer,
          'estimated_delivery_details': estimate.toMap(),
        },
      );

      final result = await orderService.placeOrderAtomic(params);

      // Verify order doc contains estimated delivery information
      final orderDoc = await fakeFirestore.collection('orders').doc(result.orderId).get();
      expect(orderDoc.exists, isTrue);

      final orderData = orderDoc.data()!;
      expect(orderData['estimated_delivery_window'], estimate.formattedWindow);
      expect(orderData['estimated_delivery_min_minutes'], estimate.minMinutes);
      expect(orderData['estimated_delivery_max_minutes'], estimate.maxMinutes);
      expect(orderData['estimated_delivery_arrival_range'], estimate.formattedTimeRange);
      expect(orderData['estimated_delivery_disclaimer'], contains('Not a strict guarantee'));
    });
  });

  group('Feature 46 - UI Widget Tests: Estimated Delivery & Disclaimer Presentation', () {
    testWidgets('renders dynamic estimated delivery time and non-guarantee disclaimer at checkout', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final userProvider = UserProvider();
      userProvider.setStoreLocation(23.259933, 77.412615);

      final address = SavedAddress(
        id: 'addr_bhopal_1',
        title: 'Home',
        address: 'MP Nagar Zone 2, Bhopal',
        houseNo: '14-B',
        latitude: 23.262000,
        longitude: 77.415000,
        label: 'Home',
        isDefault: true,
      );
      await userProvider.saveAddressModel(address);
      await userProvider.selectAddressForCheckout(address);

      final cartProvider = CartProvider();
      final shopProvider = ShopProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<UserProvider>.value(value: userProvider),
              ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
              ChangeNotifierProvider<ShopProvider>.value(value: shopProvider),
            ],
            child: Scaffold(
              body: DesktopCheckoutView(
                onBackToCart: () {},
                onOrderPlaced: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify title, window, and disclaimer are displayed
      expect(find.text('Estimated Delivery Time'), findsOneWidget);
      expect(find.textContaining('mins'), findsWidgets);
      expect(find.textContaining('Not a strict guarantee'), findsOneWidget);
    });

    testWidgets('renders Store Pickup mode with store details and free delivery at checkout',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final userProvider = UserProvider();
      final cartProvider = CartProvider();
      final shopProvider = ShopProvider();
      await shopProvider.setShop(
        'shop_123',
        'Gupta Kirana Store',
        address: 'Shop No 4, Main Market, Delhi',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<UserProvider>.value(value: userProvider),
              ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
              ChangeNotifierProvider<ShopProvider>.value(value: shopProvider),
            ],
            child: Scaffold(
              body: DesktopCheckoutView(
                deliveryType: 'Pickup',
                onBackToCart: () {},
                onOrderPlaced: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Store Pickup indicators are displayed
      expect(find.text('Store Pickup'), findsWidgets);
      expect(find.text('Gupta Kirana Store'), findsWidgets);
      expect(find.text('STORE PICKUP'), findsOneWidget);
      expect(find.text('Estimated Pickup Ready Time'), findsOneWidget);
      expect(find.text('Pay at Store'), findsOneWidget);
    });
  });
}

