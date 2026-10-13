import 'package:cloud_firestore/cloud_firestore.dart';

/// Status constants for product substitution proposals
class SubstitutionStatus {
  static const String pending = 'pending';
  static const String accepted = 'accepted';
  static const String rejected = 'rejected';
  static const String cancelled = 'cancelled';
}

/// Action to perform on the original order item if customer rejects proposed substitute
class SubstitutionRejectionAction {
  static const String removeItem = 'removeItem';
  static const String keepOriginal = 'keepOriginal';
}

/// Model representing a merchant's proposal to substitute an out-of-stock item
/// with an alternative product, subject to customer approval.
class ProductSubstitutionProposal {
  final String id;
  final String orderId;
  final String originalProductId;
  final String originalProductName;
  final double originalPrice;
  final double originalQuantity;
  final String? originalUnit;
  final String? originalImageUrl;

  final String? substituteProductId;
  final String substituteProductName;
  final double substitutePrice;
  final double substituteQuantity;
  final String? substituteUnit;
  final String? substituteImageUrl;

  final String status; // pending, accepted, rejected, cancelled
  final String? reason;
  final String proposedBy; // 'merchant', 'admin'
  final DateTime proposedAt;
  final DateTime? respondedAt;
  final String? rejectionAction; // removeItem, keepOriginal
  final String? customerNote;

  const ProductSubstitutionProposal({
    required this.id,
    required this.orderId,
    required this.originalProductId,
    required this.originalProductName,
    required this.originalPrice,
    required this.originalQuantity,
    this.originalUnit,
    this.originalImageUrl,
    this.substituteProductId,
    required this.substituteProductName,
    required this.substitutePrice,
    required this.substituteQuantity,
    this.substituteUnit,
    this.substituteImageUrl,
    this.status = SubstitutionStatus.pending,
    this.reason,
    this.proposedBy = 'merchant',
    required this.proposedAt,
    this.respondedAt,
    this.rejectionAction,
    this.customerNote,
  });

  /// Total cost of the original ordered item
  double get originalItemTotal => originalPrice * originalQuantity;

  /// Total cost of the proposed substitute item
  double get substituteItemTotal => substitutePrice * substituteQuantity;

  /// Net price difference (Positive means substitute is costlier; Negative means cheaper)
  double get priceDifference => substituteItemTotal - originalItemTotal;

  /// Whether the customer still needs to respond
  bool get isPending => status == SubstitutionStatus.pending;

  /// Whether customer accepted the substitution
  bool get isAccepted => status == SubstitutionStatus.accepted;

  /// Whether customer rejected the substitution
  bool get isRejected => status == SubstitutionStatus.rejected;

  /// Formatted price difference text (e.g., "+₹20.00" or "-₹15.00" or "No price difference")
  String get formattedDifference {
    final diff = priceDifference;
    if (diff.abs() < 0.01) {
      return 'Same price';
    } else if (diff > 0) {
      return '+₹${diff.toStringAsFixed(diff.truncateToDouble() == diff ? 0 : 2)}';
    } else {
      return '-₹${diff.abs().toStringAsFixed(diff.truncateToDouble() == diff ? 0 : 2)}';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'original_product_id': originalProductId,
      'original_product_name': originalProductName,
      'original_price': originalPrice,
      'original_quantity': originalQuantity,
      if (originalUnit != null) 'original_unit': originalUnit,
      if (originalImageUrl != null) 'original_image_url': originalImageUrl,
      if (substituteProductId != null) 'substitute_product_id': substituteProductId,
      'substitute_product_name': substituteProductName,
      'substitute_price': substitutePrice,
      'substitute_quantity': substituteQuantity,
      if (substituteUnit != null) 'substitute_unit': substituteUnit,
      if (substituteImageUrl != null) 'substitute_image_url': substituteImageUrl,
      'original_item_total': originalItemTotal,
      'substitute_item_total': substituteItemTotal,
      'price_difference': priceDifference,
      'status': status,
      if (reason != null) 'reason': reason,
      'proposed_by': proposedBy,
      'proposed_at': Timestamp.fromDate(proposedAt),
      if (respondedAt != null) 'responded_at': Timestamp.fromDate(respondedAt!),
      if (rejectionAction != null) 'rejection_action': rejectionAction,
      if (customerNote != null) 'customer_note': customerNote,
    };
  }

  factory ProductSubstitutionProposal.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return ProductSubstitutionProposal(
      id: map['id']?.toString() ?? '',
      orderId: map['order_id']?.toString() ?? '',
      originalProductId: map['original_product_id']?.toString() ?? '',
      originalProductName: map['original_product_name']?.toString() ?? '',
      originalPrice: (map['original_price'] as num?)?.toDouble() ?? 0.0,
      originalQuantity: (map['original_quantity'] as num?)?.toDouble() ?? 1.0,
      originalUnit: map['original_unit']?.toString(),
      originalImageUrl: map['original_image_url']?.toString(),
      substituteProductId: map['substitute_product_id']?.toString(),
      substituteProductName: map['substitute_product_name']?.toString() ?? '',
      substitutePrice: (map['substitute_price'] as num?)?.toDouble() ?? 0.0,
      substituteQuantity: (map['substitute_quantity'] as num?)?.toDouble() ?? 1.0,
      substituteUnit: map['substitute_unit']?.toString(),
      substituteImageUrl: map['substitute_image_url']?.toString(),
      status: map['status']?.toString() ?? SubstitutionStatus.pending,
      reason: map['reason']?.toString(),
      proposedBy: map['proposed_by']?.toString() ?? 'merchant',
      proposedAt: parseDate(map['proposed_at']),
      respondedAt: map['responded_at'] != null ? parseDate(map['responded_at']) : null,
      rejectionAction: map['rejection_action']?.toString(),
      customerNote: map['customer_note']?.toString(),
    );
  }

  ProductSubstitutionProposal copyWith({
    String? id,
    String? orderId,
    String? originalProductId,
    String? originalProductName,
    double? originalPrice,
    double? originalQuantity,
    String? originalUnit,
    String? originalImageUrl,
    String? substituteProductId,
    String? substituteProductName,
    double? substitutePrice,
    double? substituteQuantity,
    String? substituteUnit,
    String? substituteImageUrl,
    String? status,
    String? reason,
    String? proposedBy,
    DateTime? proposedAt,
    DateTime? respondedAt,
    String? rejectionAction,
    String? customerNote,
  }) {
    return ProductSubstitutionProposal(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      originalProductId: originalProductId ?? this.originalProductId,
      originalProductName: originalProductName ?? this.originalProductName,
      originalPrice: originalPrice ?? this.originalPrice,
      originalQuantity: originalQuantity ?? this.originalQuantity,
      originalUnit: originalUnit ?? this.originalUnit,
      originalImageUrl: originalImageUrl ?? this.originalImageUrl,
      substituteProductId: substituteProductId ?? this.substituteProductId,
      substituteProductName: substituteProductName ?? this.substituteProductName,
      substitutePrice: substitutePrice ?? this.substitutePrice,
      substituteQuantity: substituteQuantity ?? this.substituteQuantity,
      substituteUnit: substituteUnit ?? this.substituteUnit,
      substituteImageUrl: substituteImageUrl ?? this.substituteImageUrl,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      proposedBy: proposedBy ?? this.proposedBy,
      proposedAt: proposedAt ?? this.proposedAt,
      respondedAt: respondedAt ?? this.respondedAt,
      rejectionAction: rejectionAction ?? this.rejectionAction,
      customerNote: customerNote ?? this.customerNote,
    );
  }
}
