import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:near_kirana/shopping_list_model.dart';
import 'package:near_kirana/shopping_list_service.dart';
import 'package:near_kirana/cart_provider.dart';
import 'package:near_kirana/shop_provider.dart';
import 'package:near_kirana/user_provider.dart';
import 'package:near_kirana/widgets/reorder_summary_dialog.dart';
import 'package:near_kirana/shopping_lists_screen.dart';
import 'package:near_kirana/firebase_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'customerPhone': '9876543210',
      'customerName': 'Aarav Patel',
    });
  });

  group('Feature 52: Domain Models - ShoppingListModel & ReorderValidation', () {
    test('ShoppingListItem calculations and serialization', () {
      const item = ShoppingListItem(
        productId: 'prod_1',
        name: 'Aashirvaad Atta 5kg',
        price: 240.0,
        quantity: 2.0,
        isLoose: false,
        imageUrl: 'https://example.com/atta.png',
        category: 'Flour & Grains',
        unit: 'packet',
      );

      expect(item.totalPrice, 480.0);

      final map = item.toMap();
      expect(map['product_id'], 'prod_1');
      expect(map['price'], 240.0);
      expect(map['quantity'], 2.0);

      final restored = ShoppingListItem.fromMap(map);
      expect(restored.productId, 'prod_1');
      expect(restored.name, 'Aashirvaad Atta 5kg');
      expect(restored.totalPrice, 480.0);

      final copied = restored.copyWith(price: 260.0, quantity: 3.0);
      expect(copied.totalPrice, 780.0);
    });

    test('ShoppingListModel cost aggregation and serialization', () {
      final now = DateTime.now();
      final list = ShoppingListModel(
        id: 'LST-101',
        name: 'Weekly Grocery',
        customerPhone: '9876543210',
        shopId: 'SHOP_123',
        items: const [
          ShoppingListItem(
            productId: 'p1',
            name: 'Milk 1L',
            price: 60.0,
            quantity: 3.0,
          ),
          ShoppingListItem(
            productId: 'p2',
            name: 'Bread',
            price: 40.0,
            quantity: 1.0,
          ),
        ],
        createdAt: now,
        updatedAt: now,
        colorTag: 'green',
      );

      expect(list.itemCount, 2);
      expect(list.totalEstimatedCost, 220.0); // (60*3) + (40*1) = 180 + 40 = 220

      final map = list.toMap();
      expect(map['id'], 'LST-101');
      expect(map['name'], 'Weekly Grocery');

      final restored = ShoppingListModel.fromMap(map, 'LST-101');
      expect(restored.id, 'LST-101');
      expect(restored.itemCount, 2);
      expect(restored.totalEstimatedCost, 220.0);
    });

    test('ReorderValidationResult status flags and cost comparisons', () {
      const v1 = ReorderItemValidation(
        productId: 'p1',
        name: 'Milk',
        requestedQuantity: 2.0,
        availableQuantity: 2.0,
        originalPrice: 60.0,
        currentPrice: 65.0, // Price changed
        isLoose: false,
        status: ReorderItemStatus.priceChanged,
      );

      expect(v1.hasPriceChange, isTrue);
      expect(v1.isPriceHigher, isTrue);
      expect(v1.priceDifference, 5.0);
      expect(v1.isFullyAvailable, isTrue);

      const v2 = ReorderItemValidation(
        productId: 'p2',
        name: 'Eggs 6pk',
        requestedQuantity: 2.0,
        availableQuantity: 1.0, // Partial stock
        originalPrice: 45.0,
        currentPrice: 45.0,
        isLoose: false,
        status: ReorderItemStatus.partialStock,
      );

      expect(v2.isPartial, isTrue);
      expect(v2.availableQuantity, 1.0);

      const v3 = ReorderItemValidation(
        productId: 'p3',
        name: 'Butter',
        requestedQuantity: 1.0,
        availableQuantity: 0.0, // Out of stock
        originalPrice: 55.0,
        currentPrice: 55.0,
        isLoose: false,
        status: ReorderItemStatus.outOfStock,
      );

      expect(v3.isOutOfStock, isTrue);

      final result = ReorderValidationResult(
        shopId: 'SHOP_123',
        items: [v1, v2, v3],
      );

      expect(result.availableItems.length, 2); // v1 and v2
      expect(result.priceChangedItems.length, 1); // v1
      expect(result.partialStockItems.length, 1); // v2
      expect(result.outOfStockItems.length, 1); // v3
      expect(result.canReorderAny, isTrue);
      expect(result.allAvailable, isFalse); // Because price changed & some out of stock

      // Original cost: (60*2) + (45*2) + (55*1) = 120 + 90 + 55 = 265
      expect(result.totalOriginalCost, 265.0);
      // Current cost for available items: (65*2) + (45*1) = 130 + 45 = 175
      expect(result.totalCurrentCost, 175.0);
    });
  });

  group('Feature 52: ShoppingListService Backend Operations', () {
    late FakeFirebaseFirestore fakeFirestore;
    late ShoppingListService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = ShoppingListService(firestore: fakeFirestore);
    });

    test('saveList, streamCustomerLists, and deleteList', () async {
      final now = DateTime.now();
      final list = ShoppingListModel(
        id: 'LST-001',
        name: 'Weekly Ration',
        customerPhone: '9876543210',
        shopId: 'SHOP_KIRANA_1',
        items: const [
          ShoppingListItem(productId: 'prod_1', name: 'Rice 5kg', price: 200.0, quantity: 1.0),
        ],
        createdAt: now,
        updatedAt: now,
      );

      await service.saveList(list);

      // Verify Firestore entry
      final doc = await fakeFirestore.collection('shopping_lists').doc('LST-001').get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['name'], 'Weekly Ration');
      expect(doc.data()?['customer_phone'], '9876543210');

      // Verify stream
      final streamed = await service.streamCustomerLists('9876543210').firstWhere((l) => l.isNotEmpty);
      expect(streamed.length, 1);
      expect(streamed.first.name, 'Weekly Ration');

      // Delete list
      await service.deleteList('LST-001');
      final deletedDoc = await fakeFirestore.collection('shopping_lists').doc('LST-001').get();
      expect(deletedDoc.exists, isFalse);
    });

    test('createListFromOrder creates list with past order items', () async {
      final created = await service.createListFromOrder(
        orderId: 'ORD-999',
        name: 'Sunday Breakfast Essentials',
        customerPhone: '9876543210',
        shopId: 'SHOP_KIRANA_1',
        items: [
          {'id': 'p1', 'name': 'Bread', 'price': 40.0, 'quantity': 1},
          {'id': 'p2', 'name': 'Butter', 'price': 50.0, 'quantity': 2},
        ],
      );

      expect(created.name, 'Sunday Breakfast Essentials');
      expect(created.itemCount, 2);
      expect(created.totalEstimatedCost, 140.0); // 40 + (50*2) = 140

      final doc = await fakeFirestore.collection('shopping_lists').doc(created.id).get();
      expect(doc.exists, isTrue);
    });

    test('createListFromCart creates list with active cart items', () async {
      final cartItems = [
        CartItem(id: 'c1', name: 'Milk', price: 30.0, isLoose: false, maxStock: 10, quantity: 2),
        CartItem(id: 'c2', name: 'Curd', price: 25.0, isLoose: false, maxStock: 5, quantity: 1),
      ];

      final created = await service.createListFromCart(
        name: 'Dairy Daily',
        customerPhone: '9876543210',
        shopId: 'SHOP_KIRANA_1',
        cartItems: cartItems,
      );

      expect(created.name, 'Dairy Daily');
      expect(created.itemCount, 2);
      expect(created.totalEstimatedCost, 85.0); // (30*2) + 25 = 85
    });

    test('validateItemsForReorder detects price changes, out of stock, and discontinued items', () async {
      // Seed shop inventory in fake Firestore
      await fakeFirestore.collection('products').doc('p_milk').set({
        'shop_id': 'SHOP_1',
        'name': 'Amul Milk 500ml',
        'price': 35.0, // Price was 30 in old order
        'stock_quantity': 10.0,
        'is_active': true,
      });

      await fakeFirestore.collection('products').doc('p_bread').set({
        'shop_id': 'SHOP_1',
        'name': 'Harvest Bread',
        'price': 40.0, // Price unchanged
        'stock_quantity': 1.0, // Requested 3, so partial stock
        'is_active': true,
      });

      await fakeFirestore.collection('products').doc('p_chips').set({
        'shop_id': 'SHOP_1',
        'name': 'Lays Blue',
        'price': 20.0,
        'stock_quantity': 0.0, // Out of stock
        'is_active': true,
      });

      final orderItems = [
        {'id': 'p_milk', 'name': 'Amul Milk 500ml', 'price': 30.0, 'quantity': 2.0},
        {'id': 'p_bread', 'name': 'Harvest Bread', 'price': 40.0, 'quantity': 3.0},
        {'id': 'p_chips', 'name': 'Lays Blue', 'price': 20.0, 'quantity': 1.0},
        {'id': 'p_deleted', 'name': 'Discontinued Soda', 'price': 50.0, 'quantity': 1.0},
      ];

      final result = await service.validateItemsForReorder(
        currentShopId: 'SHOP_1',
        items: orderItems,
      );

      expect(result.items.length, 4);

      // 1. Milk: price changed from 30 to 35
      final milk = result.items.firstWhere((i) => i.productId == 'p_milk');
      expect(milk.status, ReorderItemStatus.priceChanged);
      expect(milk.availableQuantity, 2.0);
      expect(milk.currentPrice, 35.0);
      expect(milk.originalPrice, 30.0);

      // 2. Bread: stock is 1.0 while requested 3.0
      final bread = result.items.firstWhere((i) => i.productId == 'p_bread');
      expect(bread.status, ReorderItemStatus.partialStock);
      expect(bread.availableQuantity, 1.0);

      // 3. Chips: out of stock
      final chips = result.items.firstWhere((i) => i.productId == 'p_chips');
      expect(chips.status, ReorderItemStatus.outOfStock);
      expect(chips.availableQuantity, 0.0);

      // 4. Deleted: discontinued
      final deleted = result.items.firstWhere((i) => i.productId == 'p_deleted');
      expect(deleted.status, ReorderItemStatus.discontinued);
      expect(deleted.availableQuantity, 0.0);

      // Overall result
      expect(result.availableItems.length, 2); // milk & bread
      expect(result.canReorderAny, isTrue);
    });

    test('applyItemsToCart populates CartProvider with validated items', () async {
      final cart = CartProvider();

      final itemsToAdd = [
        const ReorderItemValidation(
          productId: 'p_milk',
          name: 'Amul Milk 500ml',
          requestedQuantity: 2.0,
          availableQuantity: 2.0,
          originalPrice: 30.0,
          currentPrice: 35.0,
          isLoose: false,
          status: ReorderItemStatus.priceChanged,
        ),
        const ReorderItemValidation(
          productId: 'p_bread',
          name: 'Harvest Bread',
          requestedQuantity: 3.0,
          availableQuantity: 1.0,
          originalPrice: 40.0,
          currentPrice: 40.0,
          isLoose: false,
          status: ReorderItemStatus.partialStock,
        ),
      ];

      final count = service.applyItemsToCart(
        cartProvider: cart,
        itemsToAdd: itemsToAdd,
      );

      expect(count, 2);
      expect(cart.items.containsKey('p_milk'), isTrue);
      expect(cart.items['p_milk']!.price, 35.0);
      expect(cart.items['p_milk']!.quantity, 2.0);

      expect(cart.items.containsKey('p_bread'), isTrue);
      expect(cart.items['p_bread']!.price, 40.0);
      expect(cart.items['p_bread']!.quantity, 1.0);

      expect(cart.cartTotal, 110.0); // (35*2) + 40 = 110
    });
  });

  group('Feature 52: Customer UI Widget Tests', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      FirebaseUtils.setFirestore(fakeFirestore);
    });

    Widget createTestApp(Widget child, {CartProvider? cartProvider}) {
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
        child: MaterialApp(
          home: child,
        ),
      );
    }

    testWidgets('ReorderSummaryDialog renders validation breakdown and adds items to cart', (tester) async {
      final cart = CartProvider();

      const item1 = ReorderItemValidation(
        productId: 'p1',
        name: 'Sunflower Oil 1L',
        requestedQuantity: 1.0,
        availableQuantity: 1.0,
        originalPrice: 150.0,
        currentPrice: 160.0,
        isLoose: false,
        status: ReorderItemStatus.priceChanged,
      );

      const item2 = ReorderItemValidation(
        productId: 'p2',
        name: 'Wheat Bread',
        requestedQuantity: 2.0,
        availableQuantity: 0.0,
        originalPrice: 40.0,
        currentPrice: 40.0,
        isLoose: false,
        status: ReorderItemStatus.outOfStock,
      );

      final valResult = ReorderValidationResult(
        shopId: 'SHOP_TEST',
        items: const [item1, item2],
      );

      await tester.pumpWidget(
        createTestApp(
          Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showDialog(
                  context: ctx,
                  builder: (_) => ReorderSummaryDialog(
                    sourceTitle: 'Weekly Grocery List',
                    validationResult: valResult,
                  ),
                ),
                child: const Text('Open Reorder'),
              ),
            ),
          ),
          cartProvider: cart,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Reorder'));
      await tester.pumpAndSettle();

      // Verify Title & Metrics Pills
      expect(find.text('Review & Reorder'), findsOneWidget);
      expect(find.text('Weekly Grocery List'), findsOneWidget);
      expect(find.text('1 Available'), findsOneWidget);
      expect(find.text('1 Price Updated'), findsOneWidget);
      expect(find.text('1 Unavailable'), findsOneWidget);

      // Verify item list displays
      expect(find.text('Sunflower Oil 1L'), findsOneWidget);
      expect(find.text('Wheat Bread'), findsOneWidget);

      // Verify "Add 1 to Cart" button exists and click it
      final addBtn = find.text('Add 1 to Cart');
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Verify item was added to cart
      expect(cart.items.containsKey('p1'), isTrue);
      expect(cart.items['p1']!.price, 160.0);
    });

    testWidgets('ShoppingListsScreen renders tabs and lists', (tester) async {
      // Seed a shopping list
      await fakeFirestore.collection('shopping_lists').doc('LST-1').set({
        'id': 'LST-1',
        'name': 'Sunday Specials',
        'customer_phone': '9876543210',
        'shop_id': 'SHOP_TEST',
        'items': [
          {'product_id': 'p1', 'name': 'Milk 500ml', 'price': 30.0, 'quantity': 2.0},
        ],
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await tester.pumpWidget(
        createTestApp(
          const ShoppingListsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Tabs
      expect(find.text('Saved Lists'), findsOneWidget);
      expect(find.text('Past Orders'), findsOneWidget);

      // Verify Seeded List card appears
      expect(find.text('Sunday Specials'), findsOneWidget);
      expect(find.text('1 items'), findsOneWidget);
      expect(find.text('Est. ₹60'), findsOneWidget);

      // Tap expansion tile to view items
      await tester.tap(find.text('Sunday Specials'));
      await tester.pumpAndSettle();

      expect(find.text('Milk 500ml'), findsOneWidget);
      expect(find.text('Reorder to Cart'), findsOneWidget);
    });
  });
}
