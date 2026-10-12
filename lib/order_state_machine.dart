import 'package:flutter/material.dart';
import 'app_theme.dart';

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

  static const List<String> terminalStatuses = [
    delivered,
    cancelled,
    rejected,
  ];
}

/// State Machine enforcing strict valid order state transitions and preventing illegal reversals.
class OrderStateMachine {
  /// Definitive transition graph
  static const Map<String, List<String>> _validTransitions = {
    OrderStatus.pending: [
      OrderStatus.accepted,
      OrderStatus.packing,
      OrderStatus.packed,
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
      OrderStatus.cancelled,
    ],
    OrderStatus.packed: [
      OrderStatus.ready,
      OrderStatus.outForDelivery,
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
        return deliveryType == 'Delivery' ? 'Dispatch Order' : 'Deliver to Customer';
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
