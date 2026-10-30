import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:near_kirana/cart_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feature: CartProvider Business Logic & Precision Tests', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      fakeFirestore = FakeFirebaseFirestore();
      FirebaseUtils.setFirestore(fakeFirestore);
    });

    test('CartItem serialization to and from JSON preserves data types', () {
      final item = CartItem(
        id: 'prod_1',
        name: 'Sugar (Loose)',
        price: 42.50,
        isLoose: true,
        maxStock: 50.0,
        quantity: 1.5,
        imageUrl: 'https://example.com/sugar.jpg',
      );

      final json = item.toJson();
      expect(json['id'], equals('prod_1'));
      expect(json['name'], equals('Sugar (Loose)'));
      expect(json['price'], equals(42.50));
      expect(json['isLoose'], isTrue);
      expect(json['maxStock'], equals(50.0));
      expect(json['quantity'], equals(1.5));
      expect(json['imageUrl'], equals('https://example.com/sugar.jpg'));

      final fromJson = CartItem.fromJson(json);
      expect(fromJson.id, equals(item.id));
      expect(fromJson.name, equals(item.name));
      expect(fromJson.price, equals(item.price));
      expect(fromJson.isLoose, equals(item.isLoose));
      expect(fromJson.quantity, equals(item.quantity));
    });

    test('addItem adds packaged item with quantity 1.0 and loose item with quantity 0.5', () {
      final provider = CartProvider();

      // 1. Packaged item
      final success1 = provider.addItem('biscuit_1', 'Parle-G', 10.0, false, 20.0);
      expect(success1, isTrue);
      expect(provider.items['biscuit_1']?.quantity, equals(1.0));
      expect(provider.itemCount, equals(1));

      // 2. Loose item
      final success2 = provider.addItem('dal_1', 'Toor Dal (Loose)', 120.0, true, 25.0);
      expect(success2, isTrue);
      expect(provider.items['dal_1']?.quantity, equals(0.5));
      expect(provider.items.length, equals(2));
    });

    test('addItem increments existing item by 1.0 for packaged and 0.5 for loose', () {
      final provider = CartProvider();

      provider.addItem('loose_sugar', 'Sugar', 40.0, true, 10.0);
      expect(provider.items['loose_sugar']?.quantity, equals(0.5));

      // Increment loose
      provider.addItem('loose_sugar', 'Sugar', 40.0, true, 10.0);
      expect(provider.items['loose_sugar']?.quantity, equals(1.0));

      provider.addItem('soap_1', 'Dettol Soap', 35.0, false, 5.0);
      expect(provider.items['soap_1']?.quantity, equals(1.0));

      // Increment packaged
      provider.addItem('soap_1', 'Dettol Soap', 35.0, false, 5.0);
      expect(provider.items['soap_1']?.quantity, equals(2.0));
    });

    test('addItem respects maxStock ceiling', () {
      final provider = CartProvider();

      // Only 1 item in stock
      provider.addItem('limited_oil', 'Mustard Oil 1L', 150.0, false, 1.0);
      expect(provider.items['limited_oil']?.quantity, equals(1.0));

      // Second attempt exceeds stock
      final added = provider.addItem('limited_oil', 'Mustard Oil 1L', 150.0, false, 1.0);
      expect(added, isFalse);
      expect(provider.items['limited_oil']?.quantity, equals(1.0));
    });

    test('updateQuantity handles fractional additions without floating point rounding artifacts', () {
      final provider = CartProvider();
      provider.addItem('loose_wheat', 'Sharbati Wheat', 32.0, true, 100.0);

      // Add 0.25 kg increments
      provider.updateQuantity('loose_wheat', 0.25);
      expect(provider.items['loose_wheat']?.quantity, equals(0.75));

      provider.updateQuantity('loose_wheat', 0.25);
      expect(provider.items['loose_wheat']?.quantity, equals(1.0));

      // Decrease by 0.5
      provider.updateQuantity('loose_wheat', -0.5);
      expect(provider.items['loose_wheat']?.quantity, equals(0.5));

      // Decrease past 0 removes item
      provider.updateQuantity('loose_wheat', -0.5);
      expect(provider.items.containsKey('loose_wheat'), isFalse);
    });

    test('cartTotal correctly rounds total to 2 decimal places for fractional Kirana quantities', () {
      final provider = CartProvider();

      // 0.75 kg of Rice at ₹63.50/kg = 47.625 => ₹47.63
      provider.addItem('rice_loose', 'Basmati Rice', 63.50, true, 50.0);
      provider.setQuantity('rice_loose', 0.75);

      // 1 packet of Tea at ₹99.00
      provider.addItem('tea_1', 'Tata Tea', 99.00, false, 10.0);

      // Total = 47.625 + 99.00 = 146.625 => 146.63
      expect(provider.cartTotal, equals(146.63));
    });

    test('syncPricesWithServer updates live prices and removes ghost items with 0 stock', () async {
      final provider = CartProvider();

      // Seed product catalog in fake Firestore
      await fakeFirestore.collection('products').doc('rice_1').set({
        'price': 70.0, // Price updated from 60 to 70
        'stock_quantity': 15.0,
      });

      await fakeFirestore.collection('products').doc('oil_1').set({
        'price': 140.0,
        'stock_quantity': 0.0, // Out of stock
      });

      provider.addItem('rice_1', 'Rice', 60.0, true, 20.0);
      provider.addItem('oil_1', 'Refined Oil', 140.0, false, 5.0);

      expect(provider.items['rice_1']?.price, equals(60.0));
      expect(provider.items.containsKey('oil_1'), isTrue);

      await provider.syncPricesWithServer();

      // Rice price updated to 70.0
      expect(provider.items['rice_1']?.price, equals(70.0));
      // Out of stock item oil_1 removed
      expect(provider.items.containsKey('oil_1'), isFalse);
    });

    test('clearCart removes all items from cart', () {
      final provider = CartProvider();
      provider.addItem('p1', 'Atta', 250.0, false, 10.0);
      provider.addItem('p2', 'Sugar', 45.0, true, 50.0);

      expect(provider.items.length, equals(2));

      provider.clearCart();

      expect(provider.items, isEmpty);
      expect(provider.cartTotal, equals(0.0));
      expect(provider.itemCount, equals(0));
    });
  });
}
