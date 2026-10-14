import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'firebase_utils.dart';
import 'loyalty_referral_models.dart';

/// Core backend service managing customer loyalty points, member tiers,
/// transactions ledger, unique referral codes, and purchase-triggered referral rewards.
class LoyaltyReferralService {
  final FirebaseFirestore _firestore;

  LoyaltyReferralService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseUtils.firestore;

  FirebaseFirestore get firestore => _firestore;

  CollectionReference get _configsRef => _firestore.collection('loyalty_configs');
  CollectionReference get _accountsRef => _firestore.collection('loyalty_accounts');
  CollectionReference get _transactionsRef => _firestore.collection('loyalty_transactions');
  CollectionReference get _referralsRef => _firestore.collection('referrals');

  String _cleanPhone(String phone) => phone.replaceAll(RegExp(r'\s+'), '').trim();

  String _accountId(String shopId, String phone) => '${shopId}_${_cleanPhone(phone)}';

  // ==========================================
  // PROGRAM CONFIGURATION
  // ==========================================

  /// Streams or fetches store loyalty configuration
  Stream<LoyaltyProgramConfig> streamProgramConfig(String shopId) {
    return _configsRef.doc(shopId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return LoyaltyProgramConfig(shopId: shopId);
      }
      return LoyaltyProgramConfig.fromMap(doc.data() as Map<String, dynamic>, shopId);
    });
  }

  Future<LoyaltyProgramConfig> getProgramConfig(String shopId) async {
    try {
      final doc = await _configsRef.doc(shopId).get();
      if (!doc.exists || doc.data() == null) {
        return LoyaltyProgramConfig(shopId: shopId);
      }
      return LoyaltyProgramConfig.fromMap(doc.data() as Map<String, dynamic>, shopId);
    } catch (e) {
      debugPrint('[Loyalty] Error fetching config: $e');
      return LoyaltyProgramConfig(shopId: shopId);
    }
  }

  Future<void> updateProgramConfig(LoyaltyProgramConfig config) async {
    await _configsRef.doc(config.shopId).set(config.toMap(), SetOptions(merge: true));
  }

  // ==========================================
  // CUSTOMER LOYALTY ACCOUNTS
  // ==========================================

  /// Generates a human-friendly unique referral code (e.g. KIR8392)
  String _generateReferralCode(String name, String phone) {
    final clean = name.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    final prefix = clean.length >= 3 ? clean.substring(0, 3) : 'KIR';
    final randomDigits = 1000 + Random().nextInt(9000);
    return '$prefix$randomDigits';
  }

  /// Streams customer loyalty account
  Stream<CustomerLoyaltyAccount?> streamAccount(String shopId, String phone) {
    final docId = _accountId(shopId, phone);
    return _accountsRef.doc(docId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return CustomerLoyaltyAccount.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    });
  }

  /// Fetches or initializes a customer loyalty account
  Future<CustomerLoyaltyAccount> getOrCreateAccount({
    required String shopId,
    required String customerPhone,
    required String customerName,
    String? customerUid,
  }) async {
    final cleanPhone = _cleanPhone(customerPhone);
    final docId = _accountId(shopId, cleanPhone);
    final doc = await _accountsRef.doc(docId).get();

    if (doc.exists && doc.data() != null) {
      return CustomerLoyaltyAccount.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }

    // New account setup
    final config = await getProgramConfig(shopId);
    final referralCode = _generateReferralCode(customerName, cleanPhone);
    final now = DateTime.now();
    final welcomePoints = config.isEnabled ? config.welcomeBonusPoints : 0;

    final newAccount = CustomerLoyaltyAccount(
      id: docId,
      shopId: shopId,
      customerPhone: cleanPhone,
      customerUid: customerUid,
      customerName: customerName.isNotEmpty ? customerName : 'Loyal Customer',
      currentPoints: welcomePoints,
      lifetimeEarnedPoints: welcomePoints,
      lifetimeRedeemedPoints: 0,
      referralCode: referralCode,
      tier: LoyaltyTier.fromPoints(welcomePoints),
      createdAt: now,
      updatedAt: now,
    );

    final batch = _firestore.batch();
    batch.set(_accountsRef.doc(docId), newAccount.toMap());

    // Write initial welcome bonus ledger if points granted
    if (welcomePoints > 0) {
      final txDoc = _transactionsRef.doc();
      final tx = LoyaltyTransaction(
        id: txDoc.id,
        shopId: shopId,
        customerPhone: cleanPhone,
        customerUid: customerUid,
        points: welcomePoints,
        type: LoyaltyTransactionType.welcomeBonus,
        description: 'लॉयल्टी प्रोग्राम में शामिल होने पर स्वागत अंक',
        balanceAfter: welcomePoints,
        createdAt: now,
      );
      batch.set(txDoc, tx.toMap());
    }

    await batch.commit();
    return newAccount;
  }

  // ==========================================
  // REFERRAL WORKFLOW & QUALIFYING TRIGGERS
  // ==========================================

  /// Validates and applies a referral code for a new friend (referee)
  Future<({bool success, String message, ReferralRecord? referral})> applyReferralCode({
    required String shopId,
    required String refereePhone,
    required String refereeName,
    required String referralCode,
  }) async {
    final cleanRefereePhone = _cleanPhone(refereePhone);
    final upperCode = referralCode.trim().toUpperCase();

    if (upperCode.isEmpty) {
      return (success: false, message: 'कृपया रेफरल कोड दर्ज करें (Enter code)', referral: null);
    }

    final config = await getProgramConfig(shopId);
    if (!config.referralEnabled) {
      return (success: false, message: 'इस दुकान में रेफरल प्रोग्राम वर्तमान में बंद है', referral: null);
    }

    // Fetch referee account
    final refereeDoc = await _accountsRef.doc(_accountId(shopId, cleanRefereePhone)).get();
    if (refereeDoc.exists && refereeDoc.data() != null) {
      final refData = refereeDoc.data() as Map<String, dynamic>;
      if (refData['referred_by_code'] != null && refData['referred_by_code'].toString().isNotEmpty) {
        return (success: false, message: 'आप पहले ही रेफरल कोड का उपयोग कर चुके हैं', referral: null);
      }
    }

    // Lookup referrer by referral code in the same shop
    final referrerQuery = await _accountsRef
        .where('shop_id', isEqualTo: shopId)
        .where('referral_code', isEqualTo: upperCode)
        .limit(1)
        .get();

    if (referrerQuery.docs.isEmpty) {
      return (success: false, message: 'अमान्य रेफरल कोड (Invalid referral code)', referral: null);
    }

    final referrerData = referrerQuery.docs.first.data() as Map<String, dynamic>;
    final referrerPhone = referrerData['customer_phone']?.toString() ?? '';
    final referrerName = referrerData['customer_name']?.toString() ?? 'Store Member';

    // Anti-fraud check: Prevent self-referral
    if (referrerPhone == cleanRefereePhone) {
      return (success: false, message: 'आप स्वयं का रेफरल कोड इस्तेमाल नहीं कर सकते (Self-referral not allowed)', referral: null);
    }

    // Ensure referee account exists
    await getOrCreateAccount(
      shopId: shopId,
      customerPhone: cleanRefereePhone,
      customerName: refereeName,
    );

    // Create pending referral record
    final referralDoc = _referralsRef.doc();
    final now = DateTime.now();
    final record = ReferralRecord(
      id: referralDoc.id,
      shopId: shopId,
      referralCode: upperCode,
      referrerPhone: referrerPhone,
      referrerName: referrerName,
      refereePhone: cleanRefereePhone,
      refereeName: refereeName,
      status: ReferralStatus.pending,
      referrerPointsAwarded: 0,
      refereePointsAwarded: 0,
      createdAt: now,
    );

    final batch = _firestore.batch();
    batch.set(referralDoc, record.toMap());
    batch.update(_accountsRef.doc(_accountId(shopId, cleanRefereePhone)), {
      'referred_by_code': upperCode,
      'updated_at': now.toIso8601String(),
    });

    await batch.commit();

    return (
      success: true,
      message: 'रेफरल कोड सफलतापूर्वक लागू हुआ! आपकी पहली खरीदारी पर बोनस मिलेगा।',
      referral: record,
    );
  }

  /// Processes points earned on order purchase AND checks for pending referral completion
  Future<({int earnedPoints, bool referralCompleted})> processOrderPointsAndReferrals({
    required String shopId,
    required String customerPhone,
    required String customerName,
    required String orderId,
    required double orderSubtotal,
    String? customerUid,
  }) async {
    final cleanPhone = _cleanPhone(customerPhone);
    final config = await getProgramConfig(shopId);

    if (!config.isEnabled) {
      return (earnedPoints: 0, referralCompleted: false);
    }

    final account = await getOrCreateAccount(
      shopId: shopId,
      customerPhone: cleanPhone,
      customerName: customerName,
      customerUid: customerUid,
    );

    // 1. Calculate purchase points with Tier multiplier
    final earned = config.calculateEarnedPoints(
      orderSubtotal,
      tierMultiplier: account.tier.pointsMultiplier,
    );

    final newLifetimeEarned = account.lifetimeEarnedPoints + earned;
    final newCurrentPoints = account.currentPoints + earned;
    final newTier = LoyaltyTier.fromPoints(newLifetimeEarned);
    final now = DateTime.now();

    final batch = _firestore.batch();

    if (earned > 0) {
      final txDoc = _transactionsRef.doc();
      final tx = LoyaltyTransaction(
        id: txDoc.id,
        shopId: shopId,
        customerPhone: cleanPhone,
        customerUid: customerUid,
        points: earned,
        type: LoyaltyTransactionType.earnedPurchase,
        description: 'ऑर्डर #$orderId पर अर्जित अंक (Tier: ${account.tier.simpleName})',
        orderId: orderId,
        orderAmount: orderSubtotal,
        balanceAfter: newCurrentPoints,
        createdAt: now,
      );
      batch.set(txDoc, tx.toMap());
    }

    bool referralCompleted = false;

    // 2. Check if this customer has a pending referral that can now be completed
    if (config.referralEnabled && orderSubtotal >= config.minQualifyingOrderForReferral) {
      final pendingReferralQuery = await _referralsRef
          .where('shop_id', isEqualTo: shopId)
          .where('referee_phone', isEqualTo: cleanPhone)
          .where('status', isEqualTo: ReferralStatus.pending.name)
          .limit(1)
          .get();

      if (pendingReferralQuery.docs.isNotEmpty) {
        final refDoc = pendingReferralQuery.docs.first;
        final refData = refDoc.data() as Map<String, dynamic>;
        final referrerPhone = refData['referrer_phone']?.toString() ?? '';

        final referrerPoints = config.referrerRewardPoints;
        final refereePoints = config.refereeRewardPoints;

        // Fetch referrer account
        final referrerDocRef = _accountsRef.doc(_accountId(shopId, referrerPhone));
        final referrerDoc = await referrerDocRef.get();

        if (referrerDoc.exists && referrerDoc.data() != null) {
          final rData = referrerDoc.data() as Map<String, dynamic>;
          final rCurrent = (rData['current_points'] as num?)?.toInt() ?? 0;
          final rLifetime = (rData['lifetime_earned_points'] as num?)?.toInt() ?? 0;
          final rNewCurrent = rCurrent + referrerPoints;
          final rNewLifetime = rLifetime + referrerPoints;
          final rNewTier = LoyaltyTier.fromPoints(rNewLifetime);

          batch.update(referrerDocRef, {
            'current_points': rNewCurrent,
            'lifetime_earned_points': rNewLifetime,
            'tier': rNewTier.simpleName.toLowerCase(),
            'updated_at': now.toIso8601String(),
          });

          // Ledger for Referrer
          final refTxDoc = _transactionsRef.doc();
          final refTx = LoyaltyTransaction(
            id: refTxDoc.id,
            shopId: shopId,
            customerPhone: referrerPhone,
            points: referrerPoints,
            type: LoyaltyTransactionType.referralReferrer,
            description: 'रेफरल बोनस: $customerName ने पहला ऑर्डर पूरा किया!',
            orderId: orderId,
            orderAmount: orderSubtotal,
            balanceAfter: rNewCurrent,
            createdAt: now,
          );
          batch.set(refTxDoc, refTx.toMap());
        }

        // Referee bonus points
        final finalRefereeCurrent = newCurrentPoints + refereePoints;
        final finalRefereeLifetime = newLifetimeEarned + refereePoints;
        final finalRefereeTier = LoyaltyTier.fromPoints(finalRefereeLifetime);

        // Update referee account
        batch.update(_accountsRef.doc(account.id), {
          'current_points': finalRefereeCurrent,
          'lifetime_earned_points': finalRefereeLifetime,
          'tier': finalRefereeTier.simpleName.toLowerCase(),
          'updated_at': now.toIso8601String(),
        });

        // Ledger for Referee
        final refereeTxDoc = _transactionsRef.doc();
        final refereeTx = LoyaltyTransaction(
          id: refereeTxDoc.id,
          shopId: shopId,
          customerPhone: cleanPhone,
          customerUid: customerUid,
          points: refereePoints,
          type: LoyaltyTransactionType.referralReferee,
          description: 'स्वागत रेफरल बोनस: पहला सफल ऑर्डर पूरा हुआ!',
          orderId: orderId,
          orderAmount: orderSubtotal,
          balanceAfter: finalRefereeCurrent,
          createdAt: now,
        );
        batch.set(refereeTxDoc, refereeTx.toMap());

        // Update referral record
        batch.update(refDoc.reference, {
          'status': ReferralStatus.completed.name,
          'qualifying_order_id': orderId,
          'qualifying_order_amount': orderSubtotal,
          'referrer_points_awarded': referrerPoints,
          'referee_points_awarded': refereePoints,
          'completed_at': now.toIso8601String(),
        });

        referralCompleted = true;
      } else {
        // Just update account with earned purchase points
        batch.update(_accountsRef.doc(account.id), {
          'current_points': newCurrentPoints,
          'lifetime_earned_points': newLifetimeEarned,
          'tier': newTier.simpleName.toLowerCase(),
          'updated_at': now.toIso8601String(),
        });
      }
    } else {
      batch.update(_accountsRef.doc(account.id), {
        'current_points': newCurrentPoints,
        'lifetime_earned_points': newLifetimeEarned,
        'tier': newTier.simpleName.toLowerCase(),
        'updated_at': now.toIso8601String(),
      });
    }

    await batch.commit();
    return (earnedPoints: earned, referralCompleted: referralCompleted);
  }

  // ==========================================
  // POINTS REDEMPTION
  // ==========================================

  /// Validates and debits points for order checkout discount
  Future<({bool success, String message, double discountRupees})> redeemPoints({
    required String shopId,
    required String customerPhone,
    required int pointsToRedeem,
    required double orderSubtotal,
    String? orderId,
    String? customerUid,
  }) async {
    final cleanPhone = _cleanPhone(customerPhone);
    final config = await getProgramConfig(shopId);

    if (!config.isEnabled) {
      return (success: false, message: 'लॉयल्टी रिडेम्पशन सक्रिय नहीं है', discountRupees: 0.0);
    }

    if (pointsToRedeem < config.minPointsToRedeem) {
      return (
        success: false,
        message: 'न्यूनतम ${config.minPointsToRedeem} अंक आवश्यक हैं (Min points required)',
        discountRupees: 0.0,
      );
    }

    final accountDoc = await _accountsRef.doc(_accountId(shopId, cleanPhone)).get();
    if (!accountDoc.exists || accountDoc.data() == null) {
      return (success: false, message: 'खाता नहीं मिला (Account not found)', discountRupees: 0.0);
    }

    final account = CustomerLoyaltyAccount.fromMap(accountDoc.data() as Map<String, dynamic>, accountDoc.id);

    if (account.currentPoints < pointsToRedeem) {
      return (success: false, message: 'अपर्याप्त अंक (Insufficient points balance)', discountRupees: 0.0);
    }

    // Cap check: discount cannot exceed max allowed percentage of subtotal
    final maxRedeemable = config.calculateMaxRedeemablePoints(orderSubtotal, account.currentPoints);
    if (pointsToRedeem > maxRedeemable) {
      return (
        success: false,
        message: 'इस ऑर्डर पर अधिकतम $maxRedeemable अंक भुनाए जा सकते हैं',
        discountRupees: 0.0,
      );
    }

    final discountRupees = config.pointsToRupees(pointsToRedeem);
    final newBalance = account.currentPoints - pointsToRedeem;
    final newRedeemedLifetime = account.lifetimeRedeemedPoints + pointsToRedeem;
    final now = DateTime.now();

    final batch = _firestore.batch();

    batch.update(_accountsRef.doc(account.id), {
      'current_points': newBalance,
      'lifetime_redeemed_points': newRedeemedLifetime,
      'updated_at': now.toIso8601String(),
    });

    final txDoc = _transactionsRef.doc();
    final tx = LoyaltyTransaction(
      id: txDoc.id,
      shopId: shopId,
      customerPhone: cleanPhone,
      customerUid: customerUid,
      points: -pointsToRedeem, // Negative for debit
      type: LoyaltyTransactionType.redeemedPurchase,
      description: 'ऑर्डर ${orderId != null ? "#$orderId " : ""}पर ₹${discountRupees.toStringAsFixed(1)} छूट हेतु अंक भुनाए गए',
      orderId: orderId,
      orderAmount: orderSubtotal,
      balanceAfter: newBalance,
      createdAt: now,
    );
    batch.set(txDoc, tx.toMap());

    await batch.commit();

    return (
      success: true,
      message: '₹${discountRupees.toStringAsFixed(0)} की छूट लागू हो गई!',
      discountRupees: discountRupees,
    );
  }

  // ==========================================
  // ADMIN STORE MANAGEMENT
  // ==========================================

  /// Manual admin points adjustment with audit reason
  Future<void> adminAdjustPoints({
    required String shopId,
    required String customerPhone,
    required int pointsDelta,
    required String reason,
    String? adminName,
  }) async {
    final cleanPhone = _cleanPhone(customerPhone);
    final accountDoc = await _accountsRef.doc(_accountId(shopId, cleanPhone)).get();
    if (!accountDoc.exists || accountDoc.data() == null) return;

    final account = CustomerLoyaltyAccount.fromMap(accountDoc.data() as Map<String, dynamic>, accountDoc.id);
    final newBalance = (account.currentPoints + pointsDelta).clamp(0, 999999);
    final newLifetime = pointsDelta > 0
        ? account.lifetimeEarnedPoints + pointsDelta
        : account.lifetimeEarnedPoints;
    final newTier = LoyaltyTier.fromPoints(newLifetime);
    final now = DateTime.now();

    final batch = _firestore.batch();
    batch.update(_accountsRef.doc(account.id), {
      'current_points': newBalance,
      'lifetime_earned_points': newLifetime,
      'tier': newTier.simpleName.toLowerCase(),
      'updated_at': now.toIso8601String(),
    });

    final txDoc = _transactionsRef.doc();
    final tx = LoyaltyTransaction(
      id: txDoc.id,
      shopId: shopId,
      customerPhone: cleanPhone,
      points: pointsDelta,
      type: LoyaltyTransactionType.adminAdjustment,
      description: 'दुकानदार द्वारा समायोजन: $reason ${adminName != null ? "($adminName)" : ""}',
      balanceAfter: newBalance,
      createdAt: now,
    );
    batch.set(txDoc, tx.toMap());

    await batch.commit();
  }

  // ==========================================
  // STREAMS & ANALYTICS QUERIES
  // ==========================================

  /// Streams ledger transactions for a customer
  Stream<List<LoyaltyTransaction>> streamCustomerTransactions(String shopId, String customerPhone) {
    final cleanPhone = _cleanPhone(customerPhone);
    return _transactionsRef
        .where('shop_id', isEqualTo: shopId)
        .where('customer_phone', isEqualTo: cleanPhone)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((d) => LoyaltyTransaction.fromMap(d.data() as Map<String, dynamic>, d.id))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Streams friend referrals initiated by a referrer
  Stream<List<ReferralRecord>> streamReferralsByReferrer(String shopId, String referrerPhone) {
    final cleanPhone = _cleanPhone(referrerPhone);
    return _referralsRef
        .where('shop_id', isEqualTo: shopId)
        .where('referrer_phone', isEqualTo: cleanPhone)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((d) => ReferralRecord.fromMap(d.data() as Map<String, dynamic>, d.id))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Streams all shop loyalty accounts for Admin view
  Stream<List<CustomerLoyaltyAccount>> streamShopAccounts(String shopId) {
    return _accountsRef
        .where('shop_id', isEqualTo: shopId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((d) => CustomerLoyaltyAccount.fromMap(d.data() as Map<String, dynamic>, d.id))
              .toList();
          list.sort((a, b) => b.currentPoints.compareTo(a.currentPoints));
          return list;
        });
  }

  /// Streams all shop referrals for Admin audit
  Stream<List<ReferralRecord>> streamShopReferrals(String shopId) {
    return _referralsRef
        .where('shop_id', isEqualTo: shopId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((d) => ReferralRecord.fromMap(d.data() as Map<String, dynamic>, d.id))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Computes store-level KPI analytics
  Future<({
    int totalAccounts,
    int totalPointsIssued,
    int totalPointsRedeemed,
    int totalReferralsCompleted,
    double totalDiscountGivenRupees,
  })> getShopAnalytics(String shopId) async {
    try {
      final accountsSnap = await _accountsRef.where('shop_id', isEqualTo: shopId).get();
      int issued = 0;
      int redeemed = 0;
      for (var d in accountsSnap.docs) {
        final data = d.data() as Map<String, dynamic>;
        issued += (data['lifetime_earned_points'] as num?)?.toInt() ?? 0;
        redeemed += (data['lifetime_redeemed_points'] as num?)?.toInt() ?? 0;
      }

      final referralsSnap = await _referralsRef
          .where('shop_id', isEqualTo: shopId)
          .where('status', isEqualTo: ReferralStatus.completed.name)
          .get();

      final config = await getProgramConfig(shopId);
      final discountGiven = redeemed * config.pointValueInRupees;

      return (
        totalAccounts: accountsSnap.docs.length,
        totalPointsIssued: issued,
        totalPointsRedeemed: redeemed,
        totalReferralsCompleted: referralsSnap.docs.length,
        totalDiscountGivenRupees: discountGiven,
      );
    } catch (e) {
      debugPrint('[Loyalty] Error computing analytics: $e');
      return (
        totalAccounts: 0,
        totalPointsIssued: 0,
        totalPointsRedeemed: 0,
        totalReferralsCompleted: 0,
        totalDiscountGivenRupees: 0.0,
      );
    }
  }
}
