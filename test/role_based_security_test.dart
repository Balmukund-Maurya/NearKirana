import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:near_kirana/role_permissions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String rulesContent;

  setUpAll(() {
    rulesContent = File('firestore.rules').readAsStringSync();
  });

  group('Role-Based Security: Rules & Parser Verifications', () {
    test('firestore.rules defines strict role-based access for all 3 primary roles', () {
      // 1. Core role helpers
      expect(rulesContent.contains('function isSuperAdmin()'), isTrue);
      expect(rulesContent.contains('function isShopOwner(shopId)'), isTrue);
      expect(rulesContent.contains('function isMatchingPhone(phone)'), isTrue);
      expect(rulesContent.contains('function isValidOrderTransition('), isTrue);

      // 2. Privilege Escalation Protection: Users cannot self-assign super_admin
      expect(rulesContent.contains("request.resource.data.role != 'super_admin'"), isTrue);

      // 3. Multi-tenant customer isolation: Shop A owner CANNOT see Shop B customers
      expect(rulesContent.contains("resource.data.shop_ids.hasAny([getUserShopId()])"), isTrue);
      expect(rulesContent.contains("isShopOwner(getUserShopId())"), isTrue);

      // 4. Shop approval protection: Shop owners cannot self-approve
      expect(rulesContent.contains("request.resource.data.is_active == resource.data.is_active"), isTrue);
      expect(rulesContent.contains("request.resource.data.status == resource.data.status"), isTrue);

      // 5. Payment status protection: Customers cannot self-mark as Paid
      expect(rulesContent.contains("request.resource.data.payment_status != 'Paid'"), isTrue);
    });
  });

  group('Role 1: Customer Permissions & Restrictions', () {
    const customer = UserSession(
      uid: 'USER_CUST_1',
      phone: '9876543210',
      role: AppRole.customer,
    );

    test('Customer CAN browse products and create own pending orders', () {
      expect(RolePermissions.canBrowseProducts(customer), isTrue);

      // Can place order for own phone
      expect(
        RolePermissions.canCreateOrder(
          user: customer,
          orderShopId: 'SHOP_A',
          customerPhone: '9876543210',
        ),
        isTrue,
      );

      // Can view own order
      expect(
        RolePermissions.canViewOrder(
          user: customer,
          orderShopId: 'SHOP_A',
          customerPhone: '9876543210',
        ),
        isTrue,
      );
    });

    test('Customer CANNOT place orders for another customer phone', () {
      expect(
        RolePermissions.canCreateOrder(
          user: customer,
          orderShopId: 'SHOP_A',
          customerPhone: '9123456780', // Other customer
        ),
        isFalse,
      );
    });

    test('Customer CANNOT view another customer order', () {
      expect(
        RolePermissions.canViewOrder(
          user: customer,
          orderShopId: 'SHOP_A',
          customerPhone: '9123456780', // Other customer
        ),
        isFalse,
      );
    });

    test('Customer CAN cancel own Pending order, but CANNOT mark as Delivered or Accepted', () {
      // Allowed: cancel pending
      expect(
        RolePermissions.canUpdateOrderStatus(
          user: customer,
          orderShopId: 'SHOP_A',
          currentStatus: 'Pending',
          newStatus: 'Cancelled',
        ),
        isTrue,
      );

      // Denied: mark as Accepted
      expect(
        RolePermissions.canUpdateOrderStatus(
          user: customer,
          orderShopId: 'SHOP_A',
          currentStatus: 'Pending',
          newStatus: 'Accepted',
        ),
        isFalse,
      );

      // Denied: mark as Delivered
      expect(
        RolePermissions.canUpdateOrderStatus(
          user: customer,
          orderShopId: 'SHOP_A',
          currentStatus: 'Out for Delivery',
          newStatus: 'Delivered',
        ),
        isFalse,
      );
    });

    test('Customer CANNOT mark order as Paid or Delivered', () {
      expect(
        RolePermissions.canMarkOrderPaid(
          user: customer,
          orderShopId: 'SHOP_A',
        ),
        isFalse,
      );

      expect(
        RolePermissions.canMarkOrderDelivered(
          user: customer,
          orderShopId: 'SHOP_A',
        ),
        isFalse,
      );
    });

    test('Customer CANNOT modify catalog prices or shop settings', () {
      expect(
        RolePermissions.canManageShop(
          user: customer,
          targetShopId: 'SHOP_A',
        ),
        isFalse,
      );

      expect(
        RolePermissions.canModifyInventory(
          user: customer,
          targetShopId: 'SHOP_A',
        ),
        isFalse,
      );
    });

    test('Customer CAN view own Khata statement, but CANNOT write Khata entries or view others', () {
      // Allowed: Read own Khata
      expect(
        RolePermissions.canAccessKhata(
          user: customer,
          khataShopId: 'SHOP_A',
          customerPhone: '9876543210',
          isWriteOperation: false,
        ),
        isTrue,
      );

      // Denied: Write to own Khata
      expect(
        RolePermissions.canAccessKhata(
          user: customer,
          khataShopId: 'SHOP_A',
          customerPhone: '9876543210',
          isWriteOperation: true,
        ),
        isFalse,
      );

      // Denied: Read someone else's Khata
      expect(
        RolePermissions.canAccessKhata(
          user: customer,
          khataShopId: 'SHOP_A',
          customerPhone: '9123456780',
          isWriteOperation: false,
        ),
        isFalse,
      );
    });
  });

  group('Role 2: Shop Owner Permissions & Cross-Shop Isolation', () {
    const shopOwnerA = UserSession(
      uid: 'OWNER_A_UID',
      phone: '9876500001',
      role: AppRole.shopOwner,
      shopId: 'SHOP_A',
    );

    const shopOwnerB = UserSession(
      uid: 'OWNER_B_UID',
      phone: '9876500002',
      role: AppRole.shopOwner,
      shopId: 'SHOP_B',
    );

    test('Shop Owner A CAN manage Shop A settings and catalog, but NOT Shop B', () {
      // Allowed: Manage Shop A
      expect(RolePermissions.canManageShop(user: shopOwnerA, targetShopId: 'SHOP_A'), isTrue);
      expect(RolePermissions.canModifyInventory(user: shopOwnerA, targetShopId: 'SHOP_A'), isTrue);

      // Denied: Manage Shop B
      expect(RolePermissions.canManageShop(user: shopOwnerA, targetShopId: 'SHOP_B'), isFalse);
      expect(RolePermissions.canModifyInventory(user: shopOwnerA, targetShopId: 'SHOP_B'), isFalse);
    });

    test('Shop Owner A CAN view and update Shop A orders, but NOT Shop B orders', () {
      // Allowed: View Shop A order
      expect(
        RolePermissions.canViewOrder(
          user: shopOwnerA,
          orderShopId: 'SHOP_A',
          customerPhone: '9991112223',
        ),
        isTrue,
      );

      // Denied: View Shop B order
      expect(
        RolePermissions.canViewOrder(
          user: shopOwnerA,
          orderShopId: 'SHOP_B',
          customerPhone: '9991112223',
        ),
        isFalse,
      );

      // Allowed: Transition Shop A order
      expect(
        RolePermissions.canUpdateOrderStatus(
          user: shopOwnerA,
          orderShopId: 'SHOP_A',
          currentStatus: 'Pending',
          newStatus: 'Accepted',
        ),
        isTrue,
      );

      // Denied: Transition Shop B order
      expect(
        RolePermissions.canUpdateOrderStatus(
          user: shopOwnerA,
          orderShopId: 'SHOP_B',
          currentStatus: 'Pending',
          newStatus: 'Accepted',
        ),
        isFalse,
      );
    });

    test('Terminal Invariance: Shop Owner CANNOT revert Delivered, Cancelled, or Rejected orders', () {
      // Delivered cannot be reverted to Pending
      expect(
        RolePermissions.canUpdateOrderStatus(
          user: shopOwnerA,
          orderShopId: 'SHOP_A',
          currentStatus: 'Delivered',
          newStatus: 'Pending',
        ),
        isFalse,
      );

      // Cancelled cannot be reverted
      expect(
        RolePermissions.canUpdateOrderStatus(
          user: shopOwnerA,
          orderShopId: 'SHOP_A',
          currentStatus: 'Cancelled',
          newStatus: 'Accepted',
        ),
        isFalse,
      );
    });

    test('Multi-tenant Customer Isolation: Shop A owner CANNOT see Shop B customers', () {
      // Customer registered ONLY at Shop B
      const customerAtShopB = '9123456789';
      final customerShopIds = ['SHOP_B'];

      // Shop A owner tries to access customer
      expect(
        RolePermissions.canAccessCustomerData(
          user: shopOwnerA,
          customerPhone: customerAtShopB,
          customerShopIds: customerShopIds,
        ),
        isFalse, // Access strictly denied!
      );

      // Shop B owner CAN access customer
      expect(
        RolePermissions.canAccessCustomerData(
          user: shopOwnerB,
          customerPhone: customerAtShopB,
          customerShopIds: customerShopIds,
        ),
        isTrue,
      );
    });

    test('Multi-tenant Khata Isolation: Shop A owner CANNOT access or modify Shop B Khata', () {
      // Allowed: Manage Khata for Shop A
      expect(
        RolePermissions.canAccessKhata(
          user: shopOwnerA,
          khataShopId: 'SHOP_A',
          customerPhone: '9888877777',
          isWriteOperation: true,
        ),
        isTrue,
      );

      // Denied: Access or write Khata for Shop B
      expect(
        RolePermissions.canAccessKhata(
          user: shopOwnerA,
          khataShopId: 'SHOP_B',
          customerPhone: '9888877777',
          isWriteOperation: true,
        ),
        isFalse,
      );
    });

    test('Shop Owner CANNOT self-approve shop or perform platform operations', () {
      expect(RolePermissions.canApproveShop(shopOwnerA), isFalse);
      expect(RolePermissions.canPerformPlatformOperations(shopOwnerA), isFalse);
    });
  });

  group('Role 3: Super Admin Permissions', () {
    const superAdmin = UserSession(
      uid: 'SUPER_ADMIN_UID',
      phone: '9999999999',
      role: AppRole.superAdmin,
    );

    test('Super Admin CAN manage platform operations and approve shops', () {
      expect(RolePermissions.canApproveShop(superAdmin), isTrue);
      expect(RolePermissions.canPerformPlatformOperations(superAdmin), isTrue);
    });

    test('Super Admin CAN view and manage any shop and any order across the platform', () {
      expect(RolePermissions.canManageShop(user: superAdmin, targetShopId: 'SHOP_A'), isTrue);
      expect(RolePermissions.canManageShop(user: superAdmin, targetShopId: 'SHOP_B'), isTrue);

      expect(
        RolePermissions.canViewOrder(
          user: superAdmin,
          orderShopId: 'SHOP_A',
          customerPhone: '9876543210',
        ),
        isTrue,
      );

      expect(
        RolePermissions.canViewOrder(
          user: superAdmin,
          orderShopId: 'SHOP_B',
          customerPhone: '9123456789',
        ),
        isTrue,
      );
    });

    test('Super Admin has administrative recovery privilege to correct terminal mistakes', () {
      expect(
        RolePermissions.canUpdateOrderStatus(
          user: superAdmin,
          orderShopId: 'SHOP_A',
          currentStatus: 'Delivered',
          newStatus: 'Pending',
        ),
        isTrue,
      );
    });
  });

  group('Database Simulation: Multi-Tenant Query Isolation in FakeFirestore', () {
    test('Simulated queries enforce multi-shop isolation', () async {
      final fakeDb = FakeFirebaseFirestore();

      // Seed 2 Shops
      await fakeDb.collection('shops').doc('SHOP_ALPHA').set({
        'shop_name': 'Alpha Kirana',
        'mobile': '9000000001',
        'is_active': true,
        'status': 'approved',
      });

      await fakeDb.collection('shops').doc('SHOP_BETA').set({
        'shop_name': 'Beta Kirana',
        'mobile': '9000000002',
        'is_active': true,
        'status': 'approved',
      });

      // Seed Customers:
      // Customer A is customer of Shop Alpha only
      await fakeDb.collection('customers').doc('CUST_A').set({
        'name': 'Customer Alpha',
        'mobile': '9111111111',
        'shop_ids': ['SHOP_ALPHA'],
      });

      // Customer B is customer of Shop Beta only
      await fakeDb.collection('customers').doc('CUST_B').set({
        'name': 'Customer Beta',
        'mobile': '9222222222',
        'shop_ids': ['SHOP_BETA'],
      });

      // Shop Alpha Owner queries their customers
      final alphaCustomers = await fakeDb
          .collection('customers')
          .where('shop_ids', arrayContains: 'SHOP_ALPHA')
          .get();

      expect(alphaCustomers.docs.length, equals(1));
      expect(alphaCustomers.docs.first.id, equals('CUST_A'));
      // Verifies Shop Alpha owner DOES NOT receive Customer B
      expect(alphaCustomers.docs.any((doc) => doc.id == 'CUST_B'), isFalse);

      // Shop Beta Owner queries their customers
      final betaCustomers = await fakeDb
          .collection('customers')
          .where('shop_ids', arrayContains: 'SHOP_BETA')
          .get();

      expect(betaCustomers.docs.length, equals(1));
      expect(betaCustomers.docs.first.id, equals('CUST_B'));
      // Verifies Shop Beta owner DOES NOT receive Customer A
      expect(betaCustomers.docs.any((doc) => doc.id == 'CUST_A'), isFalse);
    });
  });
}
