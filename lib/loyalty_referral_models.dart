import 'package:flutter/material.dart';

/// Customer membership tiers for loyalty rewards
enum LoyaltyTier {
  bronze,
  silver,
  gold,
  platinum;

  String get label {
    switch (this) {
      case LoyaltyTier.bronze:
        return 'Bronze (कांस्य)';
      case LoyaltyTier.silver:
        return 'Silver (रजत)';
      case LoyaltyTier.gold:
        return 'Gold (स्वर्ण)';
      case LoyaltyTier.platinum:
        return 'Platinum (प्लैटिनम)';
    }
  }

  String get simpleName {
    switch (this) {
      case LoyaltyTier.bronze:
        return 'Bronze';
      case LoyaltyTier.silver:
        return 'Silver';
      case LoyaltyTier.gold:
        return 'Gold';
      case LoyaltyTier.platinum:
        return 'Platinum';
    }
  }

  /// Minimum lifetime points earned to qualify for tier
  int get minLifetimePoints {
    switch (this) {
      case LoyaltyTier.bronze:
        return 0;
      case LoyaltyTier.silver:
        return 200;
      case LoyaltyTier.gold:
        return 600;
      case LoyaltyTier.platinum:
        return 1500;
    }
  }

  /// Multiplier on earned points (e.g. Gold earns 1.5x points)
  double get pointsMultiplier {
    switch (this) {
      case LoyaltyTier.bronze:
        return 1.0;
      case LoyaltyTier.silver:
        return 1.25;
      case LoyaltyTier.gold:
        return 1.5;
      case LoyaltyTier.platinum:
        return 2.0;
    }
  }

  Color get color {
    switch (this) {
      case LoyaltyTier.bronze:
        return const Color(0xFFCD7F32);
      case LoyaltyTier.silver:
        return const Color(0xFF757575);
      case LoyaltyTier.gold:
        return const Color(0xFFFFA000);
      case LoyaltyTier.platinum:
        return const Color(0xFF5E35B1);
    }
  }

  static LoyaltyTier fromPoints(int lifetimePoints) {
    if (lifetimePoints >= 1500) return LoyaltyTier.platinum;
    if (lifetimePoints >= 600) return LoyaltyTier.gold;
    if (lifetimePoints >= 200) return LoyaltyTier.silver;
    return LoyaltyTier.bronze;
  }

  static LoyaltyTier fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'silver':
        return LoyaltyTier.silver;
      case 'gold':
        return LoyaltyTier.gold;
      case 'platinum':
        return LoyaltyTier.platinum;
      case 'bronze':
      default:
        return LoyaltyTier.bronze;
    }
  }
}

/// Ledger transaction types for loyalty credits and debits
enum LoyaltyTransactionType {
  earnedPurchase,
  referralReferrer,
  referralReferee,
  redeemedPurchase,
  welcomeBonus,
  adminAdjustment,
  refundRestored,
  expired;

  String get label {
    switch (this) {
      case LoyaltyTransactionType.earnedPurchase:
        return 'खरीदारी पर अंक (Purchase Reward)';
      case LoyaltyTransactionType.referralReferrer:
        return 'रेफरल बोनस - मित्र रेफर किया (Referral Bonus)';
      case LoyaltyTransactionType.referralReferee:
        return 'रेफरल स्वागत बोनस (Friend Welcome Reward)';
      case LoyaltyTransactionType.redeemedPurchase:
        return 'ऑर्डर पर अंक भुनाए (Points Redeemed)';
      case LoyaltyTransactionType.welcomeBonus:
        return 'स्वागत अंक (Welcome Bonus)';
      case LoyaltyTransactionType.adminAdjustment:
        return 'दुकानदार समायोजन (Store Adjustment)';
      case LoyaltyTransactionType.refundRestored:
        return 'वापसी अंक बहाल (Points Restored)';
      case LoyaltyTransactionType.expired:
        return 'अंक समाप्त (Points Expired)';
    }
  }

  bool get isCredit {
    switch (this) {
      case LoyaltyTransactionType.earnedPurchase:
      case LoyaltyTransactionType.referralReferrer:
      case LoyaltyTransactionType.referralReferee:
      case LoyaltyTransactionType.welcomeBonus:
      case LoyaltyTransactionType.refundRestored:
        return true;
      case LoyaltyTransactionType.redeemedPurchase:
      case LoyaltyTransactionType.expired:
        return false;
      case LoyaltyTransactionType.adminAdjustment:
        return true; // Dependent on points sign
    }
  }

  static LoyaltyTransactionType fromString(String? value) {
    switch (value) {
      case 'referral_referrer':
        return LoyaltyTransactionType.referralReferrer;
      case 'referral_referee':
        return LoyaltyTransactionType.referralReferee;
      case 'redeemed_purchase':
        return LoyaltyTransactionType.redeemedPurchase;
      case 'welcome_bonus':
        return LoyaltyTransactionType.welcomeBonus;
      case 'admin_adjustment':
        return LoyaltyTransactionType.adminAdjustment;
      case 'refund_restored':
        return LoyaltyTransactionType.refundRestored;
      case 'expired':
        return LoyaltyTransactionType.expired;
      case 'earned_purchase':
      default:
        return LoyaltyTransactionType.earnedPurchase;
    }
  }

  String get key {
    switch (this) {
      case LoyaltyTransactionType.earnedPurchase:
        return 'earned_purchase';
      case LoyaltyTransactionType.referralReferrer:
        return 'referral_referrer';
      case LoyaltyTransactionType.referralReferee:
        return 'referral_referee';
      case LoyaltyTransactionType.redeemedPurchase:
        return 'redeemed_purchase';
      case LoyaltyTransactionType.welcomeBonus:
        return 'welcome_bonus';
      case LoyaltyTransactionType.adminAdjustment:
        return 'admin_adjustment';
      case LoyaltyTransactionType.refundRestored:
        return 'refund_restored';
      case LoyaltyTransactionType.expired:
        return 'expired';
    }
  }
}

/// Ledger transaction record
class LoyaltyTransaction {
  final String id;
  final String shopId;
  final String customerPhone;
  final String? customerUid;
  final int points; // Positive for credit, negative for debit
  final LoyaltyTransactionType type;
  final String description;
  final String? orderId;
  final double? orderAmount;
  final int balanceAfter;
  final DateTime createdAt;

  const LoyaltyTransaction({
    required this.id,
    required this.shopId,
    required this.customerPhone,
    this.customerUid,
    required this.points,
    required this.type,
    required this.description,
    this.orderId,
    this.orderAmount,
    required this.balanceAfter,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'shop_id': shopId,
    'customer_phone': customerPhone,
    'customer_uid': customerUid,
    'points': points,
    'type': type.key,
    'description': description,
    'order_id': orderId,
    'order_amount': orderAmount,
    'balance_after': balanceAfter,
    'created_at': createdAt.toIso8601String(),
  };

  factory LoyaltyTransaction.fromMap(Map<String, dynamic> map, String id) {
    return LoyaltyTransaction(
      id: id,
      shopId: map['shop_id']?.toString() ?? '',
      customerPhone: map['customer_phone']?.toString() ?? '',
      customerUid: map['customer_uid']?.toString(),
      points: (map['points'] as num?)?.toInt() ?? 0,
      type: LoyaltyTransactionType.fromString(map['type']?.toString()),
      description: map['description']?.toString() ?? '',
      orderId: map['order_id']?.toString(),
      orderAmount: (map['order_amount'] as num?)?.toDouble(),
      balanceAfter: (map['balance_after'] as num?)?.toInt() ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Customer's loyalty passbook account for a shop
class CustomerLoyaltyAccount {
  final String id;
  final String shopId;
  final String customerPhone;
  final String? customerUid;
  final String customerName;
  final int currentPoints;
  final int lifetimeEarnedPoints;
  final int lifetimeRedeemedPoints;
  final String referralCode;
  final String? referredByCode;
  final LoyaltyTier tier;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CustomerLoyaltyAccount({
    required this.id,
    required this.shopId,
    required this.customerPhone,
    this.customerUid,
    required this.customerName,
    required this.currentPoints,
    required this.lifetimeEarnedPoints,
    required this.lifetimeRedeemedPoints,
    required this.referralCode,
    this.referredByCode,
    required this.tier,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Rupee savings equivalent based on conversion rate (default 1 pt = ₹0.10, i.e. 100 pts = ₹10)
  double rupeeValue([double ratePerPoint = 0.10]) {
    return currentPoints * ratePerPoint;
  }

  /// Calculates progress (0.0 to 1.0) towards the next loyalty tier
  double get progressToNextTier {
    switch (tier) {
      case LoyaltyTier.bronze:
        return (lifetimeEarnedPoints / LoyaltyTier.silver.minLifetimePoints).clamp(0.0, 1.0);
      case LoyaltyTier.silver:
        final current = lifetimeEarnedPoints - LoyaltyTier.silver.minLifetimePoints;
        final target = LoyaltyTier.gold.minLifetimePoints - LoyaltyTier.silver.minLifetimePoints;
        return (current / target).clamp(0.0, 1.0);
      case LoyaltyTier.gold:
        final current = lifetimeEarnedPoints - LoyaltyTier.gold.minLifetimePoints;
        final target = LoyaltyTier.platinum.minLifetimePoints - LoyaltyTier.gold.minLifetimePoints;
        return (current / target).clamp(0.0, 1.0);
      case LoyaltyTier.platinum:
        return 1.0;
    }
  }

  /// Points needed to upgrade to the next tier
  int get pointsNeededForNextTier {
    switch (tier) {
      case LoyaltyTier.bronze:
        return (LoyaltyTier.silver.minLifetimePoints - lifetimeEarnedPoints).clamp(0, 99999);
      case LoyaltyTier.silver:
        return (LoyaltyTier.gold.minLifetimePoints - lifetimeEarnedPoints).clamp(0, 99999);
      case LoyaltyTier.gold:
        return (LoyaltyTier.platinum.minLifetimePoints - lifetimeEarnedPoints).clamp(0, 99999);
      case LoyaltyTier.platinum:
        return 0;
    }
  }

  LoyaltyTier get nextTier {
    switch (tier) {
      case LoyaltyTier.bronze:
        return LoyaltyTier.silver;
      case LoyaltyTier.silver:
        return LoyaltyTier.gold;
      case LoyaltyTier.gold:
        return LoyaltyTier.platinum;
      case LoyaltyTier.platinum:
        return LoyaltyTier.platinum;
    }
  }

  CustomerLoyaltyAccount copyWith({
    String? id,
    String? shopId,
    String? customerPhone,
    String? customerUid,
    String? customerName,
    int? currentPoints,
    int? lifetimeEarnedPoints,
    int? lifetimeRedeemedPoints,
    String? referralCode,
    String? referredByCode,
    LoyaltyTier? tier,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerLoyaltyAccount(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      customerPhone: customerPhone ?? this.customerPhone,
      customerUid: customerUid ?? this.customerUid,
      customerName: customerName ?? this.customerName,
      currentPoints: currentPoints ?? this.currentPoints,
      lifetimeEarnedPoints: lifetimeEarnedPoints ?? this.lifetimeEarnedPoints,
      lifetimeRedeemedPoints: lifetimeRedeemedPoints ?? this.lifetimeRedeemedPoints,
      referralCode: referralCode ?? this.referralCode,
      referredByCode: referredByCode ?? this.referredByCode,
      tier: tier ?? this.tier,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'shop_id': shopId,
    'customer_phone': customerPhone,
    'customer_uid': customerUid,
    'customer_name': customerName,
    'current_points': currentPoints,
    'lifetime_earned_points': lifetimeEarnedPoints,
    'lifetime_redeemed_points': lifetimeRedeemedPoints,
    'referral_code': referralCode,
    'referred_by_code': referredByCode,
    'tier': tier.simpleName.toLowerCase(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory CustomerLoyaltyAccount.fromMap(Map<String, dynamic> map, String id) {
    final earned = (map['lifetime_earned_points'] as num?)?.toInt() ?? 0;
    return CustomerLoyaltyAccount(
      id: id,
      shopId: map['shop_id']?.toString() ?? '',
      customerPhone: map['customer_phone']?.toString() ?? '',
      customerUid: map['customer_uid']?.toString(),
      customerName: map['customer_name']?.toString() ?? '',
      currentPoints: (map['current_points'] as num?)?.toInt() ?? 0,
      lifetimeEarnedPoints: earned,
      lifetimeRedeemedPoints: (map['lifetime_redeemed_points'] as num?)?.toInt() ?? 0,
      referralCode: map['referral_code']?.toString() ?? '',
      referredByCode: map['referred_by_code']?.toString(),
      tier: map['tier'] != null
          ? LoyaltyTier.fromString(map['tier'].toString())
          : LoyaltyTier.fromPoints(earned),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Referral tracking status
enum ReferralStatus {
  pending,
  completed,
  expired,
  cancelled;

  String get label {
    switch (this) {
      case ReferralStatus.pending:
        return 'प्रतीक्षारत (Pending 1st Purchase)';
      case ReferralStatus.completed:
        return 'सफल - इनाम क्रेडिट (Reward Unlocked)';
      case ReferralStatus.expired:
        return 'समाप्त (Expired)';
      case ReferralStatus.cancelled:
        return 'रद्द (Cancelled)';
    }
  }

  static ReferralStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'completed':
        return ReferralStatus.completed;
      case 'expired':
        return ReferralStatus.expired;
      case 'cancelled':
        return ReferralStatus.cancelled;
      case 'pending':
      default:
        return ReferralStatus.pending;
    }
  }
}

/// Record of a friend referral connection
class ReferralRecord {
  final String id;
  final String shopId;
  final String referralCode;
  final String referrerPhone;
  final String referrerName;
  final String refereePhone;
  final String refereeName;
  final ReferralStatus status;
  final String? qualifyingOrderId;
  final double? qualifyingOrderAmount;
  final int referrerPointsAwarded;
  final int refereePointsAwarded;
  final DateTime createdAt;
  final DateTime? completedAt;

  const ReferralRecord({
    required this.id,
    required this.shopId,
    required this.referralCode,
    required this.referrerPhone,
    required this.referrerName,
    required this.refereePhone,
    required this.refereeName,
    required this.status,
    this.qualifyingOrderId,
    this.qualifyingOrderAmount,
    this.referrerPointsAwarded = 0,
    this.refereePointsAwarded = 0,
    required this.createdAt,
    this.completedAt,
  });

  Map<String, dynamic> toMap() => {
    'shop_id': shopId,
    'referral_code': referralCode,
    'referrer_phone': referrerPhone,
    'referrer_name': referrerName,
    'referee_phone': refereePhone,
    'referee_name': refereeName,
    'status': status.name,
    'qualifying_order_id': qualifyingOrderId,
    'qualifying_order_amount': qualifyingOrderAmount,
    'referrer_points_awarded': referrerPointsAwarded,
    'referee_points_awarded': refereePointsAwarded,
    'created_at': createdAt.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
  };

  factory ReferralRecord.fromMap(Map<String, dynamic> map, String id) {
    return ReferralRecord(
      id: id,
      shopId: map['shop_id']?.toString() ?? '',
      referralCode: map['referral_code']?.toString() ?? '',
      referrerPhone: map['referrer_phone']?.toString() ?? '',
      referrerName: map['referrer_name']?.toString() ?? 'Store Member',
      refereePhone: map['referee_phone']?.toString() ?? '',
      refereeName: map['referee_name']?.toString() ?? 'Friend',
      status: ReferralStatus.fromString(map['status']?.toString()),
      qualifyingOrderId: map['qualifying_order_id']?.toString(),
      qualifyingOrderAmount: (map['qualifying_order_amount'] as num?)?.toDouble(),
      referrerPointsAwarded: (map['referrer_points_awarded'] as num?)?.toInt() ?? 0,
      refereePointsAwarded: (map['referee_points_awarded'] as num?)?.toInt() ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      completedAt: map['completed_at'] != null
          ? DateTime.tryParse(map['completed_at'].toString())
          : null,
    );
  }
}

/// Store-level configuration for Loyalty & Referral Program
class LoyaltyProgramConfig {
  final String shopId;
  final bool isEnabled;
  final int pointsPerHundredRupees; // e.g. 10 points per ₹100 = 1 pt per ₹10
  final double pointValueInRupees; // e.g. 0.10 means 100 points = ₹10
  final int minPointsToRedeem; // e.g. 50 points
  final double maxRedemptionPercentage; // e.g. 0.30 means max 30% of order subtotal
  final double minQualifyingOrderForPoints; // e.g. ₹50 min purchase
  final bool referralEnabled;
  final int referrerRewardPoints; // e.g. 100 points to referrer on qualifying purchase
  final int refereeRewardPoints; // e.g. 50 points to friend on first qualifying purchase
  final double minQualifyingOrderForReferral; // e.g. ₹100 min purchase for referral to trigger
  final int welcomeBonusPoints; // e.g. 20 points on signing up to store loyalty

  const LoyaltyProgramConfig({
    required this.shopId,
    this.isEnabled = true,
    this.pointsPerHundredRupees = 10,
    this.pointValueInRupees = 0.10,
    this.minPointsToRedeem = 50,
    this.maxRedemptionPercentage = 0.30,
    this.minQualifyingOrderForPoints = 50.0,
    this.referralEnabled = true,
    this.referrerRewardPoints = 100,
    this.refereeRewardPoints = 50,
    this.minQualifyingOrderForReferral = 100.0,
    this.welcomeBonusPoints = 20,
  });

  /// Calculates points earned for a purchase subtotal considering customer tier multiplier
  int calculateEarnedPoints(double subtotal, {double tierMultiplier = 1.0}) {
    if (!isEnabled || subtotal < minQualifyingOrderForPoints) return 0;
    final basePoints = (subtotal / 100.0) * pointsPerHundredRupees;
    return (basePoints * tierMultiplier).floor();
  }

  /// Calculates max redeemable points for an order subtotal
  int calculateMaxRedeemablePoints(double subtotal, int availablePoints) {
    if (!isEnabled || availablePoints < minPointsToRedeem) return 0;
    final maxAllowedRupeeDiscount = subtotal * maxRedemptionPercentage;
    final maxPointsByCap = (maxAllowedRupeeDiscount / pointValueInRupees).floor();
    return availablePoints.clamp(0, maxPointsByCap);
  }

  /// Converts points to equivalent rupee discount
  double pointsToRupees(int points) {
    return (points * pointValueInRupees);
  }

  Map<String, dynamic> toMap() => {
    'shop_id': shopId,
    'is_enabled': isEnabled,
    'points_per_hundred': pointsPerHundredRupees,
    'point_value_rupees': pointValueInRupees,
    'min_points_to_redeem': minPointsToRedeem,
    'max_redemption_percent': maxRedemptionPercentage,
    'min_order_for_points': minQualifyingOrderForPoints,
    'referral_enabled': referralEnabled,
    'referrer_reward_points': referrerRewardPoints,
    'referee_reward_points': refereeRewardPoints,
    'min_order_for_referral': minQualifyingOrderForReferral,
    'welcome_bonus_points': welcomeBonusPoints,
  };

  factory LoyaltyProgramConfig.fromMap(Map<String, dynamic>? map, String shopId) {
    if (map == null) return LoyaltyProgramConfig(shopId: shopId);
    return LoyaltyProgramConfig(
      shopId: shopId,
      isEnabled: map['is_enabled'] ?? true,
      pointsPerHundredRupees: (map['points_per_hundred'] as num?)?.toInt() ?? 10,
      pointValueInRupees: (map['point_value_rupees'] as num?)?.toDouble() ?? 0.10,
      minPointsToRedeem: (map['min_points_to_redeem'] as num?)?.toInt() ?? 50,
      maxRedemptionPercentage: (map['max_redemption_percent'] as num?)?.toDouble() ?? 0.30,
      minQualifyingOrderForPoints: (map['min_order_for_points'] as num?)?.toDouble() ?? 50.0,
      referralEnabled: map['referral_enabled'] ?? true,
      referrerRewardPoints: (map['referrer_reward_points'] as num?)?.toInt() ?? 100,
      refereeRewardPoints: (map['referee_reward_points'] as num?)?.toInt() ?? 50,
      minQualifyingOrderForReferral: (map['min_order_for_referral'] as num?)?.toDouble() ?? 100.0,
      welcomeBonusPoints: (map['welcome_bonus_points'] as num?)?.toInt() ?? 20,
    );
  }
}
