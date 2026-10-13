import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'firebase_utils.dart';

/// Standard Order Status constants for NearKirana
class OrderStatus {
  static const String pending = 'Pending';
  static const String accepted = 'Accepted';
  static const String packing = 'Packing';
  static const String packed = 'Packed'; // Backward compatibility alias
  static const String ready = 'Ready';
  static const String outForDelivery = 'Out for Delivery';
  static const String delivered = 'Delivered';
  static const String rejected = 'Rejected';
  static const String cancelled = 'Cancelled';
  static const String deliveryFailed = 'Delivery_Failed';

  static const List<String> allStatuses = [
    pending,
    accepted,
    packing,
    packed,
    ready,
    outForDelivery,
    delivered,
    rejected,
    cancelled,
    deliveryFailed,
  ];

  static const List<String> activeStatuses = [
    pending,
    accepted,
    packing,
    packed,
    ready,
    outForDelivery,
    deliveryFailed,
  ];

  static const List<String> terminalStatuses = [delivered, cancelled, rejected];

  static bool isTerminal(String? status) =>
      status != null && terminalStatuses.contains(status);

  static bool isActive(String? status) =>
      status != null && activeStatuses.contains(status);

  static double getProgressPercentage(String? status) {
    switch (status) {
      case pending:
        return 0.10;
      case accepted:
        return 0.25;
      case packing:
      case packed:
        return 0.50;
      case ready:
        return 0.70;
      case outForDelivery:
        return 0.85;
      case delivered:
        return 1.00;
      default:
        return 0.00;
    }
  }

  static String getDescription(String? status) {
    switch (status) {
      case pending:
        return 'Order placed. Awaiting shop confirmation.';
      case accepted:
        return 'Order accepted by store.';
      case packing:
      case packed:
        return 'Items are being packed at the store.';
      case ready:
        return 'Order is packed and ready.';
      case outForDelivery:
        return 'Order is on the way to delivery address.';
      case delivered:
        return 'Order delivered successfully.';
      case deliveryFailed:
        return 'Delivery partner could not complete delivery.';
      case rejected:
        return 'Order was rejected by shop.';
      case cancelled:
        return 'Order was cancelled.';
      default:
        return 'Order status: $status';
    }
  }
}

/// Audit representation of an administrative order correction
class OrderStateCorrectionResult {
  final bool success;
  final String orderId;
  final String previousStatus;
  final String newStatus;
  final String authorizedBy;
  final String reason;
  final DateTime timestamp;

  const OrderStateCorrectionResult({
    required this.success,
    required this.orderId,
    required this.previousStatus,
    required this.newStatus,
    required this.authorizedBy,
    required this.reason,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'success': success,
    'order_id': orderId,
    'previous_status': previousStatus,
    'new_status': newStatus,
    'authorized_by': authorizedBy,
    'reason': reason,
    'timestamp': Timestamp.fromDate(timestamp),
  };
}

/// State Machine enforcing strict valid order state transitions and preventing illegal reversals.
/// Lifecycle: Pending -> Accepted -> Packing -> Ready -> Out for Delivery -> Delivered
/// Alternative outcomes: Rejected, Cancelled, Delivery_Failed
class OrderStateMachine {
  /// Definitive transition graph
  static const Map<String, List<String>> _validTransitions = {
    OrderStatus.pending: [
      OrderStatus.accepted,
      OrderStatus.packing,
      OrderStatus.packed,
      OrderStatus.ready,
      OrderStatus.rejected,
      OrderStatus.cancelled,
    ],
    OrderStatus.accepted: [
      OrderStatus.packing,
      OrderStatus.packed,
      OrderStatus.ready,
      OrderStatus.cancelled,
    ],
    OrderStatus.packing: [
      OrderStatus.ready,
      OrderStatus.outForDelivery,
      OrderStatus.delivered,
      OrderStatus.cancelled,
    ],
    OrderStatus.packed: [
      OrderStatus.ready,
      OrderStatus.outForDelivery,
      OrderStatus.delivered,
      OrderStatus.cancelled,
    ],
    OrderStatus.ready: [
      OrderStatus.outForDelivery,
      OrderStatus.delivered,
      OrderStatus.cancelled,
    ],
    OrderStatus.outForDelivery: [
      OrderStatus.delivered,
      OrderStatus.deliveryFailed,
      OrderStatus.cancelled,
    ],
    OrderStatus.deliveryFailed: [
      OrderStatus.outForDelivery,
      OrderStatus.cancelled,
    ],
    // Terminal states - no standard forward or backward transitions!
    OrderStatus.delivered: [],
    OrderStatus.cancelled: [],
    OrderStatus.rejected: [],
  };

  /// Returns list of permitted next statuses from the given status
  static List<String> getAllowedTransitions(
    String currentStatus, {
    bool isSuperAdmin = false,
  }) {
    if (isSuperAdmin) {
      return OrderStatus.allStatuses
          .where((status) => status != currentStatus)
          .toList();
    }
    return _validTransitions[currentStatus] ?? [];
  }

  /// Returns whether a transition from [from] to [to] is valid.
  static bool isValidTransition(
    String from,
    String to, {
    bool isSuperAdmin = false,
  }) {
    if (isSuperAdmin) return true; // Super admin authorized corrections
    if (from == to) return true; // Idempotent update

    // Strict Rule: Delivered orders can NEVER be moved back to active states
    if (from == OrderStatus.delivered && to != OrderStatus.delivered) {
      return false;
    }

    // Strict Rule: Terminal states cannot be revived
    if ((from == OrderStatus.cancelled || from == OrderStatus.rejected) &&
        to != from) {
      return false;
    }

    final allowed = _validTransitions[from];
    if (allowed == null) return false;
    return allowed.contains(to);
  }

  /// Asserts valid transition, throwing StateError on illegal movement.
  static void assertValidTransition(
    String from,
    String to, {
    bool isSuperAdmin = false,
  }) {
    if (!isValidTransition(from, to, isSuperAdmin: isSuperAdmin)) {
      if (from == OrderStatus.delivered) {
        throw StateError(
          'Security Violation: Delivered orders cannot be changed back to "$to" without an authorized correction process.',
        );
      }
      if (from == OrderStatus.cancelled || from == OrderStatus.rejected) {
        throw StateError(
          'Security Violation: Terminal order in state "$from" cannot be transitioned to "$to".',
        );
      }
      throw StateError(
        'Illegal Order Transition: Cannot move order from "$from" to "$to".',
      );
    }
  }

  /// Executes an authorized administrative correction on an order (e.g. reversing a mistake on a Delivered order)
  /// Requires super admin authorization and writes persistent audit records.
  static Future<OrderStateCorrectionResult> applyAuthorizedCorrection({
    required String orderId,
    required String targetStatus,
    required String authorizedBy,
    required String correctionReason,
    bool isSuperAdmin = false,
    FirebaseFirestore? firestore,
  }) async {
    if (!isSuperAdmin) {
      throw StateError(
        'Unauthorized: Administrative correction of order status requires authorized super admin permissions.',
      );
    }

    if (!OrderStatus.allStatuses.contains(targetStatus)) {
      throw ArgumentError(
        'Invalid targetStatus "$targetStatus". Must be a known OrderStatus.',
      );
    }

    final db = firestore ?? FirebaseUtils.firestore;
    final orderRef = db.collection('orders').doc(orderId);
    final orderSnap = await orderRef.get();
    if (!orderSnap.exists) {
      throw Exception('Order #$orderId not found.');
    }

    final currentStatus =
        orderSnap.data()?['status']?.toString() ?? OrderStatus.pending;
    final now = DateTime.now();

    final correctionData = {
      'from_status': currentStatus,
      'to_status': targetStatus,
      'authorized_by': authorizedBy,
      'reason': correctionReason,
      'corrected_at': Timestamp.fromDate(now),
      'is_correction': true,
    };

    // Update main order document with new status and correction audit
    await orderRef.update({
      'status': targetStatus,
      'last_correction': correctionData,
      'status_audit_log': FieldValue.arrayUnion([correctionData]),
    });

    // Record immutable audit entry in status_history subcollection
    await orderRef.collection('status_history').add({
      ...correctionData,
      'timestamp': Timestamp.fromDate(now),
    });

    return OrderStateCorrectionResult(
      success: true,
      orderId: orderId,
      previousStatus: currentStatus,
      newStatus: targetStatus,
      authorizedBy: authorizedBy,
      reason: correctionReason,
      timestamp: now,
    );
  }

  /// Performs a verified order status transition with audit history recording
  static Future<bool> transitionOrder({
    required String orderId,
    required String targetStatus,
    required String updatedBy,
    String? note,
    bool isSuperAdmin = false,
    Map<String, dynamic>? extraUpdates,
    FirebaseFirestore? firestore,
  }) async {
    final db = firestore ?? FirebaseUtils.firestore;
    final orderRef = db.collection('orders').doc(orderId);
    final orderSnap = await orderRef.get();
    if (!orderSnap.exists) {
      throw Exception('Order #$orderId not found.');
    }

    final currentStatus =
        orderSnap.data()?['status']?.toString() ?? OrderStatus.pending;
    assertValidTransition(
      currentStatus,
      targetStatus,
      isSuperAdmin: isSuperAdmin,
    );

    final now = DateTime.now();
    final bool isCorrection =
        isSuperAdmin && OrderStatus.isTerminal(currentStatus);

    final historyEntry = {
      'from_status': currentStatus,
      'to_status': targetStatus,
      'updated_by': updatedBy,
      'timestamp': Timestamp.fromDate(now),
      'note': ?note,
      'is_correction': isCorrection,
    };

    final updateData = <String, dynamic>{
      'status': targetStatus,
      'status_audit_log': FieldValue.arrayUnion([historyEntry]),
      ...?extraUpdates,
    };

    if (targetStatus == OrderStatus.accepted) {
      updateData['accepted_at'] = Timestamp.fromDate(now);
    }
    if (targetStatus == OrderStatus.packing) {
      updateData['packing_started_at'] = Timestamp.fromDate(now);
    }
    if (targetStatus == OrderStatus.ready) {
      updateData['ready_at'] = Timestamp.fromDate(now);
    }
    if (targetStatus == OrderStatus.outForDelivery) {
      updateData['dispatched_at'] = Timestamp.fromDate(now);
    }
    if (targetStatus == OrderStatus.delivered) {
      updateData['delivered_at'] = Timestamp.fromDate(now);
    }
    if (targetStatus == OrderStatus.deliveryFailed) {
      updateData['delivery_failed_at'] = Timestamp.fromDate(now);
    }
    if (targetStatus == OrderStatus.cancelled) {
      updateData['cancelled_at'] = Timestamp.fromDate(now);
    }

    await orderRef.update(updateData);
    await orderRef.collection('status_history').add(historyEntry);

    return true;
  }

  /// Determines next standard progressive status for merchant flow
  static String? getNextProgressiveStatus(
    String currentStatus, {
    required String deliveryType,
  }) {
    switch (currentStatus) {
      case OrderStatus.pending:
        return OrderStatus.accepted;
      case OrderStatus.accepted:
        return OrderStatus.packing;
      case OrderStatus.packing:
      case OrderStatus.packed:
        return OrderStatus.ready;
      case OrderStatus.ready:
        if (deliveryType == 'Delivery') {
          return OrderStatus.outForDelivery;
        } else {
          return OrderStatus.delivered; // In-store pickup completed
        }
      case OrderStatus.outForDelivery:
        return OrderStatus.delivered;
      case OrderStatus.deliveryFailed:
        return OrderStatus.outForDelivery; // Re-attempt delivery
      default:
        return null;
    }
  }

  /// Returns button label for next progressive status
  static String getProgressiveButtonLabel(
    String currentStatus, {
    String deliveryType = 'Delivery',
  }) {
    switch (currentStatus) {
      case OrderStatus.pending:
        return 'Accept Order';
      case OrderStatus.accepted:
        return 'Start Packing';
      case OrderStatus.packing:
      case OrderStatus.packed:
        return 'Mark as Ready';
      case OrderStatus.ready:
        return deliveryType == 'Delivery'
            ? 'Dispatch Order'
            : 'Deliver to Customer';
      case OrderStatus.outForDelivery:
        return 'Verify Delivery';
      case OrderStatus.deliveryFailed:
        return 'Re-dispatch Order';
      default:
        return 'Complete';
    }
  }

  /// Returns button icon for next progressive status
  static IconData getProgressiveButtonIcon(String currentStatus) {
    switch (currentStatus) {
      case OrderStatus.pending:
        return Icons.check_circle_outline_rounded;
      case OrderStatus.accepted:
        return Icons.inventory_2_outlined;
      case OrderStatus.packing:
      case OrderStatus.packed:
        return Icons.moped_rounded;
      case OrderStatus.ready:
        return Icons.storefront_rounded;
      case OrderStatus.outForDelivery:
        return Icons.done_all_rounded;
      case OrderStatus.deliveryFailed:
        return Icons.replay_rounded;
      default:
        return Icons.check_rounded;
    }
  }

  /// Returns button color for next progressive status
  static Color getProgressiveButtonColor(String currentStatus) {
    switch (currentStatus) {
      case OrderStatus.pending:
        return AppColors.primaryDark;
      case OrderStatus.accepted:
        return Colors.orange;
      case OrderStatus.packing:
      case OrderStatus.packed:
        return Colors.blue;
      case OrderStatus.ready:
        return Colors.teal;
      case OrderStatus.outForDelivery:
        return AppColors.primaryDark;
      case OrderStatus.deliveryFailed:
        return Colors.deepOrange;
      default:
        return AppColors.primaryDark;
    }
  }

  /// Customer tracking timeline index (0 to 5)
  static int getTimelineStepIndex(String status) {
    switch (status) {
      case OrderStatus.pending:
        return 0;
      case OrderStatus.accepted:
        return 1;
      case OrderStatus.packing:
      case OrderStatus.packed:
        return 2;
      case OrderStatus.ready:
        return 3;
      case OrderStatus.outForDelivery:
        return 4;
      case OrderStatus.delivered:
        return 5;
      default:
        return 0;
    }
  }

  /// UI Status Badge Colors
  static Color getStatusColor(String status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.accepted:
        return Colors.amber.shade800;
      case OrderStatus.packing:
      case OrderStatus.packed:
        return Colors.blue;
      case OrderStatus.ready:
        return Colors.teal;
      case OrderStatus.outForDelivery:
        return Colors.indigo;
      case OrderStatus.delivered:
        return AppColors.primaryDark;
      case OrderStatus.deliveryFailed:
        return Colors.deepOrange;
      case OrderStatus.rejected:
      case OrderStatus.cancelled:
        return AppColors.error;
      default:
        return AppColors.textMid;
    }
  }
}
