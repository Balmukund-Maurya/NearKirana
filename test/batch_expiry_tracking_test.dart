import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'package:near_kirana/batch_models.dart';
import 'package:near_kirana/batch_service.dart';
import 'package:near_kirana/admin_batch_expiry_screen.dart';
import 'package:near_kirana/widgets/add_batch_dialog.dart';
import 'package:near_kirana/widgets/dispose_batch_dialog.dart';
import 'package:near_kirana/widgets/batch_details_dialog.dart';
import 'package:near_kirana/shop_provider.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({'current_shop_id': 'SHOP_TEST_BATCH'});

  group('Feature 55: Domain Models - Batch & Expiry', () {
    final now = DateTime(2026, 10, 14, 10, 0);

    test('BatchModel daysUntilExpiry, isExpired, and isNearExpiry calculations', () {
      // 1. Expired batch (expired 2 days ago)
      final expiredBatch = BatchModel(
        id: 'B1',
        shopId: 'SHOP_TEST',
        productId: 'P_MILK',
        productName: 'Amul Taaza Milk 500ml',
        batchNumber: 'L101',
        quantity: 12,
        initialQuantity: 24,
        expiryDate: now.subtract(const Duration(days: 2)),
        costPrice: 26.0,
        sellingPrice: 30.0,
        createdAt: now.subtract(const Duration(days: 7)),
        updatedAt: now,
      );

      expect(expiredBatch.daysUntilExpiry(now), -2);
      expect(expiredBatch.isExpired(now), isTrue);
      expect(expiredBatch.urgency(now), ExpiryUrgency.expired);
      expect(expiredBatch.computedStatus(now), BatchStatus.expired);

      // 2. Critical batch (expires in 4 days)
      final criticalBatch = expiredBatch.copyWith(
        expiryDate: now.add(const Duration(days: 4)),
      );
      expect(criticalBatch.daysUntilExpiry(now), 4);
      expect(criticalBatch.isExpired(now), isFalse);
      expect(criticalBatch.isNearExpiry(15, now), isTrue);
      expect(criticalBatch.urgency(now), ExpiryUrgency.critical);

      // 3. Warning batch (expires in 12 days)
      final warningBatch = expiredBatch.copyWith(
        expiryDate: now.add(const Duration(days: 12)),
      );
      expect(warningBatch.daysUntilExpiry(now), 12);
      expect(warningBatch.urgency(now), ExpiryUrgency.warning);
      expect(warningBatch.computedStatus(now), BatchStatus.nearExpiry);

      // 4. Safe batch (expires in 60 days)
      final safeBatch = expiredBatch.copyWith(
        expiryDate: now.add(const Duration(days: 60)),
      );
      expect(safeBatch.daysUntilExpiry(now), 60);
      expect(safeBatch.isNearExpiry(15, now), isFalse);
      expect(safeBatch.urgency(now), ExpiryUrgency.safe);
      expect(safeBatch.computedStatus(now), BatchStatus.active);
    });

    test('BatchModel financial metrics and valuation', () {
      final batch = BatchModel(
        id: 'B2',
        shopId: 'SHOP_TEST',
        productId: 'P_BISCUIT',
        productName: 'Parle-G 250g',
        batchNumber: 'BG-88',
        quantity: 50,
        initialQuantity: 100,
        expiryDate: DateTime(2026, 12, 31),
        costPrice: 20.0,
        sellingPrice: 25.0,
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );

      expect(batch.inventoryCostValue, 1000.0); // 50 * 20
      expect(batch.inventoryRetailValue, 1250.0); // 50 * 25
      expect(batch.grossMarginPercent, 20.0); // (25-20)/25 * 100
    });

    test('BatchModel serialization and deserialization', () {
      final batch = BatchModel(
        id: 'B3',
        shopId: 'SHOP_TEST',
        productId: 'P_BREAD',
        productName: 'Harvest Gold White Bread',
        batchNumber: 'HG-909',
        quantity: 15,
        initialQuantity: 20,
        unit: 'Packets',
        expiryDate: DateTime(2026, 10, 18),
        mfgDate: DateTime(2026, 10, 13),
        costPrice: 32.0,
        sellingPrice: 40.0,
        storageLocation: 'Front Rack 1',
        notes: 'Keep in cool dry place',
        createdAt: DateTime(2026, 10, 13),
        updatedAt: DateTime(2026, 10, 13),
      );

      final map = batch.toMap();
      expect(map['batch_number'], 'HG-909');
      expect(map['quantity'], 15);
      expect(map['storage_location'], 'Front Rack 1');

      final reconstructed = BatchModel.fromMap('B3', map);
      expect(reconstructed.id, 'B3');
      expect(reconstructed.productName, 'Harvest Gold White Bread');
      expect(reconstructed.unit, 'Packets');
      expect(reconstructed.costPrice, 32.0);
    });

    test('BatchDisposalRecord serialization and reasons', () {
      final disposal = BatchDisposalRecord(
        id: 'DISP-1',
        shopId: 'SHOP_TEST',
        batchId: 'B_EXPIRED',
        productId: 'P_MILK',
        productName: 'Amul Taaza Milk 500ml',
        batchNumber: 'L101',
        quantityDisposed: 5,
        unit: 'Packets',
        reason: DisposalReason.expired,
        lossAmount: 130.0, // 5 * 26
        disposedAt: DateTime(2026, 10, 14, 12, 0),
        disposedBy: 'Ramesh (Shopkeeper)',
        notes: 'Curdled milk packet discarded',
      );

      final map = disposal.toMap();
      expect(map['reason'], 'expired');
      expect(map['loss_amount'], 130.0);

      final reconstructed = BatchDisposalRecord.fromMap('DISP-1', map);
      expect(reconstructed.quantityDisposed, 5.0);
      expect(reconstructed.reason, DisposalReason.expired);
      expect(reconstructed.lossAmount, 130.0);
    });

    test('BatchAnalyticsSummary aggregation properties', () {
      const summary = BatchAnalyticsSummary(
        totalActiveBatches: 20,
        totalNearExpiryBatches: 5,
        totalExpiredBatches: 2,
        safeBatchesCount: 13,
        totalAtRiskUnits: 60.0,
        totalAtRiskCostValue: 1500.0,
        totalExpiredUnits: 20.0,
        totalExpiredCostValue: 500.0,
        totalDisposedUnits: 15.0,
        totalDisposedLossValue: 375.0,
      );

      expect(summary.totalUrgentUnits, 80.0); // 60 + 20
      expect(summary.totalCapitalAtRisk, 2000.0); // 1500 + 500
    });
  });

  group('Feature 55: BatchService Backend Operations', () {
    late FakeFirebaseFirestore fakeFirestore;
    late BatchService service;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      FirebaseUtils.setFirestore(fakeFirestore);
      service = BatchService(firestore: fakeFirestore);

      // Seed product
      await fakeFirestore.collection('products').doc('P_MILK').set({
        'shop_id': 'SHOP_TEST_BATCH',
        'name': 'Amul Taaza Milk 500ml',
        'stock_quantity': 40.0,
        'cost_price': 25.0,
        'price': 30.0,
      });
    });

    test('createBatch saves document, determines status, and updates product metadata', () async {
      final now = DateTime.now();
      final expiry = now.add(const Duration(days: 10)); // Near expiry <= 15 days

      final batch = await service.createBatch(
        shopId: 'SHOP_TEST_BATCH',
        productId: 'P_MILK',
        productName: 'Amul Taaza Milk 500ml',
        batchNumber: 'B-OCT26-01',
        quantity: 20,
        unit: 'Packets',
        expiryDate: expiry,
        costPrice: 25.0,
        sellingPrice: 30.0,
        storageLocation: 'Fridge Rack 2',
      );

      expect(batch.batchNumber, 'B-OCT26-01');
      expect(batch.quantity, 20.0);
      expect(batch.status, BatchStatus.nearExpiry);

      // Verify Firestore doc
      final doc = await fakeFirestore.collection('product_batches').doc(batch.id).get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['batch_number'], 'B-OCT26-01');

      // Verify product metadata updated
      final prodDoc = await fakeFirestore.collection('products').doc('P_MILK').get();
      expect(prodDoc.data()?['has_batches'], isTrue);
      expect(prodDoc.data()?['latest_batch_number'], 'B-OCT26-01');
    });

    test('updateBatch modifies batch details and dynamically recalibrates status', () async {
      final batch = await service.createBatch(
        shopId: 'SHOP_TEST_BATCH',
        productId: 'P_MILK',
        productName: 'Amul Taaza Milk 500ml',
        batchNumber: 'B-OLD',
        quantity: 15,
        expiryDate: DateTime.now().add(const Duration(days: 45)), // Active
      );
      expect(batch.status, BatchStatus.active);

      // Update to expired date
      final pastDate = DateTime.now().subtract(const Duration(days: 3));
      await service.updateBatch(
        batchId: batch.id,
        expiryDate: pastDate,
      );

      final updated = await service.getBatch(batch.id);
      expect(updated?.status, BatchStatus.expired);
    });

    test('adjustBatchStock updates quantity and sets depleted when zero', () async {
      final batch = await service.createBatch(
        shopId: 'SHOP_TEST_BATCH',
        productId: 'P_MILK',
        productName: 'Amul Taaza Milk 500ml',
        batchNumber: 'B-STOCK',
        quantity: 10,
        expiryDate: DateTime.now().add(const Duration(days: 30)),
      );

      // Decrement by 10
      await service.adjustBatchStock(batch.id, -10);

      final updated = await service.getBatch(batch.id);
      expect(updated?.quantity, 0.0);
      expect(updated?.status, BatchStatus.depleted);
    });

    test('disposeBatchStock writes off expired stock and reduces store inventory', () async {
      final batch = await service.createBatch(
        shopId: 'SHOP_TEST_BATCH',
        productId: 'P_MILK',
        productName: 'Amul Taaza Milk 500ml',
        batchNumber: 'B-DISPOSE',
        quantity: 8,
        costPrice: 25.0,
        expiryDate: DateTime.now().subtract(const Duration(days: 1)), // Expired
      );

      // Dispose 5 units
      final record = await service.disposeBatchStock(
        shopId: 'SHOP_TEST_BATCH',
        batchId: batch.id,
        quantityDisposed: 5,
        reason: DisposalReason.expired,
        notes: 'Expired stock discarded',
        syncProductStock: true,
      );

      expect(record.quantityDisposed, 5.0);
      expect(record.lossAmount, 125.0); // 5 * 25

      // Check batch remaining stock: 8 - 5 = 3
      final updatedBatch = await service.getBatch(batch.id);
      expect(updatedBatch?.quantity, 3.0);

      // Check product store stock: 40 - 5 = 35
      final prodDoc = await fakeFirestore.collection('products').doc('P_MILK').get();
      expect((prodDoc.data()?['stock_quantity'] as num).toDouble(), 35.0);

      // Verify disposal record persisted
      final disposals = await service.streamDisposalRecords('SHOP_TEST_BATCH').first;
      expect(disposals.length, 1);
      expect(disposals.first.lossAmount, 125.0);
      expect(disposals.first.reason, DisposalReason.expired);
    });

    test('fetchBatchAnalytics aggregates active, near expiry, and expired metrics', () async {
      final now = DateTime.now();

      // 1 expired batch (5 units @ ₹20 = ₹100 loss)
      await service.createBatch(
        shopId: 'SHOP_TEST_BATCH',
        productId: 'P1',
        productName: 'Item 1',
        batchNumber: 'B1',
        quantity: 5,
        costPrice: 20.0,
        expiryDate: now.subtract(const Duration(days: 2)),
      );

      // 1 near-expiry batch (10 units @ ₹30 = ₹300 at risk)
      await service.createBatch(
        shopId: 'SHOP_TEST_BATCH',
        productId: 'P2',
        productName: 'Item 2',
        batchNumber: 'B2',
        quantity: 10,
        costPrice: 30.0,
        expiryDate: now.add(const Duration(days: 8)),
      );

      // 1 safe batch (25 units @ ₹10)
      await service.createBatch(
        shopId: 'SHOP_TEST_BATCH',
        productId: 'P3',
        productName: 'Item 3',
        batchNumber: 'B3',
        quantity: 25,
        costPrice: 10.0,
        expiryDate: now.add(const Duration(days: 60)),
      );

      final summary = await service.fetchBatchAnalytics('SHOP_TEST_BATCH', nearExpiryDays: 15);

      expect(summary.totalActiveBatches, 3);
      expect(summary.totalExpiredBatches, 1);
      expect(summary.totalNearExpiryBatches, 1);
      expect(summary.safeBatchesCount, 1);
      expect(summary.totalExpiredUnits, 5.0);
      expect(summary.totalExpiredCostValue, 100.0);
      expect(summary.totalAtRiskUnits, 10.0);
      expect(summary.totalAtRiskCostValue, 300.0);
    });
  });

  group('Feature 55: UI Widget Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late BatchService service;
    late ShopProvider shopProvider;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      FirebaseUtils.setFirestore(fakeFirestore);
      service = BatchService(firestore: fakeFirestore);

      shopProvider = ShopProvider();
      await shopProvider.setShop('SHOP_TEST_BATCH', 'Ramesh Kirana Store');

      // Seed product
      await fakeFirestore.collection('products').doc('P_MILK').set({
        'shop_id': 'SHOP_TEST_BATCH',
        'name': 'Amul Taaza Milk 500ml',
        'stock_quantity': 50.0,
        'cost_price': 25.0,
        'price': 30.0,
        'unit': 'Packets',
      });
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

    testWidgets('AdminBatchExpiryScreen renders KPI cards, tabs, and alerts list',
        (tester) async {
      final now = DateTime.now();

      // Seed an urgent near-expiry batch
      await service.createBatch(
        shopId: 'SHOP_TEST_BATCH',
        productId: 'P_MILK',
        productName: 'Amul Taaza Milk 500ml',
        batchNumber: 'B-ALERT-01',
        quantity: 15,
        unit: 'Packets',
        costPrice: 25.0,
        sellingPrice: 30.0,
        expiryDate: now.add(const Duration(days: 5)),
      );

      await tester.pumpWidget(
        createTestApp(AdminBatchExpiryScreen(service: service)),
      );
      await tester.pumpAndSettle();

      // Verify Header Titles
      expect(find.text('Expiry & Batch Tracking'), findsOneWidget);
      expect(find.text('Near Expiry (15d)'), findsOneWidget);
      expect(find.text('Expired Stock'), findsOneWidget);
      expect(find.text('Active Batches'), findsOneWidget);

      // Verify Tab labels
      expect(find.text('Expiry Alerts'), findsOneWidget);
      expect(find.text('All Batches'), findsOneWidget);
      expect(find.text('Waste Log'), findsOneWidget);

      // Verify Alert item rendered
      expect(find.text('Amul Taaza Milk 500ml'), findsOneWidget);
      expect(find.text('Batch: B-ALERT-01'), findsOneWidget);
      expect(find.text('Write-off (नुकसान)'), findsOneWidget);
      expect(find.text('Clearance Promo'), findsOneWidget);
    });

    testWidgets('AddBatchDialog creates a new batch with autocomplete and validation',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => AddBatchDialog.show(
                  ctx,
                  shopId: 'SHOP_TEST_BATCH',
                  initialProductId: 'P_MILK',
                  initialProductName: 'Amul Taaza Milk 500ml',
                  service: service,
                ),
                child: const Text('Open Add Batch'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Add Batch'));
      await tester.pumpAndSettle();

      expect(find.text('Add Batch (नया बैच जोड़ें)'), findsOneWidget);
      expect(find.text('Amul Taaza Milk 500ml'), findsOneWidget);

      // Enter stock quantity
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Stock Quantity *'),
        '30',
      );
      await tester.pumpAndSettle();

      // Submit form
      await tester.ensureVisible(find.text('Save Batch (बैच सेव करें)'));
      await tester.tap(find.text('Save Batch (बैच सेव करें)'));
      await tester.pumpAndSettle();

      // Verify saved in backend
      final batches = await service.streamBatches('SHOP_TEST_BATCH').first;
      expect(batches.length, 1);
      expect(batches.first.quantity, 30.0);
      expect(batches.first.productName, 'Amul Taaza Milk 500ml');
    });

    testWidgets('DisposeBatchDialog records stock write-off and calculates financial loss',
        (tester) async {
      final batch = await service.createBatch(
        shopId: 'SHOP_TEST_BATCH',
        productId: 'P_MILK',
        productName: 'Amul Taaza Milk 500ml',
        batchNumber: 'B-WRITEOFF',
        quantity: 10,
        unit: 'Packets',
        costPrice: 25.0,
        expiryDate: DateTime.now().subtract(const Duration(days: 2)),
      );

      await tester.pumpWidget(
        createTestApp(
          Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => DisposeBatchDialog.show(
                  ctx,
                  shopId: 'SHOP_TEST_BATCH',
                  batch: batch,
                  service: service,
                ),
                child: const Text('Open Dispose Dialog'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dispose Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Write-off / Dispose Stock\n(नुकसान दर्ज करें)'), findsOneWidget);
      expect(find.text('Amul Taaza Milk 500ml'), findsOneWidget);

      // Select 'Half' preset chip (10 / 2 = 5)
      await tester.tap(find.text('Half'));
      await tester.pumpAndSettle();

      expect(find.text('₹125.00'), findsOneWidget); // 5 * 25 = 125

      // Submit disposal
      await tester.ensureVisible(find.text('Confirm Write-Off (नुकसान दर्ज करें)'));
      await tester.tap(find.text('Confirm Write-Off (नुकसान दर्ज करें)'));
      await tester.pumpAndSettle();

      // Verify batch remaining stock: 10 - 5 = 5
      final updated = await service.getBatch(batch.id);
      expect(updated?.quantity, 5.0);
    });

    testWidgets('BatchDetailsDialog displays timeline and promo share',
        (tester) async {
      final now = DateTime(2026, 10, 14, 12, 0);
      final batch = BatchModel(
        id: 'B-DETAILS',
        shopId: 'SHOP_TEST_BATCH',
        productId: 'P_MILK',
        productName: 'Amul Taaza Milk 500ml',
        batchNumber: 'BT-999',
        quantity: 12,
        initialQuantity: 24,
        unit: 'Packets',
        expiryDate: now.add(const Duration(days: 6)),
        costPrice: 25.0,
        sellingPrice: 30.0,
        storageLocation: 'Dairy Chiller',
        notes: 'Store between 2-4 deg C',
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        createTestApp(
          Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => BatchDetailsDialog.show(
                  ctx,
                  shopId: 'SHOP_TEST_BATCH',
                  batch: batch,
                  service: service,
                ),
                child: const Text('Open Batch Details'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Batch Details'));
      await tester.pumpAndSettle();

      expect(find.text('Batch #BT-999'), findsOneWidget);
      expect(find.text('Amul Taaza Milk 500ml'), findsOneWidget);
      expect(find.text('Location: Dairy Chiller'), findsOneWidget);
      expect(find.text('12.0 Packets'), findsOneWidget);
      expect(find.text('₹300.00'), findsOneWidget); // 12 * 25
      expect(find.text('Share Clearance Promo (सस्ता बेचें)'), findsOneWidget);
    });
  });
}
