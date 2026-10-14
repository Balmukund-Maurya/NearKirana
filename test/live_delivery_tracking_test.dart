import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:near_kirana/live_delivery_tracking_models.dart';
import 'package:near_kirana/live_delivery_tracking_service.dart';
import 'package:near_kirana/customer_live_tracking_screen.dart';

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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geolocator'),
      (methodCall) async {
        if (methodCall.method == 'isLocationServiceEnabled') return true;
        if (methodCall.method == 'checkPermission') return 3; // whileInUse
        if (methodCall.method == 'requestPermission') return 3;
        return null;
      },
    );
  });

  late FakeFirebaseFirestore fakeFirestore;
  late LiveDeliveryTrackingService trackingService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeFirestore = FakeFirebaseFirestore();
    trackingService = LiveDeliveryTrackingService(
      firestore: fakeFirestore,
      minUpdateIntervalSeconds: 0,
      minUpdateDistanceMeters: 0,
    );
  });

  group('Feature 59: Domain Models - Live Delivery Tracking', () {
    test('LiveTrackingStatus enum parsing and labels', () {
      expect(LiveTrackingStatus.transit.key, equals('in_transit'));
      expect(LiveTrackingStatus.nearby.key, equals('nearby'));
      expect(LiveTrackingStatus.delivered.key, equals('delivered'));
      expect(LiveTrackingStatus.ended.key, equals('ended'));

      expect(LiveTrackingStatus.transit.label, contains('रास्ते में'));
      expect(LiveTrackingStatus.nearby.label, contains('आस-पास'));
      expect(LiveTrackingStatus.delivered.label, contains('पूरी हुई'));

      expect(LiveTrackingStatus.fromString('in_transit'), equals(LiveTrackingStatus.transit));
      expect(LiveTrackingStatus.fromString('nearby'), equals(LiveTrackingStatus.nearby));
      expect(LiveTrackingStatus.fromString('arrived_nearby'), equals(LiveTrackingStatus.nearby));
      expect(LiveTrackingStatus.fromString('delivered'), equals(LiveTrackingStatus.delivered));
      expect(LiveTrackingStatus.fromString('ended'), equals(LiveTrackingStatus.ended));
      expect(LiveTrackingStatus.fromString('cancelled'), equals(LiveTrackingStatus.ended));
    });

    test('DeliveryLocationPoint serialization roundtrip', () {
      final now = DateTime(2026, 10, 14, 12, 0);
      final point = DeliveryLocationPoint(
        latitude: 28.6139,
        longitude: 77.2090,
        heading: 90.0,
        speedMps: 6.5,
        accuracyMeters: 4.0,
        timestamp: now,
      );

      final map = point.toMap();
      expect(map['latitude'], equals(28.6139));
      expect(map['longitude'], equals(77.2090));
      expect(map['heading'], equals(90.0));
      expect(map['speed_mps'], equals(6.5));
      expect(map['accuracy_meters'], equals(4.0));
      expect(map['timestamp'], isA<Timestamp>());

      final restored = DeliveryLocationPoint.fromMap(map);
      expect(restored.latitude, equals(28.6139));
      expect(restored.longitude, equals(77.2090));
      expect(restored.heading, equals(90.0));
      expect(restored.speedMps, equals(6.5));
    });

    test('LiveTrackingSession formatting and proximity getters', () {
      final now = DateTime(2026, 10, 14, 12, 0);
      final session = LiveTrackingSession(
        orderId: 'ORD-999',
        partnerId: 'partner-1',
        partnerName: 'Rahul Sharma',
        partnerPhone: '9876543210',
        partnerVehicle: 'DL 01 AB 1234',
        shopId: 'shop-1',
        customerPhone: '9123456780',
        customerName: 'Amit Verma',
        customerAddress: 'Flat 101, Sector 4, Noida',
        customerLat: 28.5355,
        customerLng: 77.3910,
        distanceRemainingMeters: 850,
        estimatedMinutesRemaining: 5,
        status: LiveTrackingStatus.transit,
        sessionStartedAt: now,
        lastUpdatedAt: now,
      );

      expect(session.isNearby, isFalse);
      expect(session.formattedDistance, equals('850 m'));
      expect(session.formattedEta, equals('5 mins'));

      // Test kilometer formatting
      final farSession = session.copyWith(
        distanceRemainingMeters: 2400,
        estimatedMinutesRemaining: 12,
      );
      expect(farSession.formattedDistance, equals('2.4 km'));
      expect(farSession.formattedEta, equals('12 mins'));

      // Test proximity threshold (<= 180m)
      final nearbySession = session.copyWith(
        distanceRemainingMeters: 120,
        status: LiveTrackingStatus.nearby,
      );
      expect(nearbySession.isNearby, isTrue);
      expect(nearbySession.formattedEta, contains('पहुंचने वाले हैं'));

      // Test delivered state
      final deliveredSession = session.copyWith(
        status: LiveTrackingStatus.delivered,
      );
      expect(deliveredSession.formattedEta, equals('Delivered'));
    });

    test('LiveTrackingSession toMap and fromMap serialization roundtrip', () {
      final now = DateTime(2026, 10, 14, 12, 0);
      final session = LiveTrackingSession(
        orderId: 'ORD-888',
        partnerId: 'partner-1',
        partnerName: 'Rahul Sharma',
        partnerPhone: '9876543210',
        partnerVehicle: 'DL 01 AB 1234',
        shopId: 'shop-1',
        shopName: 'Aditya Kirana',
        shopLat: 28.5300,
        shopLng: 77.3900,
        customerPhone: '9123456780',
        customerName: 'Amit Verma',
        customerAddress: 'Noida Sector 4',
        customerLat: 28.5355,
        customerLng: 77.3910,
        currentLocation: DeliveryLocationPoint(
          latitude: 28.5320,
          longitude: 77.3905,
          timestamp: now,
        ),
        breadcrumbs: [
          DeliveryLocationPoint(
            latitude: 28.5310,
            longitude: 77.3902,
            timestamp: now.subtract(const Duration(seconds: 30)),
          ),
        ],
        isActive: true,
        status: LiveTrackingStatus.transit,
        distanceRemainingMeters: 450,
        estimatedMinutesRemaining: 3,
        sessionStartedAt: now,
        lastUpdatedAt: now,
      );

      final map = session.toMap();
      expect(map['order_id'], equals('ORD-888'));
      expect(map['partner_name'], equals('Rahul Sharma'));
      expect(map['is_active'], isTrue);
      expect(map['status'], equals('in_transit'));
      expect((map['breadcrumbs'] as List).length, equals(1));

      final restored = LiveTrackingSession.fromMap(map, 'ORD-888');
      expect(restored.orderId, equals('ORD-888'));
      expect(restored.partnerName, equals('Rahul Sharma'));
      expect(restored.currentLocation?.latitude, equals(28.5320));
      expect(restored.breadcrumbs.length, equals(1));
      expect(restored.isActive, isTrue);
    });
  });

  group('Feature 59: LiveDeliveryTrackingService Operations', () {
    test('startBroadcasting initializes Firestore session document', () async {
      final controller = StreamController<Position>.broadcast();

      final started = await trackingService.startBroadcasting(
        orderId: 'ORD-TEST-1',
        partnerId: 'partner-101',
        partnerName: 'Vikram',
        partnerPhone: '9988776655',
        partnerVehicle: 'UP 16 Z 9999',
        shopId: 'shop-1',
        customerPhone: '9123456780',
        customerName: 'Sanjay Gupta',
        customerAddress: 'House 42, Green Park',
        customerLat: 28.5500,
        customerLng: 77.2000,
        customPositionStreamForTesting: controller.stream,
      );

      expect(started, isTrue);
      expect(trackingService.isBroadcasting, isTrue);
      expect(trackingService.activeBroadcastingOrderId, equals('ORD-TEST-1'));

      final doc = await fakeFirestore.collection('delivery_tracking').doc('ORD-TEST-1').get();
      expect(doc.exists, isTrue);
      final data = doc.data()!;
      expect(data['is_active'], isTrue);
      expect(data['partner_name'], equals('Vikram'));
      expect(data['customer_name'], equals('Sanjay Gupta'));

      await controller.close();
      await trackingService.stopBroadcasting('ORD-TEST-1');
    });

    test('updateManualPosition updates coordinate, distance, and ETA', () async {
      await trackingService.startBroadcasting(
        orderId: 'ORD-TEST-2',
        partnerId: 'partner-101',
        partnerName: 'Vikram',
        partnerPhone: '9988776655',
        shopId: 'shop-1',
        customerPhone: '9123456780',
        customerName: 'Sanjay Gupta',
        customerAddress: 'House 42, Green Park',
        customerLat: 28.5500,
        customerLng: 77.2000,
        customPositionStreamForTesting: const Stream.empty(),
      );

      // Inject position ~1 km away
      await trackingService.updateManualPosition(
        orderId: 'ORD-TEST-2',
        latitude: 28.5410,
        longitude: 77.2000,
        speedMps: 6.0,
        customerLat: 28.5500,
        customerLng: 77.2000,
      );

      final session = await trackingService.getTrackingSession('ORD-TEST-2');
      expect(session, isNotNull);
      expect(session!.currentLocation?.latitude, equals(28.5410));
      expect(session.distanceRemainingMeters, isNotNull);
      expect(session.distanceRemainingMeters!, greaterThan(500));
      expect(session.estimatedMinutesRemaining, isNotNull);
      expect(session.status, equals(LiveTrackingStatus.transit));

      // Also verify order document updated with delivery_location
      final orderDoc = await fakeFirestore.collection('orders').doc('ORD-TEST-2').get();
      expect(orderDoc.exists, isTrue);
      expect(orderDoc.data()?['delivery_location']?['latitude'], equals(28.5410));

      await trackingService.stopBroadcasting('ORD-TEST-2');
    });

    test('Proximity detection triggers nearby status when within 180m', () async {
      await trackingService.startBroadcasting(
        orderId: 'ORD-TEST-3',
        partnerId: 'partner-101',
        partnerName: 'Vikram',
        partnerPhone: '9988776655',
        shopId: 'shop-1',
        customerPhone: '9123456780',
        customerName: 'Sanjay Gupta',
        customerAddress: 'House 42, Green Park',
        customerLat: 28.5500,
        customerLng: 77.2000,
        customPositionStreamForTesting: const Stream.empty(),
      );

      // Inject position very close (~50m away)
      await trackingService.updateManualPosition(
        orderId: 'ORD-TEST-3',
        latitude: 28.5504,
        longitude: 77.2000,
        customerLat: 28.5500,
        customerLng: 77.2000,
      );

      final session = await trackingService.getTrackingSession('ORD-TEST-3');
      expect(session, isNotNull);
      expect(session!.distanceRemainingMeters, lessThanOrEqualTo(180));
      expect(session.status, equals(LiveTrackingStatus.nearby));
      expect(session.isNearby, isTrue);

      await trackingService.stopBroadcasting('ORD-TEST-3');
    });

    test('stopBroadcasting terminates session and updates Firestore', () async {
      await trackingService.startBroadcasting(
        orderId: 'ORD-TEST-4',
        partnerId: 'partner-101',
        partnerName: 'Vikram',
        partnerPhone: '9988776655',
        shopId: 'shop-1',
        customerPhone: '9123456780',
        customerName: 'Sanjay Gupta',
        customerAddress: 'House 42, Green Park',
        customPositionStreamForTesting: const Stream.empty(),
      );

      expect(trackingService.isBroadcasting, isTrue);

      await trackingService.stopBroadcasting('ORD-TEST-4', isDelivered: true);

      expect(trackingService.isBroadcasting, isFalse);
      expect(trackingService.activeBroadcastingOrderId, isNull);

      final session = await trackingService.getTrackingSession('ORD-TEST-4');
      expect(session, isNotNull);
      expect(session!.isActive, isFalse);
      expect(session.status, equals(LiveTrackingStatus.delivered));
      expect(session.sessionEndedAt, isNotNull);
    });

    test('pauseBroadcasting and resumeBroadcasting toggle state', () async {
      await trackingService.startBroadcasting(
        orderId: 'ORD-TEST-5',
        partnerId: 'partner-101',
        partnerName: 'Vikram',
        partnerPhone: '9988776655',
        shopId: 'shop-1',
        customerPhone: '9123456780',
        customerName: 'Sanjay',
        customerAddress: 'Address',
        customPositionStreamForTesting: const Stream.empty(),
      );

      expect(trackingService.isBroadcastingPaused, isFalse);
      trackingService.pauseBroadcasting();
      expect(trackingService.isBroadcastingPaused, isTrue);
      expect(trackingService.isBroadcasting, isFalse);

      trackingService.resumeBroadcasting();
      expect(trackingService.isBroadcastingPaused, isFalse);
      expect(trackingService.isBroadcasting, isTrue);

      await trackingService.stopBroadcasting('ORD-TEST-5');
    });
  });

  group('Feature 59: CustomerLiveTrackingScreen UI Widget Tests', () {
    testWidgets('CustomerLiveTrackingScreen renders top header, live pulse, and bottom card', (tester) async {
      final now = DateTime.now();

      // Seed tracking session in fake firestore
      await fakeFirestore.collection('delivery_tracking').doc('ORD-WIDGET-1').set({
        'order_id': 'ORD-WIDGET-1',
        'partner_id': 'partner-1',
        'partner_name': 'Rahul Sharma',
        'partner_phone': '9876543210',
        'partner_vehicle': 'DL 01 AB 1234',
        'shop_id': 'shop-1',
        'customer_phone': '9123456780',
        'customer_name': 'Amit Verma',
        'customer_address': 'Flat 101, Sector 4, Noida',
        'customer_lat': 28.5355,
        'customer_lng': 77.3910,
        'current_location': {
          'latitude': 28.5320,
          'longitude': 77.3905,
          'timestamp': Timestamp.fromDate(now),
        },
        'is_active': true,
        'status': 'in_transit',
        'distance_remaining_meters': 1200.0,
        'estimated_minutes_remaining': 6,
        'session_started_at': Timestamp.fromDate(now),
        'last_updated_at': Timestamp.fromDate(now),
      });

      await tester.pumpWidget(
        MaterialApp(
          home: CustomerLiveTrackingScreen(
            orderId: 'ORD-WIDGET-1',
            service: trackingService,
            enableTiles: false,
            enableAnimations: false,
            initialOrderData: const {
              'delivery_pin': '4321',
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Verify Top Header
      expect(find.text('Live Delivery Track'), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);

      // 2. Verify Partner Info & Vehicle
      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('वाहन: DL 01 AB 1234'), findsOneWidget);

      // 3. Verify ETA & Distance
      expect(find.textContaining('6 mins (1.2 km)'), findsOneWidget);

      // 4. Verify Delivery PIN pill
      expect(find.text('4321'), findsOneWidget);
      expect(find.text('PIN'), findsOneWidget);

      // 5. Verify Privacy Safeguard Notice
      expect(find.textContaining('गोपनीयता: लोकेशन सिर्फ इस डिलीवरी के दौरान लाइव है'), findsOneWidget);

      // 6. Verify Call Button
      expect(find.text('कॉल करें'), findsOneWidget);
    });

    testWidgets('CustomerLiveTrackingScreen renders Arrived Nearby state correctly', (tester) async {
      final now = DateTime.now();

      await fakeFirestore.collection('delivery_tracking').doc('ORD-WIDGET-2').set({
        'order_id': 'ORD-WIDGET-2',
        'partner_id': 'partner-1',
        'partner_name': 'Rahul Sharma',
        'partner_phone': '9876543210',
        'customer_phone': '9123456780',
        'customer_name': 'Amit Verma',
        'customer_address': 'Sector 4',
        'customer_lat': 28.5355,
        'customer_lng': 77.3910,
        'current_location': {
          'latitude': 28.5350,
          'longitude': 77.3910,
          'timestamp': Timestamp.fromDate(now),
        },
        'is_active': true,
        'status': 'nearby',
        'distance_remaining_meters': 80.0,
        'estimated_minutes_remaining': 1,
        'session_started_at': Timestamp.fromDate(now),
        'last_updated_at': Timestamp.fromDate(now),
      });

      await tester.pumpWidget(
        MaterialApp(
          home: CustomerLiveTrackingScreen(
            orderId: 'ORD-WIDGET-2',
            service: trackingService,
            enableTiles: false,
            enableAnimations: false,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('आस-पास पहुंच गए हैं'), findsWidgets);
      expect(find.textContaining('कृपया पार्सल रिसीव करने के लिए तैयार रहें'), findsOneWidget);
    });

    testWidgets('CustomerLiveTrackingScreen renders Delivered completed state', (tester) async {
      final now = DateTime.now();

      await fakeFirestore.collection('delivery_tracking').doc('ORD-WIDGET-3').set({
        'order_id': 'ORD-WIDGET-3',
        'partner_id': 'partner-1',
        'partner_name': 'Rahul Sharma',
        'partner_phone': '9876543210',
        'customer_phone': '9123456780',
        'customer_name': 'Amit Verma',
        'customer_address': 'Sector 4',
        'is_active': false,
        'status': 'delivered',
        'session_started_at': Timestamp.fromDate(now),
        'last_updated_at': Timestamp.fromDate(now),
        'session_ended_at': Timestamp.fromDate(now),
      });

      await tester.pumpWidget(
        MaterialApp(
          home: CustomerLiveTrackingScreen(
            orderId: 'ORD-WIDGET-3',
            service: trackingService,
            enableTiles: false,
            enableAnimations: false,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('ENDED'), findsOneWidget);
      expect(find.text('डिलीवरी सफल हुई'), findsOneWidget);
      expect(find.text('आपका सामान सुरक्षित डिलीवर हो चुका है'), findsOneWidget);
    });
  });
}
