import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:near_kirana/language_provider.dart';
import 'package:near_kirana/shop_provider.dart';
import 'package:near_kirana/admin_order_card.dart';
import 'package:near_kirana/order_state_machine.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeFirestore;
  late ShopProvider shopProvider;
  late LanguageProvider languageProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakeFirestore = FakeFirebaseFirestore();
    FirebaseUtils.setFirestore(fakeFirestore);

    shopProvider = ShopProvider();
    await shopProvider.setShop('SHOP_TEST_01', 'Aggarwal Kirana Store');

    languageProvider = LanguageProvider();
  });

  Widget createTestWidget(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ShopProvider>.value(value: shopProvider),
        ChangeNotifierProvider<LanguageProvider>.value(value: languageProvider),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: child,
          ),
        ),
      ),
    );
  }

  group('Feature: AdminOrderCard Component & Integration Tests', () {
    testWidgets('renders order customer details, items, and total amount', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final orderRef = fakeFirestore.collection('orders').doc('ORD_TEST_99');
      await orderRef.set({
        'shop_id': 'SHOP_TEST_01',
        'customer_name': 'Sanjay Gupta',
        'phone_number': '9876543210',
        'delivery_address': 'Flat 101, Shanti Kunj',
        'total_amount': 350.0,
        'payment_method': 'Cash on Delivery',
        'payment_status': 'Unpaid',
        'delivery_type': 'Delivery',
        'status': OrderStatus.pending,
        'delivery_pin': '4821',
        'items': [
          {'name': 'Fortune Sunlite Oil 1L', 'quantity': 2, 'price': 140.0},
          {'name': 'Tata Salt 1kg', 'quantity': 1, 'price': 28.0},
        ],
      });

      final snapshot = await orderRef.get();

      await tester.pumpWidget(createTestWidget(AdminOrderCard(orderDoc: snapshot)));
      await tester.pumpAndSettle();

      // Verify customer details
      expect(find.textContaining('Sanjay Gupta'), findsOneWidget);
      expect(find.textContaining('9876543210'), findsWidgets);
      expect(find.textContaining('₹350'), findsWidgets);

      // Expand items accordion
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      // Verify items summary
      expect(find.textContaining('Fortune Sunlite Oil 1L'), findsOneWidget);
      expect(find.textContaining('Tata Salt 1kg'), findsOneWidget);

      // Verify Progressive Button shows 'Accept Order' for pending status
      expect(find.textContaining('Accept Order'), findsOneWidget);
    });

    testWidgets('renders rider assignment banner when delivery partner is assigned', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final orderRef = fakeFirestore.collection('orders').doc('ORD_RIDER_01');
      await orderRef.set({
        'shop_id': 'SHOP_TEST_01',
        'customer_name': 'Meena Sharma',
        'phone_number': '9811122233',
        'delivery_address': 'House 14, Sector 7',
        'total_amount': 220.0,
        'payment_method': 'UPI',
        'payment_status': 'Paid',
        'delivery_type': 'Delivery',
        'status': OrderStatus.outForDelivery,
        'delivery_pin': '1934',
        'delivery_boy_id': 'rider_vansh',
        'delivery_boy_name': 'Vansh Rider',
        'delivery_boy_phone': '9988776655',
        'delivery_status': 'out_for_delivery',
        'items': [
          {'name': 'Aashirvaad Atta 5kg', 'quantity': 1, 'price': 220.0},
        ],
      });

      final snapshot = await orderRef.get();

      await tester.pumpWidget(createTestWidget(AdminOrderCard(orderDoc: snapshot)));
      await tester.pumpAndSettle();

      // Verify rider banner appears
      expect(find.textContaining('Vansh Rider'), findsOneWidget);
      expect(find.textContaining('9988776655'), findsWidgets);

      // Verify Paid online badge
      expect(find.textContaining('Paid'), findsWidgets);

      // Out for Delivery shows Complete / Verify action
      expect(find.textContaining('Complete'), findsWidgets);
    });
  });
}
