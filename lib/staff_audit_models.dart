import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Predefined roles for shop staff members.
enum StaffRole {
  manager,
  cashier,
  stockClerk,
  custom;

  String get label {
    switch (this) {
      case StaffRole.manager:
        return 'Manager (मैनेजर)';
      case StaffRole.cashier:
        return 'Cashier (कैशियर)';
      case StaffRole.stockClerk:
        return 'Stock Clerk (स्टॉक क्लर्क)';
      case StaffRole.custom:
        return 'Custom (कस्टम)';
    }
  }

  String get key => name;

  static StaffRole fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'manager':
        return StaffRole.manager;
      case 'cashier':
        return StaffRole.cashier;
      case 'stockclerk':
      case 'stock_clerk':
        return StaffRole.stockClerk;
      case 'custom':
      default:
        return StaffRole.custom;
    }
  }
}

/// Granular permissions that can be granted to staff members.
enum StaffPermission {
  billing,
  orderManagement,
  inventoryAdjustment,
  catalogEdit,
  customerKhata,
  viewReports,
  manageStaff,
  discounts;

  String get label {
    switch (this) {
      case StaffPermission.billing:
        return 'Billing & POS (बिलिंग और बिक्री)';
      case StaffPermission.orderManagement:
        return 'Order Management (ऑर्डर डिलीवरी/स्टेटस)';
      case StaffPermission.inventoryAdjustment:
        return 'Stock Adjustment (स्टॉक घटाना/बढ़ाना)';
      case StaffPermission.catalogEdit:
        return 'Catalog & Prices (प्रोडक्ट और कीमतें)';
      case StaffPermission.customerKhata:
        return 'Customer Khata (उधार और पेमेंट)';
      case StaffPermission.viewReports:
        return 'Sales & Reports (बिक्री रिपोर्ट)';
      case StaffPermission.manageStaff:
        return 'Staff Management (कर्मचारी जोड़ना)';
      case StaffPermission.discounts:
        return 'Special Discounts (विशेष छूट)';
    }
  }

  String get key => name;

  static StaffPermission fromString(String val) {
    for (final perm in StaffPermission.values) {
      if (perm.name == val) return perm;
    }
    return StaffPermission.billing;
  }
}

/// Category of audited store action.
enum AuditActionType {
  stockAdjustment,
  stockWriteOff,
  priceChange,
  orderStatusChanged,
  paymentCollected,
  khataEntryAdded,
  productCreated,
  productDeleted,
  staffCreated,
  staffUpdated,
  staffStatusToggled,
  discountApplied,
  batchCreated,
  dataExported,
  backupCreated,
  restoreTestRun;

  String get label {
    switch (this) {
      case AuditActionType.stockAdjustment:
        return 'Stock Adjustment (स्टॉक बदलाव)';
      case AuditActionType.stockWriteOff:
        return 'Stock Write-off (नुकसान दर्ज)';
      case AuditActionType.priceChange:
        return 'Price Change (कीमत बदलाव)';
      case AuditActionType.orderStatusChanged:
        return 'Order Status (ऑर्डर स्टेटस)';
      case AuditActionType.paymentCollected:
        return 'Payment Collected (पेमेंट प्राप्त)';
      case AuditActionType.khataEntryAdded:
        return 'Khata Entry (खाता एंट्री)';
      case AuditActionType.productCreated:
        return 'Product Created (नया प्रोडक्ट)';
      case AuditActionType.productDeleted:
        return 'Product Deleted (प्रोडक्ट हटाया)';
      case AuditActionType.staffCreated:
        return 'Staff Created (कर्मचारी जोड़ा)';
      case AuditActionType.staffUpdated:
        return 'Staff Updated (कर्मचारी अपडेट)';
      case AuditActionType.staffStatusToggled:
        return 'Staff Status (एक्टिव/इनएक्टिव)';
      case AuditActionType.discountApplied:
        return 'Discount Applied (छूट दी)';
      case AuditActionType.batchCreated:
        return 'Batch Created (नया बैच)';
      case AuditActionType.dataExported:
        return 'Data Export (डेटा निर्यात)';
      case AuditActionType.backupCreated:
        return 'Cloud Backup (बैकअप लिया)';
      case AuditActionType.restoreTestRun:
        return 'Restore Test (रिकवरी टेस्ट)';
    }
  }

  Color get color {
    switch (this) {
      case AuditActionType.stockAdjustment:
        return Colors.indigo;
      case AuditActionType.stockWriteOff:
        return Colors.deepOrange;
      case AuditActionType.priceChange:
        return Colors.purple;
      case AuditActionType.orderStatusChanged:
        return Colors.blue;
      case AuditActionType.paymentCollected:
        return Colors.green;
      case AuditActionType.khataEntryAdded:
        return Colors.teal;
      case AuditActionType.productCreated:
        return Colors.green.shade700;
      case AuditActionType.productDeleted:
        return Colors.red.shade700;
      case AuditActionType.staffCreated:
      case AuditActionType.staffUpdated:
      case AuditActionType.staffStatusToggled:
        return Colors.amber.shade900;
      case AuditActionType.discountApplied:
        return Colors.pink;
      case AuditActionType.batchCreated:
        return Colors.cyan.shade800;
      case AuditActionType.dataExported:
        return Colors.blueGrey;
      case AuditActionType.backupCreated:
        return Colors.teal.shade700;
      case AuditActionType.restoreTestRun:
        return Colors.deepPurple;
    }
  }

  IconData get icon {
    switch (this) {
      case AuditActionType.stockAdjustment:
        return Icons.edit_note_rounded;
      case AuditActionType.stockWriteOff:
        return Icons.delete_sweep_rounded;
      case AuditActionType.priceChange:
        return Icons.currency_rupee_rounded;
      case AuditActionType.orderStatusChanged:
        return Icons.local_shipping_rounded;
      case AuditActionType.paymentCollected:
        return Icons.check_circle_rounded;
      case AuditActionType.khataEntryAdded:
        return Icons.menu_book_rounded;
      case AuditActionType.productCreated:
        return Icons.add_circle_outline_rounded;
      case AuditActionType.productDeleted:
        return Icons.remove_circle_outline_rounded;
      case AuditActionType.staffCreated:
      case AuditActionType.staffUpdated:
      case AuditActionType.staffStatusToggled:
        return Icons.badge_rounded;
      case AuditActionType.discountApplied:
        return Icons.percent_rounded;
      case AuditActionType.batchCreated:
        return Icons.layers_rounded;
      case AuditActionType.dataExported:
        return Icons.file_download_rounded;
      case AuditActionType.backupCreated:
        return Icons.cloud_upload_rounded;
      case AuditActionType.restoreTestRun:
        return Icons.health_and_safety_rounded;
    }
  }

  static AuditActionType fromString(String? val) {
    for (final action in AuditActionType.values) {
      if (action.name == val) return action;
    }
    return AuditActionType.stockAdjustment;
  }
}

/// Represents an employee / staff member in a store.
class StaffMember {
  final String id;
  final String shopId;
  final String name;
  final String phone;
  final StaffRole role;
  final Set<StaffPermission> permissions;
  final String pin; // 4-digit POS/Action PIN
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastActiveAt;
  final String? createdBy;

  const StaffMember({
    required this.id,
    required this.shopId,
    required this.name,
    required this.phone,
    required this.role,
    required this.permissions,
    this.pin = '0000',
    this.isActive = true,
    required this.createdAt,
    this.lastActiveAt,
    this.createdBy,
  });

  /// Check whether this staff member has an active granted permission
  bool hasPermission(StaffPermission permission) {
    if (!isActive) return false;
    return permissions.contains(permission);
  }

  /// Normalized 10-digit phone number
  String get normalizedPhone {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  /// Default permissions preset for predefined roles
  static Set<StaffPermission> defaultPermissionsForRole(StaffRole role) {
    switch (role) {
      case StaffRole.manager:
        return {
          StaffPermission.billing,
          StaffPermission.orderManagement,
          StaffPermission.inventoryAdjustment,
          StaffPermission.catalogEdit,
          StaffPermission.customerKhata,
          StaffPermission.viewReports,
          StaffPermission.discounts,
        };
      case StaffRole.cashier:
        return {
          StaffPermission.billing,
          StaffPermission.orderManagement,
          StaffPermission.customerKhata,
        };
      case StaffRole.stockClerk:
        return {
          StaffPermission.inventoryAdjustment,
          StaffPermission.catalogEdit,
        };
      case StaffRole.custom:
        return {
          StaffPermission.billing,
        };
    }
  }

  StaffMember copyWith({
    String? id,
    String? shopId,
    String? name,
    String? phone,
    StaffRole? role,
    Set<StaffPermission>? permissions,
    String? pin,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    String? createdBy,
  }) {
    return StaffMember(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      permissions: permissions ?? this.permissions,
      pin: pin ?? this.pin,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shop_id': shopId,
      'name': name,
      'phone': phone,
      'role': role.key,
      'permissions': permissions.map((p) => p.key).toList(),
      'pin': pin,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'last_active_at': lastActiveAt?.toIso8601String(),
      'created_by': createdBy,
    };
  }

  factory StaffMember.fromMap(Map<String, dynamic> map, String docId) {
    final permsList = (map['permissions'] as List?)?.cast<String>() ?? [];
    return StaffMember(
      id: docId,
      shopId: map['shop_id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Staff',
      phone: map['phone']?.toString() ?? '',
      role: StaffRole.fromString(map['role']?.toString()),
      permissions: permsList.map(StaffPermission.fromString).toSet(),
      pin: map['pin']?.toString() ?? '0000',
      isActive: map['is_active'] as bool? ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastActiveAt: map['last_active_at'] != null
          ? DateTime.tryParse(map['last_active_at'].toString())
          : null,
      createdBy: map['created_by']?.toString(),
    );
  }
}

/// Represents an immutable audit log entry documenting an authorized action.
class AuditLogEntry {
  final String id;
  final String shopId;
  final String actorId; // Staff docId or UID
  final String actorName; // e.g. "Ramesh (Cashier)" or "Owner"
  final String actorRole; // "owner", "manager", "cashier", "stockClerk"
  final String? actorPhone;
  final AuditActionType actionType;
  final String entityType; // "product", "order", "staff", "inventory", "khata"
  final String entityId; // e.g. "P_ATTA_10KG", "ORD_1002"
  final String entityName; // e.g. "Ashirvaad Atta 10kg"
  final String description; // Human-readable change summary
  final Map<String, dynamic>? oldValue; // e.g. {"stock": 20}
  final Map<String, dynamic>? newValue; // e.g. {"stock": 12}
  final DateTime timestamp;
  final String? reason; // e.g. "Physical audit recount discrepancy"
  final Map<String, dynamic>? metadata;

  const AuditLogEntry({
    required this.id,
    required this.shopId,
    required this.actorId,
    required this.actorName,
    required this.actorRole,
    this.actorPhone,
    required this.actionType,
    required this.entityType,
    required this.entityId,
    required this.entityName,
    required this.description,
    this.oldValue,
    this.newValue,
    required this.timestamp,
    this.reason,
    this.metadata,
  });

  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24 && now.day == timestamp.day) {
      return 'Today, ${DateFormat('hh:mm a').format(timestamp)}';
    } else if (diff.inDays == 1 || (diff.inHours < 48 && now.day - timestamp.day == 1)) {
      return 'Yesterday, ${DateFormat('hh:mm a').format(timestamp)}';
    } else {
      return DateFormat('dd MMM yyyy, hh:mm a').format(timestamp);
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'shop_id': shopId,
      'actor_id': actorId,
      'actor_name': actorName,
      'actor_role': actorRole,
      'actor_phone': actorPhone,
      'action_type': actionType.name,
      'entity_type': entityType,
      'entity_id': entityId,
      'entity_name': entityName,
      'description': description,
      'old_value': oldValue,
      'new_value': newValue,
      'timestamp': timestamp.toIso8601String(),
      'reason': reason,
      'metadata': metadata,
    };
  }

  factory AuditLogEntry.fromMap(Map<String, dynamic> map, String docId) {
    return AuditLogEntry(
      id: docId,
      shopId: map['shop_id']?.toString() ?? '',
      actorId: map['actor_id']?.toString() ?? 'unknown',
      actorName: map['actor_name']?.toString() ?? 'System',
      actorRole: map['actor_role']?.toString() ?? 'staff',
      actorPhone: map['actor_phone']?.toString(),
      actionType: AuditActionType.fromString(map['action_type']?.toString()),
      entityType: map['entity_type']?.toString() ?? 'store',
      entityId: map['entity_id']?.toString() ?? '',
      entityName: map['entity_name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      oldValue: (map['old_value'] as Map?)?.cast<String, dynamic>(),
      newValue: (map['new_value'] as Map?)?.cast<String, dynamic>(),
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      reason: map['reason']?.toString(),
      metadata: (map['metadata'] as Map?)?.cast<String, dynamic>(),
    );
  }
}

/// Aggregated analytics summary for the store owner.
class StaffAuditAnalytics {
  final int totalStaff;
  final int activeStaff;
  final int todayLogCount;
  final int criticalChangesCount; // Stock adjustments + price changes + write-offs
  final String topActorName;
  final Map<AuditActionType, int> actionDistribution;

  const StaffAuditAnalytics({
    required this.totalStaff,
    required this.activeStaff,
    required this.todayLogCount,
    required this.criticalChangesCount,
    required this.topActorName,
    required this.actionDistribution,
  });

  factory StaffAuditAnalytics.empty() {
    return const StaffAuditAnalytics(
      totalStaff: 0,
      activeStaff: 0,
      todayLogCount: 0,
      criticalChangesCount: 0,
      topActorName: 'None',
      actionDistribution: {},
    );
  }
}
