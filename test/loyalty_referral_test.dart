import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_kirana/l10n/app_localizations.dart';
import 'package:near_kirana/loyalty_referral_models.dart';
import 'package:near_kirana/loyalty_referral_service.dart';
import 'package:near_kirana/customer_loyalty_screen.dart';
import 'package:near_kirana/widgets/loyalty_redemption_card.dart';
import 'package:near_kirana/admin_loyalty_screen.dart';

void main() {
  group('Feature 60: Domain Models - Loyalty & Referrals', () {
    test('LoyaltyTier calculations, thresholds and multipliers', () {
      expect(LoyaltyTier.fromPoints(0), LoyaltyTier.bronze);
      expect(LoyaltyTier.fromPoints(199), LoyaltyTier.bronze);
      expect(LoyaltyTier.fromPoints(200), LoyaltyTier.silver);
      expect(LoyaltyTier.fromPoints(599), LoyaltyTier.silver);
      expect(LoyaltyTier.fromPoints(600), LoyaltyTier.gold);
      expect(LoyaltyTier.fromPoints(1499), LoyaltyTier.gold);
      expect(LoyaltyTier.fromPoints(1500), LoyaltyTier.platinum);

      expect(LoyaltyTier.bronze.pointsMultiplier, 1.0);
      expect(LoyaltyTier.silver.pointsMultiplier, 1.25);
      expect(LoyaltyTier.gold.pointsMultiplier, 1.5);
      expect(LoyaltyTier.platinum.pointsMultiplier, 2.0);

      expect(LoyaltyTier.fromString('silver'), LoyaltyTier.silver);
      expect(LoyaltyTier.fromString('gold'), LoyaltyTier.gold);
      expect(LoyaltyTier.fromString('platinum'), LoyaltyTier.platinum);
      expect(LoyaltyTier.fromString('unknown'), LoyaltyTier.bronze);
    });

    test('CustomerLoyaltyAccount savings and tier progression', () {
      final account = CustomerLoyaltyAccount(
        id: 'shop1_9876543210',
        shopId: 'shop1',
        customerPhone: '9876543210',
        customerName: 'Aarav Sharma',
        currentPoints: 150,
        lifetimeEarnedPoints: 150,
        lifetimeRedeemedPoints: 0,
        referralCode: 'AAR8912',
        tier: LoyaltyTier.bronze,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      // 150 points * 0.10 = ₹15 savings
      expect(account.rupeeValue(0.10), 15.0);
      expect(account.nextTier, LoyaltyTier.silver);
      // Silver requires 200, so 50 points needed
      expect(account.pointsNeededForNextTier, 50);
      expect(account.progressToNextTier, 150 / 200.0);

      final map = account.toMap();
      expect(map['customer_phone'], '9876543210');
      expect(map['current_points'], 150);
      expect(map['referral_code'], 'AAR8912');

      final reconstructed = CustomerLoyaltyAccount.fromMap(map, account.id);
      expect(reconstructed.customerPhone, account.customerPhone);
      expect(reconstructed.currentPoints, 150);
      expect(reconstructed.tier, LoyaltyTier.bronze);
    });

    test('LoyaltyProgramConfig calculates earned points and max redemption limits', () {
      const config = LoyaltyProgramConfig(
        shopId: 'shop1',
        isEnabled: true,
        pointsPerHundredRupees: 10, // 1 pt per ₹10
        pointValueInRupees: 0.10, // 100 pts = ₹10
        minPointsToRedeem: 50,
        maxRedemptionPercentage: 0.30, // max 30% discount
        minQualifyingOrderForPoints: 50.0,
      );

      // Order ₹400 with 1.0x Bronze multiplier => 40 points
      expect(config.calculateEarnedPoints(400.0, tierMultiplier: 1.0), 40);

      // Order ₹400 with 1.5x Gold multiplier => 60 points
      expect(config.calculateEarnedPoints(400.0, tierMultiplier: 1.5), 60);

      // Order ₹30 below min qualifying order ₹50 => 0 points
      expect(config.calculateEarnedPoints(30.0), 0);

      // Max redeemable: Subtotal ₹500, max 30% = ₹150 discount = 1500 points
      // Customer has 200 points available => can redeem all 200
      expect(config.calculateMaxRedeemablePoints(500.0, 200), 200);

      // Subtotal ₹100, max 30% = ₹30 discount = 300 points
      // Customer has 500 points available => capped at 300 points
      expect(config.calculateMaxRedeemablePoints(100.0, 500), 300);

      // Subtotal ₹500, customer has only 40 points (< 50 min points required) => 0
      expect(config.calculateMaxRedeemablePoints(500.0, 40), 0);
    });
  });

  group('Feature 60: LoyaltyReferralService Backend Operations', () {
    late FakeFirebaseFirestore fakeFirestore;
    late LoyaltyReferralService service;
    const testShopId = 'test_shop_123';

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = LoyaltyReferralService(firestore: fakeFirestore);
    });

    test('getOrCreateAccount initializes account with referral code and welcome points', () async {
      final account = await service.getOrCreateAccount(
        shopId: testShopId,
        customerPhone: '9888877777',
        customerName: 'Pooja Verma',
      );

      expect(account.customerPhone, '9888877777');
      expect(account.customerName, 'Pooja Verma');
      expect(account.referralCode.isNotEmpty, true);
      expect(account.currentPoints, 20); // Default welcome points

      // Check stored document
      final snap = await fakeFirestore.collection('loyalty_accounts').doc(account.id).get();
      expect(snap.exists, true);
      expect(snap.data()?['referral_code'], account.referralCode);

      // Verify welcome transaction ledger was written
      final txQuery = await fakeFirestore.collection('loyalty_transactions').get();
      expect(txQuery.docs.length, 1);
      expect(txQuery.docs.first.data()['type'], 'welcome_bonus');
      expect(txQuery.docs.first.data()['points'], 20);
    });

    test('applyReferralCode validates code, prevents self-referral, and creates pending referral', () async {
      // 1. Create Referrer
      final referrer = await service.getOrCreateAccount(
        shopId: testShopId,
        customerPhone: '9111111111',
        customerName: 'Rahul Mehra',
      );

      // 2. Self referral attempt
      final selfRes = await service.applyReferralCode(
        shopId: testShopId,
        refereePhone: '9111111111',
        refereeName: 'Rahul',
        referralCode: referrer.referralCode,
      );
      expect(selfRes.success, false);
      expect(selfRes.message.contains('स्वयं'), true);

      // 3. Invalid code attempt
      final invalidRes = await service.applyReferralCode(
        shopId: testShopId,
        refereePhone: '9222222222',
        refereeName: 'Suresh Friend',
        referralCode: 'FAKE9999',
      );
      expect(invalidRes.success, false);

      // 4. Valid referral application
      final validRes = await service.applyReferralCode(
        shopId: testShopId,
        refereePhone: '9222222222',
        refereeName: 'Suresh Friend',
        referralCode: referrer.referralCode,
      );
      expect(validRes.success, true);
      expect(validRes.referral?.status, ReferralStatus.pending);

      // 5. Duplicate referral rejection
      final dupRes = await service.applyReferralCode(
        shopId: testShopId,
        refereePhone: '9222222222',
        refereeName: 'Suresh Friend',
        referralCode: referrer.referralCode,
      );
      expect(dupRes.success, false);
      expect(dupRes.message.contains('पहले ही'), true);
    });

    test('Full End-to-End: Qualifying purchase awards points and completes referral', () async {
      // Step A: Referrer creates account
      final referrer = await service.getOrCreateAccount(
        shopId: testShopId,
        customerPhone: '9333333333',
        customerName: 'Deepak Boss',
      );
      final initialReferrerPoints = referrer.currentPoints; // 20

      // Step B: Friend applies referral code
      final applyResult = await service.applyReferralCode(
        shopId: testShopId,
        refereePhone: '9444444444',
        refereeName: 'Anil Friend',
        referralCode: referrer.referralCode,
      );
      expect(applyResult.success, true);

      // Step C: Friend places non-qualifying small order (₹40 < min qualifying ₹100)
      final smallOrderRes = await service.processOrderPointsAndReferrals(
        shopId: testShopId,
        customerPhone: '9444444444',
        customerName: 'Anil Friend',
        orderId: 'ORD_SMALL',
        orderSubtotal: 40.0,
      );
      expect(smallOrderRes.referralCompleted, false);

      // Step D: Friend places qualifying order of ₹350 (>= ₹100)
      final qualifyingRes = await service.processOrderPointsAndReferrals(
        shopId: testShopId,
        customerPhone: '9444444444',
        customerName: 'Anil Friend',
        orderId: 'ORD_BIG',
        orderSubtotal: 350.0,
      );
      expect(qualifyingRes.referralCompleted, true);
      // ₹350 / 100 * 10 pts = 35 purchase points
      expect(qualifyingRes.earnedPoints, 35);

      // Step E: Verify Referrer received 100 bonus points
      final updatedReferrer = await service.getOrCreateAccount(
        shopId: testShopId,
        customerPhone: '9333333333',
        customerName: 'Deepak Boss',
      );
      expect(updatedReferrer.currentPoints, initialReferrerPoints + 100);

      // Step F: Verify Friend received purchase points (35) + referee bonus (50) + welcome (20) = 105
      final updatedFriend = await service.getOrCreateAccount(
        shopId: testShopId,
        customerPhone: '9444444444',
        customerName: 'Anil Friend',
      );
      expect(updatedFriend.currentPoints, 20 + 35 + 50);

      // Step G: Verify referral document is now marked 'completed'
      final refSnap = await fakeFirestore
          .collection('referrals')
          .where('referee_phone', isEqualTo: '9444444444')
          .get();
      expect(refSnap.docs.first.data()['status'], 'completed');
      expect(refSnap.docs.first.data()['qualifying_order_id'], 'ORD_BIG');
      expect(refSnap.docs.first.data()['referrer_points_awarded'], 100);
      expect(refSnap.docs.first.data()['referee_points_awarded'], 50);
    });

    test('redeemPoints debits points and enforces minimums & caps', () async {
      // Create customer with 200 points
      await service.getOrCreateAccount(
        shopId: testShopId,
        customerPhone: '9555555555',
        customerName: 'Kavita Singh',
      );
      await service.adminAdjustPoints(
        shopId: testShopId,
        customerPhone: '9555555555',
        pointsDelta: 180, // 20 welcome + 180 = 200 points
        reason: 'Bonus',
      );

      // 1. Attempt redeeming below minPointsToRedeem (40 < 50)
      final tooLow = await service.redeemPoints(
        shopId: testShopId,
        customerPhone: '9555555555',
        pointsToRedeem: 40,
        orderSubtotal: 500.0,
      );
      expect(tooLow.success, false);
      expect(tooLow.message.contains('न्यूनतम'), true);

      // 2. Successful redemption: 100 points on ₹500 order => ₹10 discount
      final successRedeem = await service.redeemPoints(
        shopId: testShopId,
        customerPhone: '9555555555',
        pointsToRedeem: 100,
        orderSubtotal: 500.0,
        orderId: 'ORD_101',
      );
      expect(successRedeem.success, true);
      expect(successRedeem.discountRupees, 10.0);

      // 3. Verify balance debited to 100 points
      final acc = await service.getOrCreateAccount(
        shopId: testShopId,
        customerPhone: '9555555555',
        customerName: 'Kavita Singh',
      );
      expect(acc.currentPoints, 100);
      expect(acc.lifetimeRedeemedPoints, 100);

      // 4. Verify transaction recorded as negative debit
      final txQuery = await fakeFirestore
          .collection('loyalty_transactions')
          .where('order_id', isEqualTo: 'ORD_101')
          .get();
      expect(txQuery.docs.length, 1);
      expect(txQuery.docs.first.data()['points'], -100);
      expect(txQuery.docs.first.data()['type'], 'redeemed_purchase');
    });

    test('getShopAnalytics aggregates metrics across accounts and referrals', () async {
      await service.getOrCreateAccount(
        shopId: testShopId,
        customerPhone: '9666666666',
        customerName: 'User A',
      );
      await service.getOrCreateAccount(
        shopId: testShopId,
        customerPhone: '9777777777',
        customerName: 'User B',
      );

      final analytics = await service.getShopAnalytics(testShopId);
      expect(analytics.totalAccounts, 2);
      expect(analytics.totalPointsIssued, 40); // 20 welcome each
      expect(analytics.totalPointsRedeemed, 0);
    });
  });

  group('Feature 60: UI Widgets - Loyalty Screens & Cards', () {
    late FakeFirebaseFirestore fakeFirestore;
    late LoyaltyReferralService service;
    const testShopId = 'ui_test_shop';

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = LoyaltyReferralService(firestore: fakeFirestore);
    });

    testWidgets('CustomerLoyaltyScreen renders hero card, referral code and tabs', (tester) async {
      // Pre-populate account
      await fakeFirestore.collection('loyalty_accounts').doc('${testShopId}_9888811111').set({
        'shop_id': testShopId,
        'customer_phone': '9888811111',
        'customer_name': 'Meera Jain',
        'current_points': 240,
        'lifetime_earned_points': 240,
        'lifetime_redeemed_points': 0,
        'referral_code': 'MEE7744',
        'tier': 'silver',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: CustomerLoyaltyScreen(
            shopId: testShopId,
            customerPhone: '9888811111',
            customerName: 'Meera Jain',
            service: service,
            enableAnimations: false,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Hero Card verifies points balance & tier
      expect(find.text('240'), findsOneWidget);
      expect(find.textContaining('Silver'), findsWidgets);
      expect(find.text('₹24.0'), findsOneWidget); // 240 * 0.10

      // Referral tab verifies code and buttons (clean English, no dual language brackets)
      expect(find.text('MEE7744'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Share on WhatsApp'), findsOneWidget);

      // Switch to Passbook Tab
      await tester.tap(find.text('Passbook'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No Points History'), findsOneWidget);
    });

    testWidgets('LoyaltyRedemptionCard renders points toggle and computes savings', (tester) async {
      await fakeFirestore.collection('loyalty_accounts').doc('${testShopId}_9999900000').set({
        'shop_id': testShopId,
        'customer_phone': '9999900000',
        'customer_name': 'Vikram Rathore',
        'current_points': 100,
        'lifetime_earned_points': 100,
        'lifetime_redeemed_points': 0,
        'referral_code': 'VIK1234',
        'tier': 'bronze',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      ({int points, double discountRupees})? selectedRedemption;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: LoyaltyRedemptionCard(
              shopId: testShopId,
              customerPhone: '9999900000',
              customerName: 'Vikram Rathore',
              subtotal: 400.0,
              service: service,
              onRedemptionChanged: (res) {
                selectedRedemption = res;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Loyalty Rewards'), findsOneWidget);
      expect(find.textContaining('Available: 100 pts'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);

      // Toggle switch to redeem points
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(selectedRedemption, isNotNull);
      expect(selectedRedemption?.points, 100);
      expect(selectedRedemption?.discountRupees, 10.0);
      expect(find.text('100 points redeemed'), findsOneWidget);
      expect(find.text('-₹10.0 off'), findsOneWidget);
    });

    testWidgets('AdminLoyaltyScreen renders KPI metrics, customer passbooks, and settings', (tester) async {
      // Seed a customer account
      await fakeFirestore.collection('loyalty_accounts').doc('${testShopId}_9112233445').set({
        'shop_id': testShopId,
        'customer_phone': '9112233445',
        'customer_name': 'Kishore Kumar',
        'current_points': 300,
        'lifetime_earned_points': 300,
        'lifetime_redeemed_points': 0,
        'referral_code': 'KIS5511',
        'tier': 'silver',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: AdminLoyaltyScreen(
            shopId: testShopId,
            service: service,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header and KPI checks (clean English)
      expect(find.text('Loyalty & Referrals'), findsOneWidget);
      expect(find.text('Total Issued'), findsOneWidget);
      expect(find.text('Total Redeemed'), findsOneWidget);

      // Customer listed in Customer Passbooks tab
      expect(find.text('Kishore Kumar'), findsOneWidget);
      expect(find.text('300 pts'), findsOneWidget);
      expect(find.text('Modify'), findsOneWidget);

      // Switch to Settings tab
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Enable Loyalty Program'), findsOneWidget);
      expect(find.text('Enable Refer & Earn Program'), findsOneWidget);
      expect(find.text('Save Settings'), findsOneWidget);
    });

    testWidgets('CustomerLoyaltyScreen renders clean Hindi without dual-language parentheses', (tester) async {
      await fakeFirestore.collection('loyalty_accounts').doc('${testShopId}_9888822222').set({
        'shop_id': testShopId,
        'customer_phone': '9888822222',
        'customer_name': 'पूजा वर्मा',
        'current_points': 150,
        'lifetime_earned_points': 150,
        'lifetime_redeemed_points': 0,
        'referral_code': 'POO1234',
        'tier': 'bronze',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('hi'),
          home: CustomerLoyaltyScreen(
            shopId: testShopId,
            customerPhone: '9888822222',
            customerName: 'पूजा वर्मा',
            service: service,
            enableAnimations: false,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ensure no dual language parentheses on buttons/tabs
      expect(find.text('कॉपी (Copy)'), findsNothing);
      expect(find.text('व्हाट्सएप पर शेयर करें (Share on WhatsApp)'), findsNothing);
      expect(find.text('अंक पासबुक (Passbook)'), findsNothing);

      // Verify clean single language Hindi
      expect(find.text('कॉपी करें'), findsOneWidget);
      expect(find.text('व्हाट्सएप पर शेयर करें'), findsOneWidget);
      expect(find.text('पासबुक'), findsOneWidget);
      expect(find.text('कांस्य'), findsWidgets); // Clean Bronze in Hindi without (कांस्य)
    });
  });
}
