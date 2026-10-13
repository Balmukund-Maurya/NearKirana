import 'package:cloud_firestore/cloud_firestore.dart';

/// Review item for an individual product included in the order
class ProductReviewItem {
  final String productId;
  final String productName;
  final double rating; // 1.0 to 5.0
  final String? comment;

  ProductReviewItem({
    required this.productId,
    required this.productName,
    required this.rating,
    this.comment,
  }) {
    if (rating < 1.0 || rating > 5.0) {
      throw ArgumentError('Product rating must be between 1.0 and 5.0');
    }
  }

  Map<String, dynamic> toMap() => {
    'product_id': productId,
    'product_name': productName,
    'rating': rating,
    if (comment != null && comment!.trim().isNotEmpty) 'comment': comment!.trim(),
  };

  factory ProductReviewItem.fromMap(Map<String, dynamic> map) {
    return ProductReviewItem(
      productId: map['product_id']?.toString() ?? '',
      productName: map['product_name']?.toString() ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      comment: map['comment']?.toString(),
    );
  }
}

/// Comprehensive model for ratings and reviews submitted by verified buyers
class ReviewModel {
  final String id;
  final String orderId;
  final String shopId;
  final String customerPhone;
  final String customerName;
  final String? customerUid;
  final double shopRating; // 1.0 to 5.0
  final double deliveryRating; // 1.0 to 5.0
  final String comment;
  final List<ProductReviewItem> productReviews;
  final bool isVerifiedPurchase;
  final String status; // 'approved', 'flagged', 'rejected'
  final DateTime createdAt;
  final DateTime? updatedAt;

  ReviewModel({
    required this.id,
    required this.orderId,
    required this.shopId,
    required this.customerPhone,
    required this.customerName,
    this.customerUid,
    required this.shopRating,
    required this.deliveryRating,
    this.comment = '',
    this.productReviews = const [],
    this.isVerifiedPurchase = true,
    this.status = 'approved',
    required this.createdAt,
    this.updatedAt,
  }) {
    if (shopRating < 1.0 || shopRating > 5.0) {
      throw ArgumentError('Shop rating must be between 1.0 and 5.0');
    }
    if (deliveryRating < 1.0 || deliveryRating > 5.0) {
      throw ArgumentError('Delivery rating must be between 1.0 and 5.0');
    }
  }

  /// Average overall score for this order review
  double get overallRating => (shopRating + deliveryRating) / 2.0;

  /// Alias for moderation status
  String get moderationStatus => status;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'shop_id': shopId,
      'customer_phone': customerPhone,
      'customer_name': customerName,
      if (customerUid != null) 'customer_uid': customerUid,
      'shop_rating': shopRating,
      'delivery_rating': deliveryRating,
      'overall_rating': overallRating,
      'comment': comment,
      'product_reviews': productReviews.map((p) => p.toMap()).toList(),
      'is_verified_purchase': isVerifiedPurchase,
      'status': status,
      'created_at': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updated_at': Timestamp.fromDate(updatedAt!),
    };
  }

  factory ReviewModel.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final rawProducts = map['product_reviews'] as List<dynamic>? ?? [];
    final products = rawProducts
        .map((e) => ProductReviewItem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    return ReviewModel(
      id: id ?? map['id']?.toString() ?? '',
      orderId: map['order_id']?.toString() ?? '',
      shopId: map['shop_id']?.toString() ?? '',
      customerPhone: map['customer_phone']?.toString() ?? '',
      customerName: map['customer_name']?.toString() ?? 'Verified Customer',
      customerUid: map['customer_uid']?.toString(),
      shopRating: (map['shop_rating'] as num?)?.toDouble() ?? 5.0,
      deliveryRating: (map['delivery_rating'] as num?)?.toDouble() ?? 5.0,
      comment: map['comment']?.toString() ?? '',
      productReviews: products,
      isVerifiedPurchase: map['is_verified_purchase'] ?? true,
      status: map['status']?.toString() ?? 'approved',
      createdAt: parseDate(map['created_at']),
      updatedAt: map['updated_at'] != null ? parseDate(map['updated_at']) : null,
    );
  }

  ReviewModel copyWith({
    String? id,
    String? orderId,
    String? shopId,
    String? customerPhone,
    String? customerName,
    String? customerUid,
    double? shopRating,
    double? deliveryRating,
    String? comment,
    List<ProductReviewItem>? productReviews,
    bool? isVerifiedPurchase,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReviewModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      shopId: shopId ?? this.shopId,
      customerPhone: customerPhone ?? this.customerPhone,
      customerName: customerName ?? this.customerName,
      customerUid: customerUid ?? this.customerUid,
      shopRating: shopRating ?? this.shopRating,
      deliveryRating: deliveryRating ?? this.deliveryRating,
      comment: comment ?? this.comment,
      productReviews: productReviews ?? this.productReviews,
      isVerifiedPurchase: isVerifiedPurchase ?? this.isVerifiedPurchase,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
