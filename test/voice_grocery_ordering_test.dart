// Unit and Widget tests for Feature 61: Voice-Based Grocery Ordering (वॉइस-बेस्ड ग्रॉसरी ऑर्डरिंग)

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:near_kirana/cart_provider.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:near_kirana/shop_provider.dart';
import 'package:near_kirana/user_provider.dart';
import 'package:near_kirana/sound_service.dart';
import 'package:near_kirana/voice_order_models.dart';
import 'package:near_kirana/voice_order_parser.dart';
import 'package:near_kirana/voice_order_service.dart';
import 'package:near_kirana/widgets/voice_order_sheet.dart';

void main() {
  group('Feature 61: Voice Order Parser - Hindi/Hinglish/English NLP', () {
    final catalog = [
      const VoiceCatalogProduct(
        id: 'p_atta_5kg',
        name: 'Aashirvaad Shudh Chakki Atta 5kg',
        price: 245.0,
        stockQuantity: 10.0,
        isLoose: false,
        unit: 'kg',
        category: 'Atta & Flours',
        searchKeywords: ['atta', 'aashirvaad', 'flour', 'chakki'],
      ),
      const VoiceCatalogProduct(
        id: 'p_milk_amul_taaza',
        name: 'Amul Taaza Toned Milk 500ml',
        price: 27.0,
        stockQuantity: 20.0,
        isLoose: false,
        unit: '500ml',
        category: 'Dairy',
        searchKeywords: ['milk', 'doodh', 'amul', 'taaza'],
      ),
      const VoiceCatalogProduct(
        id: 'p_milk_amul_gold',
        name: 'Amul Gold Full Cream Milk 500ml',
        price: 33.0,
        stockQuantity: 15.0,
        isLoose: false,
        unit: '500ml',
        category: 'Dairy',
        searchKeywords: ['milk', 'doodh', 'amul', 'gold'],
      ),
      const VoiceCatalogProduct(
        id: 'p_sugar_loose',
        name: 'Madhur Pure Sugar',
        price: 44.0,
        stockQuantity: 50.0,
        isLoose: true,
        unit: 'kg',
        category: 'Staples',
        searchKeywords: ['sugar', 'cheeni', 'shakkar'],
      ),
      const VoiceCatalogProduct(
        id: 'p_paneer_fresh',
        name: 'Fresh Malai Paneer',
        price: 360.0,
        stockQuantity: 15.0,
        isLoose: true,
        unit: 'kg',
        category: 'Dairy',
        searchKeywords: ['paneer', 'cottage cheese'],
      ),
      const VoiceCatalogProduct(
        id: 'p_tamatar',
        name: 'Fresh Desi Tamatar',
        price: 40.0,
        stockQuantity: 25.0,
        isLoose: true,
        unit: 'kg',
        category: 'Vegetables',
        searchKeywords: ['tamatar', 'tomato'],
      ),
      const VoiceCatalogProduct(
        id: 'p_maggi_noodles',
        name: 'Maggi 2-Minute Masala Noodles',
        price: 14.0,
        stockQuantity: 40.0,
        isLoose: false,
        unit: 'packet',
        category: 'Snacks',
        searchKeywords: ['maggi', 'noodles', 'masala'],
      ),
      const VoiceCatalogProduct(
        id: 'p_bread_white',
        name: 'Harvest Gold White Bread',
        price: 45.0,
        stockQuantity: 8.0,
        isLoose: false,
        unit: 'packet',
        category: 'Bakery',
        searchKeywords: ['bread', 'pav', 'loaf'],
      ),
      const VoiceCatalogProduct(
        id: 'p_salt_tata',
        name: 'Tata Salt Vacuum Evaporated 1kg',
        price: 28.0,
        stockQuantity: 0.0, // Out of stock
        isLoose: false,
        unit: 'kg',
        category: 'Staples',
        searchKeywords: ['salt', 'namak', 'tata salt'],
      ),
    ];

    test('Parses classic user example: "Do kilo atta aur ek litre doodh add karo"', () {
      final result = VoiceOrderParser.parseSpokenOrder(
        spokenText: 'Do kilo atta aur ek litre doodh add karo',
        catalog: catalog,
      );

      expect(result.parsedItems.length, 2);
      expect(result.detectedLanguage, 'Hinglish');

      // Item 1: Atta
      final attaItem = result.parsedItems[0];
      expect(attaItem.rawItemName.toLowerCase(), contains('atta'));
      expect(attaItem.requestedQuantity, 2.0);
      expect(attaItem.unit, 'kg');
      expect(attaItem.matchedProduct?.id, 'p_atta_5kg');
      expect(attaItem.status, VoiceItemStatus.ready);

      // Item 2: Milk (Multiple matching milk brands -> ambiguous)
      final milkItem = result.parsedItems[1];
      expect(milkItem.rawItemName.toLowerCase(), contains('doodh'));
      expect(milkItem.unit, 'litre');
      expect(milkItem.status, VoiceItemStatus.ambiguous);
      expect(milkItem.candidateProducts.length, greaterThanOrEqualTo(2));
      expect(
        milkItem.candidateProducts.map((p) => p.name),
        containsAll([
          'Amul Taaza Toned Milk 500ml',
          'Amul Gold Full Cream Milk 500ml',
        ]),
      );
    });

    test('Parses fractional quantities: aadha kilo, paav, dedh, dhai', () {
      // 1. aadha kilo (0.5 kg)
      final r1 = VoiceOrderParser.parseSpokenOrder(
        spokenText: 'aadha kilo tamatar',
        catalog: catalog,
      );
      expect(r1.parsedItems.length, 1);
      expect(r1.parsedItems[0].requestedQuantity, 0.5);
      expect(r1.parsedItems[0].finalQuantity, 0.5);
      expect(r1.parsedItems[0].matchedProduct?.id, 'p_tamatar');

      // 2. 500 gram paneer (loose item -> 0.5 kg)
      final r2 = VoiceOrderParser.parseSpokenOrder(
        spokenText: '500 gram paneer',
        catalog: catalog,
      );
      expect(r2.parsedItems.length, 1);
      expect(r2.parsedItems[0].requestedQuantity, 500.0);
      expect(r2.parsedItems[0].finalQuantity, 0.5); // Converted 500g to 0.5kg
      expect(r2.parsedItems[0].matchedProduct?.id, 'p_paneer_fresh');

      // 3. dedh kilo (1.5 kg)
      final r3 = VoiceOrderParser.parseSpokenOrder(
        spokenText: 'dedh kilo cheeni',
        catalog: catalog,
      );
      expect(r3.parsedItems.length, 1);
      expect(r3.parsedItems[0].requestedQuantity, 1.5);
      expect(r3.parsedItems[0].matchedProduct?.id, 'p_sugar_loose');

      // 4. dhai kilo (2.5 kg)
      final r4 = VoiceOrderParser.parseSpokenOrder(
        spokenText: 'dhai kilo cheeni',
        catalog: catalog,
      );
      expect(r4.parsedItems.length, 1);
      expect(r4.parsedItems[0].requestedQuantity, 2.5);
    });

    test('Strips common action fillers and polite words', () {
      final r = VoiceOrderParser.parseSpokenOrder(
        spokenText: 'kripya 2 packet maggi cart me daal do aur humko 1 kg cheeni chahiye',
        catalog: catalog,
      );

      expect(r.parsedItems.length, 2);
      expect(r.parsedItems[0].matchedProduct?.id, 'p_maggi_noodles');
      expect(r.parsedItems[0].requestedQuantity, 2.0);

      expect(r.parsedItems[1].matchedProduct?.id, 'p_sugar_loose');
      expect(r.parsedItems[1].requestedQuantity, 1.0);
    });

    test('Detects out-of-stock items cleanly', () {
      final r = VoiceOrderParser.parseSpokenOrder(
        spokenText: '1 packet namak',
        catalog: catalog,
      );

      expect(r.parsedItems.length, 1);
      expect(r.parsedItems[0].status, VoiceItemStatus.outOfStock);
      expect(r.parsedItems[0].matchedProduct?.id, 'p_salt_tata');
      expect(r.parsedItems[0].isReadyToAdd, isFalse);
    });

    test('Handles items not found in store catalog', () {
      final r = VoiceOrderParser.parseSpokenOrder(
        spokenText: '2 kilo dragonfruit',
        catalog: catalog,
      );

      expect(r.parsedItems.length, 1);
      expect(r.parsedItems[0].status, VoiceItemStatus.notFound);
      expect(r.parsedItems[0].matchedProduct, isNull);
      expect(r.parsedItems[0].isReadyToAdd, isFalse);
    });

    test('Disambiguation resolution allows user to select specific candidate', () {
      final r = VoiceOrderParser.parseSpokenOrder(
        spokenText: 'ek packet doodh',
        catalog: catalog,
      );

      expect(r.parsedItems.length, 1);
      final ambiguousItem = r.parsedItems[0];
      expect(ambiguousItem.status, VoiceItemStatus.ambiguous);
      expect(ambiguousItem.isReadyToAdd, isFalse);

      // Customer picks Amul Gold
      final chosenCandidate = ambiguousItem.candidateProducts.firstWhere(
        (p) => p.name.contains('Gold'),
      );
      final resolvedItem = ambiguousItem.copyWith(
        selectedProduct: chosenCandidate,
        status: VoiceItemStatus.ready,
      );

      expect(resolvedItem.effectiveProduct?.id, 'p_milk_amul_gold');
      expect(resolvedItem.status, VoiceItemStatus.ready);
      expect(resolvedItem.isReadyToAdd, isTrue);
      expect(resolvedItem.effectivePrice, 33.0);
    });
  });

  group('Feature 61: VoiceOrderService Integration Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late VoiceOrderService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SoundService().setEnabled(false);
      SoundService().setHapticsEnabled(false);
      fakeFirestore = FakeFirebaseFirestore();
      FirebaseUtils.setFirestore(fakeFirestore);
      service = VoiceOrderService(firestore: fakeFirestore);
    });

    test('fetchCatalog loads and filters active store products', () async {
      await fakeFirestore.collection('products').doc('p1').set({
        'name': 'Aashirvaad Atta 5kg',
        'price': 250.0,
        'stock_quantity': 5.0,
        'shop_id': 'shop_abc',
        'is_loose': false,
        'searchKeywords': ['atta', 'flour'],
      });
      await fakeFirestore.collection('products').doc('p2').set({
        'name': 'Other Shop Product',
        'price': 100.0,
        'stock_quantity': 10.0,
        'shop_id': 'shop_xyz',
      });

      final products = await service.fetchCatalog('shop_abc');
      expect(products.length, 1);
      expect(products.first.id, 'p1');
      expect(products.first.name, 'Aashirvaad Atta 5kg');
      expect(products.first.price, 250.0);
    });

    test('addItemsToCart commits parsed voice items to CartProvider with correct quantities', () {
      final cartProvider = CartProvider();
      const product = VoiceCatalogProduct(
        id: 'p_atta_loose',
        name: 'Fresh Chakki Atta',
        price: 35.0,
        stockQuantity: 100.0,
        isLoose: true,
      );

      final items = [
        const ParsedVoiceItem(
          rawSegment: '2 kilo atta',
          rawItemName: 'atta',
          requestedQuantity: 2.0,
          matchedProduct: product,
          status: VoiceItemStatus.ready,
          finalQuantity: 2.0,
        ),
      ];

      final count = service.addItemsToCart(
        cartProvider: cartProvider,
        items: items,
      );

      expect(count, 1);
      expect(cartProvider.items.containsKey('p_atta_loose'), isTrue);
      expect(cartProvider.items['p_atta_loose']!.quantity, 2.0);
      expect(cartProvider.cartTotal, 70.0);
    });

    test('saveVoiceOrderLog saves audit record in Firestore', () async {
      const product = VoiceCatalogProduct(
        id: 'p1',
        name: 'Amul Milk',
        price: 27.0,
        stockQuantity: 10.0,
      );

      final items = [
        const ParsedVoiceItem(
          rawSegment: '1 packet doodh',
          rawItemName: 'doodh',
          requestedQuantity: 1.0,
          matchedProduct: product,
          status: VoiceItemStatus.ready,
          finalQuantity: 1.0,
        ),
      ];

      await service.saveVoiceOrderLog(
        shopId: 'shop_123',
        customerPhone: '9876543210',
        spokenText: '1 packet doodh',
        items: items,
      );

      final logs = await fakeFirestore.collection('voice_order_logs').get();
      expect(logs.docs.length, 1);
      final logData = logs.docs.first.data();
      expect(logData['shop_id'], 'shop_123');
      expect(logData['customer_phone'], '9876543210');
      expect(logData['spoken_text'], '1 packet doodh');
      expect(logData['matched_item_names'], contains('Amul Milk'));
    });
  });

  group('Feature 61: UI Widget Tests - VoiceOrderSheet', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SoundService().setEnabled(false);
      SoundService().setHapticsEnabled(false);
      fakeFirestore = FakeFirebaseFirestore();
      FirebaseUtils.setFirestore(fakeFirestore);
    });

    final testCatalog = [
      const VoiceCatalogProduct(
        id: 'p1',
        name: 'Aashirvaad Shudh Chakki Atta 5kg',
        price: 245.0,
        stockQuantity: 10.0,
        isLoose: false,
        unit: 'kg',
        searchKeywords: ['atta', 'aashirvaad'],
      ),
      const VoiceCatalogProduct(
        id: 'p2',
        name: 'Amul Taaza Milk 500ml',
        price: 27.0,
        stockQuantity: 20.0,
        isLoose: false,
        unit: '500ml',
        searchKeywords: ['milk', 'doodh', 'amul'],
      ),
    ];

    Widget createTestApp({
      required Widget child,
      CartProvider? cartProvider,
    }) {
      final shopProvider = ShopProvider();
      final userProvider = UserProvider();
      userProvider.setUser('Aarav Patel', '9876543210');

      return MultiProvider(
        providers: [
          ChangeNotifierProvider<ShopProvider>.value(value: shopProvider),
          ChangeNotifierProvider<UserProvider>.value(value: userProvider),
          ChangeNotifierProvider<CartProvider>.value(
            value: cartProvider ?? CartProvider(),
          ),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      );
    }

    testWidgets('VoiceOrderSheet renders mic button, quick chips and transcript field', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: VoiceOrderSheet(
            shopId: 'shop_123',
            initialCatalog: testCatalog,
            isPulsingEnabled: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Voice Grocery Ordering'), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
      expect(find.text('Tap mic to speak (बोलने के लिए माइक दबाएं)'), findsOneWidget);
      expect(find.text('Quick Sample Voice Prompts (क्विक बोलकर देखें):'), findsOneWidget);
      expect(find.byType(ActionChip), findsWidgets);
    });

    testWidgets('VoiceOrderSheet parses items with prompt and confirms addition to CartProvider', (tester) async {
      final cart = CartProvider();

      await tester.pumpWidget(
        createTestApp(
          cartProvider: cart,
          child: VoiceOrderSheet(
            shopId: 'shop_123',
            initialCatalog: testCatalog,
            initialPrompt: '2 kilo atta',
            isPulsingEnabled: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify item card is displayed
      expect(find.text('Recognized Items (1)'), findsOneWidget);
      expect(find.text('Aashirvaad Shudh Chakki Atta 5kg'), findsOneWidget);
      expect(find.text('Ready to Add (तैयार है)'), findsOneWidget);

      // Verify confirm button
      final confirmBtn = find.text('Confirm & Add to Cart');
      expect(confirmBtn, findsOneWidget);

      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Check item was added to CartProvider
      expect(cart.items.containsKey('p1'), isTrue);
      expect(cart.items['p1']!.quantity, 2.0);
    });
  });
}
