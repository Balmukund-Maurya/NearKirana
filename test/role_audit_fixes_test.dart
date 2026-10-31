import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:near_kirana/shop_provider.dart';
import 'package:near_kirana/cart_provider.dart';
import 'package:near_kirana/atomic_order_service.dart';
import 'package:near_kirana/complaint_service.dart';
import 'package:near_kirana/complaint_model.dart';
import 'package:near_kirana/delivery_partner_service.dart';
import 'package:near_kirana/receive_payment_screen.dart';
import 'package:near_kirana/shopping_list_service.dart';
import 'package:near_kirana/supplier_service.dart';
import 'package:near_kirana/admin_shop_boys_screen.dart';
import 'package:near_kirana/language_provider.dart';
import 'package:near_kirana/product_substitution_service.dart';
import 'package:near_kirana/rating_review_service.dart';
import 'package:near_kirana/delivery_partner_models.dart';
import 'package:near_kirana/analytics_service.dart';
import 'package:near_kirana/analytics_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeFirestore = FakeFirebaseFirestore();
    FirebaseUtils.setFirestore(fakeFirestore);
  });

  group('Role Audit Bug Fixes: CartProvider Image and Stock Protection', () {
    test('CartItem imageUrl is preserved across addItem, setQuantity, updatePrice, and syncPricesWithServer', () async {
      final cart = CartProvider();
      const imageUrl = 'https://example.com/fortune_oil.png';

      // 1. Initial add with image
      cart.addItem('oil_1', 'Fortune Mustard Oil 1L', 160.0, false, 10.0, imageUrl: imageUrl);
      expect(cart.items['oil_1']?.imageUrl, equals(imageUrl));

      // 2. Add same item again -> imageUrl should NOT be lost or nullified
      cart.addItem('oil_1', 'Fortune Mustard Oil 1L', 160.0, false, 10.0);
      expect(cart.items['oil_1']?.quantity, equals(2.0));
      expect(cart.items['oil_1']?.imageUrl, equals(imageUrl));

      // 3. setQuantity -> imageUrl should be preserved
      cart.setQuantity('oil_1', 4.0);
      expect(cart.items['oil_1']?.quantity, equals(4.0));
      expect(cart.items['oil_1']?.imageUrl, equals(imageUrl));

      // 4. setQuantity beyond maxStock -> clamps to maxStock (10.0)
      cart.setQuantity('oil_1', 50.0);
      expect(cart.items['oil_1']?.quantity, equals(10.0));
      expect(cart.items['oil_1']?.imageUrl, equals(imageUrl));

      // 5. updatePrice -> imageUrl should be preserved
      cart.updatePrice('oil_1', 175.0);
      expect(cart.items['oil_1']?.price, equals(175.0));
      expect(cart.items['oil_1']?.imageUrl, equals(imageUrl));

      // 6. syncPricesWithServer -> imageUrl should be preserved
      await fakeFirestore.collection('products').doc('oil_1').set({
        'price': 180.0,
        'stock_quantity': 15.0,
      });
      await cart.syncPricesWithServer();
      expect(cart.items['oil_1']?.price, equals(180.0));
      expect(cart.items['oil_1']?.imageUrl, equals(imageUrl));
    });
  });

  group('Role Audit Bug Fixes: AtomicOrderService Cancellation & Rider / Loyalty Cleanup', () {
    test('cancelOrderAtomic decrements assigned rider active orders count and marks available if 0', () async {
      final atomicService = AtomicOrderService(firestore: fakeFirestore);

      // Seed rider
      await fakeFirestore.collection('delivery_partners').doc('rider_101').set({
        'name': 'Ramesh Rider',
        'status': 'delivering',
        'active_orders_count': 1,
      });

      // Seed order assigned to rider_101
      await fakeFirestore.collection('orders').doc('order_with_rider').set({
        'shop_id': 'shop_1',
        'customer_id': 'cust_1',
        'status': 'Accepted',
        'delivery_partner_id': 'rider_101',
        'items': [
          {'id': 'prod_a', 'quantity': 2.0},
        ],
      });

      // Seed product stock
      await fakeFirestore.collection('products').doc('prod_a').set({
        'stock_quantity': 5.0,
        'shop_id': 'shop_1',
      });

      // Cancel order
      final cancelled = await atomicService.cancelOrderAtomic(
        orderId: 'order_with_rider',
        cancelledBy: 'customer',
        reason: 'Order placed by mistake',
      );
      expect(cancelled, isTrue);

      // Verify rider active orders count decremented and status changed to available
      final riderDoc = await fakeFirestore.collection('delivery_partners').doc('rider_101').get();
      expect(riderDoc.data()?['active_orders_count'], equals(0));
      expect(riderDoc.data()?['status'], equals('available'));
    });

    test('cancelOrderAtomic refunds loyalty points if order used loyalty discount', () async {
      final atomicService = AtomicOrderService(firestore: fakeFirestore);

      // Seed customer loyalty account with 50 points remaining after 100 spent
      await fakeFirestore.collection('loyalty_accounts').doc('shop_1_9876543210').set({
        'shop_id': 'shop_1',
        'customer_phone': '9876543210',
        'customer_name': 'Loyal Customer',
        'current_points': 50,
        'lifetime_earned_points': 150,
        'lifetime_redeemed_points': 100,
        'referral_code': 'REF123',
        'tier': 'bronze',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Seed order with points_redeemed = 100
      await fakeFirestore.collection('orders').doc('order_with_loyalty').set({
        'shop_id': 'shop_1',
        'customer_id': 'cust_loyalty_user',
        'phone_number': '9876543210',
        'status': 'Pending',
        'points_redeemed': 100,
        'loyalty_discount': 100.0,
        'items': [],
      });

      // Cancel order
      final cancelled = await atomicService.cancelOrderAtomic(
        orderId: 'order_with_loyalty',
        cancelledBy: 'admin',
        reason: 'Merchant cancelled',
      );
      expect(cancelled, isTrue);

      // Check loyalty balance restored back by 100 points
      final loyaltyDoc = await fakeFirestore.collection('loyalty_accounts').doc('shop_1_9876543210').get();
      expect(loyaltyDoc.data()?['current_points'], equals(150));
      expect(loyaltyDoc.data()?['lifetime_redeemed_points'], equals(0));
    });
  });

  group('Role Audit Bug Fixes: Khata Double-Debit Prevention & Complaint Refund', () {
    test('DeliveryPartnerService respects khata_recorded flag to prevent double udhaar debit', () async {
      final deliveryService = DeliveryPartnerService(firestore: fakeFirestore);

      // Seed customer khata with initial total_udhaar = 500.0
      await fakeFirestore.collection('customers').doc('cust_khata_1').set({
        'name': 'Rakesh Verma',
        'mobile': '9876543210',
        'total_udhaar': 500.0,
        'shop_balances': {'shop_123': 500.0},
      });

      // Seed order where khata_recorded is TRUE (debited at checkout)
      await fakeFirestore.collection('orders').doc('khata_order_1').set({
        'shop_id': 'shop_123',
        'customer_id': 'cust_khata_1',
        'customer_phone': '9876543210',
        'phone_number': '9876543210',
        'total_amount': 500.0,
        'payment_method': 'Khata',
        'khata_recorded': true,
        'status': 'Out for Delivery',
        'delivery_pin': '1234',
        'items': [],
      });

      // Seed delivery partner
      await fakeFirestore.collection('delivery_partners').doc('rider_99').set({
        'name': 'Sonu Rider',
        'active_orders_count': 1,
        'status': 'delivering',
      });

      // Deliver order
      await deliveryService.completeDelivery(
        orderId: 'khata_order_1',
        partnerId: 'rider_99',
        shopId: 'shop_123',
        isKhata: true,
        customerPhone: '9876543210',
        orderTotal: 500.0,
      );

      // Verify that total_udhaar was NOT debited a second time (still 500.0, not 1000.0)
      final custDoc = await fakeFirestore.collection('customers').doc('cust_khata_1').get();
      expect(custDoc.data()?['total_udhaar'], equals(500.0));
      expect(custDoc.data()?['shop_balances']['shop_123'], equals(500.0));
    });

    test('ComplaintService._creditCustomerKhata properly credits khata ledger and decreases total_udhaar', () async {
      final complaintService = ComplaintService(firestore: fakeFirestore);

      // Customer initially owes 800 total udhaar (500 to SHOP_KIRANA_1)
      await fakeFirestore.collection('customers').doc('9876543210').set({
        'name': 'Anil Kumar',
        'mobile': '9876543210',
        'total_udhaar': 800.0,
        'shop_balances': {'SHOP_KIRANA_1': 500.0},
        'shop_ids': ['SHOP_KIRANA_1'],
      });

      // Seed order
      await fakeFirestore.collection('orders').doc('order_comp_1').set({
        'shop_id': 'SHOP_KIRANA_1',
        'phone_number': '9876543210',
        'customer_name': 'Anil Kumar',
        'status': 'Delivered',
        'total_amount': 200.0,
        'items': [
          {'id': 'p1', 'name': 'Biscuits', 'quantity': 2, 'price': 100.0},
        ],
      });

      final complaint = await complaintService.createComplaint(
        orderId: 'order_comp_1',
        shopId: 'SHOP_KIRANA_1',
        customerPhone: '9876543210',
        customerName: 'Anil Kumar',
        type: ComplaintType.damaged,
        description: 'Biscuits packets crushed',
        affectedItems: const [
          ComplaintItem(
            itemId: 'p1',
            name: 'Biscuits',
            quantityOrdered: 2,
            quantityAffected: 2,
            pricePerUnit: 100.0,
          ),
        ],
      );

      // Resolve complaint with store credit / khata adjustment
      await complaintService.resolveComplaint(
        complaintId: complaint.id,
        resolutionType: ResolutionType.refund,
        resolutionNotes: 'Approved return for crushed packets',
        refundAmount: 200.0,
        refundMethod: RefundMethod.khataCredit,
        resolvedBy: 'Shopkeeper',
      );

      // Verify customer total_udhaar decreased from 800 to 600, and shop balance from 500 to 300
      final custDoc = await fakeFirestore.collection('customers').doc('9876543210').get();
      expect(custDoc.data()?['total_udhaar'], equals(600.0));
      expect(custDoc.data()?['shop_balances']['SHOP_KIRANA_1'], equals(300.0));
    });
  });

  group('Role Audit Bug Fixes: ReceivePaymentScreen Mobile Responsiveness', () {
    testWidgets('ReceivePaymentScreen renders without unbounded height/overflow on narrow mobile screen', (WidgetTester tester) async {
      // Set mobile phone screen size (360 x 640)
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Seed customer
      await fakeFirestore.collection('customers').doc('cust_rec_1').set({
        'name': 'Suresh Lal',
        'mobile': '9876543210',
        'total_udhaar': 1200.0,
        'shop_balances': {'shop_test': 1200.0},
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ShopProvider>(create: (_) => ShopProvider()),
          ],
          child: const MaterialApp(
            home: ReceivePaymentScreen(
              customerId: 'cust_rec_1',
              customerName: 'Suresh Lal',
              customerPhone: '9876543210',
            ),
          ),
        ),
      );

      // Pump frame
      await tester.pumpAndSettle();

      // Ensure screen header and quick amounts render properly without throwing layout exceptions
      expect(find.text('Receive Payment'), findsWidgets);
      expect(find.text('₹500'), findsOneWidget);
      expect(find.text('₹1000'), findsOneWidget);
      expect(find.text('Suresh Lal'), findsOneWidget);
    });
  });

  group('Role Audit Bug Fixes: Reorder Stock, Loyalty Anti-Farming & Supplier Types', () {
    test('ShoppingListService.applyItemsToCart preserves true live maxStock (not clamping to requested quantity)', () async {
      final shoppingService = ShoppingListService(firestore: fakeFirestore);
      final cart = CartProvider();

      // Seed product with 50 units in stock
      await fakeFirestore.collection('products').doc('maggi_pack').set({
        'name': 'Maggi Noodles 280g',
        'price': 40.0,
        'stock_quantity': 50.0,
        'is_active': true,
        'shop_id': 'shop_kirana_9',
      });

      // Customer previously saved list with requested 2 packets
      final validationResult = await shoppingService.validateItemsForReorder(
        currentShopId: 'shop_kirana_9',
        items: [
          {
            'id': 'maggi_pack',
            'name': 'Maggi Noodles 280g',
            'price': 40.0,
            'quantity': 2.0,
          },
        ],
      );

      expect(validationResult.items.first.effectiveMaxStock, equals(50.0));

      // Apply to cart
      shoppingService.applyItemsToCart(
        cartProvider: cart,
        itemsToAdd: validationResult.items,
      );

      // Cart item quantity is 2.0, but maxStock should be 50.0!
      final cartItem = cart.items['maggi_pack'];
      expect(cartItem, isNotNull);
      expect(cartItem!.quantity, equals(2.0));
      expect(cartItem.maxStock, equals(50.0));

      // Customer can increase quantity beyond 2 up to 50
      final added = cart.addItem('maggi_pack', 'Maggi Noodles 280g', 40.0, false, 50.0);
      expect(added, isTrue);
      expect(cart.items['maggi_pack']?.quantity, equals(3.0));
    });

    test('cancelOrderAtomic reverses earned loyalty points to prevent infinite points farming exploit', () async {
      final atomicService = AtomicOrderService(firestore: fakeFirestore);

      // Seed customer loyalty account with 80 current points (having earned 30 from previous order)
      await fakeFirestore.collection('loyalty_accounts').doc('shop_1_9876543210').set({
        'shop_id': 'shop_1',
        'customer_phone': '9876543210',
        'customer_name': 'Aman Gupta',
        'current_points': 80,
        'lifetime_earned_points': 180,
        'lifetime_redeemed_points': 0,
        'referral_code': 'AMAN99',
        'tier': 'bronze',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Seed order that earned 30 points
      await fakeFirestore.collection('orders').doc('farmed_order_1').set({
        'shop_id': 'shop_1',
        'customer_id': 'cust_farm_1',
        'phone_number': '9876543210',
        'status': 'Pending',
        'points_earned': 30,
        'loyalty_points_earned': 30,
        'total_amount': 600.0,
        'items': [],
      });

      // Customer or admin cancels this order
      final cancelled = await atomicService.cancelOrderAtomic(
        orderId: 'farmed_order_1',
        cancelledBy: 'customer',
        reason: 'Customer cancelled',
      );
      expect(cancelled, isTrue);

      // Verify that earned 30 points were reversed (80 - 30 = 50) and lifetime earned adjusted
      final loyaltyDoc = await fakeFirestore.collection('loyalty_accounts').doc('shop_1_9876543210').get();
      expect(loyaltyDoc.data()?['current_points'], equals(50));
      expect(loyaltyDoc.data()?['lifetime_earned_points'], equals(150));
    });

    test('SupplierService.searchProducts safely parses int and double cost_prices without cast error', () async {
      final supplierService = SupplierService(firestore: fakeFirestore);

      // Product 1 with int cost_price and int price
      await fakeFirestore.collection('products').doc('soap_int').set({
        'shop_id': 'shop_sup_1',
        'name': 'Lifebuoy Soap',
        'cost_price': 25, // int
        'price': 35, // int
        'stock_quantity': 100,
        'barcode': 'BAR123',
      });

      // Product 2 with double cost_price
      await fakeFirestore.collection('products').doc('oil_double').set({
        'shop_id': 'shop_sup_1',
        'name': 'Mustard Oil 1L',
        'cost_price': 142.50, // double
        'price': 165.0,
        'stock_quantity': 20.0,
        'barcode': 'BAR456',
      });

      final results = await supplierService.searchProducts('shop_sup_1', '');
      expect(results.length, equals(2));

      final soap = results.firstWhere((p) => p['id'] == 'soap_int');
      expect(soap['cost_price'], equals(25.0));
      expect(soap['selling_price'], equals(35.0));
      expect(soap['cost_price'], isA<double>());

      final oil = results.firstWhere((p) => p['id'] == 'oil_double');
      expect(oil['cost_price'], equals(142.50));
      expect(oil['selling_price'], equals(165.0));
    });

    test('DeliveryPartnerService.settlePartnerCash settles COD cash and resets rider cash balance', () async {
      final deliveryService = DeliveryPartnerService(firestore: fakeFirestore);

      // Seed rider with ₹1500 cash in hand collected from COD deliveries
      await fakeFirestore.collection('delivery_partners').doc('rider_cod_1').set({
        'name': 'Deepak Rider',
        'phone': '9876543210',
        'cash_collected': 1500.0,
        'total_delivered_count': 5,
        'status': 'available',
      });

      // Merchant receives ₹1500 cash from rider
      await deliveryService.settlePartnerCash(
        partnerId: 'rider_cod_1',
        amount: 1500.0,
        notes: 'End of day cash handover',
      );

      // Verify rider cash_collected is now 0.0
      final riderDoc = await fakeFirestore.collection('delivery_partners').doc('rider_cod_1').get();
      expect(riderDoc.data()?['cash_collected'], equals(0.0));
      expect(riderDoc.data()?['last_cash_settled_amount'], equals(1500.0));
      expect(riderDoc.data()?['last_cash_settle_notes'], equals('End of day cash handover'));
    });

    testWidgets('AdminShopBoysScreen displays Cash in Hand badge and Settle Cash button', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'current_shop_id': 'shop_test_123'});
      final shopProvider = ShopProvider();
      await shopProvider.loadCurrentShop();

      // Seed rider with cash_collected > 0 in fakeFirestore
      await fakeFirestore.collection('delivery_partners').doc('rider_ui_1').set({
        'shop_id': 'shop_test_123',
        'name': 'Vikas Rider',
        'phone': '9876543210',
        'vehicle_number': 'DL 01 AB 1234',
        'status': 'available',
        'cash_collected': 850.0,
        'total_delivered_count': 3,
        'active_orders_count': 0,
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ShopProvider>.value(value: shopProvider),
            ChangeNotifierProvider<LanguageProvider>(create: (_) => LanguageProvider()),
          ],
          child: const MaterialApp(
            home: AdminShopBoysScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify rider name, deliveries badge, cash badge (₹850), and Settle Cash button render
      expect(find.text('Vikas Rider'), findsOneWidget);
      expect(find.text('₹850'), findsOneWidget);
      expect(find.text('Settle Cash'), findsOneWidget);
    });
  });

  group('Role Audit Bug Fixes: Khata Cancellation & Substitution Reconciliations', () {
    test('cancelOrderAtomic reverses Khata balance and logs transaction for cancelled Khata orders', () async {
      final atomicService = AtomicOrderService(firestore: fakeFirestore);

      // Seed customer with ₹600 udhaar on shop_test_123
      final custRef = fakeFirestore.collection('customers').doc('cust_khata_1');
      await custRef.set({
        'name': 'Ramesh Kumar',
        'mobile': '9876543210',
        'shop_ids': ['shop_test_123'],
        'shop_balances': {'shop_test_123': 600.0},
        'total_udhaar': 600.0,
      });

      // Seed product
      await fakeFirestore.collection('products').doc('rice_1').set({
        'stock_quantity': 20.0,
      });

      // Seed order placed with Khata
      await fakeFirestore.collection('orders').doc('order_khata_cancel_1').set({
        'shop_id': 'shop_test_123',
        'customer_phone': '9876543210',
        'phone_number': '9876543210',
        'customer_name': 'Ramesh Kumar',
        'status': 'Pending',
        'payment_method': 'Khata',
        'khata_recorded': true,
        'total_amount': 600.0,
        'items': [
          {'id': 'rice_1', 'name': 'Basmati Rice 5kg', 'quantity': 1.0, 'price': 600.0}
        ],
      });

      // Cancel the Khata order
      final cancelled = await atomicService.cancelOrderAtomic(
        orderId: 'order_khata_cancel_1',
        cancelledBy: 'customer',
        reason: 'Customer changed mind',
      );

      expect(cancelled, isTrue);

      // Verify product stock restored
      final prodDoc = await fakeFirestore.collection('products').doc('rice_1').get();
      expect(prodDoc.data()?['stock_quantity'], equals(21.0));

      // Verify customer Khata balance was reversed
      final updatedCust = await custRef.get();
      final balances = updatedCust.data()?['shop_balances'] as Map<String, dynamic>;
      expect(balances['shop_test_123'], equals(0.0));
      expect(updatedCust.data()?['total_udhaar'], equals(0.0));

      // Verify credit transaction logged in khata_transactions
      final txSnap = await custRef.collection('khata_transactions').get();
      expect(txSnap.docs.length, equals(1));
      expect(txSnap.docs.first.data()['amount'], equals(600.0));
      expect(txSnap.docs.first.data()['type'], equals('credit'));
      expect(txSnap.docs.first.data()['order_id'], equals('order_khata_cancel_1'));
    });

    test('ProductSubstitutionService reconciles customer Khata balance when substitution price increases', () async {
      final subService = ProductSubstitutionService(firestore: fakeFirestore);

      // Seed customer with ₹300 initial balance
      final custRef = fakeFirestore.collection('customers').doc('cust_sub_1');
      await custRef.set({
        'name': 'Pooja Sharma',
        'mobile': '9876500001',
        'shop_ids': ['shop_test_123'],
        'shop_balances': {'shop_test_123': 300.0},
        'total_udhaar': 300.0,
      });

      // Seed order on Khata
      final orderRef = fakeFirestore.collection('orders').doc('order_sub_khata_1');
      await orderRef.set({
        'shop_id': 'shop_test_123',
        'customer_phone': '9876500001',
        'phone_number': '9876500001',
        'payment_method': 'Khata',
        'khata_recorded': true,
        'subtotal': 300.0,
        'total_amount': 300.0,
        'delivery_fee': 0.0,
        'discount': 0.0,
        'status': 'Pending',
        'items': [
          {'id': 'tea_1', 'name': 'Tata Tea Gold 250g', 'price': 150.0, 'quantity': 2.0}
        ],
        'timeline': [],
      });

      // Propose substitute with higher price (Tata Tea @ 150 -> 180, +60 delta)
      final proposal = await subService.proposeSubstitution(
        orderId: 'order_sub_khata_1',
        originalProductId: 'tea_1',
        originalProductName: 'Tata Tea Gold 250g',
        originalPrice: 150.0,
        originalQuantity: 2.0,
        substituteProductId: 'tea_2',
        substituteProductName: 'Brooke Bond Red Label 250g',
        substitutePrice: 180.0,
        substituteQuantity: 2.0,
        reason: 'Tata Tea out of stock',
        proposedBy: 'merchant',
      );

      // Customer accepts substitution
      await subService.respondToSubstitution(
        orderId: 'order_sub_khata_1',
        proposalId: proposal.id,
        isAccepted: true,
      );

      // Verify order total updated to 360
      final updatedOrder = await orderRef.get();
      expect(updatedOrder.data()?['total_amount'], equals(360.0));

      // Verify customer Khata balance updated from 300 to 360 (+60)
      final updatedCust = await custRef.get();
      final balances = updatedCust.data()?['shop_balances'] as Map<String, dynamic>;
      expect(balances['shop_test_123'], equals(360.0));
      expect(updatedCust.data()?['total_udhaar'], equals(360.0));

      // Verify debit transaction logged for the difference
      final txSnap = await custRef.collection('khata_transactions').get();
      expect(txSnap.docs.length, equals(1));
      expect(txSnap.docs.first.data()['amount'], equals(60.0));
      expect(txSnap.docs.first.data()['type'], equals('debit'));
    });

    test('ProductSubstitutionService records refund_due on paid online orders when item price decreases', () async {
      final subService = ProductSubstitutionService(firestore: fakeFirestore);

      // Seed paid order (e.g. ₹500 via online payment)
      final orderRef = fakeFirestore.collection('orders').doc('order_sub_online_1');
      await orderRef.set({
        'shop_id': 'shop_test_123',
        'customer_phone': '9876500002',
        'payment_method': 'Online',
        'payment_status': 'Paid',
        'subtotal': 500.0,
        'total_amount': 500.0,
        'delivery_fee': 0.0,
        'discount': 0.0,
        'status': 'Pending',
        'items': [
          {'id': 'oil_p', 'name': 'Fortune Sunflower 1L', 'price': 200.0, 'quantity': 1.0},
          {'id': 'atta_p', 'name': 'Ashirvaad Atta 5kg', 'price': 300.0, 'quantity': 1.0},
        ],
        'timeline': [],
      });

      // Propose substitute for Fortune Sunflower 1L with cheaper Dhara 1L (@ ₹160, -40 delta)
      final proposal = await subService.proposeSubstitution(
        orderId: 'order_sub_online_1',
        originalProductId: 'oil_p',
        originalProductName: 'Fortune Sunflower 1L',
        originalPrice: 200.0,
        originalQuantity: 1.0,
        substituteProductId: 'oil_cheaper',
        substituteProductName: 'Dhara Mustard 1L',
        substitutePrice: 160.0,
        substituteQuantity: 1.0,
        reason: 'Fortune Sunflower out of stock',
        proposedBy: 'merchant',
      );

      // Customer accepts cheaper substitute
      await subService.respondToSubstitution(
        orderId: 'order_sub_online_1',
        proposalId: proposal.id,
        isAccepted: true,
      );

      // Verify order revised total is 460.0 and refund_due is tracked
      final updatedOrder = await orderRef.get();
      expect(updatedOrder.data()?['total_amount'], equals(460.0));
      expect(updatedOrder.data()?['refund_due'], equals(40.0));
      expect(updatedOrder.data()?['partial_refund_pending'], isTrue);
    });
  });

  group('Role Audit Bug Fixes: Rider Re-assignment, Delivery Ratings & Analytics Accuracy', () {
    test('assignOrderToPartner decrements previous rider count and prevents duplicate increments on re-assign', () async {
      final deliveryService = DeliveryPartnerService(firestore: fakeFirestore);

      // Seed Rider A with 0 active orders
      final riderARef = fakeFirestore.collection('delivery_partners').doc('rider_a');
      await riderARef.set({
        'shop_id': 'shop_test_123',
        'name': 'Rider Ajay',
        'phone': '9876543210',
        'vehicle_number': 'DL 01 A 1111',
        'status': 'available',
        'active_orders_count': 0,
        'total_delivered_count': 2,
        'created_at': DateTime.now(),
      });

      // Seed Rider B with 0 active orders
      final riderBRef = fakeFirestore.collection('delivery_partners').doc('rider_b');
      await riderBRef.set({
        'shop_id': 'shop_test_123',
        'name': 'Rider Bobby',
        'phone': '9876543211',
        'vehicle_number': 'DL 01 B 2222',
        'status': 'available',
        'active_orders_count': 0,
        'total_delivered_count': 1,
        'created_at': DateTime.now(),
      });

      // Seed order
      final orderRef = fakeFirestore.collection('orders').doc('order_reassign_1');
      await orderRef.set({
        'shop_id': 'shop_test_123',
        'status': 'Ready',
        'delivery_type': 'Delivery',
      });

      final partnerA = DeliveryPartner.fromMap((await riderARef.get()).data()!, 'rider_a');
      final partnerB = DeliveryPartner.fromMap((await riderBRef.get()).data()!, 'rider_b');

      // 1. Assign to Rider A
      await deliveryService.assignOrderToPartner(
        shopId: 'shop_test_123',
        orderId: 'order_reassign_1',
        partner: partnerA,
      );

      final rASnap1 = await riderARef.get();
      expect(rASnap1.data()?['active_orders_count'], equals(1));

      // 2. Re-assign order to Rider B (Rider A active count decrements to 0, Rider B to 1)
      await deliveryService.assignOrderToPartner(
        shopId: 'shop_test_123',
        orderId: 'order_reassign_1',
        partner: partnerB,
      );

      final rASnap2 = await riderARef.get();
      expect(rASnap2.data()?['active_orders_count'], equals(0));
      expect(rASnap2.data()?['status'], equals('available'));

      final rBSnap1 = await riderBRef.get();
      expect(rBSnap1.data()?['active_orders_count'], equals(1));

      // 3. Re-assigning to Rider B again should NOT double-increment Rider B
      await deliveryService.assignOrderToPartner(
        shopId: 'shop_test_123',
        orderId: 'order_reassign_1',
        partner: partnerB,
      );

      final rBSnap2 = await riderBRef.get();
      expect(rBSnap2.data()?['active_orders_count'], equals(1));
    });

    test('RatingReviewService.submitOrderReview updates delivery partner rating aggregate', () async {
      final reviewService = RatingReviewService(firestore: fakeFirestore);

      // Seed rider
      final riderRef = fakeFirestore.collection('delivery_partners').doc('rider_rating_1');
      await riderRef.set({
        'shop_id': 'shop_test_123',
        'name': 'Sunil Rider',
        'phone': '9876543212',
        'rating': 5.0,
        'rating_count': 0,
        'total_rating_points': 0.0,
        'status': 'available',
      });

      // Seed delivered order with assigned rider
      final orderRef = fakeFirestore.collection('orders').doc('order_rated_1');
      await orderRef.set({
        'shop_id': 'shop_test_123',
        'delivery_boy_id': 'rider_rating_1',
        'delivery_boy_name': 'Sunil Rider',
        'status': 'Delivered',
        'total_amount': 250.0,
      });

      // Customer submits review with deliveryRating = 4.0 and shopRating = 5.0
      await reviewService.submitOrderReview(
        orderId: 'order_rated_1',
        shopRating: 5.0,
        deliveryRating: 4.0,
        comment: 'Fast and courteous delivery!',
      );

      // Verify rider rating is updated to 4.0 with count 1
      final updatedRider = await riderRef.get();
      expect(updatedRider.data()?['rating'], equals(4.0));
      expect(updatedRider.data()?['rating_count'], equals(1));
      expect(updatedRider.data()?['total_rating_points'], equals(4.0));
    });

    test('ComplaintService.resolveComplaint with full refund marks order as Refunded', () async {
      final complaintService = ComplaintService(firestore: fakeFirestore);

      // Seed order
      final orderRef = fakeFirestore.collection('orders').doc('order_comp_1');
      await orderRef.set({
        'shop_id': 'shop_test_123',
        'total_amount': 350.0,
        'status': 'Delivered',
        'payment_status': 'Paid',
      });

      // Seed complaint
      final compRef = fakeFirestore.collection('complaints').doc('comp_refund_1');
      await compRef.set({
        'order_id': 'order_comp_1',
        'shop_id': 'shop_test_123',
        'customer_phone': '9876543210',
        'customer_name': 'Asha Devi',
        'status': 'pending',
        'category': 'damaged_item',
        'description': 'Oil packet leaked completely',
        'created_at': DateTime.now(),
      });

      // Resolve with full refund
      await complaintService.resolveComplaint(
        complaintId: 'comp_refund_1',
        resolutionType: ResolutionType.refund,
        resolutionNotes: 'Approved refund for damaged oil bottle',
        refundAmount: 350.0,
        refundMethod: RefundMethod.cash,
        resolvedBy: 'Merchant Ramesh',
      );

      final updatedOrder = await orderRef.get();
      expect(updatedOrder.data()?['complaint_status'], equals('resolved_refund'));
      expect(updatedOrder.data()?['payment_status'], equals('Refunded'));
      expect(updatedOrder.data()?['refund_amount'], equals(350.0));
      expect(updatedOrder.data()?['refund_id'], contains('REF_COMP_'));
    });

    test('AnalyticsService parses string cost_price and excludes cancelled orders from AOV', () async {
      final analytics = AnalyticsService(firestore: fakeFirestore);

      final now = DateTime.now();
      // Seed product with cost_price as String
      await fakeFirestore.collection('products').doc('p_cost_str').set({
        'name': 'Ghee 1L',
        'shop_id': 'shop_analytics_test',
        'price': 600.0,
        'cost_price': '500.0', // String representation from CSV/import
        'category': 'Dairy',
      });

      // Seed 2 orders: 1 Delivered (₹600 revenue, ₹500 COGS), 1 Cancelled (₹0 revenue)
      await fakeFirestore.collection('orders').doc('order_aov_delivered').set({
        'shop_id': 'shop_analytics_test',
        'status': 'Delivered',
        'total_amount': 600.0,
        'created_at': Timestamp.fromDate(now),
        'items': [
          {'id': 'p_cost_str', 'name': 'Ghee 1L', 'price': 600.0, 'quantity': 1.0}
        ],
      });

      await fakeFirestore.collection('orders').doc('order_aov_cancelled').set({
        'shop_id': 'shop_analytics_test',
        'status': 'Cancelled',
        'total_amount': 600.0,
        'created_at': Timestamp.fromDate(now),
        'items': [
          {'id': 'p_cost_str', 'name': 'Ghee 1L', 'price': 600.0, 'quantity': 1.0}
        ],
      });

      final summary = await analytics.fetchAnalyticsSummary(
        shopId: 'shop_analytics_test',
        period: AnalyticsTimePeriod.today,
      );

      // Verify total revenue is 600
      expect(summary.totalRevenue, equals(600.0));
      // Verify total COGS is 500 (read parsed string '500.0', not 85% estimate which would be 510)
      expect(summary.totalCOGS, equals(500.0));
      expect(summary.grossProfit, equals(100.0));
      // AOV should be based on completed/active orders (600 / 1 = 600), not depressed by cancelled order (600 / 2 = 300)
      expect(summary.averageOrderValue, equals(600.0));
    });
  });
}
