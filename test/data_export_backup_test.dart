import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'dart:io';

import 'package:near_kirana/data_export_backup_models.dart';
import 'package:near_kirana/data_export_backup_service.dart';
import 'package:near_kirana/shop_provider.dart';
import 'package:near_kirana/admin_data_export_backup_screen.dart';
import 'package:near_kirana/widgets/export_filter_modal.dart';
import 'package:near_kirana/widgets/restore_test_dialog.dart';
import 'package:near_kirana/widgets/create_backup_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testShopId = 'shop_test_101';
  late FakeFirebaseFirestore fakeFirestore;
  late DataExportBackupService service;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    service = DataExportBackupService(firestore: fakeFirestore);
  });

  group('Feature 57: Domain Models - Data Export & Backup', () {
    test('ExportDomain and ExportFormat properties and file extensions', () {
      expect(ExportDomain.salesReport.defaultBaseName, equals('Sales_Report'));
      expect(ExportDomain.inventoryCatalog.defaultBaseName, equals('Inventory_Catalog'));
      expect(ExportDomain.khataStatements.defaultBaseName, equals('Khata_Statements'));
      expect(ExportDomain.auditLogs.defaultBaseName, equals('Audit_Trail'));

      expect(ExportFormat.csv.extension, equals('csv'));
      expect(ExportFormat.pdf.extension, equals('pdf'));
      expect(ExportFormat.json.extension, equals('json'));

      expect(ExportFormat.csv.mimeType, equals('text/csv'));
      expect(ExportFormat.pdf.mimeType, equals('application/pdf'));
    });

    test('DateRangePreset calculates accurate date ranges', () {
      final now = DateTime(2026, 10, 14, 12, 0, 0);

      final todayRange = DateRangePreset.today.getDateRange(now: now);
      expect(todayRange.start.day, equals(14));
      expect(todayRange.end.day, equals(14));

      final thisMonthRange = DateRangePreset.thisMonth.getDateRange(now: now);
      expect(thisMonthRange.start.day, equals(1));
      expect(thisMonthRange.start.month, equals(10));
      expect(thisMonthRange.end.day, equals(14));

      final lastMonthRange = DateRangePreset.lastMonth.getDateRange(now: now);
      expect(lastMonthRange.start.month, equals(9));
      expect(lastMonthRange.start.day, equals(1));
      expect(lastMonthRange.end.month, equals(9));
      expect(lastMonthRange.end.day, equals(30));
    });

    test('ExportFilter generates proper file names', () {
      final filter = ExportFilter(
        shopId: testShopId,
        domain: ExportDomain.salesReport,
        format: ExportFormat.csv,
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 31),
      );

      final fileName = filter.generateFileName();
      expect(fileName, equals('Sales_Report_20261001_to_20261031.csv'));
    });

    test('BackupSnapshot serialization, retention expiration and short checksum', () {
      final createdAt = DateTime.now().subtract(const Duration(days: 35));
      final snapshot = BackupSnapshot(
        id: 'bk_1',
        shopId: testShopId,
        createdAt: createdAt,
        retentionDays: 30,
        totalRecords: 120,
        countsByDomain: {'products': 50, 'customers': 20, 'orders': 50},
        checksumSha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        sizeBytes: 2048,
        createdBy: 'Owner Ramesh',
      );

      expect(snapshot.isExpired(), isTrue);
      expect(snapshot.formattedSize, equals('2.0 KB'));
      expect(snapshot.shortChecksum, contains('e3b0c442...b855'));

      final map = snapshot.toMap();
      final reconstructed = BackupSnapshot.fromMap(map, docId: 'bk_1');
      expect(reconstructed.id, equals('bk_1'));
      expect(reconstructed.shopId, equals(testShopId));
      expect(reconstructed.totalRecords, equals(120));
      expect(reconstructed.checksumSha256, equals(snapshot.checksumSha256));
    });

    test('RestoreTestResult serialization and health score calculation', () {
      final result = RestoreTestResult(
        id: 'test_101',
        backupId: 'bk_1',
        testedAt: DateTime.now(),
        status: RestoreTestStatus.passed,
        healthScorePercent: 100.0,
        testedBy: 'Owner Ramesh',
        stepsPassed: ['Checksum valid', 'Schema valid'],
        verifiedCounts: {'products': 50, 'customers': 20},
        executionDurationMs: 45,
      );

      final map = result.toMap();
      final fromMap = RestoreTestResult.fromMap(map);
      expect(fromMap.status, equals(RestoreTestStatus.passed));
      expect(fromMap.healthScorePercent, equals(100.0));
      expect(fromMap.stepsPassed.length, equals(2));
      expect(fromMap.verifiedCounts['products'], equals(50));
    });

    test('BackupAnalyticsSummary accurately summarizes snapshot metrics', () {
      final s1 = BackupSnapshot(
        id: 's1',
        shopId: testShopId,
        createdAt: DateTime.now(),
        retentionDays: 30,
        totalRecords: 100,
        countsByDomain: {'products': 100},
        checksumSha256: 'abc123456789def',
        sizeBytes: 1024,
        createdBy: 'Owner',
        lastRestoreTestResult: RestoreTestResult(
          id: 't1',
          backupId: 's1',
          testedAt: DateTime.now(),
          status: RestoreTestStatus.passed,
          healthScorePercent: 100.0,
          testedBy: 'Owner',
          stepsPassed: ['All checks passed'],
          verifiedCounts: {'products': 100},
          executionDurationMs: 30,
        ),
      );

      final analytics = BackupAnalyticsSummary.fromSnapshots([s1]);
      expect(analytics.totalBackups, equals(1));
      expect(analytics.averageHealthScore, equals(100.0));
      expect(analytics.totalProtectedRecords, equals(100));
      expect(analytics.activeRetentionDays, equals(30));
    });
  });

  group('Feature 57: DataExportBackupService Backend Operations', () {
    test('generateExport for Sales Report exports orders with RFC 4180 CSV, PDF and Audit Log', () async {
      // Seed test orders for shop
      await fakeFirestore.collection('orders').doc('ord_1').set({
        'shop_id': testShopId,
        'customer_name': 'Aarav Sharma',
        'customer_phone': '9876543210',
        'total_amount': 550.0,
        'discount_amount': 50.0,
        'payment_method': 'UPI',
        'status': 'Delivered',
        'items': [{'name': 'Atta 5kg', 'quantity': 1}],
        'created_at': Timestamp.fromDate(DateTime(2026, 10, 10, 14, 0)),
      });

      await fakeFirestore.collection('orders').doc('ord_2').set({
        'shop_id': testShopId,
        'customer_name': 'Meera Patel',
        'customer_phone': '9123456780',
        'total_amount': 300.0,
        'discount_amount': 0.0,
        'payment_method': 'Cash',
        'status': 'Delivered',
        'items': [{'name': 'Sugar 1kg', 'quantity': 2}],
        'created_at': Timestamp.fromDate(DateTime(2026, 10, 12, 10, 0)),
      });

      // Out of range order (should be ignored)
      await fakeFirestore.collection('orders').doc('ord_old').set({
        'shop_id': testShopId,
        'total_amount': 100.0,
        'created_at': Timestamp.fromDate(DateTime(2026, 8, 1)),
      });

      final filter = ExportFilter(
        shopId: testShopId,
        domain: ExportDomain.salesReport,
        format: ExportFormat.csv,
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 31),
      );

      final result = await service.generateExport(filter);

      expect(result.recordCount, equals(2));
      expect(result.summaryMetrics['gross_revenue'], equals(850.0));
      expect(result.summaryMetrics['total_discounts'], equals(50.0));
      expect(result.summaryMetrics['net_revenue'], equals(800.0));

      // CSV verification
      expect(result.csvString, contains('Order ID,Date,Customer Name'));
      expect(result.csvString, contains('Aarav Sharma'));
      expect(result.csvString, contains('Meera Patel'));
      expect(result.csvString, contains('550.00'));

      // PDF bytes generated
      expect(result.pdfBytes, isNotNull);
      expect(result.pdfBytes!.isNotEmpty, isTrue);

      // Verify Audit Log recorded
      final auditSnap = await fakeFirestore
          .collection('audit_logs')
          .where('shop_id', isEqualTo: testShopId)
          .where('action_type', isEqualTo: 'dataExported')
          .get();
      expect(auditSnap.docs.length, equals(1));
      expect(auditSnap.docs.first.data()['reason'], contains('Exported 2 records'));
    });

    test('generateExport for Inventory Catalog exports products with stock values and barcode', () async {
      await fakeFirestore.collection('products').doc('p1').set({
        'shop_id': testShopId,
        'name': 'Fortune Oil 1L',
        'barcode': '8901234567890',
        'category': 'Oils',
        'mrp': 160.0,
        'price': 140.0,
        'stock_quantity': 20.0,
        'unit': 'bottle',
        'is_active': true,
      });

      final filter = ExportFilter(
        shopId: testShopId,
        domain: ExportDomain.inventoryCatalog,
        format: ExportFormat.csv,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 12, 31),
      );

      final result = await service.generateExport(filter);
      expect(result.recordCount, equals(1));
      expect(result.summaryMetrics['total_stock_value'], equals(2800.0));
      expect(result.csvString, contains('Fortune Oil 1L'));
      expect(result.csvString, contains('8901234567890'));
      expect(result.csvString, contains('2800.00'));
    });

    test('generateExport for Khata Statements exports customer credit balances', () async {
      await fakeFirestore.collection('customers').doc('c1').set({
        'shop_id': testShopId,
        'name': 'Rajesh Gupta',
        'phone': '9811223344',
        'khata_balance': 1250.0,
        'khata_limit': 5000.0,
      });

      final filter = ExportFilter(
        shopId: testShopId,
        domain: ExportDomain.khataStatements,
        format: ExportFormat.csv,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 12, 31),
      );

      final result = await service.generateExport(filter);
      expect(result.recordCount, equals(1));
      expect(result.summaryMetrics['total_outstanding_credit'], equals(1250.0));
      expect(result.csvString, contains('Rajesh Gupta'));
      expect(result.csvString, contains('1250.00'));
    });

    test('createBackupSnapshot serializes data, generates SHA-256 and records backupCreated audit', () async {
      await fakeFirestore.collection('products').doc('prod_1').set({
        'shop_id': testShopId,
        'name': 'Maggi 70g',
        'price': 14.0,
        'stock_quantity': 50.0,
      });

      await fakeFirestore.collection('customers').doc('cust_1').set({
        'shop_id': testShopId,
        'name': 'Sanjay Singh',
        'phone': '9988776655',
        'khata_balance': 200.0,
      });

      final snapshot = await service.createBackupSnapshot(
        shopId: testShopId,
        createdBy: 'Owner Ramesh',
        retentionDays: 30,
      );

      expect(snapshot.shopId, equals(testShopId));
      expect(snapshot.countsByDomain['products'], equals(1));
      expect(snapshot.countsByDomain['customers'], equals(1));
      expect(snapshot.totalRecords, equals(2));
      expect(snapshot.checksumSha256.length, equals(64)); // 256 bits in hex

      // Verify Firestore persistence
      final doc = await fakeFirestore.collection('backups').doc(snapshot.id).get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['checksum_sha256'], equals(snapshot.checksumSha256));

      // Verify Audit Log
      final auditSnap = await fakeFirestore
          .collection('audit_logs')
          .where('shop_id', isEqualTo: testShopId)
          .where('action_type', isEqualTo: 'backupCreated')
          .get();
      expect(auditSnap.docs.isNotEmpty, isTrue);
    });

    test('enforceRetentionPolicy deletes backups older than retention window', () async {
      // 1 old expired backup (40 days old)
      final oldDate = DateTime.now().subtract(const Duration(days: 40));
      await fakeFirestore.collection('backups').doc('old_bk').set({
        'shop_id': testShopId,
        'created_at': oldDate.toIso8601String(),
        'retention_days': 30,
      });

      // 1 fresh backup (2 days old)
      final freshDate = DateTime.now().subtract(const Duration(days: 2));
      await fakeFirestore.collection('backups').doc('fresh_bk').set({
        'shop_id': testShopId,
        'created_at': freshDate.toIso8601String(),
        'retention_days': 30,
      });

      final purged = await service.enforceRetentionPolicy(testShopId);
      expect(purged, equals(1));

      final oldDoc = await fakeFirestore.collection('backups').doc('old_bk').get();
      expect(oldDoc.exists, isFalse);

      final freshDoc = await fakeFirestore.collection('backups').doc('fresh_bk').get();
      expect(freshDoc.exists, isTrue);
    });

    test('runRestoreTest performs sandbox dry-run integrity verification with 100% health score', () async {
      await fakeFirestore.collection('products').doc('p1').set({
        'shop_id': testShopId,
        'name': 'Sugar 1kg',
        'price': 44.0,
        'stock_quantity': 30.0,
      });

      final snapshot = await service.createBackupSnapshot(
        shopId: testShopId,
        createdBy: 'Owner Ramesh',
      );

      final testResult = await service.runRestoreTest(
        backup: snapshot,
        testedBy: 'Owner Ramesh',
      );

      expect(testResult.status, equals(RestoreTestStatus.passed));
      expect(testResult.healthScorePercent, equals(100.0));
      expect(testResult.stepsPassed.any((s) => s.contains('SHA-256 Checksum verified')), isTrue);
      expect(testResult.stepsPassed.any((s) => s.contains('Product Catalog Schema verified')), isTrue);
      expect(testResult.errors.isEmpty, isTrue);

      // Verify backup document updated
      final updatedBk = await fakeFirestore.collection('backups').doc(snapshot.id).get();
      expect(updatedBk.data()!['last_restore_tested_at'], isNotNull);

      // Verify audit log
      final auditSnap = await fakeFirestore
          .collection('audit_logs')
          .where('shop_id', isEqualTo: testShopId)
          .where('action_type', isEqualTo: 'restoreTestRun')
          .get();
      expect(auditSnap.docs.isNotEmpty, isTrue);
    });

    test('runRestoreTest detects corrupted checksum and marks test as failed', () async {
      final validPayload = jsonEncode({
        'shop_id': testShopId,
        'products': [{'name': 'Milk', 'price': 30.0}],
      });

      final corruptedSnapshot = BackupSnapshot(
        id: 'corrupt_bk',
        shopId: testShopId,
        createdAt: DateTime.now(),
        retentionDays: 30,
        totalRecords: 1,
        countsByDomain: {'products': 1},
        checksumSha256: 'tampered_fake_checksum_1234567890abcdef',
        sizeBytes: 100,
        backupPayloadJson: validPayload,
        createdBy: 'Owner',
      );

      await fakeFirestore.collection('backups').doc('corrupt_bk').set(corruptedSnapshot.toMap());

      final testResult = await service.runRestoreTest(
        backup: corruptedSnapshot,
        testedBy: 'Owner',
      );

      expect(testResult.status, equals(RestoreTestStatus.failed));
      expect(testResult.healthScorePercent, lessThan(100.0));
      expect(testResult.errors.any((e) => e.contains('Checksum mismatch')), isTrue);
    });

    test('executeSafeRestore recovers products and customers from verified snapshot', () async {
      final payload = jsonEncode({
        'shop_id': testShopId,
        'products': [
          {'id': 'prod_restored', 'name': 'Restored Rice 5kg', 'price': 320.0, 'stock_quantity': 15.0}
        ],
        'customers': [
          {'id': 'cust_restored', 'name': 'Restored Customer', 'phone': '9876500000', 'khata_balance': 0.0}
        ],
      });

      final backup = BackupSnapshot(
        id: 'bk_restore',
        shopId: testShopId,
        createdAt: DateTime.now(),
        retentionDays: 30,
        totalRecords: 2,
        countsByDomain: {'products': 1, 'customers': 1},
        checksumSha256: 'abc',
        sizeBytes: 200,
        backupPayloadJson: payload,
        createdBy: 'Owner',
      );

      final success = await service.executeSafeRestore(
        backup: backup,
        ownerPin: '0000',
        executedBy: 'Owner',
      );

      expect(success, isTrue);

      final prodDoc = await fakeFirestore.collection('products').doc('prod_restored').get();
      expect(prodDoc.exists, isTrue);
      expect(prodDoc.data()!['name'], equals('Restored Rice 5kg'));

      final custDoc = await fakeFirestore.collection('customers').doc('cust_restored').get();
      expect(custDoc.exists, isTrue);
      expect(custDoc.data()!['name'], equals('Restored Customer'));
    });
  });

  group('Feature 57: UI Widget Tests', () {
    Widget createTestApp(Widget child) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<ShopProvider>(
            create: (_) {
              final sp = ShopProvider();
              sp.setShop(testShopId, 'NearKirana Superstore');
              return sp;
            },
          ),
        ],
        child: MaterialApp(
          home: child,
        ),
      );
    }

    testWidgets('AdminDataExportBackupScreen renders KPI cards, Tab 1 and Tab 2', (tester) async {
      await tester.pumpWidget(createTestApp(AdminDataExportBackupScreen(service: service)));
      await tester.pumpAndSettle();

      // Check AppBar
      expect(find.text('Data Export & Backup (डेटा व बैकअप)'), findsOneWidget);

      // Check Tabs
      expect(find.text('Export Reports (डेटा निर्यात)'), findsOneWidget);
      expect(find.text('Cloud Backups (क्लाउड बैकअप)'), findsOneWidget);

      // Check KPI Cards
      expect(find.text('Last Cloud Backup'), findsOneWidget);
      expect(find.text('Total Snapshots'), findsOneWidget);
      expect(find.text('Restore Health'), findsOneWidget);

      // Check Month-End Hero Card
      expect(find.text('Month-End Sales Report (मंथ-एंड सेल्स रिपोर्ट)'), findsOneWidget);
      expect(find.text('Export CSV (Excel)'), findsOneWidget);
      expect(find.text('Export PDF (Print)'), findsOneWidget);

      // Check Domain Tiles
      expect(find.text('Sales & Revenue Orders'), findsOneWidget);
      expect(find.text('Inventory & Stock Catalog'), findsOneWidget);
      expect(find.text('Customer Khata Statements'), findsOneWidget);

      // Switch to Tab 2 (Cloud Backups)
      await tester.tap(find.text('Cloud Backups (क्लाउड बैकअप)'));
      await tester.pumpAndSettle();

      expect(find.text('Automated Cloud Backups (बैकअप स्नैपशॉट्स)'), findsOneWidget);
      expect(find.text('Backup Now'), findsOneWidget);
    });

    testWidgets('ExportFilterModal renders domain choices, format selector, and date presets', (tester) async {
      await tester.pumpWidget(createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => ExportFilterModal.show(context, shopId: testShopId, service: service),
            child: const Text('Open Export Modal'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Export Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Export Business Records\n(डेटा निर्यात करें)'), findsOneWidget);
      expect(find.text('CSV (Excel/Tally)'), findsOneWidget);
      expect(find.text('PDF (Printable)'), findsOneWidget);
      expect(find.text('Month-End (CA Special)'), findsOneWidget);
      expect(find.text('Generate CSV Export'), findsOneWidget);
    });

    testWidgets('CreateBackupModal renders retention lifespan selection and creates snapshot', (tester) async {
      await tester.pumpWidget(createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => CreateBackupModal.show(context, shopId: testShopId, service: service),
            child: const Text('Open Backup Modal'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Backup Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Create Cloud Backup\n(नया बैकअप स्नैपशॉट लें)'), findsOneWidget);
      expect(find.text('30 Days'), findsOneWidget);
      expect(find.text('Recommended (महीना)'), findsOneWidget);
      expect(find.text('Create Snapshot Now (बैकअप लें)'), findsOneWidget);

      // Tap Create Snapshot
      await tester.tap(find.text('Create Snapshot Now (बैकअप लें)'));
      await tester.pumpAndSettle();

      // Verify backup document was created in FakeFirebaseFirestore
      final snap = await fakeFirestore.collection('backups').where('shop_id', isEqualTo: testShopId).get();
      expect(snap.docs.length, equals(1));
    });

    testWidgets('RestoreTestDialog displays SHA-256 fingerprint, runs restore test and shows health score', (tester) async {
      final payloadJson = jsonEncode({
        'shop_id': testShopId,
        'products': [{'name': 'Item A', 'price': 10.0}],
        'customers': [{'name': 'Customer A', 'phone': '9999999999'}],
      });
      final checksum = sha256.convert(utf8.encode(payloadJson)).toString();

      final snapshot = BackupSnapshot(
        id: 'bk_test_ui',
        shopId: testShopId,
        createdAt: DateTime.now(),
        retentionDays: 30,
        totalRecords: 2,
        countsByDomain: {'products': 1, 'customers': 1},
        checksumSha256: checksum,
        sizeBytes: 1500,
        backupPayloadJson: payloadJson,
        createdBy: 'Owner Ramesh',
      );

      await fakeFirestore.collection('backups').doc('bk_test_ui').set(snapshot.toMap());

      await tester.pumpWidget(createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => RestoreTestDialog.show(context, backup: snapshot, service: service),
            child: const Text('Open Restore Dialog'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Restore Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Restore Testing & Integrity\n(डेटा रिकवरी टेस्ट रिपोर्ट)'), findsOneWidget);
      expect(find.text('Run Restore Test'), findsOneWidget);

      // Execute restore test
      await tester.tap(find.text('Run Restore Test'));
      await tester.pumpAndSettle();

      expect(find.text('Verified 100% (सत्यापित)'), findsOneWidget);
      expect(find.text('Safe Restore'), findsOneWidget);
    });
  });

  group('Feature 57: Firestore Security Rules Verification', () {
    test('firestore.rules contains Section 16 for backups collection multi-tenant isolation', () {
      final rulesFile = File('firestore.rules');
      expect(rulesFile.existsSync(), isTrue);

      final content = rulesFile.readAsStringSync();
      expect(content, contains('16. DATA EXPORTS & CLOUD BACKUPS'));
      expect(content, contains('match /backups/{backupId}'));
      expect(content, contains('isShopOwner(resource.data.shop_id)'));
    });
  });
}
