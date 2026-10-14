/// Role-Based Access Control (RBAC) security and permission engine.
/// Mirrors and enforces Firestore Security Rules at the business logic layer,
/// ensuring strict multi-tenant isolation between Customers, Shop Owners, and Super Admins.
library;

import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'staff_audit_models.dart';

enum AppRole {
  customer,
  shopOwner,
  superAdmin;

  static AppRole fromString(String? role) {
    switch (role?.toLowerCase()) {
      case 'super_admin':
      case 'superadmin':
        return AppRole.superAdmin;
      case 'shop_owner':
      case 'admin':
      case 'shopowner':
        return AppRole.shopOwner;
      case 'customer':
      default:
        return AppRole.customer;
    }
  }

  String toRoleString() {
    switch (this) {
      case AppRole.superAdmin:
        return 'super_admin';
      case AppRole.shopOwner:
        return 'shop_owner';
      case AppRole.customer:
        return 'customer';
    }
  }
}

class UserSession {
  final String uid;
  final String phone;
  final AppRole role;
  final String? shopId;

  const UserSession({
    required this.uid,
    required this.phone,
    required this.role,
    this.shopId,
  });

  bool get isSuperAdmin => role == AppRole.superAdmin;
  bool get isShopOwner => role == AppRole.shopOwner;
  bool get isCustomer => role == AppRole.customer;

  String get normalizedPhone {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  /// Factory to fetch current active UserSession from local preferences and auth
  static Future<UserSession> current() async {
    final prefs = await SharedPreferences.getInstance();
    final roleStr = prefs.getString('app_role');
    final phone = prefs.getString('global_phone') ??
        prefs.getString('customerPhone') ??
        '';
    final shopId = prefs.getString('current_shop_id') ??
        prefs.getString('last_selected_shop_id');
    final uid = AuthService().currentUid ?? 'anonymous';

    return UserSession(
      uid: uid,
      phone: phone,
      role: AppRole.fromString(roleStr),
      shopId: shopId,
    );
  }
}

class RolePermissions {
  /// Normalize any phone string to the last 10 digits
  static String normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  /// Whether user can browse catalog products
  static bool canBrowseProducts(UserSession user) {
    // Products are accessible to browse for all users (customers, owners, super admins)
    return true;
  }

  /// Whether user can manage shop profile, settings, and catalog
  static bool canManageShop({
    required UserSession user,
    required String targetShopId,
  }) {
    if (user.isSuperAdmin) return true;
    if (user.isShopOwner && user.shopId != null && user.shopId == targetShopId) {
      return true;
    }
    return false;
  }

  /// Whether user can view customer data / profiles.
  /// Enforces multi-shop data isolation: Shop A owner CANNOT see Shop B's customers!
  static bool canAccessCustomerData({
    required UserSession user,
    required String customerPhone,
    required List<String> customerShopIds,
  }) {
    if (user.isSuperAdmin) return true;

    // Customer can view their own profile data
    if (user.isCustomer) {
      return normalizePhone(user.phone) == normalizePhone(customerPhone);
    }

    // Shop Owner can ONLY view customers that belong to THEIR shop
    if (user.isShopOwner && user.shopId != null) {
      return customerShopIds.contains(user.shopId);
    }

    return false;
  }

  /// Whether user can view a specific customer order
  static bool canViewOrder({
    required UserSession user,
    required String orderShopId,
    required String customerPhone,
  }) {
    if (user.isSuperAdmin) return true;
    // Shop owner can view orders belonging to their shop
    if (user.isShopOwner && user.shopId == orderShopId) return true;
    // Customer can only view orders associated with their phone number
    if (user.isCustomer &&
        normalizePhone(user.phone) == normalizePhone(customerPhone)) {
      return true;
    }
    return false;
  }

  /// Whether user can update an order status based on RBAC and state machine invariants
  static bool canUpdateOrderStatus({
    required UserSession user,
    required String orderShopId,
    required String currentStatus,
    required String newStatus,
  }) {
    // Super Admin has master recovery privilege to correct terminal mistakes
    if (user.isSuperAdmin) return true;

    // Terminal statuses (Delivered, Cancelled, Rejected) cannot be modified by non-super-admins!
    const terminalStatuses = {'Delivered', 'Cancelled', 'Rejected'};
    if (terminalStatuses.contains(currentStatus)) {
      return false;
    }

    // Customer can only cancel their own order if still in Pending state
    if (user.isCustomer) {
      return currentStatus == 'Pending' && newStatus == 'Cancelled';
    }

    // Shop owner can only transition orders for their own shop
    if (user.isShopOwner) {
      if (user.shopId != orderShopId) return false;

      // Validate allowed transitions
      switch (currentStatus) {
        case 'Pending':
          return {
            'Accepted',
            'Packing',
            'Packed',
            'Ready',
            'Rejected',
            'Cancelled',
          }.contains(newStatus);
        case 'Accepted':
          return {'Packing', 'Packed', 'Ready', 'Cancelled'}.contains(newStatus);
        case 'Packing':
        case 'Packed':
          return {
            'Ready',
            'Out for Delivery',
            'Delivered',
            'Cancelled',
          }.contains(newStatus);
        case 'Ready':
          return {'Out for Delivery', 'Delivered', 'Cancelled'}.contains(newStatus);
        case 'Out for Delivery':
          return {'Delivered', 'Delivery_Failed', 'Cancelled'}.contains(newStatus);
        case 'Delivery_Failed':
          return {'Out for Delivery', 'Cancelled'}.contains(newStatus);
        default:
          return false;
      }
    }

    return false;
  }

  /// Whether user can place/create a new order
  static bool canCreateOrder({
    required UserSession user,
    required String orderShopId,
    required String customerPhone,
  }) {
    if (user.isSuperAdmin) return true;
    if (user.isCustomer) {
      return normalizePhone(user.phone) == normalizePhone(customerPhone);
    }
    // Shop owner can create in-store manual orders for their shop
    if (user.isShopOwner) {
      return user.shopId == orderShopId;
    }
    return false;
  }

  /// Whether user can mark order as Paid (Customer can NEVER self-mark as Paid)
  static bool canMarkOrderPaid({
    required UserSession user,
    required String orderShopId,
  }) {
    if (user.isSuperAdmin) return true;
    if (user.isShopOwner && user.shopId == orderShopId) return true;
    return false; // Customer denied!
  }

  /// Whether user can mark order as Delivered (Customer can NEVER self-mark as Delivered)
  static bool canMarkOrderDelivered({
    required UserSession user,
    required String orderShopId,
  }) {
    if (user.isSuperAdmin) return true;
    if (user.isShopOwner && user.shopId == orderShopId) return true;
    return false; // Customer denied!
  }

  /// Whether user can modify shop inventory/stock (products, prices, categories)
  static bool canModifyInventory({
    required UserSession user,
    required String targetShopId,
  }) {
    if (user.isSuperAdmin) return true;
    return user.isShopOwner && user.shopId == targetShopId;
  }

  /// Whether user can view and manage Khata / Udhaar records
  static bool canAccessKhata({
    required UserSession user,
    required String khataShopId,
    required String customerPhone,
    bool isWriteOperation = false,
  }) {
    if (user.isSuperAdmin) return true;

    // Shop owner can manage Khata in their own shop
    if (user.isShopOwner && user.shopId == khataShopId) {
      return true;
    }

    // Customer can only read their own statement, never write or view other customers
    if (user.isCustomer) {
      if (isWriteOperation) return false;
      return normalizePhone(user.phone) == normalizePhone(customerPhone);
    }

    return false;
  }

  /// Whether user can approve, reject, or suspend shops
  static bool canApproveShop(UserSession user) {
    return user.isSuperAdmin;
  }

  /// Whether user can perform platform-level operations
  static bool canPerformPlatformOperations(UserSession user) {
    return user.isSuperAdmin;
  }

  /// Whether an active staff member can execute a protected action in their shop
  static bool canStaffPerform({
    required StaffMember? staff,
    required String targetShopId,
    required StaffPermission requiredPermission,
  }) {
    if (staff == null) return false;
    if (!staff.isActive) return false;
    if (staff.shopId != targetShopId) return false;
    return staff.hasPermission(requiredPermission);
  }
}
