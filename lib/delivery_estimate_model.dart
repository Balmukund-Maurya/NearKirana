import 'package:intl/intl.dart';

/// Represents an approximate delivery time estimation with transparency breakdown
/// and explicit non-guarantee disclaimer.
class DeliveryEstimate {
  final int minMinutes;
  final int maxMinutes;
  final int prepTimeMinutes;
  final int transitTimeMinutes;
  final int queueDelayMinutes;
  final double distanceKm;
  final bool isStoreOpen;
  final String deliveryType; // 'Delivery' or 'Pickup'
  final DateTime estimatedArrivalStart;
  final DateTime estimatedArrivalEnd;
  final DateTime calculatedAt;
  final String disclaimer;

  const DeliveryEstimate({
    required this.minMinutes,
    required this.maxMinutes,
    required this.prepTimeMinutes,
    required this.transitTimeMinutes,
    required this.queueDelayMinutes,
    required this.distanceKm,
    required this.isStoreOpen,
    required this.deliveryType,
    required this.estimatedArrivalStart,
    required this.estimatedArrivalEnd,
    required this.calculatedAt,
    this.disclaimer = 'Approximate time window. Traffic, weather & rush volume may cause variations. Not a strict guarantee.',
  });

  /// Approximate window string, e.g., "35–50 mins"
  String get formattedWindow {
    if (!isStoreOpen) {
      return 'Store Closed';
    }
    if (minMinutes == maxMinutes) {
      return '~$minMinutes mins';
    }
    return '$minMinutes–$maxMinutes mins';
  }

  /// Clock time range format, e.g., "7:30 PM – 7:50 PM"
  String get formattedTimeRange {
    if (!isStoreOpen) {
      return 'Upon store opening';
    }
    final format = DateFormat('h:mm a');
    final startStr = format.format(estimatedArrivalStart);
    final endStr = format.format(estimatedArrivalEnd);
    return '$startStr – $endStr';
  }

  /// Short summary for badges and order cards
  String get summary {
    if (!isStoreOpen) return 'Store Closed';
    return deliveryType == 'Pickup'
        ? 'Ready in ~$formattedWindow'
        : 'Est. Delivery: $formattedWindow';
  }

  /// Full explanatory text for customer display
  String get fullDescription {
    if (!isStoreOpen) {
      return 'Store is currently closed. Order will be processed once store opens.';
    }
    if (deliveryType == 'Pickup') {
      return 'Estimated ready for pickup in $formattedWindow ($formattedTimeRange)';
    }
    return 'Estimated delivery in $formattedWindow (around $formattedTimeRange)';
  }

  Map<String, dynamic> toMap() {
    return {
      'min_minutes': minMinutes,
      'max_minutes': maxMinutes,
      'prep_time_minutes': prepTimeMinutes,
      'transit_time_minutes': transitTimeMinutes,
      'queue_delay_minutes': queueDelayMinutes,
      'distance_km': distanceKm,
      'is_store_open': isStoreOpen,
      'delivery_type': deliveryType,
      'estimated_arrival_start': estimatedArrivalStart.toIso8601String(),
      'estimated_arrival_end': estimatedArrivalEnd.toIso8601String(),
      'calculated_at': calculatedAt.toIso8601String(),
      'disclaimer': disclaimer,
      'formatted_window': formattedWindow,
      'formatted_time_range': formattedTimeRange,
    };
  }

  factory DeliveryEstimate.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    return DeliveryEstimate(
      minMinutes: (map['min_minutes'] as num?)?.toInt() ?? 30,
      maxMinutes: (map['max_minutes'] as num?)?.toInt() ?? 45,
      prepTimeMinutes: (map['prep_time_minutes'] as num?)?.toInt() ?? 15,
      transitTimeMinutes: (map['transit_time_minutes'] as num?)?.toInt() ?? 15,
      queueDelayMinutes: (map['queue_delay_minutes'] as num?)?.toInt() ?? 0,
      distanceKm: (map['distance_km'] as num?)?.toDouble() ?? 0.0,
      isStoreOpen: map['is_store_open'] as bool? ?? true,
      deliveryType: map['delivery_type']?.toString() ?? 'Delivery',
      estimatedArrivalStart: map['estimated_arrival_start'] != null
          ? DateTime.tryParse(map['estimated_arrival_start'].toString()) ?? now.add(const Duration(minutes: 30))
          : now.add(const Duration(minutes: 30)),
      estimatedArrivalEnd: map['estimated_arrival_end'] != null
          ? DateTime.tryParse(map['estimated_arrival_end'].toString()) ?? now.add(const Duration(minutes: 45))
          : now.add(const Duration(minutes: 45)),
      calculatedAt: map['calculated_at'] != null
          ? DateTime.tryParse(map['calculated_at'].toString()) ?? now
          : now,
      disclaimer: map['disclaimer']?.toString() ??
          'Approximate time window. Traffic, weather & rush volume may cause variations. Not a strict guarantee.',
    );
  }

  DeliveryEstimate copyWith({
    int? minMinutes,
    int? maxMinutes,
    int? prepTimeMinutes,
    int? transitTimeMinutes,
    int? queueDelayMinutes,
    double? distanceKm,
    bool? isStoreOpen,
    String? deliveryType,
    DateTime? estimatedArrivalStart,
    DateTime? estimatedArrivalEnd,
    DateTime? calculatedAt,
    String? disclaimer,
  }) {
    return DeliveryEstimate(
      minMinutes: minMinutes ?? this.minMinutes,
      maxMinutes: maxMinutes ?? this.maxMinutes,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      transitTimeMinutes: transitTimeMinutes ?? this.transitTimeMinutes,
      queueDelayMinutes: queueDelayMinutes ?? this.queueDelayMinutes,
      distanceKm: distanceKm ?? this.distanceKm,
      isStoreOpen: isStoreOpen ?? this.isStoreOpen,
      deliveryType: deliveryType ?? this.deliveryType,
      estimatedArrivalStart: estimatedArrivalStart ?? this.estimatedArrivalStart,
      estimatedArrivalEnd: estimatedArrivalEnd ?? this.estimatedArrivalEnd,
      calculatedAt: calculatedAt ?? this.calculatedAt,
      disclaimer: disclaimer ?? this.disclaimer,
    );
  }
}
