import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'package:near_kirana/supplier_models.dart';
import 'package:near_kirana/supplier_service.dart';
import 'package:near_kirana/admin_suppliers_screen.dart';
import 'package:near_kirana/widgets/add_supplier_dialog.dart';
import 'package:near_kirana/widgets/record_supplier_payment_dialog.dart';
import 'package:near_kirana/widgets/purchase_order_details_dialog.dart';
import 'package:near_kirana/shop_provider.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({'current_shop_id': 'SHOP_TEST_1'});

  group('Feature 54: Domain Models - Supplier, Purchase & Payment', () {
    test('SupplierModel serialization and dues calculation', () {
      final now = DateTime(2026, 10, 14, 10, 0);
      final supplier = SupplierModel(
        id: 'SUP-1001',
        shopId: 'SHOP_TEST_1',
        name: 'M/s Agarwal Wholesalers',
        contactPerson: 'Rajesh Agarwal',
        phone: '9876543210',
        email: 'agarwal@kirana.com',
        gstin: '07AAAAA0000A1Z5',
        address: 'Main Grain Market, Shop 14',
        category: 'FMCG & Packaged Foods',
        balanceDue: 4500.0,
        totalPurchased: 25000.0,
        totalPaid: 20500.0,
        notes: 'Delivery every Tuesday',
        createdAt: now,
        updatedAt: now,
      );

      expect(supplier.hasOutstandingDue, isTrue);

      final map = supplier.toMap();
      expect(map['name'], 'M/s Agarwal Wholesalers');
      expect(map['balance_due'], 4500.0);
      expect(map['total_purchased'], 25000.0);

      final reconstructed = SupplierModel.fromMap('SUP-1001', map);
      expect(reconstructed.id, 'SUP-1001');
      expect(reconstructed.name, supplier.name);
      expect(reconstructed.contactPerson, 'Rajesh Agarwal');
      expect(reconstructed.balanceDue, 4500.0);

      final updated = supplier.copyWith(balanceDue: 0.0);
      expect(updated.hasOutstandingDue, isFalse);
    });

    test('PurchaseItemModel subtotal and margin calculation', () {
      const item = PurchaseItemModel(
        productId: 'BARCODE_BISCUIT_50',
        productName: 'Parle-G 250g',
        orderedQuantity: 50.0,
        receivedQuantity: 50.0,
        unit: 'Packets',
        costPrice: 20.0,
        sellingPrice: 25.0,
      );

      expect(item.subtotal, 1000.0); // 50 * 20
      expect(item.estimatedMarginPercent, 20.0); // (25-20)/25 = 20%

      final map = item.toMap();
      expect(map['product_id'], 'BARCODE_BISCUIT_50');
      expect(map['subtotal'], 1000.0);

      final fromMap = PurchaseItemModel.fromMap(map);
      expect(fromMap.productName, 'Parle-G 250g');
      expect(fromMap.subtotal, 1000.0);
    });

    test('PurchaseOrderModel financials and status serialization', () {
      final now = DateTime(2026, 10, 14, 11, 0);
      final po = PurchaseOrderModel(
        id: 'PO-2001',
        shopId: 'SHOP_TEST_1',
        supplierId: 'SUP-1001',
        supplierName: 'M/s Agarwal Wholesalers',
        supplierPhone: '9876543210',
        invoiceNumber: 'INV-8821',
        purchaseDate: now,
        status: PurchaseOrderStatus.received,
        items: const [
          PurchaseItemModel(
            productId: 'P1',
            productName: 'Biscuit Packets',
            orderedQuantity: 50,
            receivedQuantity: 50,
            costPrice: 20,
            sellingPrice: 25,
          ),
          PurchaseItemModel(
            productId: 'P2',
            productName: 'Atta 5kg',
            orderedQuantity: 10,
            receivedQuantity: 10,
            costPrice: 180,
            sellingPrice: 210,
          ),
        ],
        subtotal: 2800.0, // (50*20 = 1000) + (10*180 = 1800)
        transportCharges: 100.0,
        discount: 50.0,
        totalAmount: 2850.0, // 2800 + 100 - 50
        paidAmount: 850.0,
        balanceDue: 2000.0,
        paymentStatus: PaymentStatus.partial,
        paymentMethod: PurchasePaymentMethod.cash,
        stockUpdated: true,
        createdAt: now,
        updatedAt: now,
      );

      expect(po.totalItemUnits, 60); // 50 + 10
      expect(po.totalAmount, 2850.0);
      expect(po.balanceDue, 2000.0);
      expect(po.paymentStatus, PaymentStatus.partial);

      final map = po.toMap();
      expect(map['invoice_number'], 'INV-8821');
      expect(map['total_amount'], 2850.0);
      expect(map['stock_updated'], isTrue);

      final reconstructed = PurchaseOrderModel.fromMap('PO-2001', map);
      expect(reconstructed.id, 'PO-2001');
      expect(reconstructed.items.length, 2);
      expect(reconstructed.totalItemUnits, 60);
      expect(reconstructed.balanceDue, 2000.0);
    });

    test('SupplierPaymentModel serialization', () {
      final now = DateTime(2026, 10, 14, 12, 0);
      final payment = SupplierPaymentModel(
        id: 'SPAY-3001',
        shopId: 'SHOP_TEST_1',
        supplierId: 'SUP-1001',
        supplierName: 'M/s Agarwal Wholesalers',
        purchaseOrderId: 'PO-2001',
        amount: 2000.0,
        paymentDate: now,
        paymentMethod: PurchasePaymentMethod.upi,
        referenceNumber: 'UPI98234710',
        notes: 'Cleared invoice INV-8821 balance',
        createdAt: now,
      );

      final map = payment.toMap();
      expect(map['amount'], 2000.0);
      expect(map['payment_method'], 'upi');
      expect(map['reference_number'], 'UPI98234710');

      final reconstructed = SupplierPaymentModel.fromMap('SPAY-3001', map);
      expect(reconstructed.id, 'SPAY-3001');
      expect(reconstructed.amount, 2000.0);
      expect(reconstructed.paymentMethod, PurchasePaymentMethod.upi);
    });
  });

  group('Feature 54: SupplierService Backend Operations', () {
    late FakeFirebaseFirestore fakeFirestore;
    late SupplierService service;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      FirebaseUtils.setFirestore(fakeFirestore);
      service = SupplierService(firestore: fakeFirestore);

      // Seed a test product in inventory: 10 biscuit packets in stock @ ₹20 cost
      await fakeFirestore.collection('products').doc('PROD_BISCUIT').set({
        'shop_id': 'SHOP_TEST_1',
        'barcode': 'PROD_BISCUIT',
        'name': 'Parle-G 250g',
        'price': 25.0,
        'cost_price': 20.0,
        'purchase_price': 20.0,
        'stock_quantity': 10.0,
        'unit': 'Packets',
        'is_loose': false,
      });
    });

    test('createSupplier, updateSupplier, and streamSuppliers', () async {
      final supplier = await service.createSupplier(
        shopId: 'SHOP_TEST_1',
        name: 'Gupta Traders',
        contactPerson: 'Sunil Gupta',
        phone: '9811223344',
        category: 'Grains, Atta & Pulses',
        openingBalanceDue: 1500.0,
      );

      expect(supplier.id.startsWith('SUP-'), isTrue);
      expect(supplier.balanceDue, 1500.0);

      // Verify Firestore record
      final doc = await fakeFirestore.collection('suppliers').doc(supplier.id).get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['name'], 'Gupta Traders');
      expect(doc.data()?['balance_due'], 1500.0);

      // Update
      await service.updateSupplier(
        supplierId: supplier.id,
        contactPerson: 'Sunil Kumar Gupta',
      );
      final updatedDoc = await fakeFirestore.collection('suppliers').doc(supplier.id).get();
      expect(updatedDoc.data()?['contact_person'], 'Sunil Kumar Gupta');

      // Stream
      final list = await service.streamSuppliers('SHOP_TEST_1').first;
      expect(list.length, 1);
      expect(list.first.name, 'Gupta Traders');
    });

    test('createPurchaseOrder updates inventory stock automatically and updates supplier dues', () async {
      // 1. Create supplier
      final supplier = await service.createSupplier(
        shopId: 'SHOP_TEST_1',
        name: 'Amul Dairy Agency',
        phone: '9899001122',
        category: 'Dairy & Bakery',
      );

      // 2. Buy 50 biscuit packets @ ₹22 cost price (User example scenario)
      final purchaseOrder = await service.createPurchaseOrder(
        shopId: 'SHOP_TEST_1',
        supplierId: supplier.id,
        supplierName: supplier.name,
        supplierPhone: supplier.phone,
        invoiceNumber: 'INV-4001',
        purchaseDate: DateTime.now(),
        items: const [
          PurchaseItemModel(
            productId: 'PROD_BISCUIT',
            productName: 'Parle-G 250g',
            orderedQuantity: 50,
            receivedQuantity: 50,
            unit: 'Packets',
            costPrice: 22.0,
            sellingPrice: 25.0,
          ),
        ],
        paidAmount: 300.0, // Partial payment: 300 paid out of 1100
        paymentMethod: PurchasePaymentMethod.cash,
        updateStock: true,
      );

      expect(purchaseOrder.totalAmount, 1100.0); // 50 * 22
      expect(purchaseOrder.paidAmount, 300.0);
      expect(purchaseOrder.balanceDue, 800.0);
      expect(purchaseOrder.stockUpdated, isTrue);

      // 3. Verify Product Inventory Stock Increment: 10 + 50 = 60!
      final prodDoc = await fakeFirestore.collection('products').doc('PROD_BISCUIT').get();
      expect((prodDoc.data()?['stock_quantity'] as num).toDouble(), 60.0);
      // Cost price updated to latest purchase cost
      expect((prodDoc.data()?['cost_price'] as num).toDouble(), 22.0);
      expect((prodDoc.data()?['purchase_price'] as num).toDouble(), 22.0);

      // 4. Verify Supplier Ledger
      final supDoc = await fakeFirestore.collection('suppliers').doc(supplier.id).get();
      expect((supDoc.data()?['total_purchased'] as num).toDouble(), 1100.0);
      expect((supDoc.data()?['total_paid'] as num).toDouble(), 300.0);
      expect((supDoc.data()?['balance_due'] as num).toDouble(), 800.0);

      // 5. Verify initial payment record created in supplier_payments
      final payments = await service.streamSupplierPayments('SHOP_TEST_1').first;
      expect(payments.length, 1);
      expect(payments.first.amount, 300.0);
      expect(payments.first.purchaseOrderId, purchaseOrder.id);
    });

    test('recordSupplierPayment clears outstanding dues and updates purchase order', () async {
      final supplier = await service.createSupplier(
        shopId: 'SHOP_TEST_1',
        name: 'Sharma Provisions',
        phone: '9812345678',
      );

      final po = await service.createPurchaseOrder(
        shopId: 'SHOP_TEST_1',
        supplierId: supplier.id,
        supplierName: supplier.name,
        supplierPhone: supplier.phone,
        invoiceNumber: 'INV-5002',
        purchaseDate: DateTime.now(),
        items: const [
          PurchaseItemModel(
            productId: 'PROD_BISCUIT',
            productName: 'Parle-G 250g',
            orderedQuantity: 20,
            receivedQuantity: 20,
            costPrice: 20.0,
          ),
        ],
        paidAmount: 0.0, // Full credit
      );

      expect(po.balanceDue, 400.0);

      // Record ₹400 payment to clear balance
      final payment = await service.recordSupplierPayment(
        shopId: 'SHOP_TEST_1',
        supplierId: supplier.id,
        supplierName: supplier.name,
        purchaseOrderId: po.id,
        amount: 400.0,
        paymentDate: DateTime.now(),
        paymentMethod: PurchasePaymentMethod.upi,
        referenceNumber: 'UPI99228811',
      );

      expect(payment.amount, 400.0);

      // Supplier balance should now be 0
      final supDoc = await fakeFirestore.collection('suppliers').doc(supplier.id).get();
      expect((supDoc.data()?['balance_due'] as num).toDouble(), 0.0);
      expect((supDoc.data()?['total_paid'] as num).toDouble(), 400.0);

      // Purchase order balance should now be 0 & marked paid
      final poDoc = await fakeFirestore.collection('purchase_orders').doc(po.id).get();
      expect((poDoc.data()?['balance_due'] as num).toDouble(), 0.0);
      expect((poDoc.data()?['paid_amount'] as num).toDouble(), 400.0);
      expect(poDoc.data()?['payment_status'], 'paid');
    });

    test('receivePurchaseOrder applies deferred stock updates', () async {
      final supplier = await service.createSupplier(
        shopId: 'SHOP_TEST_1',
        name: 'Direct Wholesaler',
        phone: '9800112233',
      );

      // Order placed in advance (ordered status, stock NOT updated yet)
      final po = await service.createPurchaseOrder(
        shopId: 'SHOP_TEST_1',
        supplierId: supplier.id,
        supplierName: supplier.name,
        supplierPhone: supplier.phone,
        invoiceNumber: 'INV-6003',
        purchaseDate: DateTime.now(),
        status: PurchaseOrderStatus.ordered,
        items: const [
          PurchaseItemModel(
            productId: 'PROD_BISCUIT',
            productName: 'Parle-G 250g',
            orderedQuantity: 30,
            receivedQuantity: 30,
            costPrice: 21.0,
          ),
        ],
        updateStock: false,
      );

      // Stock before receiving is still 10
      var prodDoc = await fakeFirestore.collection('products').doc('PROD_BISCUIT').get();
      expect((prodDoc.data()?['stock_quantity'] as num).toDouble(), 10.0);

      // Mark received now
      await service.receivePurchaseOrder(po.id);

      // Stock should now be 10 + 30 = 40
      prodDoc = await fakeFirestore.collection('products').doc('PROD_BISCUIT').get();
      expect((prodDoc.data()?['stock_quantity'] as num).toDouble(), 40.0);

      final poDoc = await fakeFirestore.collection('purchase_orders').doc(po.id).get();
      expect(poDoc.data()?['status'], 'received');
      expect(poDoc.data()?['stock_updated'], isTrue);
    });

    test('fetchSupplierAnalytics aggregates KPI metrics correctly', () async {
      final s1 = await service.createSupplier(
        shopId: 'SHOP_TEST_1',
        name: 'Supplier A',
        phone: '9811111111',
        openingBalanceDue: 1200.0,
      );

      await service.createPurchaseOrder(
        shopId: 'SHOP_TEST_1',
        supplierId: s1.id,
        supplierName: s1.name,
        supplierPhone: s1.phone,
        invoiceNumber: 'INV-A1',
        purchaseDate: DateTime.now(),
        items: const [
          PurchaseItemModel(
            productId: 'PROD_BISCUIT',
            productName: 'Parle-G 250g',
            orderedQuantity: 10,
            receivedQuantity: 10,
            costPrice: 20.0,
          ),
        ],
        paidAmount: 200.0,
      );

      final analytics = await service.fetchSupplierAnalytics('SHOP_TEST_1');
      expect(analytics.totalSuppliersCount, 1);
      expect(analytics.suppliersWithDuesCount, 1);
      expect(analytics.totalPurchasesAmount, 200.0);
      expect(analytics.totalPaidAmount, 200.0);
      expect(analytics.totalOutstandingDues, 1200.0); // opening balance
      expect(analytics.totalItemsReceived, 10);
    });
  });

  group('Feature 54: UI Widget Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late SupplierService service;
    late ShopProvider shopProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'current_shop_id': 'SHOP_TEST_1'});
      fakeFirestore = FakeFirebaseFirestore();
      FirebaseUtils.setFirestore(fakeFirestore);
      service = SupplierService(firestore: fakeFirestore);

      await fakeFirestore.collection('products').doc('P_TEST').set({
        'shop_id': 'SHOP_TEST_1',
        'barcode': 'P_TEST',
        'name': 'Test Biscuit 100g',
        'price': 30.0,
        'cost_price': 22.0,
        'stock_quantity': 15.0,
      });

      await service.createSupplier(
        shopId: 'SHOP_TEST_1',
        name: 'National Distributors',
        phone: '9988776655',
        openingBalanceDue: 2500.0,
      );

      shopProvider = ShopProvider();
      await shopProvider.setShop('SHOP_TEST_1', 'Ramesh Kirana Store');
    });

    Widget createTestApp(Widget child) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<ShopProvider>.value(value: shopProvider),
        ],
        child: MaterialApp(
          home: child,
        ),
      );
    }

    testWidgets('AdminSuppliersScreen renders KPI header, tabs and supplier list',
        (tester) async {
      await tester.pumpWidget(createTestApp(AdminSuppliersScreen(service: service)));
      await tester.pumpAndSettle();

      // Check header title
      expect(find.textContaining('Suppliers & Purchases'), findsOneWidget);

      // Check tabs
      expect(find.textContaining('Purchases (खरीद)'), findsOneWidget);
      expect(find.textContaining('Suppliers & Dues (उधारी)'), findsOneWidget);
      expect(find.textContaining('Payment Ledger (लेज़र)'), findsOneWidget);

      // Check FAB
      expect(find.text('New Purchase (नई खरीद)'), findsOneWidget);

      // Switch to Suppliers tab
      await tester.tap(find.textContaining('Suppliers & Dues (उधारी)'));
      await tester.pumpAndSettle();

      expect(find.text('National Distributors'), findsOneWidget);
      expect(find.text('₹2500'), findsAtLeastNWidgets(1));
      expect(find.text('Pay Due'), findsOneWidget);
    });

    testWidgets('AddSupplierDialog creates a new supplier with validation',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(
          Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => AddSupplierDialog.show(
                  ctx,
                  shopId: 'SHOP_TEST_1',
                  service: service,
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Add New Wholesaler / Supplier'), findsOneWidget);

      // Enter supplier details
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Supplier / Business Name *'),
        'Kalyan Grains Agency',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone Number *'),
        '9876543210',
      );

      // Tap Register Supplier
      await tester.tap(find.text('Register Supplier'));
      await tester.pumpAndSettle();

      // Verify in Firestore
      final sups = await service.streamSuppliers('SHOP_TEST_1').first;
      expect(sups.any((s) => s.name == 'Kalyan Grains Agency'), isTrue);
    });

    testWidgets('RecordSupplierPaymentDialog displays balance and records payment',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final sups = await service.streamSuppliers('SHOP_TEST_1').first;
      final supplier = sups.first;

      await tester.pumpWidget(
        createTestApp(
          Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => RecordSupplierPaymentDialog.show(
                  ctx,
                  shopId: 'SHOP_TEST_1',
                  supplier: supplier,
                  service: service,
                ),
                child: const Text('Open Payment Dialog'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Payment Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Record Supplier Payment'), findsOneWidget);
      expect(find.text('National Distributors'), findsOneWidget);
      expect(find.text('₹2500.00'), findsOneWidget);

      // Enter 1250 payment
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Payment Amount (₹) *'),
        '1250',
      );
      await tester.pumpAndSettle();

      // Submit payment
      await tester.ensureVisible(find.text('Record Payment'));
      await tester.tap(find.text('Record Payment'));
      await tester.pumpAndSettle();

      // Verify supplier balance decreased from 2500 to 1250
      final updatedSup = await service.getSupplier(supplier.id);
      expect(updatedSup?.balanceDue, 1250.0);
    });

    testWidgets('PurchaseOrderDetailsDialog renders table and financial summary',
        (tester) async {
      final now = DateTime(2026, 10, 14, 14, 0);
      final po = PurchaseOrderModel(
        id: 'PO-9999',
        shopId: 'SHOP_TEST_1',
        supplierId: 'SUP-1',
        supplierName: 'National Distributors',
        supplierPhone: '9876543210',
        invoiceNumber: 'INV-12345',
        purchaseDate: now,
        status: PurchaseOrderStatus.received,
        items: const [
          PurchaseItemModel(
            productId: 'P_TEST',
            productName: 'Test Biscuit 100g',
            orderedQuantity: 40,
            receivedQuantity: 40,
            costPrice: 20,
            sellingPrice: 25,
          ),
        ],
        subtotal: 800.0,
        totalAmount: 800.0,
        paidAmount: 300.0,
        balanceDue: 500.0,
        paymentStatus: PaymentStatus.partial,
        stockUpdated: true,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        createTestApp(
          Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => PurchaseOrderDetailsDialog.show(
                  ctx,
                  shopId: 'SHOP_TEST_1',
                  purchaseOrder: po,
                  service: service,
                ),
                child: const Text('Open Details'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Details'));
      await tester.pumpAndSettle();

      expect(find.text('Purchase Invoice #INV-12345'), findsOneWidget);
      expect(find.text('Test Biscuit 100g'), findsOneWidget);
      expect(find.text('40 Pcs'), findsOneWidget);
      expect(find.text('₹800.00'), findsAtLeastNWidgets(1));
      expect(find.text('₹500.00'), findsOneWidget);
      expect(find.text('Pay Due (₹500)'), findsOneWidget);
      expect(find.text('Copy / Share'), findsOneWidget);
    });
  });
}
