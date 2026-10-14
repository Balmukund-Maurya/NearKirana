import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'staff_audit_models.dart';

/// Business service managing Staff Accounts and the Immutable Audit Trail.
class StaffAuditService {
  final FirebaseFirestore _firestore;

  StaffAuditService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseUtils.firestore;

  CollectionReference get _staffCollection => _firestore.collection('staff_members');
  CollectionReference get _auditLogsCollection => _firestore.collection('audit_logs');
  CollectionReference get _productsCollection => _firestore.collection('products');

  // ===========================================================================
  // STAFF ACCOUNTS MANAGEMENT
  // ===========================================================================

  /// Create a new staff account with assigned role and permissions.
  Future<StaffMember> createStaff({
    required String shopId,
    required String name,
    required String phone,
    required StaffRole role,
    Set<StaffPermission>? permissions,
    String pin = '0000',
    String? createdBy,
    String actorName = 'Store Owner',
    String actorRole = 'owner',
  }) async {
    final perms = permissions ?? StaffMember.defaultPermissionsForRole(role);
    final now = DateTime.now();
    final docRef = _staffCollection.doc();

    final staff = StaffMember(
      id: docRef.id,
      shopId: shopId,
      name: name.trim(),
      phone: phone.trim(),
      role: role,
      permissions: perms,
      pin: pin.trim(),
      isActive: true,
      createdAt: now,
      createdBy: createdBy,
    );

    await docRef.set(staff.toMap());

    // Record audit log
    await recordAuditLog(
      shopId: shopId,
      actorId: createdBy ?? 'owner',
      actorName: actorName,
      actorRole: actorRole,
      actionType: AuditActionType.staffCreated,
      entityType: 'staff',
      entityId: staff.id,
      entityName: staff.name,
      description: 'New staff account created: ${staff.name} (${staff.role.label}) with ${perms.length} permissions.',
      newValue: {
        'role': staff.role.name,
        'phone': staff.phone,
        'permissions': perms.map((p) => p.name).toList(),
      },
    );

    return staff;
  }

  /// Update an existing staff member's profile or permissions.
  Future<void> updateStaff({
    required String staffId,
    required String shopId,
    String? name,
    String? phone,
    StaffRole? role,
    Set<StaffPermission>? permissions,
    String? pin,
    String actorId = 'owner',
    String actorName = 'Store Owner',
    String actorRole = 'owner',
  }) async {
    final doc = await _staffCollection.doc(staffId).get();
    if (!doc.exists) return;

    final existing = StaffMember.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    final updates = <String, dynamic>{};

    if (name != null) updates['name'] = name.trim();
    if (phone != null) updates['phone'] = phone.trim();
    if (role != null) updates['role'] = role.key;
    if (permissions != null) {
      updates['permissions'] = permissions.map((p) => p.key).toList();
    }
    if (pin != null) updates['pin'] = pin.trim();

    if (updates.isEmpty) return;

    await _staffCollection.doc(staffId).update(updates);

    // Record audit log
    await recordAuditLog(
      shopId: shopId,
      actorId: actorId,
      actorName: actorName,
      actorRole: actorRole,
      actionType: AuditActionType.staffUpdated,
      entityType: 'staff',
      entityId: staffId,
      entityName: name ?? existing.name,
      description: 'Staff account updated for ${name ?? existing.name}. Changed fields: ${updates.keys.join(', ')}.',
      oldValue: {
        'role': existing.role.name,
        'permissions': existing.permissions.map((p) => p.name).toList(),
      },
      newValue: {
        if (role != null) 'role': role.name,
        if (permissions != null)
          'permissions': permissions.map((p) => p.name).toList(),
      },
    );
  }

  /// Toggle staff member active/inactive status.
  Future<void> toggleStaffStatus({
    required String staffId,
    required String shopId,
    required bool isActive,
    String actorId = 'owner',
    String actorName = 'Store Owner',
    String actorRole = 'owner',
  }) async {
    final doc = await _staffCollection.doc(staffId).get();
    if (!doc.exists) return;

    final existing = StaffMember.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    await _staffCollection.doc(staffId).update({'is_active': isActive});

    // Record audit log
    await recordAuditLog(
      shopId: shopId,
      actorId: actorId,
      actorName: actorName,
      actorRole: actorRole,
      actionType: AuditActionType.staffStatusToggled,
      entityType: 'staff',
      entityId: staffId,
      entityName: existing.name,
      description: isActive
          ? 'Staff member ${existing.name} was ACTIVATED.'
          : 'Staff member ${existing.name} was DEACTIVATED.',
      oldValue: {'is_active': existing.isActive},
      newValue: {'is_active': isActive},
    );
  }

  /// Delete a staff account permanently.
  Future<void> deleteStaff({
    required String staffId,
    required String shopId,
    String actorId = 'owner',
    String actorName = 'Store Owner',
    String actorRole = 'owner',
  }) async {
    final doc = await _staffCollection.doc(staffId).get();
    if (!doc.exists) return;

    final existing = StaffMember.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    await _staffCollection.doc(staffId).delete();

    // Record audit log
    await recordAuditLog(
      shopId: shopId,
      actorId: actorId,
      actorName: actorName,
      actorRole: actorRole,
      actionType: AuditActionType.staffUpdated,
      entityType: 'staff',
      entityId: staffId,
      entityName: existing.name,
      description: 'Staff account for ${existing.name} was removed from the store.',
      oldValue: existing.toMap(),
    );
  }

  /// Stream all staff members belonging to a shop.
  Stream<List<StaffMember>> streamShopStaff(String shopId) {
    if (shopId.isEmpty) return Stream.value([]);
    return _staffCollection
        .where('shop_id', isEqualTo: shopId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((d) => StaffMember.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  /// Verify quick security PIN for a staff member during high-impact operations.
  Future<bool> verifyStaffPin({
    required String shopId,
    required String staffId,
    required String pin,
  }) async {
    final doc = await _staffCollection.doc(staffId).get();
    if (!doc.exists) return false;
    final staff = StaffMember.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    if (!staff.isActive || staff.shopId != shopId) return false;
    return staff.pin == pin.trim();
  }

  // ===========================================================================
  // IMMUTABLE AUDIT LOGS
  // ===========================================================================

  /// Record an audit log entry in the Firestore collection.
  Future<AuditLogEntry> recordAuditLog({
    required String shopId,
    required String actorId,
    required String actorName,
    required String actorRole,
    String? actorPhone,
    required AuditActionType actionType,
    required String entityType,
    required String entityId,
    required String entityName,
    required String description,
    Map<String, dynamic>? oldValue,
    Map<String, dynamic>? newValue,
    String? reason,
    Map<String, dynamic>? metadata,
  }) async {
    final docRef = _auditLogsCollection.doc();
    final now = DateTime.now();

    final entry = AuditLogEntry(
      id: docRef.id,
      shopId: shopId,
      actorId: actorId,
      actorName: actorName,
      actorRole: actorRole,
      actorPhone: actorPhone,
      actionType: actionType,
      entityType: entityType,
      entityId: entityId,
      entityName: entityName,
      description: description,
      oldValue: oldValue,
      newValue: newValue,
      timestamp: now,
      reason: reason,
      metadata: metadata,
    );

    await docRef.set(entry.toMap());
    return entry;
  }

  /// Stream audit logs for a shop, with optional filter by action type.
  Stream<List<AuditLogEntry>> streamAuditLogs(
    String shopId, {
    AuditActionType? filterAction,
    String? actorId,
    int limit = 100,
  }) {
    if (shopId.isEmpty) return Stream.value([]);

    Query query = _auditLogsCollection.where('shop_id', isEqualTo: shopId);

    if (filterAction != null) {
      query = query.where('action_type', isEqualTo: filterAction.name);
    }
    if (actorId != null && actorId.isNotEmpty) {
      query = query.where('actor_id', isEqualTo: actorId);
    }

    return query.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((d) => AuditLogEntry.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
      // Sort newest first
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list.take(limit).toList();
    });
  }

  /// Adjust stock on a product with a complete immutable audit log record.
  /// Example requirement: Stock 20 se 12 units hua. Audit log se pata chal sakega
  /// ki authorized user ne kab aur kis wajah se adjustment kiya.
  Future<void> adjustStockWithAudit({
    required String shopId,
    required String productId,
    required String productName,
    required double oldStock,
    required double newStock,
    required String reason,
    required String actorId,
    required String actorName,
    required String actorRole,
    String? actorPhone,
  }) async {
    // 1. Update product stock in catalog
    await _productsCollection.doc(productId).update({
      'stock_quantity': newStock,
      'last_stock_adjustment': {
        'old_stock': oldStock,
        'new_stock': newStock,
        'reason': reason,
        'actor_name': actorName,
        'timestamp': DateTime.now().toIso8601String(),
      },
    });

    // 2. Generate and store immutable audit log
    final diff = newStock - oldStock;
    final diffStr = diff >= 0 ? '+${diff.toStringAsFixed(1)}' : diff.toStringAsFixed(1);

    await recordAuditLog(
      shopId: shopId,
      actorId: actorId,
      actorName: actorName,
      actorRole: actorRole,
      actorPhone: actorPhone,
      actionType: AuditActionType.stockAdjustment,
      entityType: 'product',
      entityId: productId,
      entityName: productName,
      description: 'Stock adjusted for "$productName" from ${oldStock.toStringAsFixed(1)} to ${newStock.toStringAsFixed(1)} units ($diffStr).',
      oldValue: {'stock_quantity': oldStock},
      newValue: {'stock_quantity': newStock, 'difference': diff},
      reason: reason.trim().isNotEmpty ? reason.trim() : 'Manual inventory recount',
      metadata: {
        'difference': diff,
        'unit': 'Units',
      },
    );
  }

  /// Fetch aggregated summary of staff and audit trail for KPI dashboard.
  Future<StaffAuditAnalytics> fetchAnalyticsSummary(String shopId) async {
    if (shopId.isEmpty) return StaffAuditAnalytics.empty();

    // 1. Fetch staff counts
    final staffSnap = await _staffCollection.where('shop_id', isEqualTo: shopId).get();
    int totalStaff = staffSnap.docs.length;
    int activeStaff = 0;
    for (final doc in staffSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['is_active'] == true) activeStaff++;
    }

    // 2. Fetch logs
    final logsSnap = await _auditLogsCollection.where('shop_id', isEqualTo: shopId).get();
    final now = DateTime.now();
    int todayLogs = 0;
    int criticalChanges = 0;
    final actorActivity = <String, int>{};
    final actionDist = <AuditActionType, int>{};

    for (final doc in logsSnap.docs) {
      final entry = AuditLogEntry.fromMap(doc.data() as Map<String, dynamic>, doc.id);

      // Today log check
      if (entry.timestamp.year == now.year &&
          entry.timestamp.month == now.month &&
          entry.timestamp.day == now.day) {
        todayLogs++;
      }

      // Critical changes check (stock, price, write-off)
      if (entry.actionType == AuditActionType.stockAdjustment ||
          entry.actionType == AuditActionType.stockWriteOff ||
          entry.actionType == AuditActionType.priceChange) {
        criticalChanges++;
      }

      // Most active actor
      actorActivity[entry.actorName] = (actorActivity[entry.actorName] ?? 0) + 1;

      // Action distribution
      actionDist[entry.actionType] = (actionDist[entry.actionType] ?? 0) + 1;
    }

    String topActor = 'None';
    int maxLogs = 0;
    actorActivity.forEach((actor, logCount) {
      if (logCount > maxLogs) {
        maxLogs = logCount;
        topActor = actor;
      }
    });

    return StaffAuditAnalytics(
      totalStaff: totalStaff,
      activeStaff: activeStaff,
      todayLogCount: todayLogs,
      criticalChangesCount: criticalChanges,
      topActorName: topActor,
      actionDistribution: actionDist,
    );
  }
}
