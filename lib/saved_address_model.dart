import 'package:flutter/material.dart';

/// Data model representing a customer's saved delivery address.
/// Supports multiple addresses (Home, Office, Other, etc.) with coordinates and default selection.
class SavedAddress {
  final String id;
  final String label; // 'Home', 'Office', 'Other'
  final String address;
  final String houseNo;
  final String title;
  final String landmark;
  final double? lat;
  final double? lng;
  final bool isDefault;
  final String? recipientName;
  final String? recipientPhone;
  final DateTime createdAt;

  double? get latitude => lat;
  double? get longitude => lng;

  SavedAddress({
    String? id,
    String? title,
    this.label = 'Home',
    required this.address,
    this.houseNo = '',
    this.landmark = '',
    double? lat,
    double? lng,
    double? latitude,
    double? longitude,
    this.isDefault = false,
    this.recipientName,
    this.recipientPhone,
    DateTime? createdAt,
  })  : id = id ?? 'addr_${DateTime.now().millisecondsSinceEpoch}',
        title = title ?? label,
        lat = lat ?? latitude,
        lng = lng ?? longitude,
        createdAt = createdAt ?? DateTime.now();

  /// Formatted single-line or multi-line address representation
  String get formattedAddress {
    final parts = <String>[];
    if (houseNo.trim().isNotEmpty) parts.add(houseNo.trim());
    if (address.trim().isNotEmpty) parts.add(address.trim());
    if (landmark.trim().isNotEmpty) {
      final lm = landmark.trim();
      parts.add(lm.toLowerCase().startsWith('near') ? lm : 'Near $lm');
    }
    return parts.join(', ');
  }

  /// Icon corresponding to the address label
  IconData get icon {
    switch (label.toLowerCase()) {
      case 'home':
        return Icons.home_rounded;
      case 'office':
      case 'work':
        return Icons.business_rounded;
      default:
        return Icons.location_on_rounded;
    }
  }

  /// Color accent for address label
  Color get labelColor {
    switch (label.toLowerCase()) {
      case 'home':
        return const Color(0xFF4CAF50);
      case 'office':
      case 'work':
        return const Color(0xFF2196F3);
      default:
        return const Color(0xFFFF9800);
    }
  }

  SavedAddress copyWith({
    String? id,
    String? title,
    String? label,
    String? address,
    String? houseNo,
    String? landmark,
    double? lat,
    double? lng,
    double? latitude,
    double? longitude,
    bool? isDefault,
    String? recipientName,
    String? recipientPhone,
    DateTime? createdAt,
  }) {
    return SavedAddress(
      id: id ?? this.id,
      title: title ?? this.title,
      label: label ?? this.label,
      address: address ?? this.address,
      houseNo: houseNo ?? this.houseNo,
      landmark: landmark ?? this.landmark,
      lat: lat ?? latitude ?? this.lat,
      lng: lng ?? longitude ?? this.lng,
      isDefault: isDefault ?? this.isDefault,
      recipientName: recipientName ?? this.recipientName,
      recipientPhone: recipientPhone ?? this.recipientPhone,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'label': label,
      'address': address,
      'houseNo': houseNo,
      'landmark': landmark,
      'lat': lat,
      'lng': lng,
      'isDefault': isDefault,
      if (recipientName != null) 'recipientName': recipientName,
      if (recipientPhone != null) 'recipientPhone': recipientPhone,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SavedAddress.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) {
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    final id = map['id']?.toString() ??
        'addr_${map['address'].hashCode}_${map['houseNo'].hashCode}';

    return SavedAddress(
      id: id,
      title: map['title']?.toString(),
      label: map['label']?.toString() ?? 'Home',
      address: map['address']?.toString() ?? '',
      houseNo: map['houseNo']?.toString() ?? '',
      landmark: map['landmark']?.toString() ?? '',
      lat: parseDouble(map['lat']),
      lng: parseDouble(map['lng']),
      isDefault: map['isDefault'] == true,
      recipientName: map['recipientName']?.toString(),
      recipientPhone: map['recipientPhone']?.toString(),
      createdAt: parseDate(map['createdAt']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedAddress &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Result of evaluating an address against a store's serviceability parameters
class AddressServiceabilityResult {
  final bool isServiceable;
  final double distanceKm;
  final double maxRadiusKm;
  final String? errorMessage;

  const AddressServiceabilityResult({
    required this.isServiceable,
    required this.distanceKm,
    required this.maxRadiusKm,
    this.errorMessage,
  });

  bool get isOutOfDeliveryRadius => !isServiceable && distanceKm > maxRadiusKm;
  double get deliveryRadiusKm => maxRadiusKm;
}
