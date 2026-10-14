import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_utils.dart';
import 'payment_service.dart';
import 'notification_service.dart';
import 'coupon_model.dart';
import 'loyalty_referral_service.dart';

/// Request model representing an individual cart item in an atomic order placement
class OrderItemRequest {
  final String productId;
  final String name;
  final double price;
  final double quantity;
  final bool isLoose;
  final String? imageUrl;
  final String? unit;

  const OrderItemRequest({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    this.isLoose = false,
    this.imageUrl,
    this.unit,
  });

  Map<String, dynamic> toMap() => {
    'id': productId,
    'name': name,
    'price': price,
    'quantity': quantity,
    'is_loose': isLoose,
    'isLoose': isLoose,
    'image_url': imageUrl ?? '',
    if (unit != null) 'unit': unit,
  };

  factory OrderItemRequest.fromMap(Map<String, dynamic> map) {
    return OrderItemRequest(
      productId: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      isLoose: map['is_loose'] == true || map['isLoose'] == true,
      imageUrl: map['image_url']?.toString(),
      unit: map['unit']?.toString(),
    );
  }
}

/// Parameters for placing an atomic order with stock reservation and idempotency
class OrderPlacementParams {
  final String shopId;
  final String? customerUid;
  final String customerName;
  final String customerPhone;
  final String? deliveryAddress;
  final double? customerLat;
  final double? customerLng;
  final String deliveryType; // 'Delivery' or 'Pickup'
  final double deliveryFee;
  final String paymentMethod; // 'Cash on Delivery', 'UPI', 'Online Gateway'
  final String? paymentStatus;
  final String? upiId;
  final String? upiRefId;
  final String? instructions;
  final String? deliveryPin;
  final String idempotencyKey;
  final List<OrderItemRequest> items;
  final double? minOrder;
  final double? freeDeliveryThreshold;
  final bool enforceStockCheck;
  final bool enforceStoreOpen;
  final String? couponCode;
  final Map<String, dynamic>? extraData;

  const OrderPlacementParams({
    required this.shopId,
    this.customerUid,
    required this.customerName,
    required this.customerPhone,
    this.deliveryAddress,
    this.customerLat,
    this.customerLng,
    this.deliveryType = 'Delivery',
    this.deliveryFee = 0.0,
    this.paymentMethod = 'Cash on Delivery',
    this.paymentStatus,
    this.upiId,
    this.upiRefId,
    this.instructions,
    this.deliveryPin,
    required this.idempotencyKey,
    required this.items,
    this.minOrder,
    this.freeDeliveryThreshold,
    this.enforceStockCheck = true,
    this.enforceStoreOpen = false,
    this.couponCode,
    this.extraData,
  });
}

/// Result returned after executing atomic order placement
class OrderPlacementResult {
  final String orderId;
  final bool isDuplicate; // True if fulfilled via idempotency cache/replay
  final String status;
  final String deliveryPin;
  final double totalAmount;
  final double subtotal;
  final double deliveryFee;
  final double discount;
  final String? couponCode;
  final Map<String, double> reservedStocks;

  const OrderPlacementResult({
    required this.orderId,
    required this.isDuplicate,
    required this.status,
    required this.deliveryPin,
    required this.totalAmount,
    required this.subtotal,
    required this.deliveryFee,
    this.discount = 0.0,
    this.couponCode,
    this.reservedStocks = const {},
  });
}

/// Thrown when a coupon code cannot be applied or verified
class InvalidCouponException extends AtomicOrderException {
  final String couponCode;
  final String reason;

  InvalidCouponException({
    required this.couponCode,
    required this.reason,
  }) : super('Coupon "$couponCode" is invalid: $reason');
}

/// Base class for all atomic order errors
abstract class AtomicOrderException implements Exception {
  final String message;
  const AtomicOrderException(this.message);
  @override
  String toString() => message;
}

/// Thrown when stock is insufficient for one or more items
class InsufficientStockException extends AtomicOrderException {
  final String productId;
  final String productName;
  final double availableStock;
  final double requestedQuantity;

  InsufficientStockException({
    required this.productId,
    required this.productName,
    required this.availableStock,
    required this.requestedQuantity,
  }) : super('STOCK_ERROR|$productId|$productName|$availableStock');

  String get userFriendlyMessage => availableStock <= 0
      ? "Kshama karein! 🚨 '$productName' abhi kisi aur customer ne kharid liya hai aur stock khatam ho gaya hai."
      : "Kshama karein! 🚨 '$productName' ka kewal ${availableStock.toStringAsFixed(1)} bacha hai (requested $requestedQuantity).";
}

/// Thrown when a product in the cart no longer exists in the catalog
class ProductNotFoundException extends AtomicOrderException {
  final String productId;
  final String productName;

  ProductNotFoundException({required this.productId, required this.productName})
    : super(
        'Product "$productName" ($productId) is no longer available in the shop.',
      );
}

/// Thrown when live price differs from cart snapshot
class PriceChangedException extends AtomicOrderException {
  final String productId;
  final String productName;
  final double oldPrice;
  final double newPrice;

  PriceChangedException({
    required this.productId,
    required this.productName,
    required this.oldPrice,
    required this.newPrice,
  }) : super('PRICE_CHANGED|$productId|$productName|$newPrice');
}

/// Thrown when subtotal is below minimum delivery order
class MinimumOrderViolationException extends AtomicOrderException {
  final double minOrder;
  final double subtotal;

  MinimumOrderViolationException({
    required this.minOrder,
    required this.subtotal,
  }) : super('MIN_ORDER_ERROR|$minOrder');
}

/// Thrown when store is closed
class StoreClosedException extends AtomicOrderException {
  StoreClosedException() : super('Store is currently closed for orders.');
}

/// Trusted backend/client atomic order & inventory reservation service.
/// Enforces:
/// 1. Transactional two-phase read/write inventory reservation (prevents overselling & negative stock).
/// 2. Idempotency mechanism with `idempotency_key` deduplication (prevents double orders on network retry).
/// 3. Invariant: `stock_quantity` can never be negative.
/// 4. All-or-nothing atomicity: If even one product has insufficient stock, zero inventory is deducted.
class AtomicOrderService {
  final FirebaseFirestore _firestore;

  AtomicOrderService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseUtils.firestore;

  static final AtomicOrderService instance = AtomicOrderService();

  /// Places an order atomically with strict stock reservation and idempotency deduplication.
  Future<OrderPlacementResult> placeOrderAtomic(
    OrderPlacementParams params,
  ) async {
    if (params.items.isEmpty) {
      throw ArgumentError('Order must contain at least one item');
    }
    if (params.idempotencyKey.trim().isEmpty) {
      throw ArgumentError('idempotencyKey must not be empty');
    }

    final trimmedKey = params.idempotencyKey.trim();

    // STEP 1: Pre-flight Idempotency Check (Fast query)
    final existingOrders = await _firestore
        .collection('orders')
        .where('idempotency_key', isEqualTo: trimmedKey)
        .limit(1)
        .get();

    if (existingOrders.docs.isNotEmpty) {
      final doc = existingOrders.docs.first;
      final data = doc.data();
      return OrderPlacementResult(
        orderId: doc.id,
        isDuplicate: true,
        status: data['status']?.toString() ?? 'Pending',
        deliveryPin: data['delivery_pin']?.toString() ?? '',
        totalAmount: (data['total_amount'] as num?)?.toDouble() ?? 0.0,
        subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0.0,
        deliveryFee: (data['delivery_fee'] as num?)?.toDouble() ?? 0.0,
        discount: (data['discount'] as num?)?.toDouble() ?? 0.0,
        couponCode: data['coupon_code']?.toString(),
      );
    }

    // Pre-flight Coupon Resolution if requested
    DocumentReference? preflightCouponRef;
    int preflightUserUsageCount = 0;
    final cleanCouponCode = params.couponCode?.toUpperCase().trim();

    if (cleanCouponCode != null && cleanCouponCode.isNotEmpty) {
      final cQuery = await _firestore
          .collection('coupons')
          .where('code', isEqualTo: cleanCouponCode)
          .limit(1)
          .get();

      if (cQuery.docs.isEmpty) {
        throw InvalidCouponException(
          couponCode: cleanCouponCode,
          reason: 'Coupon code does not exist',
        );
      }

      preflightCouponRef = cQuery.docs.first.reference;

      final cleanPhone = params.customerPhone.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.isNotEmpty) {
        final uQuery = await _firestore
            .collection('coupon_usages')
            .where('coupon_id', isEqualTo: preflightCouponRef.id)
            .where('customer_phone', isEqualTo: cleanPhone)
            .get();
        preflightUserUsageCount = uQuery.docs.length;
      }
    }

    // Generate deterministic or safe order document reference
    final sanitizedKey = trimmedKey.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final String targetOrderId =
        (sanitizedKey.length >= 8 && sanitizedKey.length <= 80)
        ? 'ord_$sanitizedKey'
        : _firestore.collection('orders').doc().id;
    final DocumentReference orderRef = _firestore
        .collection('orders')
        .doc(targetOrderId);

    // STEP 2: Execute Atomic Firestore Transaction
    final result = await _firestore.runTransaction<OrderPlacementResult>((
      transaction,
    ) async {
      // -----------------------------------------------------------------------
      // PHASE 1: ALL READS (Firestore transactions require all reads before writes)
      // -----------------------------------------------------------------------

      // 1.1 Intra-transaction check for deterministic order ID (prevents concurrent race with same idempotency key)
      final existingDocSnap = await transaction.get(orderRef);
      if (existingDocSnap.exists) {
        final data = existingDocSnap.data() as Map<String, dynamic>;
        return OrderPlacementResult(
          orderId: orderRef.id,
          isDuplicate: true,
          status: data['status']?.toString() ?? 'Pending',
          deliveryPin: data['delivery_pin']?.toString() ?? '',
          totalAmount: (data['total_amount'] as num?)?.toDouble() ?? 0.0,
          subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0.0,
          deliveryFee: (data['delivery_fee'] as num?)?.toDouble() ?? 0.0,
          discount: (data['discount'] as num?)?.toDouble() ?? 0.0,
          couponCode: data['coupon_code']?.toString(),
        );
      }

      // 1.2 Store open verification if enforced
      if (params.enforceStoreOpen) {
        bool isStoreOpen = true;

        if (params.shopId.trim().isNotEmpty) {
          final shopRef =
              _firestore.collection('shops').doc(params.shopId.trim());
          final shopSnap = await transaction.get(shopRef);
          if (shopSnap.exists && shopSnap.data() != null) {
            final sData = shopSnap.data() as Map<String, dynamic>;
            if (sData.containsKey('is_store_open')) {
              isStoreOpen = sData['is_store_open'] == true;
            } else {
              // Fallback to app_config if shop doesn't specify is_store_open
              final settingsRef =
                  _firestore.collection('settings').doc('app_config');
              final settingsSnap = await transaction.get(settingsRef);
              if (settingsSnap.exists && settingsSnap.data() != null) {
                final cData = settingsSnap.data() as Map<String, dynamic>;
                isStoreOpen = cData['is_store_open'] != false;
              }
            }
          } else {
            final settingsRef =
                _firestore.collection('settings').doc('app_config');
            final settingsSnap = await transaction.get(settingsRef);
            if (settingsSnap.exists && settingsSnap.data() != null) {
              final cData = settingsSnap.data() as Map<String, dynamic>;
              isStoreOpen = cData['is_store_open'] != false;
            }
          }
        } else {
          final settingsRef =
              _firestore.collection('settings').doc('app_config');
          final settingsSnap = await transaction.get(settingsRef);
          if (settingsSnap.exists && settingsSnap.data() != null) {
            final cData = settingsSnap.data() as Map<String, dynamic>;
            isStoreOpen = cData['is_store_open'] != false;
          }
        }

        if (!isStoreOpen) {
          throw StoreClosedException();
        }
      }

      // 1.3 Read live product stocks and calculate verified subtotal
      double liveSubtotal = 0.0;
      final Map<DocumentReference, double> pendingStockDeductions = {};
      final Map<String, double> reservedStocksMap = {};
      final List<Map<String, dynamic>> verifiedItemsList = [];

      for (final item in params.items) {
        final productRef = _firestore
            .collection('products')
            .doc(item.productId);
        final productSnap = await transaction.get(productRef);

        if (!productSnap.exists) {
          throw ProductNotFoundException(
            productId: item.productId,
            productName: item.name,
          );
        }

        final pData = productSnap.data() as Map<String, dynamic>;
        final currentStock =
            (pData['stock_quantity'] as num?)?.toDouble() ?? 0.0;
        final currentPrice = (pData['price'] as num?)?.toDouble() ?? item.price;

        if (params.enforceStockCheck) {
          if (currentStock <= 0 || currentStock < item.quantity) {
            throw InsufficientStockException(
              productId: item.productId,
              productName: pData['name']?.toString() ?? item.name,
              availableStock: currentStock,
              requestedQuantity: item.quantity,
            );
          }
        }

        final double newStock = currentStock - item.quantity;
        if (params.enforceStockCheck && newStock < 0) {
          throw InsufficientStockException(
            productId: item.productId,
            productName: pData['name']?.toString() ?? item.name,
            availableStock: currentStock,
            requestedQuantity: item.quantity,
          );
        }

        pendingStockDeductions[productRef] = newStock;
        reservedStocksMap[item.productId] = newStock;
        liveSubtotal += currentPrice * item.quantity;

        verifiedItemsList.add({
          'id': item.productId,
          'name': pData['name']?.toString() ?? item.name,
          'price': currentPrice,
          'quantity': item.quantity,
          'is_loose': item.isLoose,
          'isLoose': item.isLoose,
          'image_url': item.imageUrl ?? pData['image_url']?.toString() ?? '',
          if (item.unit != null) 'unit': item.unit,
        });
      }

      // 1.4 Minimum order check for delivery orders
      final double minOrder = params.minOrder ?? 0.0;
      final double freeThreshold = params.freeDeliveryThreshold ?? 500.0;

      if (params.deliveryType == 'Delivery' &&
          minOrder > 0 &&
          liveSubtotal < minOrder) {
        throw MinimumOrderViolationException(
          minOrder: minOrder,
          subtotal: liveSubtotal,
        );
      }

      // 1.4 Coupon Verification & Server-Side Discount Calculation (Inside Transaction Read Phase)
      CouponModel? verifiedCoupon;
      double serverDiscount = 0.0;
      double deliveryDiscount = 0.0;
      final couponRef = preflightCouponRef;

      if (couponRef != null) {
        final couponSnap = await transaction.get(couponRef);
        if (!couponSnap.exists) {
          throw InvalidCouponException(
            couponCode: cleanCouponCode!,
            reason: 'Coupon record no longer exists',
          );
        }

        final cData = couponSnap.data() as Map<String, dynamic>;
        verifiedCoupon = CouponModel.fromMap(cData, id: couponRef.id);

        if (!verifiedCoupon.isActive) {
          throw InvalidCouponException(
            couponCode: cleanCouponCode!,
            reason: 'Coupon is currently inactive',
          );
        }

        if (verifiedCoupon.shopId != null &&
            verifiedCoupon.shopId!.isNotEmpty &&
            verifiedCoupon.shopId != params.shopId) {
          throw InvalidCouponException(
            couponCode: cleanCouponCode!,
            reason: 'Coupon is not valid for this store',
          );
        }

        final now = DateTime.now();
        if (verifiedCoupon.startDate != null && now.isBefore(verifiedCoupon.startDate!)) {
          throw InvalidCouponException(
            couponCode: cleanCouponCode!,
            reason: 'Coupon is not yet active',
          );
        }

        if (verifiedCoupon.isExpired(now)) {
          throw InvalidCouponException(
            couponCode: cleanCouponCode!,
            reason: 'Coupon has expired',
          );
        }

        if (liveSubtotal < verifiedCoupon.minOrderValue) {
          throw InvalidCouponException(
            couponCode: cleanCouponCode!,
            reason: 'Minimum cart value of ₹${verifiedCoupon.minOrderValue.toStringAsFixed(0)} required',
          );
        }

        if (verifiedCoupon.isFullyClaimed()) {
          throw InvalidCouponException(
            couponCode: cleanCouponCode!,
            reason: 'Coupon global usage limit reached',
          );
        }

        if (preflightUserUsageCount >= verifiedCoupon.perUserLimit) {
          throw InvalidCouponException(
            couponCode: cleanCouponCode!,
            reason: 'You have already reached the maximum usage limit for this coupon',
          );
        }

        serverDiscount = verifiedCoupon.calculateDiscount(
          subtotal: liveSubtotal,
          deliveryFee: params.deliveryFee,
        );

        if (verifiedCoupon.type == CouponDiscountType.freeDelivery) {
          deliveryDiscount = params.deliveryFee;
        }
      }

      // 1.5 Calculate final delivery fee and net payable total
      double calculatedDeliveryFee =
          (params.deliveryType == 'Delivery' && liveSubtotal < freeThreshold)
          ? params.deliveryFee
          : 0.0;

      if (deliveryDiscount > 0) {
        calculatedDeliveryFee = 0.0;
      }

      final double liveFinalTotal =
          ((liveSubtotal - serverDiscount).clamp(0.0, double.infinity)) + calculatedDeliveryFee;

      // -----------------------------------------------------------------------
      // PHASE 2: ALL WRITES (Executed atomically together)
      // -----------------------------------------------------------------------

      // 2.1 Deduct stock for all products atomically
      for (final entry in pendingStockDeductions.entries) {
        transaction.update(entry.key, {'stock_quantity': entry.value});
      }

      // 2.2 Generate secure 4-digit Delivery PIN
      final String pin =
          params.deliveryPin ?? (1000 + Random().nextInt(9000)).toString();

      // 2.3 Create order document with verified items and idempotency key
      final orderData = <String, dynamic>{
        'shop_id': params.shopId,
        'idempotency_key': trimmedKey,
        'customer_name': params.customerName,
        'phone_number': params.customerPhone,
        if (params.customerUid != null) 'customer_uid': params.customerUid,
        'delivery_address': params.deliveryType == 'Delivery'
            ? params.deliveryAddress
            : null,
        'customer_lat': params.deliveryType == 'Delivery'
            ? params.customerLat
            : null,
        'customer_lng': params.deliveryType == 'Delivery'
            ? params.customerLng
            : null,
        'delivery_type': params.deliveryType,
        'delivery_fee': calculatedDeliveryFee,
        'subtotal': liveSubtotal,
        'discount': serverDiscount,
        if (cleanCouponCode != null && cleanCouponCode.isNotEmpty) ...{
          'coupon_code': cleanCouponCode,
          'coupon_id': verifiedCoupon?.id,
        },
        'total_amount': liveFinalTotal,
        'items': verifiedItemsList,
        'status': 'Pending',
        'delivery_pin': pin,
        'payment_method': params.paymentMethod,
        'payment_status': params.paymentStatus ?? PaymentStatus.unpaid,
        if (params.upiId != null) 'upi_id': params.upiId,
        if (params.upiRefId != null) 'upi_ref_id': params.upiRefId,
        if (params.instructions != null && params.instructions!.isNotEmpty)
          'instructions': params.instructions,
        'created_at': FieldValue.serverTimestamp(),
        if (params.extraData != null) ...params.extraData!,
      };

      transaction.set(orderRef, orderData);

      // 2.4 Atomically increment coupon usage and record usage log
      if (couponRef != null && verifiedCoupon != null) {
        transaction.update(couponRef, {
          'used_count': verifiedCoupon.usedCount + 1,
        });

        final usageRef = _firestore
            .collection('coupon_usages')
            .doc('usage_${orderRef.id}_${verifiedCoupon.id}');
        transaction.set(usageRef, {
          'coupon_id': verifiedCoupon.id,
          'coupon_code': verifiedCoupon.code,
          'order_id': orderRef.id,
          'customer_phone': params.customerPhone.replaceAll(RegExp(r'\D'), ''),
          'discount_applied': serverDiscount,
          'used_at': FieldValue.serverTimestamp(),
        });
      }

      return OrderPlacementResult(
        orderId: orderRef.id,
        isDuplicate: false,
        status: 'Pending',
        deliveryPin: pin,
        totalAmount: liveFinalTotal,
        subtotal: liveSubtotal,
        deliveryFee: calculatedDeliveryFee,
        discount: serverDiscount,
        couponCode: cleanCouponCode,
        reservedStocks: reservedStocksMap,
      );
    });

    if (!result.isDuplicate) {
      try {
        await NotificationService.dispatchOrderStatusNotification(
          orderId: result.orderId,
          newStatus: 'Pending',
          customerPhone: params.customerPhone,
          customerUid: params.customerUid,
          shopId: params.shopId,
          orderTotal: result.totalAmount,
          firestore: _firestore,
        );
      } catch (e) {
        // Notification failure should never block or fail order placement
      }

      // Feature 60: Automatically calculate and credit loyalty points and complete qualifying referrals
      try {
        await LoyaltyReferralService(firestore: _firestore).processOrderPointsAndReferrals(
          shopId: params.shopId,
          customerPhone: params.customerPhone,
          customerName: params.customerName,
          orderId: result.orderId,
          orderSubtotal: result.subtotal,
          customerUid: params.customerUid,
        );
      } catch (e) {
        // Loyalty failure should never block or fail order placement
      }
    }

    return result;
  }

  /// Cancels an order atomically and safely restores reserved stock back to the products catalog.
  /// If the order is already cancelled, this operation is safely idempotent (returns false without duplicating stock).
  Future<bool> cancelOrderAtomic({
    required String orderId,
    required String cancelledBy, // 'customer' or 'admin'
    String reason = 'Cancelled',
    bool restoreStock = true,
  }) async {
    final orderRef = _firestore.collection('orders').doc(orderId);

    final didCancel = await _firestore.runTransaction<bool>((
      transaction,
    ) async {
      final orderSnap = await transaction.get(orderRef);
      if (!orderSnap.exists) {
        throw Exception('Order not found');
      }

      final data = orderSnap.data() as Map<String, dynamic>;
      final currentStatus = data['status']?.toString() ?? '';

      // Idempotency: Already cancelled order does not duplicate stock restoration
      if (currentStatus == 'Cancelled') {
        return false;
      }

      // Terminal state protection: Cannot cancel delivered or rejected orders
      if (currentStatus == 'Delivered' || currentStatus == 'Rejected') {
        throw Exception(
          'Cannot cancel order in terminal state: $currentStatus',
        );
      }

      final rawItems = data['items'];
      final List<Map<String, dynamic>> itemsList = [];
      if (rawItems is List) {
        for (var item in rawItems) {
          if (item is Map) {
            itemsList.add(Map<String, dynamic>.from(item));
          }
        }
      }

      // PHASE 1 READS: Read current stocks to increment
      final Map<DocumentReference, double> stockRestores = {};
      if (restoreStock && itemsList.isNotEmpty) {
        for (final item in itemsList) {
          final String? productId =
              item['id']?.toString() ?? item['productId']?.toString();
          if (productId != null) {
            final double qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
            if (qty > 0) {
              final prodRef = _firestore.collection('products').doc(productId);
              final prodSnap = await transaction.get(prodRef);
              if (prodSnap.exists) {
                final currentStock =
                    (prodSnap.data()?['stock_quantity'] as num?)?.toDouble() ??
                    0.0;
                stockRestores[prodRef] = currentStock + qty;
              }
            }
          }
        }
      }

      // PHASE 2 WRITES: Apply restored stock
      if (restoreStock) {
        for (final entry in stockRestores.entries) {
          transaction.update(entry.key, {'stock_quantity': entry.value});
        }
      }

      final currentPaymentStatus = data['payment_status'] as String?;
      final bool wasPaid = currentPaymentStatus == PaymentStatus.paid;
      final double orderTotal =
          (data['total_amount'] as num?)?.toDouble() ?? 0.0;

      final orderUpdates = <String, dynamic>{
        'status': 'Cancelled',
        'cancellation_reason': reason,
        'cancelled_at': FieldValue.serverTimestamp(),
        'cancelled_by': cancelledBy,
      };

      if (wasPaid) {
        orderUpdates['payment_status'] = PaymentStatus.refunded;
        orderUpdates['refund_id'] = PaymentService.generateRefundId();
        orderUpdates['refund_amount'] = orderTotal;
        orderUpdates['refund_reason'] = reason;
        orderUpdates['refunded_at'] = FieldValue.serverTimestamp();
        orderUpdates['refunded_by'] = cancelledBy;
      }

      transaction.update(orderRef, orderUpdates);
      return true;
    });

    if (didCancel) {
      try {
        final orderDoc = await _firestore
            .collection('orders')
            .doc(orderId)
            .get();
        final data = orderDoc.data();
        if (data != null) {
          await NotificationService.dispatchOrderStatusNotification(
            orderId: orderId,
            newStatus: 'Cancelled',
            customerPhone: data['phone_number']?.toString() ?? '',
            customerUid: data['customer_uid']?.toString(),
            shopId: data['shop_id']?.toString() ?? '',
            orderTotal: (data['total_amount'] as num?)?.toDouble(),
            failureReason: reason,
            firestore: _firestore,
          );
        }
      } catch (e) {
        // Notification failure should never affect cancellation success
      }
    }

    return didCancel;
  }
}
