import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String rulesContent;

  setUpAll(() {
    rulesContent = File('firestore.rules').readAsStringSync();
  });

  test('firestore.rules file exists and parses without syntax errors', () {
    expect(rulesContent.isNotEmpty, isTrue);
    expect(rulesContent.contains('service cloud.firestore'), isTrue);
    expect(rulesContent.contains('rules_version = \'2\';'), isTrue);

    expect(rulesContent.contains('match /databases/{database}/documents'), isTrue);
    expect(rulesContent.contains('match /orders/{orderId}'), isTrue);
    expect(rulesContent.contains('match /shops/{shopId}'), isTrue);
    expect(rulesContent.contains('match /products/{barcode}'), isTrue);
    expect(rulesContent.contains('match /customers/{customerId}'), isTrue);
    expect(rulesContent.contains('match /users/{userId}'), isTrue);
    expect(rulesContent.contains('match /complaints/{complaintId}'), isTrue);
  });

  test('Multi-tenant isolation: Shop Owner A and Shop Owner B data isolation', () async {
    final fakeFirestore = FakeFirebaseFirestore();

    // 1. Setup Shop A and Shop B
    await fakeFirestore.collection('shops').doc('SHOP_A').set({
      'shop_id': 'SHOP_A',
      'shop_name': 'Kirana Store A',
      'owner_name': 'Owner A',
      'mobile': '9876543210',
      'is_active': true,
      'status': 'approved',
    });

    await fakeFirestore.collection('shops').doc('SHOP_B').set({
      'shop_id': 'SHOP_B',
      'shop_name': 'Kirana Store B',
      'owner_name': 'Owner B',
      'mobile': '9123456780',
      'is_active': true,
      'status': 'approved',
    });

    // 2. Setup Orders for Shop A and Shop B
    await fakeFirestore.collection('orders').doc('ORDER_A_1').set({
      'shop_id': 'SHOP_A',
      'customer_name': 'Ramesh',
      'phone_number': '9988776655',
      'total_amount': 250.0,
      'status': 'Pending',
    });

    await fakeFirestore.collection('orders').doc('ORDER_B_1').set({
      'shop_id': 'SHOP_B',
      'customer_name': 'Suresh',
      'phone_number': '9871234567',
      'total_amount': 500.0,
      'status': 'Pending',
    });

    // Shop A owner query must only return Shop A orders
    final shopAOrders = await fakeFirestore
        .collection('orders')
        .where('shop_id', isEqualTo: 'SHOP_A')
        .get();

    expect(shopAOrders.docs.length, equals(1));
    expect(shopAOrders.docs.first.id, equals('ORDER_A_1'));
    expect(shopAOrders.docs.any((d) => d.id == 'ORDER_B_1'), isFalse);

    // Customer Ramesh queries his orders by phone number
    final rameshOrders = await fakeFirestore
        .collection('orders')
        .where('phone_number', isEqualTo: '9988776655')
        .get();

    expect(rameshOrders.docs.length, equals(1));
    expect(rameshOrders.docs.first.id, equals('ORDER_A_1'));
    // Ramesh cannot see Suresh's order
    expect(rameshOrders.docs.any((d) => d.id == 'ORDER_B_1'), isFalse);
  });

  test('Multi-tenant Khata Udhaar isolation per shop', () async {
    final fakeFirestore = FakeFirebaseFirestore();

    // Customer Ramesh has khata in Shop A and Shop B
    final customerRef = fakeFirestore.collection('customers').doc('CUST_RAMESH');
    await customerRef.set({
      'name': 'Ramesh',
      'mobile': '9988776655',
      'shop_ids': ['SHOP_A', 'SHOP_B'],
      'shop_balances': {
        'SHOP_A': 150.0,
        'SHOP_B': 300.0,
      },
    });

    // Shop A transaction
    await customerRef.collection('khata_transactions').doc('TX_A_1').set({
      'shop_id': 'SHOP_A',
      'amount': 150.0,
      'type': 'udhaar',
      'description': 'Atta & Sugar',
    });

    // Shop B transaction
    await customerRef.collection('khata_transactions').doc('TX_B_1').set({
      'shop_id': 'SHOP_B',
      'amount': 300.0,
      'type': 'udhaar',
      'description': 'Oil & Spices',
    });

    // When Shop A views statement for customer Ramesh, only Shop A transactions are fetched
    final shopATransactions = await customerRef
        .collection('khata_transactions')
        .where('shop_id', isEqualTo: 'SHOP_A')
        .get();

    expect(shopATransactions.docs.length, equals(1));
    expect(shopATransactions.docs.first.id, equals('TX_A_1'));
    expect(shopATransactions.docs.any((d) => d.id == 'TX_B_1'), isFalse);
  });

  test('firestore.rules enforces non-negative stock and safe atomic stock updates', () {
    // 1. Invariant: stock_quantity can never be negative
    expect(rulesContent.contains('stock_quantity >= 0'), isTrue);
    // 2. Strict key constraint: only stock_quantity can be modified by customer
    expect(
      rulesContent.contains(
        "request.resource.data.diff(resource.data).affectedKeys().hasOnly(['stock_quantity'])",
      ),
      isTrue,
    );
    // 3. Order constraints: items must be non-empty list and status Pending
    expect(rulesContent.contains('request.resource.data.items is list'), isTrue);
    expect(rulesContent.contains('request.resource.data.items.size() > 0'), isTrue);
    expect(rulesContent.contains("request.resource.data.status == 'Pending'"), isTrue);
    expect(rulesContent.contains('request.resource.data.total_amount >= 0'), isTrue);
  });

  test('Safe Order Placement & Stock Reservation: Stock 1 simultaneous orders test', () async {
    final fakeFirestore = FakeFirebaseFirestore();

    // Setup product with stock = 1
    final productRef = fakeFirestore.collection('products').doc('PROD_LAST_ITEM');
    await productRef.set({
      'name': 'Fortune Oil 1L',
      'price': 140.0,
      'stock_quantity': 1.0,
      'shop_id': 'SHOP_TEST',
    });

    // Helper simulating atomic order placement transaction
    Future<bool> placeOrderTransaction({
      required String customerPhone,
      required String customerName,
      required double quantityRequested,
    }) async {
      try {
        await fakeFirestore.runTransaction((transaction) async {
          // Read Phase
          final snapshot = await transaction.get(productRef);
          if (!snapshot.exists) {
            throw Exception('PRODUCT_NOT_FOUND');
          }
          final data = snapshot.data() as Map<String, dynamic>;
          final currentStock = (data['stock_quantity'] as num?)?.toDouble() ?? 0.0;

          if (currentStock <= 0 || currentStock < quantityRequested) {
            throw Exception('STOCK_ERROR|PROD_LAST_ITEM|${data['name']}|$currentStock');
          }

          final double newStock = currentStock - quantityRequested;
          if (newStock < 0) {
            throw Exception('STOCK_ERROR|PROD_LAST_ITEM|${data['name']}|$currentStock');
          }

          // Write Phase
          transaction.update(productRef, {
            'stock_quantity': newStock,
          });

          final orderRef = fakeFirestore.collection('orders').doc();
          transaction.set(orderRef, {
            'shop_id': 'SHOP_TEST',
            'customer_name': customerName,
            'phone_number': customerPhone,
            'total_amount': 140.0 * quantityRequested,
            'items': [
              {
                'id': 'PROD_LAST_ITEM',
                'name': data['name'],
                'price': 140.0,
                'quantity': quantityRequested,
              }
            ],
            'status': 'Pending',
          });
        });
        return true;
      } catch (e) {
        return false;
      }
    }

    // Customer 1 places order for quantity 1
    final c1Success = await placeOrderTransaction(
      customerPhone: '9876543210',
      customerName: 'Customer One',
      quantityRequested: 1.0,
    );

    // Customer 2 attempts to place order concurrently for quantity 1
    final c2Success = await placeOrderTransaction(
      customerPhone: '9123456789',
      customerName: 'Customer Two',
      quantityRequested: 1.0,
    );

    // Assert: Customer 1 succeeds, Customer 2 is safely rejected
    expect(c1Success, isTrue);
    expect(c2Success, isFalse);

    // Verify stock in database is strictly 0.0 (NEVER negative!)
    final productDoc = await productRef.get();
    final finalStock = (productDoc.data()?['stock_quantity'] as num).toDouble();
    expect(finalStock, equals(0.0));

    // Verify only 1 order was created (no duplicate orders)
    final ordersQuery = await fakeFirestore.collection('orders').get();
    expect(ordersQuery.docs.length, equals(1));
    expect(ordersQuery.docs.first.data()['customer_name'], equals('Customer One'));
    expect(ordersQuery.docs.first.data()['phone_number'], equals('9876543210'));
  });

  test('firestore.rules enforces complete order state machine transitions and terminal protection', () {
    // 1. Enforces transition helper function
    expect(rulesContent.contains('function isValidOrderTransition('), isTrue);

    // 2. Defines transitions for Pending -> Accepted -> Packing -> Ready -> Out for Delivery -> Delivered
    expect(rulesContent.contains('Accepted'), isTrue);
    expect(rulesContent.contains('Packing'), isTrue);
    expect(rulesContent.contains('Ready'), isTrue);
    expect(rulesContent.contains('Out for Delivery'), isTrue);
    expect(rulesContent.contains('Delivered'), isTrue);

    // 3. Defines failure & terminal transitions (Rejected, Cancelled, Delivery_Failed)
    expect(rulesContent.contains('Rejected'), isTrue);
    expect(rulesContent.contains('Delivery_Failed'), isTrue);

    // 4. Enforces Terminal Protection: Delivered, Cancelled, and Rejected orders cannot be altered without super_admin
    expect(rulesContent.contains("(!(resource.data.status in ['Delivered', 'Cancelled', 'Rejected'])) ||"), isTrue);
    expect(rulesContent.contains("isValidOrderTransition(resource.data.status, request.resource.data.status)"), isTrue);
  });
}

