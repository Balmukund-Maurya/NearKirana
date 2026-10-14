import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of the live delivery tracking session
enum LiveTrackingStatus {
  transit('in_transit', 'रास्ते में है (On the Way)'),
  nearby('nearby', 'आस-पास पहुंच गए हैं (Arrived Nearby)'),
  delivered('delivered', 'डिलीवरी पूरी हुई (Delivered)'),
  ended('ended', 'ट्रैकिंग समाप्त (Tracking Ended)');

  final String key;
  final String label;
  const LiveTrackingStatus(this.key, this.label);

  static LiveTrackingStatus fromString(String? key) {
    switch (key?.toLowerCase().trim()) {
      case 'nearby':
      case 'arrived_nearby':
        return LiveTrackingStatus.nearby;
      case 'delivered':
        return LiveTrackingStatus.delivered;
      case 'ended':
      case 'cancelled':
        return LiveTrackingStatus.ended;
      case 'in_transit':
      case 'transit':
      default:
        return LiveTrackingStatus.transit;
    }
  }
}

/// A single GPS location point with heading and speed
class DeliveryLocationPoint {
  final double latitude;
  final double longitude;
  final double? heading;
  final double? speedMps;
  final double? accuracyMeters;
  final DateTime timestamp;

  const DeliveryLocationPoint({
    required this.latitude,
    required this.longitude,
    this.heading,
    this.speedMps,
    this.accuracyMeters,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading,
      'speed_mps': speedMps,
      'accuracy_meters': accuracyMeters,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory DeliveryLocationPoint.fromMap(Map<String, dynamic> map) {
    DateTime parsedTime = DateTime.now();
    final rawTs = map['timestamp'];
    if (rawTs is Timestamp) {
      parsedTime = rawTs.toDate();
    } else if (rawTs is String) {
      parsedTime = DateTime.tryParse(rawTs) ?? DateTime.now();
    }

    return DeliveryLocationPoint(
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      heading: (map['heading'] as num?)?.toDouble(),
      speedMps: (map['speed_mps'] as num?)?.toDouble(),
      accuracyMeters: (map['accuracy_meters'] as num?)?.toDouble(),
      timestamp: parsedTime,
    );
  }
}

/// Complete live delivery tracking session associated with an active order
class LiveTrackingSession {
  final String orderId;
  final String partnerId;
  final String partnerName;
  final String partnerPhone;
  final String? partnerVehicle;
  final String shopId;
  final String? shopName;
  final double? shopLat;
  final double? shopLng;
  final String customerPhone;
  final String customerName;
  final String customerAddress;
  final double? customerLat;
  final double? customerLng;
  final DeliveryLocationPoint? currentLocation;
  final List<DeliveryLocationPoint> breadcrumbs;
  final bool isActive;
  final LiveTrackingStatus status;
  final double? distanceRemainingMeters;
  final int? estimatedMinutesRemaining;
  final DateTime sessionStartedAt;
  final DateTime lastUpdatedAt;
  final DateTime? sessionEndedAt;

  const LiveTrackingSession({
    required this.orderId,
    required this.partnerId,
    required this.partnerName,
    required this.partnerPhone,
    this.partnerVehicle,
    required this.shopId,
    this.shopName,
    this.shopLat,
    this.shopLng,
    required this.customerPhone,
    required this.customerName,
    required this.customerAddress,
    this.customerLat,
    this.customerLng,
    this.currentLocation,
    this.breadcrumbs = const [],
    this.isActive = true,
    this.status = LiveTrackingStatus.transit,
    this.distanceRemainingMeters,
    this.estimatedMinutesRemaining,
    required this.sessionStartedAt,
    required this.lastUpdatedAt,
    this.sessionEndedAt,
  });

  /// True if partner is within proximity threshold (e.g. 180 meters)
  bool get isNearby =>
      status == LiveTrackingStatus.nearby ||
      (distanceRemainingMeters != null && distanceRemainingMeters! <= 180.0);

  /// Human-friendly distance string (e.g. "850 m" or "2.4 km")
  String get formattedDistance {
    if (distanceRemainingMeters == null) return 'कैलकुलेट हो रहा है...';
    if (distanceRemainingMeters! < 1000) {
      return '${distanceRemainingMeters!.round()} m';
    }
    final km = distanceRemainingMeters! / 1000;
    return '${km.toStringAsFixed(1)} km';
  }

  /// Human-friendly ETA string (e.g. "5–8 mins" or "Arriving shortly")
  String get formattedEta {
    if (status == LiveTrackingStatus.delivered) {
      return 'Delivered';
    }
    if (isNearby) {
      return 'पहुंचने वाले हैं (1-2 mins)';
    }
    if (estimatedMinutesRemaining == null || estimatedMinutesRemaining! <= 0) {
      return 'कैलकुलेट हो रहा है...';
    }
    if (estimatedMinutesRemaining! <= 2) {
      return '1–2 mins';
    }
    return '$estimatedMinutesRemaining mins';
  }

  Map<String, dynamic> toMap() {
    return {
      'order_id': orderId,
      'partner_id': partnerId,
      'partner_name': partnerName,
      'partner_phone': partnerPhone,
      'partner_vehicle': partnerVehicle,
      'shop_id': shopId,
      'shop_name': shopName,
      'shop_lat': shopLat,
      'shop_lng': shopLng,
      'customer_phone': customerPhone,
      'customer_name': customerName,
      'customer_address': customerAddress,
      'customer_lat': customerLat,
      'customer_lng': customerLng,
      'current_location': currentLocation?.toMap(),
      'breadcrumbs': breadcrumbs.map((b) => b.toMap()).toList(),
      'is_active': isActive,
      'status': status.key,
      'distance_remaining_meters': distanceRemainingMeters,
      'estimated_minutes_remaining': estimatedMinutesRemaining,
      'session_started_at': Timestamp.fromDate(sessionStartedAt),
      'last_updated_at': Timestamp.fromDate(lastUpdatedAt),
      'session_ended_at':
          sessionEndedAt != null ? Timestamp.fromDate(sessionEndedAt!) : null,
    };
  }

  factory LiveTrackingSession.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseTs(dynamic val, DateTime fallback) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? fallback;
      return fallback;
    }

    final startedAt = parseTs(map['session_started_at'], DateTime.now());
    final updatedAt = parseTs(map['last_updated_at'], startedAt);
    final endedAt = map['session_ended_at'] != null
        ? parseTs(map['session_ended_at'], DateTime.now())
        : null;

    DeliveryLocationPoint? loc;
    if (map['current_location'] is Map<String, dynamic>) {
      loc = DeliveryLocationPoint.fromMap(
        map['current_location'] as Map<String, dynamic>,
      );
    } else if (map['latitude'] != null && map['longitude'] != null) {
      loc = DeliveryLocationPoint(
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        heading: (map['heading'] as num?)?.toDouble(),
        speedMps: (map['speed_mps'] as num?)?.toDouble(),
        accuracyMeters: (map['accuracy_meters'] as num?)?.toDouble(),
        timestamp: updatedAt,
      );
    }

    final rawCrumbs = map['breadcrumbs'];
    final List<DeliveryLocationPoint> crumbsList = [];
    if (rawCrumbs is List) {
      for (final item in rawCrumbs) {
        if (item is Map<String, dynamic>) {
          crumbsList.add(DeliveryLocationPoint.fromMap(item));
        }
      }
    }

    return LiveTrackingSession(
      orderId: map['order_id']?.toString() ?? docId,
      partnerId: map['partner_id']?.toString() ?? '',
      partnerName: map['partner_name']?.toString() ?? 'डिलीवरी पार्टनर',
      partnerPhone: map['partner_phone']?.toString() ?? '',
      partnerVehicle: map['partner_vehicle']?.toString(),
      shopId: map['shop_id']?.toString() ?? '',
      shopName: map['shop_name']?.toString(),
      shopLat: (map['shop_lat'] as num?)?.toDouble(),
      shopLng: (map['shop_lng'] as num?)?.toDouble(),
      customerPhone: map['customer_phone']?.toString() ?? '',
      customerName: map['customer_name']?.toString() ?? '',
      customerAddress: map['customer_address']?.toString() ?? '',
      customerLat: (map['customer_lat'] as num?)?.toDouble(),
      customerLng: (map['customer_lng'] as num?)?.toDouble(),
      currentLocation: loc,
      breadcrumbs: crumbsList,
      isActive: map['is_active'] as bool? ?? false,
      status: LiveTrackingStatus.fromString(map['status']?.toString()),
      distanceRemainingMeters:
          (map['distance_remaining_meters'] as num?)?.toDouble(),
      estimatedMinutesRemaining:
          (map['estimated_minutes_remaining'] as num?)?.toInt(),
      sessionStartedAt: startedAt,
      lastUpdatedAt: updatedAt,
      sessionEndedAt: endedAt,
    );
  }

  LiveTrackingSession copyWith({
    DeliveryLocationPoint? currentLocation,
    List<DeliveryLocationPoint>? breadcrumbs,
    bool? isActive,
    LiveTrackingStatus? status,
    double? distanceRemainingMeters,
    int? estimatedMinutesRemaining,
    DateTime? lastUpdatedAt,
    DateTime? sessionEndedAt,
  }) {
    return LiveTrackingSession(
      orderId: orderId,
      partnerId: partnerId,
      partnerName: partnerName,
      partnerPhone: partnerPhone,
      partnerVehicle: partnerVehicle,
      shopId: shopId,
      shopName: shopName,
      shopLat: shopLat,
      shopLng: shopLng,
      customerPhone: customerPhone,
      customerName: customerName,
      customerAddress: customerAddress,
      customerLat: customerLat,
      customerLng: customerLng,
      currentLocation: currentLocation ?? this.currentLocation,
      breadcrumbs: breadcrumbs ?? this.breadcrumbs,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      distanceRemainingMeters:
          distanceRemainingMeters ?? this.distanceRemainingMeters,
      estimatedMinutesRemaining:
          estimatedMinutesRemaining ?? this.estimatedMinutesRemaining,
      sessionStartedAt: sessionStartedAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      sessionEndedAt: sessionEndedAt ?? this.sessionEndedAt,
    );
  }
}
