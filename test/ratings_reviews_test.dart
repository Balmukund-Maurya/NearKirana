import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'package:near_kirana/review_model.dart';
import 'package:near_kirana/rating_review_service.dart';
import 'package:near_kirana/widgets/rating_review_dialog.dart';
import 'firebase_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore fakeFirestore;
  late RatingReviewService reviewService;

  setUp(() async {
    setupFirebaseAuthMocks();
    fakeFirestore = FakeFirebaseFirestore();
    FirebaseUtils.setFirestore(fakeFirestore);
    reviewService = RatingReviewService(firestore: fakeFirestore);
  });

  group('Feature 48 - ReviewModel & ProductReviewItem Tests', () {
    test('creates ReviewModel with valid 1-5 ratings and calculated overall rating', () {
      final review = ReviewModel(
        id: 'rev_ord_101',
        orderId: 'ord_101',
        shopId: 'shop_001',
        customerPhone: '9876543210',
        customerName: 'Rahul Kumar',
        shopRating: 4.0,
        deliveryRating: 5.0,
        comment: 'Fresh vegetables and on-time doorstep delivery!',
        isVerifiedPurchase: true,
        createdAt: DateTime.now(),
        productReviews: [
          ProductReviewItem(
            productId: 'prod_1',
            productName: 'Aashirvaad Atta 5kg',
            rating: 5.0,
          ),
          ProductReviewItem(
            productId: 'prod_2',
            productName: 'Fortune Oil 1L',
            rating: 4.0,
          ),
        ],
      );

      expect(review.orderId, 'ord_101');
      expect(review.shopRating, 4.0);
      expect(review.deliveryRating, 5.0);
      expect(review.overallRating, 4.5);
      expect(review.isVerifiedPurchase, isTrue);
      expect(review.productReviews.length, 2);
    });

    test('rejects out-of-range star ratings (< 1 or > 5)', () {
      expect(
        () => ReviewModel(
          id: 'rev_bad',
          orderId: 'ord_1',
          shopId: 'shop_1',
          customerPhone: '9876543210',
          customerName: 'Customer',
          shopRating: 0.0,
          deliveryRating: 5.0,
          createdAt: DateTime.now(),
        ),
        throwsArgumentError,
      );

      expect(
        () => ReviewModel(
          id: 'rev_bad',
          orderId: 'ord_1',
          shopId: 'shop_1',
          customerPhone: '9876543210',
          customerName: 'Customer',
          shopRating: 4.0,
          deliveryRating: 6.0,
          createdAt: DateTime.now(),
        ),
        throwsArgumentError,
      );

      expect(
        () => ProductReviewItem(
          productId: 'prod_1',
          productName: 'Milk',
          rating: 5.5,
        ),
        throwsArgumentError,
      );
    });

    test('serializes to and from Map without data loss', () {
      final now = DateTime(2026, 10, 13, 19, 0);
      final original = ReviewModel(
        id: 'rev_123',
        orderId: 'ord_123',
        shopId: 'shop_abc',
        customerPhone: '9876543210',
        customerName: 'Priya Sharma',
        shopRating: 5.0,
        deliveryRating: 4.0,
        comment: 'Very polite delivery boy.',
        isVerifiedPurchase: true,
        status: 'approved',
        createdAt: now,
        productReviews: [
          ProductReviewItem(
            productId: 'p_10',
            productName: 'Tata Salt 1kg',
            rating: 5.0,
            comment: 'Crisp packing',
          ),
        ],
      );

      final map = original.toMap();
      final reconstituted = ReviewModel.fromMap(map, id: 'rev_123');

      expect(reconstituted.id, 'rev_123');
      expect(reconstituted.orderId, original.orderId);
      expect(reconstituted.shopId, original.shopId);
      expect(reconstituted.customerName, original.customerName);
      expect(reconstituted.shopRating, original.shopRating);
      expect(reconstituted.deliveryRating, original.deliveryRating);
      expect(reconstituted.overallRating, 4.5);
      expect(reconstituted.comment, original.comment);
      expect(reconstituted.moderationStatus, 'approved');
      expect(reconstituted.productReviews.first.productName, 'Tata Salt 1kg');
      expect(reconstituted.productReviews.first.rating, 5.0);
    });
  });

  group('Feature 48 - ReviewModerationEngine Tests', () {
    test('permits legitimate customer review feedback', () {
      const goodReview = 'Bahut badiya packaging thi, items bilkul fresh delivery hue.';
      expect(ReviewModerationEngine.isContentClean(goodReview), isTrue);
      expect(
        () => ReviewModerationEngine.validateForSubmission(goodReview),
        returnsNormally,
      );
    });

    test('blocks spam links and external promo URLs', () {
      final spamComments = [
        'Visit http://cheat-deals.com to win cash prize',
        'Click here: https://t.me/freecoupons for 90% discount',
        'Check out www.mybonus.in right now',
        'Use bit.ly/freestuff to get free groceries',
      ];

      for (final spam in spamComments) {
        expect(ReviewModerationEngine.isContentClean(spam), isFalse);
        expect(
          () => ReviewModerationEngine.validateForSubmission(spam),
          throwsArgumentError,
        );
      }
    });

    test('blocks promotional spam keywords and spam bot offers', () {
      final promoReviews = [
        'Call now for loan and lottery',
        'free cash and win crore now',
        'whatsapp me for instant loan',
      ];

      for (final promo in promoReviews) {
        expect(ReviewModerationEngine.isContentClean(promo), isFalse);
        expect(
          () => ReviewModerationEngine.validateForSubmission(promo),
          throwsArgumentError,
        );
      }
    });

    test('blocks abusive and vulgar language', () {
      final abusiveTexts = [
        'Shopkeeper is a scammer fraud',
        'chutiya service delivery is worst',
      ];

      for (final text in abusiveTexts) {
        expect(ReviewModerationEngine.isContentClean(text), isFalse);
        expect(
          () => ReviewModerationEngine.validateForSubmission(text),
          throwsArgumentError,
        );
      }
    });

    test('sanitizes text by trimming whitespace and capping length', () {
      final excessive = '   Clean review   with   excessive spacing   \n\n\n  ';
      final sanitized = ReviewModerationEngine.sanitizeComment(excessive);
      expect(sanitized, 'Clean review with excessive spacing');

      final overlong = 'A' * 600;
      final capped = ReviewModerationEngine.sanitizeComment(overlong, maxLength: 50);
      expect(capped.length, 50);
    });
  });

  group('Feature 48 - RatingReviewService Verified Buyer & Deduplication Tests', () {
    test('canReviewOrder returns true only for Delivered and unreviewed orders', () async {
      // 1. Pending order -> cannot review
      await fakeFirestore.collection('orders').doc('ord_pending').set({
        'status': 'Pending',
        'is_reviewed': false,
      });
      expect(await reviewService.canReviewOrder('ord_pending'), isFalse);

      // 2. Out for delivery -> cannot review
      await fakeFirestore.collection('orders').doc('ord_out').set({
        'status': 'Out for Delivery',
        'is_reviewed': false,
      });
      expect(await reviewService.canReviewOrder('ord_out'), isFalse);

      // 3. Cancelled -> cannot review
      await fakeFirestore.collection('orders').doc('ord_cancelled').set({
        'status': 'Cancelled',
        'is_reviewed': false,
      });
      expect(await reviewService.canReviewOrder('ord_cancelled'), isFalse);

      // 4. Delivered but already reviewed -> cannot review
      await fakeFirestore.collection('orders').doc('ord_done_reviewed').set({
        'status': 'Delivered',
        'is_reviewed': true,
      });
      expect(await reviewService.canReviewOrder('ord_done_reviewed'), isFalse);

      // 5. Delivered and unreviewed -> CAN review!
      await fakeFirestore.collection('orders').doc('ord_eligible').set({
        'status': 'Delivered',
        'is_reviewed': false,
      });
      expect(await reviewService.canReviewOrder('ord_eligible'), isTrue);
    });

    test('rejects review submission for non-delivered order', () async {
      await fakeFirestore.collection('orders').doc('ord_in_progress').set({
        'status': 'Packing',
        'is_reviewed': false,
        'shop_id': 'shop_1',
      });

      final review = ReviewModel(
        id: 'rev_ord_in_progress',
        orderId: 'ord_in_progress',
        shopId: 'shop_1',
        customerPhone: '9876543210',
        customerName: 'Customer',
        shopRating: 5.0,
        deliveryRating: 5.0,
        createdAt: DateTime.now(),
      );

      expect(
        () => reviewService.submitReview(review),
        throwsA(isA<StateError>()),
      );
    });

    test('submits review atomically, updates order flag, and prevents duplicate reviews', () async {
      // Seed shop and product
      await fakeFirestore.collection('shops').doc('shop_xyz').set({
        'rating_count': 2,
        'total_rating_points': 8.0,
        'average_rating': 4.0,
      });

      await fakeFirestore.collection('products').doc('prod_rice').set({
        'rating_count': 1,
        'total_rating_points': 4.0,
        'average_rating': 4.0,
      });

      // Seed delivered order
      await fakeFirestore.collection('orders').doc('ord_delivered_1').set({
        'status': 'Delivered',
        'is_reviewed': false,
        'shop_id': 'shop_xyz',
      });

      final review = ReviewModel(
        id: 'rev_ord_delivered_1',
        orderId: 'ord_delivered_1',
        shopId: 'shop_xyz',
        customerPhone: '9876543210',
        customerName: 'Aman Verma',
        shopRating: 5.0,
        deliveryRating: 5.0,
        comment: 'Super fast delivery and fresh rice packet!',
        createdAt: DateTime.now(),
        productReviews: [
          ProductReviewItem(
            productId: 'prod_rice',
            productName: 'Basmati Rice 5kg',
            rating: 5.0,
          ),
        ],
      );

      // Submit review
      await reviewService.submitReview(review);

      // Verify order doc was updated with review state
      final orderSnap = await fakeFirestore.collection('orders').doc('ord_delivered_1').get();
      expect(orderSnap.data()!['is_reviewed'], isTrue);
      expect(orderSnap.data()!['shop_rating'], 5.0);
      expect(orderSnap.data()!['delivery_rating'], 5.0);
      expect(orderSnap.data()!['review_comment'], contains('Super fast delivery'));

      // Verify review doc was written to reviews collection
      final reviewDoc = await fakeFirestore.collection('reviews').doc('rev_ord_delivered_1').get();
      expect(reviewDoc.exists, isTrue);
      expect(reviewDoc.data()!['is_verified_purchase'], isTrue);
      expect(reviewDoc.data()!['customer_name'], 'Aman Verma');

      // Verify shop aggregated rating: (8.0 + 5.0) / 3 = 13.0 / 3 = 4.3
      final shopSnap = await fakeFirestore.collection('shops').doc('shop_xyz').get();
      expect(shopSnap.data()!['rating_count'], 3);
      expect(shopSnap.data()!['total_rating_points'], 13.0);
      expect(shopSnap.data()!['average_rating'], 4.3);

      // Verify product aggregated rating: (4.0 + 5.0) / 2 = 9.0 / 2 = 4.5
      final productSnap = await fakeFirestore.collection('products').doc('prod_rice').get();
      expect(productSnap.data()!['rating_count'], 2);
      expect(productSnap.data()!['total_rating_points'], 9.0);
      expect(productSnap.data()!['average_rating'], 4.5);

      // DEDUPLICATION TEST: Attempting to review the same order a 2nd time must fail!
      expect(
        () => reviewService.submitReview(review),
        throwsA(isA<StateError>()),
      );
    });

    test('getOrderReview retrieves submitted review correctly', () async {
      await fakeFirestore.collection('orders').doc('ord_fetch').set({
        'status': 'Delivered',
        'is_reviewed': false,
        'shop_id': 'shop_f',
      });

      final review = ReviewModel(
        id: 'rev_ord_fetch',
        orderId: 'ord_fetch',
        shopId: 'shop_f',
        customerPhone: '9999999999',
        customerName: 'Customer',
        shopRating: 4.0,
        deliveryRating: 4.0,
        comment: 'Good overall',
        createdAt: DateTime.now(),
      );

      await reviewService.submitReview(review);

      final fetched = await reviewService.getOrderReview('ord_fetch');
      expect(fetched, isNotNull);
      expect(fetched!.orderId, 'ord_fetch');
      expect(fetched.comment, 'Good overall');
      expect(fetched.shopRating, 4.0);
    });
  });

  group('Feature 48 - UI Widgets Tests', () {
    testWidgets('StarRatingSelector allows interactive star selection', (tester) async {
      double selectedRating = 3.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return StarRatingSelector(
                  rating: selectedRating,
                  onRatingChanged: (val) {
                    setState(() {
                      selectedRating = val;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.byType(IconButton), findsNWidgets(5));
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
      expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(2));

      // Tap 5th star
      await tester.tap(find.byType(IconButton).last);
      await tester.pumpAndSettle();

      expect(selectedRating, 5.0);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(5));
    });

    testWidgets('RatingDisplayPill renders rating and label correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RatingDisplayPill(
              rating: 4.8,
              label: 'Verified Purchase',
            ),
          ),
        ),
      );

      expect(find.text('4.8 / 5'), findsOneWidget);
      expect(find.text('• Verified Purchase'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });

    testWidgets('OrderReviewPromptBanner shows actionable prompt', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OrderReviewPromptBanner(
              orderId: 'ord_test_prompt',
              shopId: 'shop_test',
              items: [
                {'id': 'p1', 'name': 'Milk', 'price': 30, 'quantity': 1}
              ],
            ),
          ),
        ),
      );

      expect(find.text('How was your order experience?'), findsOneWidget);
      expect(find.text('Rate your delivery and store to help other buyers.'), findsOneWidget);
      expect(find.text('Rate Order'), findsOneWidget);

      // Tapping 'Rate Order' opens RatingReviewDialog
      await tester.tap(find.text('Rate Order'));
      await tester.pumpAndSettle();

      expect(find.byType(RatingReviewDialog), findsOneWidget);
      expect(find.text('Rate & Review Order'), findsOneWidget);
      expect(find.text('Verified Purchase Review'), findsOneWidget);
      expect(find.text('Store & Item Quality'), findsOneWidget);
      expect(find.text('Delivery Speed & Experience'), findsOneWidget);
      expect(find.text('Submit Review'), findsOneWidget);
    });
  });
}
