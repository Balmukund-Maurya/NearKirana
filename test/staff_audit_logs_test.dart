import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:io';

import 'package:near_kirana/firebase_utils.dart';
import 'package:near_kirana/staff_audit_models.dart';
import 'package:near_kirana/staff_audit_service.dart';
import 'package:near_kirana/role_permissions.dart';
import 'package:near_kirana/shop_provider.dart';
import 'package:near_kirana/admin_staff_audit_screen.dart';
import 'package:near_kirana/widgets/add_edit_staff_dialog.dart';
import 'package:near_kirana/widgets/audit_log_details_dialog.dart';
import 'package:near_kirana/widgets/quick_stock_adjustment_dialog.dart';

Widget createTestApp(Widget child, {String shopId = 'SHOP_TEST_STAFF'}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ShopProvider>(
        create: (_) {
          final sp = ShopProvider();
          sp.setShop(shopId, 'Test Kirana Store');
          return sp;
        },
      ),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feature 56: Domain Models - Staff & Audit', () {
    test('StaffRole enum and default permissions', () {
      expect(StaffRole.fromString('manager'), StaffRole.manager);
      expect(StaffRole.fromString('cashier'), StaffRole.cashier);
      expect(StaffRole.fromString('stock_clerk'), StaffRole.stockClerk);
      expect(StaffRole.fromString('unknown'), StaffRole.custom);

      final managerPerms = StaffMember.defaultPermissionsForRole(StaffRole.manager);
      expect(managerPerms.contains(StaffPermission.billing), isTrue);
      expect(managerPerms.contains(StaffPermission.inventoryAdjustment), isTrue);
      expect(managerPerms.contains(StaffPermission.viewReports), isTrue);

      final cashierPerms = StaffMember.defaultPermissionsForRole(StaffRole.cashier);
      expect(cashierPerms.contains(StaffPermission.billing), isTrue);
      expect(cashierPerms.contains(StaffPermission.inventoryAdjustment), isFalse);

      final stockPerms = StaffMember.defaultPermissionsForRole(StaffRole.stockClerk);
      expect(stockPerms.contains(StaffPermission.inventoryAdjustment), isTrue);
      expect(stockPerms.contains(StaffPermission.billing), isFalse);
    });

    test('StaffMember hasPermission checks and deactivation behavior', () {
      final activeStaff = StaffMember(
        id: 'STAFF_1',
        shopId: 'SHOP_TEST',
        name: 'Ramesh Cashier',
        phone: '9876543210',
        role: StaffRole.cashier,
        permissions: {StaffPermission.billing, StaffPermission.orderManagement},
        pin: '1234',
        isActive: true,
        createdAt: DateTime.now(),
      );

      expect(activeStaff.hasPermission(StaffPermission.billing), isTrue);
      expect(activeStaff.hasPermission(StaffPermission.inventoryAdjustment), isFalse);

      // Deactivated staff has no effective permissions
      final inactiveStaff = activeStaff.copyWith(isActive: false);
      expect(inactiveStaff.hasPermission(StaffPermission.billing), isFalse);
    });

    test('StaffMember serialization toMap and fromMap', () {
      final now = DateTime(2026, 10, 14, 10, 0);
      final staff = StaffMember(
        id: 'STAFF_2',
        shopId: 'SHOP_TEST',
        name: 'Suresh Manager',
        phone: '9123456780',
        role: StaffRole.manager,
        permissions: {StaffPermission.billing, StaffPermission.catalogEdit},
        pin: '9999',
        isActive: true,
        createdAt: now,
      );

      final map = staff.toMap();
      expect(map['shop_id'], 'SHOP_TEST');
      expect(map['name'], 'Suresh Manager');
      expect(map['role'], 'manager');
      expect((map['permissions'] as List).contains('billing'), isTrue);

      final reconstituted = StaffMember.fromMap(map, 'STAFF_2');
      expect(reconstituted.id, 'STAFF_2');
      expect(reconstituted.name, 'Suresh Manager');
      expect(reconstituted.role, StaffRole.manager);
      expect(reconstituted.permissions.contains(StaffPermission.catalogEdit), isTrue);
    });

    test('AuditLogEntry serialization and formattedTime', () {
      final now = DateTime.now();
      final entry = AuditLogEntry(
        id: 'LOG_1',
        shopId: 'SHOP_TEST',
        actorId: 'STAFF_1',
        actorName: 'Ramesh',
        actorRole: 'cashier',
        actionType: AuditActionType.stockAdjustment,
        entityType: 'product',
        entityId: 'P_MILK',
        entityName: 'Amul Milk',
        description: 'Stock adjusted from 20 to 12',
        oldValue: {'stock': 20},
        newValue: {'stock': 12},
        timestamp: now,
        reason: 'Recount discrepancy',
      );

      expect(entry.formattedTime, 'Just now');

      final map = entry.toMap();
      expect(map['action_type'], 'stockAdjustment');
      expect(map['reason'], 'Recount discrepancy');
      expect(map['old_value']['stock'], 20);

      final reconstituted = AuditLogEntry.fromMap(map, 'LOG_1');
      expect(reconstituted.id, 'LOG_1');
      expect(reconstituted.actionType, AuditActionType.stockAdjustment);
      expect(reconstituted.reason, 'Recount discrepancy');
    });
  });

  group('Feature 56: StaffAuditService Backend Operations', () {
    late FakeFirebaseFirestore fakeFirestore;
    late StaffAuditService service;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      FirebaseUtils.setFirestore(fakeFirestore);
      service = StaffAuditService(firestore: fakeFirestore);

      // Seed product
      await fakeFirestore.collection('products').doc('P_ATTA_10KG').set({
        'shop_id': 'SHOP_TEST_STAFF',
        'name': 'Ashirvaad Atta 10kg',
        'stock_quantity': 20.0,
        'price': 420.0,
      });
    });

    test('createStaff saves staff and automatically records staffCreated audit log', () async {
      final staff = await service.createStaff(
        shopId: 'SHOP_TEST_STAFF',
        name: 'Vikas Sharma',
        phone: '9811223344',
        role: StaffRole.cashier,
        pin: '4321',
        actorName: 'Store Owner',
        actorRole: 'owner',
      );

      expect(staff.name, 'Vikas Sharma');
      expect(staff.role, StaffRole.cashier);
      expect(staff.hasPermission(StaffPermission.billing), isTrue);

      // Verify doc in Firestore
      final staffDoc = await fakeFirestore.collection('staff_members').doc(staff.id).get();
      expect(staffDoc.exists, isTrue);
      expect(staffDoc.data()?['phone'], '9811223344');

      // Verify audit log created
      final logsSnap = await fakeFirestore.collection('audit_logs').where('shop_id', isEqualTo: 'SHOP_TEST_STAFF').get();
      expect(logsSnap.docs.isNotEmpty, isTrue);
      final logData = logsSnap.docs.first.data();
      expect(logData['action_type'], 'staffCreated');
      expect(logData['entity_name'], 'Vikas Sharma');
    });

    test('updateStaff updates role/permissions and logs audit diff', () async {
      final staff = await service.createStaff(
        shopId: 'SHOP_TEST_STAFF',
        name: 'Pooja Verma',
        phone: '9877001122',
        role: StaffRole.cashier,
      );

      // Promote to manager with expanded permissions
      await service.updateStaff(
        staffId: staff.id,
        shopId: 'SHOP_TEST_STAFF',
        role: StaffRole.manager,
        permissions: {StaffPermission.billing, StaffPermission.inventoryAdjustment, StaffPermission.viewReports},
        actorName: 'Store Owner',
      );

      final updatedDoc = await fakeFirestore.collection('staff_members').doc(staff.id).get();
      expect(updatedDoc.data()?['role'], 'manager');

      // Check audit log
      final logsSnap = await fakeFirestore
          .collection('audit_logs')
          .where('action_type', isEqualTo: 'staffUpdated')
          .get();
      expect(logsSnap.docs.isNotEmpty, isTrue);
      final log = logsSnap.docs.last.data();
      expect(log['entity_id'], staff.id);
      expect(log['new_value']['role'], 'manager');
    });

    test('toggleStaffStatus updates is_active and logs status change', () async {
      final staff = await service.createStaff(
        shopId: 'SHOP_TEST_STAFF',
        name: 'Amit Kumar',
        phone: '9800112233',
        role: StaffRole.stockClerk,
      );
      expect(staff.isActive, isTrue);

      await service.toggleStaffStatus(
        staffId: staff.id,
        shopId: 'SHOP_TEST_STAFF',
        isActive: false,
      );

      final doc = await fakeFirestore.collection('staff_members').doc(staff.id).get();
      expect(doc.data()?['is_active'], isFalse);

      final logsSnap = await fakeFirestore
          .collection('audit_logs')
          .where('action_type', isEqualTo: 'staffStatusToggled')
          .get();
      expect(logsSnap.docs.isNotEmpty, isTrue);
      expect(logsSnap.docs.first.data()['new_value']['is_active'], isFalse);
    });

    test('verifyStaffPin authenticates active staff with correct PIN', () async {
      final staff = await service.createStaff(
        shopId: 'SHOP_TEST_STAFF',
        name: 'Sunil',
        phone: '9988776655',
        role: StaffRole.cashier,
        pin: '5566',
      );

      // Correct PIN
      expect(
        await service.verifyStaffPin(
          shopId: 'SHOP_TEST_STAFF',
          staffId: staff.id,
          pin: '5566',
        ),
        isTrue,
      );

      // Incorrect PIN
      expect(
        await service.verifyStaffPin(
          shopId: 'SHOP_TEST_STAFF',
          staffId: staff.id,
          pin: '0000',
        ),
        isFalse,
      );

      // Deactivated staff
      await service.toggleStaffStatus(staffId: staff.id, shopId: 'SHOP_TEST_STAFF', isActive: false);
      expect(
        await service.verifyStaffPin(
          shopId: 'SHOP_TEST_STAFF',
          staffId: staff.id,
          pin: '5566',
        ),
        isFalse,
      );
    });

    test('adjustStockWithAudit updates stock from 20 to 12 and logs reason and actor', () async {
      // User request exact scenario:
      // "Stock 20 se 12 units hua. Audit log se pata chal sakega ki authorized user ne kab aur kis wajah se adjustment kiya."
      await service.adjustStockWithAudit(
        shopId: 'SHOP_TEST_STAFF',
        productId: 'P_ATTA_10KG',
        productName: 'Ashirvaad Atta 10kg',
        oldStock: 20.0,
        newStock: 12.0,
        reason: 'Physical stock audit discrepancy',
        actorId: 'STAFF_MGR_1',
        actorName: 'Suresh (Manager)',
        actorRole: 'manager',
      );

      // 1. Verify product updated in Firestore
      final prodDoc = await fakeFirestore.collection('products').doc('P_ATTA_10KG').get();
      expect(prodDoc.data()?['stock_quantity'], 12.0);
      expect(prodDoc.data()?['last_stock_adjustment']['reason'], 'Physical stock audit discrepancy');
      expect(prodDoc.data()?['last_stock_adjustment']['actor_name'], 'Suresh (Manager)');

      // 2. Verify immutable audit log entry
      final logsSnap = await fakeFirestore
          .collection('audit_logs')
          .where('action_type', isEqualTo: 'stockAdjustment')
          .get();

      expect(logsSnap.docs.isNotEmpty, isTrue);
      final log = logsSnap.docs.first.data();
      expect(log['entity_name'], 'Ashirvaad Atta 10kg');
      expect(log['actor_name'], 'Suresh (Manager)');
      expect(log['actor_role'], 'manager');
      expect(log['old_value']['stock_quantity'], 20.0);
      expect(log['new_value']['stock_quantity'], 12.0);
      expect(log['new_value']['difference'], -8.0);
      expect(log['reason'], 'Physical stock audit discrepancy');
    });

    test('fetchAnalyticsSummary calculates staff counts, today logs, and critical adjustments', () async {
      // Create 2 staff
      await service.createStaff(
        shopId: 'SHOP_TEST_STAFF',
        name: 'Staff A',
        phone: '9000000001',
        role: StaffRole.manager,
      );
      final staffB = await service.createStaff(
        shopId: 'SHOP_TEST_STAFF',
        name: 'Staff B',
        phone: '9000000002',
        role: StaffRole.cashier,
      );
      await service.toggleStaffStatus(staffId: staffB.id, shopId: 'SHOP_TEST_STAFF', isActive: false);

      // Trigger stock adjustment
      await service.adjustStockWithAudit(
        shopId: 'SHOP_TEST_STAFF',
        productId: 'P_ATTA_10KG',
        productName: 'Ashirvaad Atta 10kg',
        oldStock: 20.0,
        newStock: 12.0,
        reason: 'Physical count check',
        actorId: 'OWNER_UID',
        actorName: 'Store Owner',
        actorRole: 'owner',
      );

      final analytics = await service.fetchAnalyticsSummary('SHOP_TEST_STAFF');
      expect(analytics.totalStaff, 2);
      expect(analytics.activeStaff, 1);
      expect(analytics.todayLogCount >= 3, isTrue); // 2 staff created + 1 status toggle + 1 adjustment
      expect(analytics.criticalChangesCount, 1);
      expect(analytics.topActorName, 'Store Owner');
    });
  });

  group('Feature 56: RBAC & Firestore Security Rules Verification', () {
    test('RolePermissions.canStaffPerform enforces permission and shop isolation', () {
      final staff = StaffMember(
        id: 'STAFF_SHOP_A',
        shopId: 'SHOP_A',
        name: 'Rohan Cashier',
        phone: '9988112233',
        role: StaffRole.cashier,
        permissions: {StaffPermission.billing, StaffPermission.orderManagement},
        createdAt: DateTime.now(),
        isActive: true,
      );

      // Allowed: Billing in Shop A
      expect(
        RolePermissions.canStaffPerform(
          staff: staff,
          targetShopId: 'SHOP_A',
          requiredPermission: StaffPermission.billing,
        ),
        isTrue,
      );

      // Denied: Inventory adjustment (permission not granted to cashier)
      expect(
        RolePermissions.canStaffPerform(
          staff: staff,
          targetShopId: 'SHOP_A',
          requiredPermission: StaffPermission.inventoryAdjustment,
        ),
        isFalse,
      );

      // Denied: Cross-shop action (Staff belonging to Shop A cannot touch Shop B)
      expect(
        RolePermissions.canStaffPerform(
          staff: staff,
          targetShopId: 'SHOP_B',
          requiredPermission: StaffPermission.billing,
        ),
        isFalse,
      );

      // Denied: Deactivated staff
      final inactive = staff.copyWith(isActive: false);
      expect(
        RolePermissions.canStaffPerform(
          staff: inactive,
          targetShopId: 'SHOP_A',
          requiredPermission: StaffPermission.billing,
        ),
        isFalse,
      );
    });

    test('firestore.rules contains Section 15 for staff_members and immutable audit_logs', () {
      final rulesFile = File('firestore.rules');
      expect(rulesFile.existsSync(), isTrue);
      final content = rulesFile.readAsStringSync();

      expect(content.contains('match /staff_members/{staffId}'), isTrue);
      expect(content.contains('match /audit_logs/{logId}'), isTrue);
      expect(content.contains('// Audit logs are strictly immutable: cannot be modified or deleted by normal users!'), isTrue);
    });
  });

  group('Feature 56: UI Widget Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late StaffAuditService service;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      FirebaseUtils.setFirestore(fakeFirestore);
      service = StaffAuditService(firestore: fakeFirestore);

      // Seed staff member
      await service.createStaff(
        shopId: 'SHOP_TEST_STAFF',
        name: 'Manish Kumar',
        phone: '9876501234',
        role: StaffRole.manager,
        pin: '1122',
      );

      // Seed audit log
      await service.recordAuditLog(
        shopId: 'SHOP_TEST_STAFF',
        actorId: 'STAFF_1',
        actorName: 'Manish (Manager)',
        actorRole: 'manager',
        actionType: AuditActionType.stockAdjustment,
        entityType: 'product',
        entityId: 'P_ATTA',
        entityName: 'Ashirvaad Atta 10kg',
        description: 'Stock adjusted for "Ashirvaad Atta 10kg" from 20.0 to 12.0 units (-8.0).',
        oldValue: {'stock_quantity': 20.0},
        newValue: {'stock_quantity': 12.0},
        reason: 'Physical stock audit discrepancy',
      );
    });

    testWidgets('AdminStaffAuditScreen renders KPI cards, tabs, and staff list', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          AdminStaffAuditScreen(service: service),
          shopId: 'SHOP_TEST_STAFF',
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header & KPI metrics
      expect(find.text('Staff & Audit Logs'), findsOneWidget);
      expect(find.text('Active Staff'), findsOneWidget);
      expect(find.text('Today Logs'), findsOneWidget);
      expect(find.text('Critical Changes'), findsOneWidget);

      // Verify Tab 1 (Staff Accounts)
      expect(find.text('Manish Kumar'), findsOneWidget);
      expect(find.text('+91 9876501234'), findsOneWidget);
      expect(find.text('Add Staff (कर्मचारी जोड़ें)'), findsOneWidget);

      // Switch to Tab 2 (Audit Trail)
      await tester.tap(find.text('Audit Trail'));
      await tester.pumpAndSettle();

      expect(find.text('Stock Changes'), findsOneWidget);
      expect(find.text('Price Changes'), findsOneWidget);
      expect(find.text('Stock adjusted for "Ashirvaad Atta 10kg" from 20.0 to 12.0 units (-8.0).'), findsOneWidget);
      expect(find.text('Reason: Physical stock audit discrepancy'), findsOneWidget);
      expect(find.text('Adjust Stock (स्टॉक बदलें)'), findsOneWidget);
    });

    testWidgets('AddEditStaffDialog allows creating a new staff account', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => AddEditStaffDialog.show(ctx, shopId: 'SHOP_TEST_STAFF', service: service),
                child: const Text('Open Add Staff'),
              ),
            ),
          ),
          shopId: 'SHOP_TEST_STAFF',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Add Staff'));
      await tester.pumpAndSettle();

      expect(find.text('Add Staff Account\n(नया कर्मचारी जोड़ें)'), findsOneWidget);

      // Fill in details
      await tester.enterText(find.widgetWithText(TextFormField, 'e.g. Ramesh Kumar'), 'Deepak Cashier');
      await tester.enterText(find.widgetWithText(TextFormField, '10-digit number'), '9812345678');
      await tester.enterText(find.widgetWithText(TextFormField, '4-digit PIN'), '9988');

      // Submit
      await tester.tap(find.text('Create Staff Account (खाता बनाएं)'));
      await tester.pumpAndSettle();

      // Verify staff in firestore
      final staffSnap = await fakeFirestore.collection('staff_members').where('phone', isEqualTo: '9812345678').get();
      expect(staffSnap.docs.isNotEmpty, isTrue);
      expect(staffSnap.docs.first.data()['name'], 'Deepak Cashier');
    });

    testWidgets('AuditLogDetailsDialog renders Before and After diff cards', (tester) async {
      final log = AuditLogEntry(
        id: 'LOG_DIFF_TEST',
        shopId: 'SHOP_TEST_STAFF',
        actorId: 'STAFF_MGR',
        actorName: 'Suresh Manager',
        actorRole: 'manager',
        actorPhone: '9876543210',
        actionType: AuditActionType.stockAdjustment,
        entityType: 'product',
        entityId: 'P_1',
        entityName: 'Tata Salt 1kg',
        description: 'Stock updated from 20.0 to 12.0 units',
        oldValue: {'stock': 20.0},
        newValue: {'stock': 12.0},
        timestamp: DateTime.now(),
        reason: 'Audit discrepancy',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => AuditLogDetailsDialog.show(ctx, log),
                child: const Text('Open Diff Dialog'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Diff Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Suresh Manager'), findsOneWidget);
      expect(find.text('OLD VALUE'), findsOneWidget);
      expect(find.text('NEW VALUE'), findsOneWidget);
      expect(find.text('stock: 20.0'), findsOneWidget);
      expect(find.text('stock: 12.0'), findsOneWidget);
      expect(find.text('Audit discrepancy'), findsOneWidget);
    });

    testWidgets('QuickStockAdjustmentDialog adjusts stock and logs audit', (tester) async {
      await fakeFirestore.collection('products').doc('P_TEST_ADJ').set({
        'shop_id': 'SHOP_TEST_STAFF',
        'name': 'Parle-G 800g',
        'stock_quantity': 20.0,
      });

      await tester.pumpWidget(
        createTestApp(
          Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => QuickStockAdjustmentDialog.show(
                  ctx,
                  shopId: 'SHOP_TEST_STAFF',
                  initialProductId: 'P_TEST_ADJ',
                  initialProductName: 'Parle-G 800g',
                  initialStock: 20.0,
                  service: service,
                ),
                child: const Text('Open Stock Adjustment'),
              ),
            ),
          ),
          shopId: 'SHOP_TEST_STAFF',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Stock Adjustment'));
      await tester.pumpAndSettle();

      expect(find.text('Parle-G 800g'), findsOneWidget);
      expect(find.text('20.0 units'), findsOneWidget);

      // Enter new target stock 12
      await tester.enterText(find.widgetWithText(TextFormField, 'e.g. 12'), '12.0');
      await tester.pumpAndSettle();

      // Submit adjustment
      await tester.tap(find.text('Save & Log Adjustment (सेव करें)'));
      await tester.pumpAndSettle();

      // Verify product stock is 12
      final prodDoc = await fakeFirestore.collection('products').doc('P_TEST_ADJ').get();
      expect(prodDoc.data()?['stock_quantity'], 12.0);

      // Verify audit log created
      final logsSnap = await fakeFirestore.collection('audit_logs').where('entity_name', isEqualTo: 'Parle-G 800g').get();
      expect(logsSnap.docs.isNotEmpty, isTrue);
      expect(logsSnap.docs.first.data()['new_value']['stock_quantity'], 12.0);
    });
  });
}
