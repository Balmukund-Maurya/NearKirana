import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:near_kirana/delivery_partner_models.dart';
import 'package:near_kirana/delivery_partner_service.dart';
import 'package:near_kirana/delivery_partner_screen.dart';
import 'package:near_kirana/widgets/assign_delivery_partner_dialog.dart';
import 'package:flutter/services.dart';
import 'package:near_kirana/order_state_machine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (methodCall) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (methodCall) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (methodCall) async => null,
    );
  });

  const testShopId = 'shop_test_101';
  late FakeFirebaseFirestore fakeFirestore;
  late DeliveryPartnerService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeFirestore = FakeFirebaseFirestore();
    service = DeliveryPartnerService(firestore: fakeFirestore);
  });

  group('Feature 58: Domain Models - Delivery Partner & Dispatch Tasks', () {
    test('DeliveryPartnerStatus enum keys, labels, and string parsing', () {
      expect(DeliveryPartnerStatus.available.key, equals('available'));
      expect(DeliveryPartnerStatus.onDelivery.key, equals('onDelivery'));
      expect(DeliveryPartnerStatus.offline.key, equals('offline'));

      expect(DeliveryPartnerStatus.available.label, equals('Available'));
      expect(DeliveryPartnerStatus.onDelivery.label, equals('On Delivery'));
      expect(DeliveryPartnerStatus.offline.label, equals('Offline'));

      expect(DeliveryPartnerStatus.available.hindiLabel, contains('उपलब्ध'));
      expect(DeliveryPartnerStatus.onDelivery.hindiLabel, contains('डिलीवरी'));
      expect(DeliveryPartnerStatus.offline.hindiLabel, contains('ऑफलाइन'));

      expect(DeliveryPartnerStatus.fromString('available'), equals(DeliveryPartnerStatus.available));
      expect(DeliveryPartnerStatus.fromString('active'), equals(DeliveryPartnerStatus.available));
      expect(DeliveryPartnerStatus.fromString('on_delivery'), equals(DeliveryPartnerStatus.onDelivery));
      expect(DeliveryPartnerStatus.fromString('busy'), equals(DeliveryPartnerStatus.onDelivery));
      expect(DeliveryPartnerStatus.fromString('offline'), equals(DeliveryPartnerStatus.offline));
      expect(DeliveryPartnerStatus.fromString(null), equals(DeliveryPartnerStatus.offline));
    });

    test('DeliveryTaskStatus enum keys, labels, and string parsing', () {
      expect(DeliveryTaskStatus.assigned.key, equals('assigned'));
      expect(DeliveryTaskStatus.accepted.key, equals('accepted'));
      expect(DeliveryTaskStatus.pickedUp.key, equals('picked_up'));
      expect(DeliveryTaskStatus.delivered.key, equals('delivered'));
      expect(DeliveryTaskStatus.cancelled.key, equals('cancelled'));

      expect(DeliveryTaskStatus.fromString('assigned'), equals(DeliveryTaskStatus.assigned));
      expect(DeliveryTaskStatus.fromString('accepted'), equals(DeliveryTaskStatus.accepted));
      expect(DeliveryTaskStatus.fromString('picked_up'), equals(DeliveryTaskStatus.pickedUp));
      expect(DeliveryTaskStatus.fromString('out for delivery'), equals(DeliveryTaskStatus.pickedUp));
      expect(DeliveryTaskStatus.fromString('delivered'), equals(DeliveryTaskStatus.delivered));
      expect(DeliveryTaskStatus.fromString('cancelled'), equals(DeliveryTaskStatus.cancelled));
      expect(DeliveryTaskStatus.fromString('unknown'), equals(DeliveryTaskStatus.assigned));
    });

    test('DeliveryPartner toMap and fromMap serialization roundtrip', () {
      final now = DateTime(2026, 10, 14, 13, 0);
      final partner = DeliveryPartner(
        id: 'partner_01',
        shopId: testShopId,
        name: 'Rahul Sharma',
        phone: '9876543210',
        vehicleNumber: 'MP04 AB 1234',
        status: DeliveryPartnerStatus.available,
        activeOrdersCount: 2,
        totalDeliveredCount: 45,
        rating: 4.9,
        cashCollected: 1250.0,
        createdAt: now,
      );

      final map = partner.toMap();
      expect(map['shop_id'], equals(testShopId));
      expect(map['name'], equals('Rahul Sharma'));
      expect(map['phone'], equals('9876543210'));
      expect(map['vehicle_number'], equals('MP04 AB 1234'));
      expect(map['status'], equals('available'));
      expect(map['active_orders_count'], equals(2));
      expect(map['total_delivered_count'], equals(45));
      expect(map['cash_collected'], equals(1250.0));

      final restored = DeliveryPartner.fromMap(map, 'partner_01');
      expect(restored.id, equals('partner_01'));
      expect(restored.name, equals('Rahul Sharma'));
      expect(restored.phone, equals('9876543210'));
      expect(restored.vehicleNumber, equals('MP04 AB 1234'));
      expect(restored.status, equals(DeliveryPartnerStatus.available));
      expect(restored.isOnline, isTrue);
      expect(restored.isAvailable, isTrue);
      expect(restored.activeOrdersCount, equals(2));
      expect(restored.totalDeliveredCount, equals(45));
      expect(restored.cashCollected, equals(1250.0));
    });

    test('DeliveryOrderTask parses items and status flags accurately', () {
      final orderData = {
        'shop_id': testShopId,
        'delivery_boy_id': 'partner_01',
        'delivery_boy_name': 'Rahul Sharma',
        'delivery_boy_phone': '9876543210',
        'customer_name': 'Anita Verma',
        'phone_number': '9123456789',
        'delivery_address': 'Flat 302, Sunrise Heights, Bhopal',
        'total_amount': 750.0,
        'payment_mode': 'COD',
        'payment_status': 'Unpaid',
        'status': 'Out for Delivery',
        'delivery_status': 'picked_up',
        'items': [
          {'name': 'Fortune Oil 1L', 'quantity': 2},
          {'name': 'Sugar 1kg', 'quantity': 1},
        ],
        'delivery_assigned_at': Timestamp.fromDate(DateTime(2026, 10, 14, 13, 10)),
        'delivery_picked_up_at': Timestamp.fromDate(DateTime(2026, 10, 14, 13, 20)),
      };

      final task = DeliveryOrderTask.fromFirestoreDoc(orderData, 'order_999');
      expect(task.orderId, equals('order_999'));
      expect(task.partnerId, equals('partner_01'));
      expect(task.customerName, equals('Anita Verma'));
      expect(task.deliveryAddress, contains('Sunrise Heights'));
      expect(task.totalAmount, equals(750.0));
      expect(task.isCOD, isTrue);
      expect(task.deliveryTaskStatus, equals(DeliveryTaskStatus.pickedUp));
      expect(task.isPickedUp, isTrue);
      expect(task.isDelivered, isFalse);
      expect(task.itemsCount, equals(2));
      expect(task.itemsSummary.first, contains('Fortune Oil'));
    });
  });

  group('Feature 58: DeliveryPartnerService - Operations & Workflows', () {
    test('registerOrUpdatePartner creates and retrieves partner profile', () async {
      final partner = DeliveryPartner(
        id: '',
        shopId: testShopId,
        name: 'Rahul Sharma',
        phone: '9876543210',
        vehicleNumber: 'MP04 AB 1234',
        createdAt: DateTime.now(),
      );

      final saved = await service.registerOrUpdatePartner(partner);
      expect(saved.id, isNotEmpty);
      expect(saved.name, equals('Rahul Sharma'));

      final fetched = await service.getPartner(saved.id);
      expect(fetched, isNotNull);
      expect(fetched!.phone, equals('9876543210'));
      expect(fetched.vehicleNumber, equals('MP04 AB 1234'));

      final byPhone = await service.getPartnerByPhone('9876543210');
      expect(byPhone, isNotNull);
      expect(byPhone!.id, equals(saved.id));
    });

    test('streamShopPartners filters by shopId and sorts by name', () async {
      await service.registerOrUpdatePartner(DeliveryPartner(
        id: 'p1',
        shopId: testShopId,
        name: 'Suresh Patel',
        phone: '9876543211',
        createdAt: DateTime.now(),
      ));

      await service.registerOrUpdatePartner(DeliveryPartner(
        id: 'p2',
        shopId: testShopId,
        name: 'Amit Yadav',
        phone: '9876543212',
        createdAt: DateTime.now(),
      ));

      await service.registerOrUpdatePartner(DeliveryPartner(
        id: 'p3',
        shopId: 'other_shop',
        name: 'Other Shop Partner',
        phone: '9876543213',
        createdAt: DateTime.now(),
      ));

      final shopPartners = await service.streamShopPartners(testShopId).first;
      expect(shopPartners.length, equals(2));
      expect(shopPartners[0].name, equals('Amit Yadav')); // Alphabetical sort
      expect(shopPartners[1].name, equals('Suresh Patel'));
    });

    test('updatePartnerStatus updates status and last_active_at', () async {
      final saved = await service.registerOrUpdatePartner(DeliveryPartner(
        id: 'p_status',
        shopId: testShopId,
        name: 'Raju',
        phone: '9876543215',
        status: DeliveryPartnerStatus.available,
        createdAt: DateTime.now(),
      ));

      await service.updatePartnerStatus(saved.id, DeliveryPartnerStatus.offline);
      final updated = await service.getPartner(saved.id);
      expect(updated!.status, equals(DeliveryPartnerStatus.offline));
      expect(updated.isOnline, isFalse);
    });

    test('End-to-End Workflow: Assign -> Accept -> Store Pickup -> Mark Delivered', () async {
      // 1. Create registered delivery partner
      final partner = await service.registerOrUpdatePartner(DeliveryPartner(
        id: 'partner_rahul',
        shopId: testShopId,
        name: 'Rahul',
        phone: '9876543210',
        vehicleNumber: 'MP04 AB 1234',
        status: DeliveryPartnerStatus.available,
        createdAt: DateTime.now(),
      ));

      // 2. Shopkeeper creates packed order
      final orderRef = fakeFirestore.collection('orders').doc('order_1001');
      await orderRef.set({
        'shop_id': testShopId,
        'customer_name': 'Ramesh Kumar',
        'phone_number': '9988776655',
        'delivery_address': '12 Sector B, Bhopal',
        'total_amount': 500.0,
        'payment_mode': 'COD',
        'payment_status': 'Unpaid',
        'status': OrderStatus.ready,
        'items': [{'name': 'Aashirvaad Atta 5kg', 'quantity': 1}],
      });

      // 3. Shopkeeper assigns order to Rahul
      await service.assignOrderToPartner(
        shopId: testShopId,
        orderId: 'order_1001',
        partner: partner,
        notes: 'Handle with care',
      );

      var orderSnap = await orderRef.get();
      expect(orderSnap.data()!['delivery_boy_id'], equals('partner_rahul'));
      expect(orderSnap.data()!['delivery_boy_name'], equals('Rahul'));
      expect(orderSnap.data()!['delivery_status'], equals('assigned'));
      expect(orderSnap.data()!['delivery_notes'], equals('Handle with care'));

      var partnerSnap = await service.getPartner('partner_rahul');
      expect(partnerSnap!.activeOrdersCount, equals(1));

      // 4. Partner accepts delivery task
      await service.acceptDeliveryTask(
        orderId: 'order_1001',
        partnerId: 'partner_rahul',
      );

      orderSnap = await orderRef.get();
      expect(orderSnap.data()!['delivery_status'], equals('accepted'));

      // 5. Partner confirms store pickup
      await service.confirmStorePickup(
        orderId: 'order_1001',
        partnerId: 'partner_rahul',
        shopId: testShopId,
        customerPhone: '9988776655',
        orderTotal: 500.0,
        partnerName: 'Rahul',
      );

      orderSnap = await orderRef.get();
      expect(orderSnap.data()!['status'], equals(OrderStatus.outForDelivery));
      expect(orderSnap.data()!['delivery_status'], equals('picked_up'));

      partnerSnap = await service.getPartner('partner_rahul');
      expect(partnerSnap!.status, equals(DeliveryPartnerStatus.onDelivery));

      // Verify active task appears in streamPartnerActiveTasks
      final activeTasks = await service.streamPartnerActiveTasks('partner_rahul').first;
      expect(activeTasks.length, equals(1));
      expect(activeTasks.first.orderId, equals('order_1001'));
      expect(activeTasks.first.isPickedUp, isTrue);

      // 6. Partner delivers parcel to customer & collects COD cash
      await service.completeDelivery(
        orderId: 'order_1001',
        partnerId: 'partner_rahul',
        shopId: testShopId,
        codCollected: true,
        codAmount: 500.0,
        completionNotes: 'Handed to customer at door',
        customerPhone: '9988776655',
        orderTotal: 500.0,
        partnerName: 'Rahul',
      );

      orderSnap = await orderRef.get();
      expect(orderSnap.data()!['status'], equals(OrderStatus.delivered));
      expect(orderSnap.data()!['delivery_status'], equals('delivered'));
      expect(orderSnap.data()!['payment_status'], equals('Paid'));
      expect(orderSnap.data()!['cod_collected_by_partner'], isTrue);
      expect(orderSnap.data()!['cod_amount_collected'], equals(500.0));

      partnerSnap = await service.getPartner('partner_rahul');
      expect(partnerSnap!.activeOrdersCount, equals(0));
      expect(partnerSnap.totalDeliveredCount, equals(1));
      expect(partnerSnap.cashCollected, equals(500.0));
      expect(partnerSnap.status, equals(DeliveryPartnerStatus.available));

      // Active tasks stream should now be empty and history should have 1 entry
      final remainingActive = await service.streamPartnerActiveTasks('partner_rahul').first;
      expect(remainingActive, isEmpty);

      final completedTasks = await service.streamPartnerCompletedTasks('partner_rahul').first;
      expect(completedTasks.length, equals(1));
      expect(completedTasks.first.orderId, equals('order_1001'));
    });
  });

  group('Feature 58: UI Widgets - Dialogs & Screens', () {
    testWidgets('AssignDeliveryPartnerDialog renders and assigns partner', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Pre-populate a partner
      await service.registerOrUpdatePartner(DeliveryPartner(
        id: 'p_rahul',
        shopId: testShopId,
        name: 'Rahul Sharma',
        phone: '9876543210',
        vehicleNumber: 'MP04 AB 1234',
        status: DeliveryPartnerStatus.available,
        createdAt: DateTime.now(),
      ));

      final orderData = {
        'customer_name': 'Anita Verma',
        'delivery_address': 'Flat 302, Sunrise Heights',
        'total_amount': 450.0,
        'status': 'Ready',
      };
      await fakeFirestore.collection('orders').doc('order_test_1').set(orderData);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  AssignDeliveryPartnerDialog.show(
                    context: ctx,
                    orderId: 'order_test_1',
                    shopId: testShopId,
                    orderData: orderData,
                    service: service,
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Check header and order details
      expect(find.text('Assign Delivery Partner'), findsOneWidget);
      expect(find.textContaining('Anita Verma'), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsOneWidget);

      // Select Rahul
      await tester.tap(find.text('Rahul Sharma'));
      await tester.pumpAndSettle();

      // Tap Assign
      expect(find.text('Assign to Rahul Sharma'), findsOneWidget);
      await tester.tap(find.text('Assign to Rahul Sharma'));
      await tester.pumpAndSettle();

      // Verify dialog dismissed and order was updated in fakeFirestore
      expect(find.text('Assign Delivery Partner'), findsNothing);
      final doc = await fakeFirestore.collection('orders').doc('order_test_1').get();
      expect(doc.data()!['delivery_boy_id'], equals('p_rahul'));
      expect(doc.data()!['delivery_boy_name'], equals('Rahul Sharma'));
    });

    testWidgets('DeliveryPartnerScreen renders duty toggle and active tasks', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final partner = await service.registerOrUpdatePartner(DeliveryPartner(
        id: 'partner_hero',
        shopId: testShopId,
        name: 'Vikas Kumar',
        phone: '9876543222',
        vehicleNumber: 'MP04 XY 9999',
        status: DeliveryPartnerStatus.available,
        createdAt: DateTime.now(),
      ));

      // Add active assigned order
      await fakeFirestore.collection('orders').doc('order_live_1').set({
        'shop_id': testShopId,
        'delivery_boy_id': 'partner_hero',
        'delivery_boy_name': 'Vikas Kumar',
        'delivery_boy_phone': '9876543222',
        'customer_name': 'Sunil Gupta',
        'phone_number': '9888877777',
        'delivery_address': 'Shop 4, Market Road, Bhopal',
        'total_amount': 320.0,
        'payment_mode': 'COD',
        'payment_status': 'Unpaid',
        'status': 'Ready',
        'delivery_status': 'assigned',
        'items': [{'name': 'Milk 500ml', 'quantity': 2}],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: DeliveryPartnerScreen(
            initialPartnerId: partner.id,
            service: service,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check partner details rendered
      expect(find.text('Vikas Kumar'), findsOneWidget);
      expect(find.text('On Duty'), findsOneWidget);
      expect(find.text('Active Tasks'), findsOneWidget);

      // Check order card rendered
      expect(find.text('Sunil Gupta'), findsOneWidget);
      expect(find.textContaining('Market Road'), findsOneWidget);
      expect(find.text('Accept Delivery Task (स्वीकार करें)'), findsOneWidget);

      // Accept task
      await tester.tap(find.text('Accept Delivery Task (स्वीकार करें)'));
      await tester.pumpAndSettle();

      // Button should transition to Store Pickup confirmation
      expect(find.text('Confirm Store Pickup (दुकान से पार्सल लिया)'), findsOneWidget);

      // Confirm Pickup
      await tester.tap(find.text('Confirm Store Pickup (दुकान से पार्सल लिया)'));
      await tester.pumpAndSettle();

      // Button should now allow marking delivered
      expect(find.textContaining('Mark Delivered'), findsOneWidget);
    });
  });
}
