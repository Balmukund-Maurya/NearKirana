import 'package:cloud_firestore/cloud_firestore.dart';

/// Supported coupon discount types
enum CouponDiscountType {
  flat, // Fixed rupee amount (e.g. ₹50 OFF)
  percentage, // Percentage discount (e.g. 10% OFF)
  freeDelivery, // Waives off delivery fee
}

/// Comprehensive model for shop and platform coupons
class CouponModel {
  final String id;
  final String code; // Uppercase coupon code (e.g. SAVE50)
  final String description; // Description shown to customers
  final CouponDiscountType type;
  final double discountValue; // Value in ₹ or %
  final double minOrderValue; // Minimum cart value required
  final double? maxDiscount; // Max discount cap for percentage discounts
  final DateTime? startDate; // When coupon becomes active
  final DateTime? endDate; // When coupon expires
  final int? usageLimit; // Global usage limit
  final int usedCount; // Current times used across platform/shop
  final int perUserLimit; // Times a single customer can use this coupon (default 1)
  final String? shopId; // Specific store ID or null for platform-wide
  final bool isActive; // Toggle switch
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CouponModel({
    required this.id,
    required this.code,
    this.description = '',
    this.type = CouponDiscountType.flat,
    this.discountValue = 0.0,
    this.minOrderValue = 0.0,
    this.maxDiscount,
    this.startDate,
    this.endDate,
    this.usageLimit,
    this.usedCount = 0,
    this.perUserLimit = 1,
    this.shopId,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  /// Formatted type string ('flat', 'percent', 'free_delivery')
  String get typeString {
    switch (type) {
      case CouponDiscountType.flat:
        return 'flat';
      case CouponDiscountType.percentage:
        return 'percent';
      case CouponDiscountType.freeDelivery:
        return 'free_delivery';
    }
  }

  /// Parses type from string
  static CouponDiscountType parseType(String? val) {
    if (val == null) return CouponDiscountType.flat;
    switch (val.toLowerCase().trim()) {
      case 'percent':
      case 'percentage':
        return CouponDiscountType.percentage;
      case 'free_delivery':
      case 'freeshipping':
      case 'free_shipping':
        return CouponDiscountType.freeDelivery;
      case 'flat':
      case 'fixed':
      default:
        return CouponDiscountType.flat;
    }
  }

  /// Formatted badge string (e.g., '₹50 OFF', '10% OFF', 'FREE DELIVERY')
  String get formattedDiscountText {
    switch (type) {
      case CouponDiscountType.flat:
        return '₹${discountValue.toStringAsFixed(0)} OFF';
      case CouponDiscountType.percentage:
        return '${discountValue.toStringAsFixed(0)}% OFF';
      case CouponDiscountType.freeDelivery:
        return 'FREE DELIVERY';
    }
  }

  /// Alias for formattedDiscountText
  String get formattedDiscount => formattedDiscountText;

  /// Checks if coupon is within its valid date window
  bool isWithinDateWindow([DateTime? now]) {
    final current = now ?? DateTime.now();
    if (startDate != null && current.isBefore(startDate!)) {
      return false;
    }
    if (endDate != null && current.isAfter(endDate!)) {
      return false;
    }
    return true;
  }

  /// Checks if coupon has expired
  bool isExpired([DateTime? now]) {
    final current = now ?? DateTime.now();
    return endDate != null && current.isAfter(endDate!);
  }

  /// Checks if global usage limit has been exhausted
  bool isFullyClaimed() {
    return usageLimit != null && usedCount >= usageLimit!;
  }

  /// Calculates discount for a given subtotal and delivery fee
  double calculateDiscount({
    required double subtotal,
    double deliveryFee = 0.0,
  }) {
    if (subtotal <= 0) return 0.0;
    if (subtotal < minOrderValue) return 0.0;

    double calculated = 0.0;
    switch (type) {
      case CouponDiscountType.flat:
        calculated = discountValue;
        break;
      case CouponDiscountType.percentage:
        calculated = (subtotal * discountValue) / 100.0;
        if (maxDiscount != null && calculated > maxDiscount!) {
          calculated = maxDiscount!;
        }
        break;
      case CouponDiscountType.freeDelivery:
        calculated = deliveryFee;
        break;
    }

    // Safety invariant: Discount cannot exceed subtotal (unless free delivery which waives delivery fee)
    if (type != CouponDiscountType.freeDelivery && calculated > subtotal) {
      calculated = subtotal;
    }

    return double.parse(calculated.toStringAsFixed(2));
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code.toUpperCase().trim(),
      'description': description,
      'type': typeString,
      'discount_value': discountValue,
      'min_order_value': minOrderValue,
      if (maxDiscount != null) 'max_discount': maxDiscount,
      if (startDate != null) 'start_date': Timestamp.fromDate(startDate!),
      if (endDate != null) 'end_date': Timestamp.fromDate(endDate!),
      if (usageLimit != null) 'usage_limit': usageLimit,
      'used_count': usedCount,
      'per_user_limit': perUserLimit,
      if (shopId != null && shopId!.isNotEmpty) 'shop_id': shopId,
      'is_active': isActive,
      'created_at': Timestamp.fromDate(createdAt ?? DateTime.now()),
      if (updatedAt != null) 'updated_at': Timestamp.fromDate(updatedAt!),
    };
  }

  factory CouponModel.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return CouponModel(
      id: id ?? map['id']?.toString() ?? '',
      code: (map['code']?.toString() ?? '').toUpperCase().trim(),
      description: map['description']?.toString() ?? '',
      type: parseType(map['type']?.toString()),
      discountValue: (map['discount_value'] as num?)?.toDouble() ??
          (map['value'] as num?)?.toDouble() ??
          0.0,
      minOrderValue: (map['min_order_value'] as num?)?.toDouble() ??
          (map['min_order'] as num?)?.toDouble() ??
          0.0,
      maxDiscount: (map['max_discount'] as num?)?.toDouble(),
      startDate: parseDate(map['start_date']),
      endDate: parseDate(map['end_date']),
      usageLimit: (map['usage_limit'] as num?)?.toInt(),
      usedCount: (map['used_count'] as num?)?.toInt() ?? 0,
      perUserLimit: (map['per_user_limit'] as num?)?.toInt() ?? 1,
      shopId: map['shop_id']?.toString(),
      isActive: map['is_active'] ?? map['status'] == 'Active' || map['status'] == null,
      createdAt: parseDate(map['created_at']) ?? DateTime.now(),
      updatedAt: parseDate(map['updated_at']),
    );
  }

  CouponModel copyWith({
    String? id,
    String? code,
    String? description,
    CouponDiscountType? type,
    double? discountValue,
    double? minOrderValue,
    double? maxDiscount,
    DateTime? startDate,
    DateTime? endDate,
    int? usageLimit,
    int? usedCount,
    int? perUserLimit,
    String? shopId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CouponModel(
      id: id ?? this.id,
      code: code ?? this.code,
      description: description ?? this.description,
      type: type ?? this.type,
      discountValue: discountValue ?? this.discountValue,
      minOrderValue: minOrderValue ?? this.minOrderValue,
      maxDiscount: maxDiscount ?? this.maxDiscount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      usageLimit: usageLimit ?? this.usageLimit,
      usedCount: usedCount ?? this.usedCount,
      perUserLimit: perUserLimit ?? this.perUserLimit,
      shopId: shopId ?? this.shopId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Detailed validation output for coupon eligibility
class CouponValidationResult {
  final bool isValid;
  final CouponModel? coupon;
  final double discountAmount;
  final String? errorMessage;
  final double deliveryDiscount;

  const CouponValidationResult({
    required this.isValid,
    this.coupon,
    this.discountAmount = 0.0,
    this.errorMessage,
    this.deliveryDiscount = 0.0,
  });

  static const CouponValidationResult invalid = CouponValidationResult(
    isValid: false,
    errorMessage: 'Invalid coupon code',
  );

  double get totalSavings => discountAmount + deliveryDiscount;
}
