import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_utils.dart';
import 'coupon_model.dart';

/// Central server-side and client-side Coupon & Discount Engine.
/// Handles deterministic validation, multi-rule discount calculations,
/// and atomic usage tracking.
class CouponService {
  final FirebaseFirestore _firestore;

  CouponService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseUtils.firestore;

  static final CouponService instance = CouponService();

  /// Validates a coupon code against all promotional rules:
  /// - Exists in catalog
  /// - Active status
  /// - Store scope (global or store-specific)
  /// - Date range (start date & expiry)
  /// - Minimum order threshold
  /// - Global usage limits
  /// - Per-customer usage limits
  Future<CouponValidationResult> validateCoupon({
    required String code,
    required double subtotal,
    double deliveryFee = 0.0,
    String? customerPhone,
    String? shopId,
    DateTime? now,
  }) async {
    final cleanCode = code.toUpperCase().trim();
    if (cleanCode.isEmpty) {
      return const CouponValidationResult(
        isValid: false,
        errorMessage: 'Please enter a coupon code',
      );
    }

    try {
      final querySnap = await _firestore
          .collection('coupons')
          .where('code', isEqualTo: cleanCode)
          .limit(1)
          .get();

      DocumentSnapshot<Map<String, dynamic>>? foundDoc;
      if (querySnap.docs.isNotEmpty) {
        foundDoc = querySnap.docs.first;
      } else {
        // Fallback: search by original code or scan active coupons case-insensitively
        final altSnap = await _firestore
            .collection('coupons')
            .where('code', isEqualTo: code.trim())
            .limit(1)
            .get();
        if (altSnap.docs.isNotEmpty) {
          foundDoc = altSnap.docs.first;
        } else {
          final allSnap = await _firestore
              .collection('coupons')
              .limit(50)
              .get();
          for (final d in allSnap.docs) {
            final c = (d.data()['code']?.toString() ?? '').toUpperCase().trim();
            if (c == cleanCode) {
              foundDoc = d;
              break;
            }
          }
        }
      }

      if (foundDoc == null) {
        return CouponValidationResult(
          isValid: false,
          errorMessage: 'Coupon code "$cleanCode" is invalid or does not exist.',
        );
      }

      final doc = foundDoc;
      final coupon = CouponModel.fromMap(doc.data()!, id: doc.id);

      final currentTime = now ?? DateTime.now();

      // Rule 1: Active status
      if (!coupon.isActive) {
        return CouponValidationResult(
          isValid: false,
          coupon: coupon,
          errorMessage: 'Coupon "$cleanCode" is currently inactive.',
        );
      }

      // Rule 2: Store scope
      if (coupon.shopId != null &&
          coupon.shopId!.isNotEmpty &&
          shopId != null &&
          shopId.isNotEmpty &&
          coupon.shopId != shopId) {
        return CouponValidationResult(
          isValid: false,
          coupon: coupon,
          errorMessage: 'This coupon is not valid for this store.',
        );
      }

      // Rule 3: Start date
      if (coupon.startDate != null && currentTime.isBefore(coupon.startDate!)) {
        final startFormatted =
            '${coupon.startDate!.day}/${coupon.startDate!.month}/${coupon.startDate!.year}';
        return CouponValidationResult(
          isValid: false,
          coupon: coupon,
          errorMessage: 'Coupon will become active on $startFormatted.',
        );
      }

      // Rule 4: Expiry date
      if (coupon.isExpired(currentTime)) {
        final endFormatted =
            '${coupon.endDate!.day}/${coupon.endDate!.month}/${coupon.endDate!.year}';
        return CouponValidationResult(
          isValid: false,
          coupon: coupon,
          errorMessage: 'Coupon "$cleanCode" expired on $endFormatted.',
        );
      }

      // Rule 5: Minimum order value
      if (subtotal < coupon.minOrderValue) {
        final remaining = coupon.minOrderValue - subtotal;
        return CouponValidationResult(
          isValid: false,
          coupon: coupon,
          errorMessage:
              'Min order value of ₹${coupon.minOrderValue.toStringAsFixed(0)} required (Add ₹${remaining.toStringAsFixed(0)} more).',
        );
      }

      // Rule 6: Global usage limit
      if (coupon.isFullyClaimed()) {
        return CouponValidationResult(
          isValid: false,
          coupon: coupon,
          errorMessage:
              'This coupon has reached its maximum global usage limit.',
        );
      }

      // Rule 7: Per-user usage limit
      if (customerPhone != null && customerPhone.trim().isNotEmpty) {
        final cleanPhone = customerPhone.replaceAll(RegExp(r'\D'), '');
        final usagesSnap = await _firestore
            .collection('coupon_usages')
            .where('coupon_id', isEqualTo: coupon.id)
            .where('customer_phone', isEqualTo: cleanPhone)
            .get();

        if (usagesSnap.docs.length >= coupon.perUserLimit) {
          return CouponValidationResult(
            isValid: false,
            coupon: coupon,
            errorMessage:
                'You have already redeemed coupon "$cleanCode" the maximum allowed times (${coupon.perUserLimit}).',
          );
        }
      }

      // Rule 8: Calculate valid discount
      final discount = coupon.calculateDiscount(
        subtotal: subtotal,
        deliveryFee: deliveryFee,
      );

      final deliveryDiscount =
          coupon.type == CouponDiscountType.freeDelivery ? deliveryFee : 0.0;

      return CouponValidationResult(
        isValid: true,
        coupon: coupon,
        discountAmount: discount,
        deliveryDiscount: deliveryDiscount,
      );
    } catch (e) {
      return CouponValidationResult(
        isValid: false,
        errorMessage: 'Unable to validate coupon: $e',
      );
    }
  }

  /// Atomically increments usage count and writes a coupon usage entry.
  /// Can be called standalone or within an atomic transaction.
  Future<void> recordCouponUsage({
    required String couponId,
    required String orderId,
    required String customerPhone,
    required double discountApplied,
    FirebaseFirestore? firestore,
  }) async {
    final fs = firestore ?? _firestore;
    final cleanPhone = customerPhone.replaceAll(RegExp(r'\D'), '');

    final couponRef = fs.collection('coupons').doc(couponId);
    final usageRef = fs.collection('coupon_usages').doc('usage_${orderId}_$couponId');

    await fs.runTransaction((transaction) async {
      final couponSnap = await transaction.get(couponRef);
      if (couponSnap.exists) {
        final currentCount =
            (couponSnap.data()?['used_count'] as num?)?.toInt() ?? 0;
        transaction.update(couponRef, {'used_count': currentCount + 1});
      }

      transaction.set(usageRef, {
        'coupon_id': couponId,
        'order_id': orderId,
        'customer_phone': cleanPhone,
        'discount_applied': discountApplied,
        'used_at': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Real-time stream of all available active coupons for a store and platform
  Stream<List<CouponModel>> getAvailableCouponsStream({
    String? shopId,
    int limit = 50,
  }) {
    return _firestore
        .collection('coupons')
        .where('is_active', isEqualTo: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final coupons = snapshot.docs
          .map((doc) => CouponModel.fromMap(doc.data(), id: doc.id))
          .where((c) {
            // Include platform coupons (shopId null) or store-specific coupons
            if (shopId != null && c.shopId != null && c.shopId!.isNotEmpty) {
              return c.shopId == shopId;
            }
            return true;
          })
          .where((c) => !c.isExpired() && !c.isFullyClaimed())
          .toList();

      // Sort by best discount value
      coupons.sort((a, b) => b.discountValue.compareTo(a.discountValue));
      return coupons;
    });
  }

  /// Stream of all coupons (active and inactive) for admin management
  Stream<List<CouponModel>> getAllCouponsStream({String? shopId}) {
    return _firestore.collection('coupons').snapshots().map((snapshot) {
      final coupons = snapshot.docs
          .map((doc) => CouponModel.fromMap(doc.data(), id: doc.id))
          .where((c) {
            if (shopId != null && shopId.isNotEmpty && c.shopId != null && c.shopId!.isNotEmpty) {
              return c.shopId == shopId;
            }
            return true;
          })
          .toList();

      coupons.sort((a, b) {
        final aDate = a.startDate ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.startDate ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return coupons;
    });
  }

  /// Admin: Create a new promotional coupon
  Future<String> createCoupon(CouponModel coupon) async {
    final upperCode = coupon.code.toUpperCase().trim();
    if (upperCode.isEmpty) {
      throw ArgumentError('Coupon code cannot be empty');
    }
    if (coupon.discountValue <= 0) {
      throw ArgumentError('Discount value must be greater than zero');
    }

    // Check if code already exists
    final existing = await _firestore
        .collection('coupons')
        .where('code', isEqualTo: upperCode)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw StateError('A coupon with code "$upperCode" already exists');
    }

    final docRef = _firestore.collection('coupons').doc('coup_$upperCode');
    final newCoupon = coupon.copyWith(
      id: docRef.id,
      code: upperCode,
      createdAt: DateTime.now(),
    );

    await docRef.set(newCoupon.toMap());
    return docRef.id;
  }

  /// Admin: Update existing coupon
  Future<void> updateCoupon(CouponModel coupon) async {
    final docRef = _firestore.collection('coupons').doc(coupon.id);
    await docRef.update({
      ...coupon.toMap(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Admin: Toggle active status
  Future<void> toggleCouponStatus(String couponId, bool isActive) async {
    await _firestore
        .collection('coupons')
        .doc(couponId)
        .update({'is_active': isActive, 'updated_at': FieldValue.serverTimestamp()});
  }

  /// Admin: Delete a coupon
  Future<void> deleteCoupon(String couponId) async {
    await _firestore.collection('coupons').doc(couponId).delete();
  }
}
