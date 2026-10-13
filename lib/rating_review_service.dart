import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_utils.dart';
import 'review_model.dart';

/// Content moderation utility to sanitize review text and detect spam, profanity, and abusive content.
class ReviewModerationEngine {
  // Common abusive, offensive, and harassment keywords (English & Roman Hindi)
  static final List<String> _blockedKeywords = [
    'chutiya',
    'bhosdike',
    'madarchod',
    'behenchod',
    'harami',
    'gandu',
    'kamina',
    'fuck',
    'bitch',
    'bastard',
    'asshole',
    'scammer fraud',
    'kill you',
    'die in hell',
    'terrorist',
  ];

  // Spam detection regexes (links, telegram/whatsapp promotions, spam bots)
  static final RegExp _urlRegex = RegExp(
    r'(https?:\/\/|www\.|bit\.ly\/|tinyurl\.com\/|t\.me\/|[a-zA-Z0-9-]+\.(com|in|org|net|co|io|me)\b)',
    caseSensitive: false,
  );

  static final RegExp _spamPromoRegex = RegExp(
    r'(free\s+cash|free\s+money|lottery|win\s+crore|telegram\s*:@?|whatsapp\s+me|call\s+now\s+for\s+loan)',
    caseSensitive: false,
  );

  /// Analyzes text for abusive or spam patterns.
  /// Returns a result containing whether the content is acceptable and any flagged reason.
  static ModerationResult inspect(String text) {
    final lower = text.toLowerCase().trim();

    // Check for spam URLs
    if (_urlRegex.hasMatch(lower)) {
      return const ModerationResult(
        isClean: false,
        reason: 'Links and URLs are not permitted in reviews.',
      );
    }

    // Check for spam promotions
    if (_spamPromoRegex.hasMatch(lower)) {
      return const ModerationResult(
        isClean: false,
        reason: 'Spam, promotional, or unauthorized advertising content detected.',
      );
    }

    // Check for abusive keywords
    for (final word in _blockedKeywords) {
      if (lower.contains(word)) {
        return const ModerationResult(
          isClean: false,
          reason: 'Review contains abusive, profane, or inappropriate language.',
        );
      }
    }

    return const ModerationResult(isClean: true);
  }

  /// Convenience check whether comment passes moderation
  static bool isContentClean(String text) => inspect(text).isClean;

  /// Throws ArgumentError with moderation failure explanation if text is not clean
  static void validateForSubmission(String text) {
    final result = inspect(text);
    if (!result.isClean) {
      throw ArgumentError(result.reason ?? 'Inappropriate content in review');
    }
  }

  /// Sanitizes text comment: collapses excess whitespace and trims to max length
  static String sanitizeComment(String text, {int maxLength = 500}) {
    var cleaned = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.length > maxLength) {
      cleaned = cleaned.substring(0, maxLength);
    }
    return cleaned;
  }
}

class ModerationResult {
  final bool isClean;
  final String? reason;

  const ModerationResult({required this.isClean, this.reason});
}

/// Service managing verified ratings and reviews for orders, shops, and products.
/// Enforces:
/// 1. Verified Customer Invariant: Only delivered orders can be reviewed.
/// 2. Deduplication: Exactly 1 review per order.
/// 3. Rating Range Validation: Ratings must be between 1.0 and 5.0.
/// 4. Automated Moderation: Filters spam, abusive content, and unauthorized links.
/// 5. Atomic Aggregation: Updates shop and product average ratings and review counts.
class RatingReviewService {
  final FirebaseFirestore _firestore;

  RatingReviewService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseUtils.firestore;

  static final RatingReviewService instance = RatingReviewService();

  /// Checks if an order is eligible for review by a customer.
  Future<bool> canReviewOrder(String orderId) async {
    try {
      final doc = await _firestore.collection('orders').doc(orderId).get();
      if (!doc.exists) return false;
      final data = doc.data()!;
      final status = data['status']?.toString();
      final isReviewed = data['is_reviewed'] == true;

      return status == 'Delivered' && !isReviewed;
    } catch (_) {
      return false;
    }
  }

  /// Submits an order review with shop rating, delivery rating, and optional product ratings.
  /// Runs inside an atomic Firestore transaction to prevent duplicate reviews and update aggregates.
  Future<ReviewModel> submitOrderReview({
    String? orderId,
    double? shopRating,
    double? deliveryRating,
    String? comment,
    List<ProductReviewItem> productReviews = const [],
    String? customerName,
    String? customerPhone,
    String? customerUid,
    ReviewModel? review,
  }) async {
    final effectiveOrderId = review?.orderId ?? orderId;
    final effectiveShopRating = review?.shopRating ?? shopRating;
    final effectiveDeliveryRating = review?.deliveryRating ?? deliveryRating;
    final effectiveComment = ReviewModerationEngine.sanitizeComment(
      review?.comment ?? comment ?? '',
    );
    final effectiveProductReviews = review?.productReviews ?? productReviews;
    final effectiveCustomerName = review?.customerName ?? customerName;
    final effectiveCustomerPhone = review?.customerPhone ?? customerPhone;
    final effectiveCustomerUid = review?.customerUid ?? customerUid;

    if (effectiveOrderId == null || effectiveOrderId.isEmpty) {
      throw ArgumentError('Order ID cannot be empty');
    }
    if (effectiveShopRating == null || effectiveDeliveryRating == null) {
      throw ArgumentError('Shop rating and delivery rating are required');
    }

    // 1. Validate rating values
    if (effectiveShopRating < 1.0 || effectiveShopRating > 5.0) {
      throw ArgumentError('Shop rating must be between 1 and 5 stars');
    }
    if (effectiveDeliveryRating < 1.0 || effectiveDeliveryRating > 5.0) {
      throw ArgumentError('Delivery rating must be between 1 and 5 stars');
    }
    for (final pr in effectiveProductReviews) {
      if (pr.rating < 1.0 || pr.rating > 5.0) {
        throw ArgumentError('Product rating must be between 1 and 5 stars');
      }
    }

    // 2. Validate content length
    if (effectiveComment.length > 500) {
      throw ArgumentError('Review comment cannot exceed 500 characters');
    }

    // 3. Content moderation check
    if (effectiveComment.isNotEmpty) {
      ReviewModerationEngine.validateForSubmission(effectiveComment);
    }

    final orderRef = _firestore.collection('orders').doc(effectiveOrderId);
    final reviewRef = _firestore.collection('reviews').doc('rev_$effectiveOrderId');
    final now = DateTime.now();

    return await _firestore.runTransaction((transaction) async {
      // Step A: Read order document
      final orderSnap = await transaction.get(orderRef);
      if (!orderSnap.exists) {
        throw StateError('Order $orderId does not exist');
      }

      final orderData = orderSnap.data() as Map<String, dynamic>;
      final status = orderData['status']?.toString();
      final isReviewed = orderData['is_reviewed'] == true;

      // Invariant: Must be Delivered
      if (status != 'Delivered') {
        throw StateError('Only completed and delivered orders can be reviewed (Current status: $status)');
      }

      // Invariant: Deduplication check
      if (isReviewed) {
        throw StateError('This order has already been reviewed');
      }

      final shopId = orderData['shop_id']?.toString() ?? '';
      final phone = effectiveCustomerPhone ?? orderData['phone_number']?.toString() ?? '';
      final name = effectiveCustomerName ?? orderData['customer_name']?.toString() ?? 'Verified Customer';
      final uid = effectiveCustomerUid ?? orderData['customer_uid']?.toString();

      // Step B: Read existing shop document to update rating aggregates
      DocumentReference? shopRef;
      DocumentSnapshot? shopSnap;
      if (shopId.isNotEmpty) {
        shopRef = _firestore.collection('shops').doc(shopId);
        shopSnap = await transaction.get(shopRef);
      }

      // Step C: Read all product documents BEFORE any writes (Firestore invariant)
      final Map<DocumentReference, DocumentSnapshot> prodSnaps = {};
      for (final pr in effectiveProductReviews) {
        if (pr.productId.isNotEmpty) {
          final prodRef = _firestore.collection('products').doc(pr.productId);
          final pSnap = await transaction.get(prodRef);
          if (pSnap.exists) {
            prodSnaps[prodRef] = pSnap;
          }
        }
      }

      // Step D: Build ReviewModel
      final reviewModel = ReviewModel(
        id: reviewRef.id,
        orderId: effectiveOrderId,
        shopId: shopId,
        customerPhone: phone,
        customerName: name,
        customerUid: uid,
        shopRating: effectiveShopRating,
        deliveryRating: effectiveDeliveryRating,
        comment: effectiveComment,
        productReviews: effectiveProductReviews,
        isVerifiedPurchase: true,
        status: 'approved',
        createdAt: now,
      );

      // Step E: Write review document
      transaction.set(reviewRef, reviewModel.toMap());

      // Step F: Update order document
      transaction.update(orderRef, {
        'is_reviewed': true,
        'review_id': reviewRef.id,
        'shop_rating': effectiveShopRating,
        'delivery_rating': effectiveDeliveryRating,
        if (effectiveComment.isNotEmpty) 'review_comment': effectiveComment,
        'reviewed_at': Timestamp.fromDate(now),
      });

      // Step G: Atomically update shop rating aggregates
      if (shopRef != null && shopSnap != null && shopSnap.exists) {
        final shopData = shopSnap.data() as Map<String, dynamic>;
        final currentCount = (shopData['rating_count'] as num?)?.toInt() ?? 0;
        final currentTotalPoints = (shopData['total_rating_points'] as num?)?.toDouble() ??
            ((shopData['average_rating'] as num?)?.toDouble() ?? 5.0) * currentCount;

        final newCount = currentCount + 1;
        final newTotalPoints = currentTotalPoints + effectiveShopRating;
        final newAverage = (newTotalPoints / newCount).clamp(1.0, 5.0);

        transaction.update(shopRef, {
          'rating_count': newCount,
          'total_rating_points': newTotalPoints,
          'average_rating': double.parse(newAverage.toStringAsFixed(1)),
        });
      }

      // Step H: Update individual product ratings
      for (final pr in effectiveProductReviews) {
        if (pr.productId.isNotEmpty) {
          final prodRef = _firestore.collection('products').doc(pr.productId);
          final pSnap = prodSnaps[prodRef];
          if (pSnap != null && pSnap.exists) {
            final prodData = pSnap.data() as Map<String, dynamic>;
            final currentProdCount = (prodData['rating_count'] as num?)?.toInt() ??
                (prodData['review_count'] as num?)?.toInt() ?? 0;
            final currentProdPoints = (prodData['total_rating_points'] as num?)?.toDouble() ??
                ((prodData['average_rating'] as num?)?.toDouble() ??
                 (prodData['rating'] as num?)?.toDouble() ?? 5.0) * currentProdCount;

            final newProdCount = currentProdCount + 1;
            final newProdPoints = currentProdPoints + pr.rating;
            final newProdAvg = (newProdPoints / newProdCount).clamp(1.0, 5.0);

            transaction.update(prodRef, {
              'rating_count': newProdCount,
              'review_count': newProdCount,
              'total_rating_points': newProdPoints,
              'average_rating': double.parse(newProdAvg.toStringAsFixed(1)),
              'rating': double.parse(newProdAvg.toStringAsFixed(1)),
            });
          }
        }
      }

      return reviewModel;
    });
  }

  /// Convenience wrapper to submit a ReviewModel directly
  Future<ReviewModel> submitReview(ReviewModel review) =>
      submitOrderReview(review: review);

  /// Retrieves the review submitted for an order, or null if not yet reviewed.
  Future<ReviewModel?> getOrderReview(String orderId) async {
    try {
      final doc = await _firestore.collection('reviews').doc('rev_$orderId').get();
      if (!doc.exists) return null;
      return ReviewModel.fromMap(doc.data()!);
    } catch (_) {
      return null;
    }
  }

  /// Real-time stream of reviews for a shop.
  Stream<List<ReviewModel>> getShopReviewsStream(String shopId, {int limit = 50}) {
    return _firestore
        .collection('reviews')
        .where('shop_id', isEqualTo: shopId)
        .where('status', isEqualTo: 'approved')
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ReviewModel.fromMap(doc.data()))
            .toList());
  }
}
