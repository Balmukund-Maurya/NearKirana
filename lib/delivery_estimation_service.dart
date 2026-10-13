import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:near_kirana/firebase_utils.dart';
import 'delivery_estimate_model.dart';

/// Calculation engine for estimated delivery and pickup times.
/// Factors in shop preparation time, travel distance, current pending orders queue,
/// and store operating status, while always presenting a non-guarantee disclaimer.
class DeliveryEstimationService {
  static final DeliveryEstimationService instance = DeliveryEstimationService();

  /// Calculates an estimated delivery time window using domain parameters.
  /// Pure function behavior when [currentTime] is supplied.
  DeliveryEstimate calculateEstimate({
    double? storeLat,
    double? storeLng,
    double? customerLat,
    double? customerLng,
    double? customDistanceKm,
    String deliveryType = 'Delivery',
    int basePrepMinutes = 15,
    int pendingOrdersCount = 0,
    bool isStoreOpen = true,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();
    final isPickup = deliveryType.toLowerCase() == 'pickup';

    // 1. Preparation Time
    final int prepTime = max(10, basePrepMinutes);

    // 2. Transit Time based on distance
    double distanceKm = 0.0;
    int transitTime = 0;

    if (!isPickup) {
      if (customDistanceKm != null && customDistanceKm >= 0) {
        distanceKm = customDistanceKm;
      } else if (storeLat != null && storeLng != null && customerLat != null && customerLng != null) {
        final meters = Geolocator.distanceBetween(
          storeLat,
          storeLng,
          customerLat,
          customerLng,
        );
        distanceKm = meters / 1000.0;
      }

      if (distanceKm > 0) {
        // 5 min dispatch overhead + ~4 mins per km (standard local bike speed ~15 km/h in city traffic)
        transitTime = 5 + (distanceKm * 4.0).round();
      } else {
        // Fallback default transit when location is not yet known
        transitTime = 15;
      }
    }

    // 3. Queue Delay based on pending/active shop orders
    int queueDelay = 0;
    if (pendingOrdersCount >= 10) {
      queueDelay = 15;
    } else if (pendingOrdersCount >= 6) {
      queueDelay = 10;
    } else if (pendingOrdersCount >= 3) {
      queueDelay = 5;
    }

    // 4. Calculate realistic time window
    int minMinutes;
    int maxMinutes;

    if (!isStoreOpen) {
      minMinutes = 60;
      maxMinutes = 120;
    } else if (isPickup) {
      final totalPickupPrep = prepTime + queueDelay;
      minMinutes = max(10, totalPickupPrep - 5);
      maxMinutes = totalPickupPrep + 10;
    } else {
      final totalExpected = prepTime + transitTime + queueDelay;
      // Round to clean 5-minute increments
      final rawMin = (totalExpected * 0.88).round();
      final rawMax = (totalExpected * 1.20).round();

      minMinutes = max(20, (rawMin / 5).round() * 5);
      maxMinutes = max(minMinutes + 10, (rawMax / 5).round() * 5);
    }

    final startArrival = now.add(Duration(minutes: minMinutes));
    final endArrival = now.add(Duration(minutes: maxMinutes));

    return DeliveryEstimate(
      minMinutes: minMinutes,
      maxMinutes: maxMinutes,
      prepTimeMinutes: prepTime,
      transitTimeMinutes: transitTime,
      queueDelayMinutes: queueDelay,
      distanceKm: double.parse(distanceKm.toStringAsFixed(1)),
      isStoreOpen: isStoreOpen,
      deliveryType: deliveryType,
      estimatedArrivalStart: startArrival,
      estimatedArrivalEnd: endArrival,
      calculatedAt: now,
    );
  }

  /// Live estimation querying current shop settings and active order queue from Firestore
  Future<DeliveryEstimate> fetchLiveEstimateForShop({
    required String? shopId,
    double? customerLat,
    double? customerLng,
    String deliveryType = 'Delivery',
    FirebaseFirestore? firestore,
  }) async {
    final db = firestore ?? FirebaseUtils.firestore;
    int basePrep = 15;
    bool isStoreOpen = true;
    double? storeLat;
    double? storeLng;

    try {
      DocumentSnapshot? shopDoc;
      if (shopId != null && shopId.isNotEmpty) {
        shopDoc = await db.collection('shops').doc(shopId).get();
      }
      if (shopDoc == null || !shopDoc.exists) {
        shopDoc = await db.collection('settings').doc('app_config').get();
      }

      if (shopDoc.exists) {
        final data = shopDoc.data() as Map<String, dynamic>? ?? {};
        basePrep = (data['base_prep_time_minutes'] as num?)?.toInt() ??
            (data['prep_time_minutes'] as num?)?.toInt() ?? 15;
        isStoreOpen = data['is_store_open'] as bool? ?? true;
        storeLat = (data['store_latitude'] as num?)?.toDouble();
        storeLng = (data['store_longitude'] as num?)?.toDouble();
      }
    } catch (_) {}

    // Count pending / active orders for this shop to assess kitchen load
    int pendingCount = 0;
    try {
      if (shopId != null && shopId.isNotEmpty) {
        final querySnap = await db
            .collection('orders')
            .where('shop_id', isEqualTo: shopId)
            .where('status', whereIn: ['Pending', 'Accepted', 'Packing'])
            .limit(20)
            .get();
        pendingCount = querySnap.docs.length;
      }
    } catch (_) {}

    return calculateEstimate(
      storeLat: storeLat,
      storeLng: storeLng,
      customerLat: customerLat,
      customerLng: customerLng,
      deliveryType: deliveryType,
      basePrepMinutes: basePrep,
      pendingOrdersCount: pendingCount,
      isStoreOpen: isStoreOpen,
    );
  }
}
