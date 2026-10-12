import 'package:flutter_test/flutter_test.dart';
import 'package:near_kirana/role_permissions.dart';

void main() {
  group('Role-Based Access Control (RBAC) & Multi-Tenant Isolation', () {
    // Test users
    const customerRamesh = UserSession(
      uid: 'user_ramesh_123',
      phone: '9988776655',
      role: AppRole.customer,
    );

    const customerSuresh = UserSession(
      uid: 'user_suresh_456',
      phone: '+91 9871234567',
      role: AppRole.customer,
    );

    const shopOwnerA = UserSession(
      uid: 'owner_a_789',
      phone: '9876543210',
      role: AppRole.shopOwner,
      shopId: 'SHOP_A',
    );

    const shopOwnerB = UserSession(
      uid: 'owner_b_321',
      phone: '9123456780',
      role: AppRole.shopOwner,
      shopId: 'SHOP_B',
    );

    const superAdmin = UserSession(
      uid: 'super_admin_999',
      phone: '9999999999',
      role: AppRole.superAdmin,
    );

    group('Shop Management Permissions', () {
      test('Shop Owner can manage their own shop only', () {
        expect(
          RolePermissions.canManageShop(user: shopOwnerA, targetShopId: 'SHOP_A'),
          isTrue,
        );
        expect(
          RolePermissions.canManageShop(user: shopOwnerA, targetShopId: 'SHOP_B'),
          isFalse,
        );
        expect(
          RolePermissions.canManageShop(user: shopOwnerB, targetShopId: 'SHOP_B'),
          isTrue,
        );
        expect(
          RolePermissions.canManageShop(user: shopOwnerB, targetShopId: 'SHOP_A'),
          isFalse,
        );
      });

      test('Customer cannot manage any shop', () {
        expect(
          RolePermissions.canManageShop(user: customerRamesh, targetShopId: 'SHOP_A'),
          isFalse,
        );
      });

      test('Super Admin can manage all shops', () {
        expect(
          RolePermissions.canManageShop(user: superAdmin, targetShopId: 'SHOP_A'),
          isTrue,
        );
        expect(
          RolePermissions.canManageShop(user: superAdmin, targetShopId: 'SHOP_B'),
          isTrue,
        );
      });
    });

    group('Order Visibility & Customer Isolation', () {
      test('Customer can view their own orders', () {
        expect(
          RolePermissions.canViewOrder(
            user: customerRamesh,
            orderShopId: 'SHOP_A',
            customerPhone: '9988776655',
          ),
          isTrue,
        );

        // Works with +91 country prefix formatting
        expect(
          RolePermissions.canViewOrder(
            user: customerRamesh,
            orderShopId: 'SHOP_A',
            customerPhone: '+919988776655',
          ),
          isTrue,
        );

        // Customer Suresh can view Suresh's order
        expect(
          RolePermissions.canViewOrder(
            user: customerSuresh,
            orderShopId: 'SHOP_B',
            customerPhone: '9871234567',
          ),
          isTrue,
        );
      });

      test('Customer cannot view another customer orders (Privacy Leak Prevention)', () {
        expect(
          RolePermissions.canViewOrder(
            user: customerRamesh,
            orderShopId: 'SHOP_A',
            customerPhone: '9871234567', // Suresh's phone
          ),
          isFalse,
        );

        expect(
          RolePermissions.canViewOrder(
            user: customerSuresh,
            orderShopId: 'SHOP_A',
            customerPhone: '9988776655', // Ramesh's phone
          ),
          isFalse,
        );
      });

      test('Shop Owner A can only view orders of Shop A, never Shop B', () {
        expect(
          RolePermissions.canViewOrder(
            user: shopOwnerA,
            orderShopId: 'SHOP_A',
            customerPhone: '9988776655',
          ),
          isTrue,
        );

        expect(
          RolePermissions.canViewOrder(
            user: shopOwnerA,
            orderShopId: 'SHOP_B',
            customerPhone: '9988776655',
          ),
          isFalse,
        );
      });

      test('Super Admin can view orders across all shops and customers', () {
        expect(
          RolePermissions.canViewOrder(
            user: superAdmin,
            orderShopId: 'SHOP_A',
            customerPhone: '9988776655',
          ),
          isTrue,
        );
        expect(
          RolePermissions.canViewOrder(
            user: superAdmin,
            orderShopId: 'SHOP_B',
            customerPhone: '9871234567',
          ),
          isTrue,
        );
      });
    });

    group('Order Status Transitions & State Machine Enforcement', () {
      test('Customer can cancel Pending order, but cannot change to any other status', () {
        expect(
          RolePermissions.canUpdateOrderStatus(
            user: customerRamesh,
            orderShopId: 'SHOP_A',
            currentStatus: 'Pending',
            newStatus: 'Cancelled',
          ),
          isTrue,
        );

        // Customer cannot accept order
        expect(
          RolePermissions.canUpdateOrderStatus(
            user: customerRamesh,
            orderShopId: 'SHOP_A',
            currentStatus: 'Pending',
            newStatus: 'Accepted',
          ),
          isFalse,
        );

        // Customer cannot cancel after shop accepts order
        expect(
          RolePermissions.canUpdateOrderStatus(
            user: customerRamesh,
            orderShopId: 'SHOP_A',
            currentStatus: 'Accepted',
            newStatus: 'Cancelled',
          ),
          isFalse,
        );
      });

      test('Shop Owner A can perform valid state transitions for Shop A orders', () {
        // Pending -> Accepted
        expect(
          RolePermissions.canUpdateOrderStatus(
            user: shopOwnerA,
            orderShopId: 'SHOP_A',
            currentStatus: 'Pending',
            newStatus: 'Accepted',
          ),
          isTrue,
        );

        // Accepted -> Packing
        expect(
          RolePermissions.canUpdateOrderStatus(
            user: shopOwnerA,
            orderShopId: 'SHOP_A',
            currentStatus: 'Accepted',
            newStatus: 'Packing',
          ),
          isTrue,
        );

        // Packing -> Ready
        expect(
          RolePermissions.canUpdateOrderStatus(
            user: shopOwnerA,
            orderShopId: 'SHOP_A',
            currentStatus: 'Packing',
            newStatus: 'Ready',
          ),
          isTrue,
        );

        // Ready -> Out for Delivery
        expect(
          RolePermissions.canUpdateOrderStatus(
            user: shopOwnerA,
            orderShopId: 'SHOP_A',
            currentStatus: 'Ready',
            newStatus: 'Out for Delivery',
          ),
          isTrue,
        );

        // Out for Delivery -> Delivered
        expect(
          RolePermissions.canUpdateOrderStatus(
            user: shopOwnerA,
            orderShopId: 'SHOP_A',
            currentStatus: 'Out for Delivery',
            newStatus: 'Delivered',
          ),
          isTrue,
        );
      });

      test('Shop Owner A cannot update orders belonging to Shop B', () {
        expect(
          RolePermissions.canUpdateOrderStatus(
            user: shopOwnerA,
            orderShopId: 'SHOP_B', // Different shop!
            currentStatus: 'Pending',
            newStatus: 'Accepted',
          ),
          isFalse,
        );
      });

      test('Terminal Protection: Delivered or Cancelled order cannot be modified by Shop Owner', () {
        // Cannot revert Delivered order to Pending or Packing
        expect(
          RolePermissions.canUpdateOrderStatus(
            user: shopOwnerA,
            orderShopId: 'SHOP_A',
            currentStatus: 'Delivered',
            newStatus: 'Pending',
          ),
          isFalse,
        );

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

      test('Super Admin has master override privilege for terminal orders', () {
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

    group('Inventory & Khata Udhaar Data Isolation', () {
      test('Inventory: Shop Owner can modify only their own stock', () {
        expect(
          RolePermissions.canModifyInventory(user: shopOwnerA, targetShopId: 'SHOP_A'),
          isTrue,
        );
        expect(
          RolePermissions.canModifyInventory(user: shopOwnerA, targetShopId: 'SHOP_B'),
          isFalse,
        );
        expect(
          RolePermissions.canModifyInventory(user: customerRamesh, targetShopId: 'SHOP_A'),
          isFalse,
        );
      });

      test('Khata: Customer can view their own statement, but cannot add transactions', () {
        // Customer reading own statement
        expect(
          RolePermissions.canAccessKhata(
            user: customerRamesh,
            khataShopId: 'SHOP_A',
            customerPhone: '9988776655',
            isWriteOperation: false,
          ),
          isTrue,
        );

        // Customer writing/creating transaction is blocked
        expect(
          RolePermissions.canAccessKhata(
            user: customerRamesh,
            khataShopId: 'SHOP_A',
            customerPhone: '9988776655',
            isWriteOperation: true,
          ),
          isFalse,
        );

        // Customer reading other customer's statement is blocked
        expect(
          RolePermissions.canAccessKhata(
            user: customerRamesh,
            khataShopId: 'SHOP_A',
            customerPhone: '9871234567',
            isWriteOperation: false,
          ),
          isFalse,
        );
      });

      test('Khata: Shop Owner A can read and write transactions for Shop A, but not Shop B', () {
        expect(
          RolePermissions.canAccessKhata(
            user: shopOwnerA,
            khataShopId: 'SHOP_A',
            customerPhone: '9988776655',
            isWriteOperation: true,
          ),
          isTrue,
        );

        expect(
          RolePermissions.canAccessKhata(
            user: shopOwnerA,
            khataShopId: 'SHOP_B',
            customerPhone: '9988776655',
            isWriteOperation: true,
          ),
          isFalse,
        );
      });
    });
  });
}
