import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Type of customer complaint/dispute
enum ComplaintType {
  damaged('damaged', 'Damaged Item', Icons.broken_image_rounded),
  missingItem('missing_item', 'Missing Item', Icons.remove_shopping_cart_rounded),
  wrongItem('wrong_item', 'Wrong Item Delivered', Icons.swap_horiz_rounded),
  expiredOrQuality('expired_quality', 'Quality / Expiry Issue', Icons.warning_amber_rounded),
  billingIssue('billing_issue', 'Billing / Overcharged', Icons.receipt_long_rounded),
  other('other', 'Other Issue', Icons.help_outline_rounded);

  final String value;
  final String label;
  final IconData icon;

  const ComplaintType(this.value, this.label, this.icon);

  static ComplaintType fromString(String? val) {
    return ComplaintType.values.firstWhere(
      (e) => e.value == val,
      orElse: () => ComplaintType.other,
    );
  }
}

/// Lifecycle status of the complaint
enum ComplaintStatus {
  pending('pending', 'Pending Review', Colors.orange),
  inReview('in_review', 'In Review', Colors.blue),
  resolvedRefund('resolved_refund', 'Resolved (Refunded)', Colors.purple),
  resolvedReplacement('resolved_replacement', 'Resolved (Replaced)', Colors.green),
  rejected('rejected', 'Rejected', Colors.red),
  cancelled('cancelled', 'Cancelled', Colors.grey);

  final String value;
  final String label;
  final MaterialColor color;

  const ComplaintStatus(this.value, this.label, this.color);

  static ComplaintStatus fromString(String? val) {
    return ComplaintStatus.values.firstWhere(
      (e) => e.value == val,
      orElse: () => ComplaintStatus.pending,
    );
  }
}

/// Resolution action applied by storekeeper/support
enum ResolutionType {
  refund('refund', 'Refund'),
  replacement('replacement', 'Replacement Item'),
  noAction('no_action', 'Reject / No Action');

  final String value;
  final String label;

  const ResolutionType(this.value, this.label);

  static ResolutionType fromString(String? val) {
    return ResolutionType.values.firstWhere(
      (e) => e.value == val,
      orElse: () => ResolutionType.noAction,
    );
  }
}

/// Method used when refunding
enum RefundMethod {
  khataCredit('khata_credit', 'Khata Balance Credit'),
  cash('cash', 'Cash on Next Visit'),
  upi('upi', 'UPI / Online Refund');

  final String value;
  final String label;

  const RefundMethod(this.value, this.label);

  static RefundMethod? fromString(String? val) {
    if (val == null || val.isEmpty) return null;
    return RefundMethod.values.firstWhere(
      (e) => e.value == val,
      orElse: () => RefundMethod.khataCredit,
    );
  }
}

/// Specific order item affected in the complaint
class ComplaintItem {
  final String itemId;
  final String name;
  final int quantityOrdered;
  final int quantityAffected;
  final double pricePerUnit;
  final String? notes;

  const ComplaintItem({
    required this.itemId,
    required this.name,
    required this.quantityOrdered,
    required this.quantityAffected,
    required this.pricePerUnit,
    this.notes,
  });

  double get totalAffectedValue => quantityAffected * pricePerUnit;

  Map<String, dynamic> toMap() {
    return {
      'item_id': itemId,
      'name': name,
      'quantity_ordered': quantityOrdered,
      'quantity_affected': quantityAffected,
      'price_per_unit': pricePerUnit,
      if (notes != null) 'notes': notes,
    };
  }

  factory ComplaintItem.fromMap(Map<String, dynamic> map) {
    return ComplaintItem(
      itemId: map['item_id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      quantityOrdered: (map['quantity_ordered'] as num?)?.toInt() ?? 1,
      quantityAffected: (map['quantity_affected'] as num?)?.toInt() ?? 1,
      pricePerUnit: (map['price_per_unit'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes']?.toString(),
    );
  }
}

/// Comprehensive model for Returns, Refunds & Complaints (Feature 51)
class ComplaintModel {
  final String id;
  final String orderId;
  final String shopId;
  final String customerPhone;
  final String customerName;
  final ComplaintType type;
  final ComplaintStatus status;
  final String description;
  final String? imageUrl;
  final List<ComplaintItem> affectedItems;
  final ResolutionType requestedResolution;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ResolutionType? resolutionType;
  final String? resolutionNotes;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final double? refundAmount;
  final RefundMethod? refundMethod;
  final String? replacementDetails;

  const ComplaintModel({
    required this.id,
    required this.orderId,
    required this.shopId,
    required this.customerPhone,
    required this.customerName,
    required this.type,
    required this.status,
    required this.description,
    this.imageUrl,
    this.affectedItems = const [],
    this.requestedResolution = ResolutionType.refund,
    required this.createdAt,
    required this.updatedAt,
    this.resolutionType,
    this.resolutionNotes,
    this.resolvedAt,
    this.resolvedBy,
    this.refundAmount,
    this.refundMethod,
    this.replacementDetails,
  });

  /// Total claim value calculated from affected items
  double get estimatedClaimAmount {
    if (affectedItems.isEmpty) return 0.0;
    return affectedItems.fold(
      0.0,
      (totalClaim, item) => totalClaim + item.totalAffectedValue,
    );
  }

  bool get isPending => status == ComplaintStatus.pending;
  bool get isInReview => status == ComplaintStatus.inReview;
  bool get isResolved =>
      status == ComplaintStatus.resolvedRefund ||
      status == ComplaintStatus.resolvedReplacement;
  bool get isRejected => status == ComplaintStatus.rejected;
  bool get isCancelled => status == ComplaintStatus.cancelled;

  Map<String, dynamic> toMap() {
    return {
      'order_id': orderId,
      'shop_id': shopId,
      'customer_phone': customerPhone,
      'customer_name': customerName,
      'type': type.value,
      'status': status.value,
      'description': description,
      if (imageUrl != null && imageUrl!.isNotEmpty) 'image_url': imageUrl,
      'affected_items': affectedItems.map((e) => e.toMap()).toList(),
      'requested_resolution': requestedResolution.value,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      if (resolutionType != null) 'resolution_type': resolutionType!.value,
      if (resolutionNotes != null) 'resolution_notes': resolutionNotes,
      if (resolvedAt != null) 'resolved_at': Timestamp.fromDate(resolvedAt!),
      if (resolvedBy != null) 'resolved_by': resolvedBy,
      if (refundAmount != null) 'refund_amount': refundAmount,
      if (refundMethod != null) 'refund_method': refundMethod!.value,
      if (replacementDetails != null) 'replacement_details': replacementDetails,
    };
  }

  factory ComplaintModel.fromMap(String docId, Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final rawItems = map['affected_items'] as List<dynamic>? ?? [];
    final items = rawItems
        .map((e) => ComplaintItem.fromMap(e as Map<String, dynamic>))
        .toList();

    return ComplaintModel(
      id: docId,
      orderId: map['order_id']?.toString() ?? '',
      shopId: map['shop_id']?.toString() ?? '',
      customerPhone: map['customer_phone']?.toString() ?? '',
      customerName: map['customer_name']?.toString() ?? '',
      type: ComplaintType.fromString(map['type']?.toString()),
      status: ComplaintStatus.fromString(map['status']?.toString()),
      description: map['description']?.toString() ?? '',
      imageUrl: map['image_url']?.toString(),
      affectedItems: items,
      requestedResolution: ResolutionType.fromString(
        map['requested_resolution']?.toString(),
      ),
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
      resolutionType: map['resolution_type'] != null
          ? ResolutionType.fromString(map['resolution_type']?.toString())
          : null,
      resolutionNotes: map['resolution_notes']?.toString(),
      resolvedAt: map['resolved_at'] != null ? parseDate(map['resolved_at']) : null,
      resolvedBy: map['resolved_by']?.toString(),
      refundAmount: (map['refund_amount'] as num?)?.toDouble(),
      refundMethod: RefundMethod.fromString(map['refund_method']?.toString()),
      replacementDetails: map['replacement_details']?.toString(),
    );
  }

  factory ComplaintModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ComplaintModel.fromMap(doc.id, data);
  }

  ComplaintModel copyWith({
    String? id,
    String? orderId,
    String? shopId,
    String? customerPhone,
    String? customerName,
    ComplaintType? type,
    ComplaintStatus? status,
    String? description,
    String? imageUrl,
    List<ComplaintItem>? affectedItems,
    ResolutionType? requestedResolution,
    DateTime? createdAt,
    DateTime? updatedAt,
    ResolutionType? resolutionType,
    String? resolutionNotes,
    DateTime? resolvedAt,
    String? resolvedBy,
    double? refundAmount,
    RefundMethod? refundMethod,
    String? replacementDetails,
  }) {
    return ComplaintModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      shopId: shopId ?? this.shopId,
      customerPhone: customerPhone ?? this.customerPhone,
      customerName: customerName ?? this.customerName,
      type: type ?? this.type,
      status: status ?? this.status,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      affectedItems: affectedItems ?? this.affectedItems,
      requestedResolution: requestedResolution ?? this.requestedResolution,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resolutionType: resolutionType ?? this.resolutionType,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      refundAmount: refundAmount ?? this.refundAmount,
      refundMethod: refundMethod ?? this.refundMethod,
      replacementDetails: replacementDetails ?? this.replacementDetails,
    );
  }
}
