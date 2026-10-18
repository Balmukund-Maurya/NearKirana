import 'package:cloud_firestore/cloud_firestore.dart';

/// Availability and duty status of a delivery partner
enum DeliveryPartnerStatus {
  available,
  onDelivery,
  offline;

  String get key => name;

  String get label {
    switch (this) {
      case DeliveryPartnerStatus.available:
        return 'Available';
      case DeliveryPartnerStatus.onDelivery:
        return 'On Delivery';
      case DeliveryPartnerStatus.offline:
        return 'Offline';
    }
  }

  String get hindiLabel {
    switch (this) {
      case DeliveryPartnerStatus.available:
        return 'उपलब्ध (ड्यूटी पर)';
      case DeliveryPartnerStatus.onDelivery:
        return 'डिलीवरी पर';
      case DeliveryPartnerStatus.offline:
        return 'ऑफलाइन';
    }
  }

  static DeliveryPartnerStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'available':
      case 'active':
        return DeliveryPartnerStatus.available;
      case 'ondelivery':
      case 'on_delivery':
      case 'busy':
        return DeliveryPartnerStatus.onDelivery;
      case 'offline':
      case 'inactive':
      default:
        return DeliveryPartnerStatus.offline;
    }
  }
}

/// Lifecycle status of an individual delivery dispatch assignment
enum DeliveryTaskStatus {
  assigned,
  accepted,
  pickedUp,
  delivered,
  cancelled;

  String get key {
    switch (this) {
      case DeliveryTaskStatus.assigned:
        return 'assigned';
      case DeliveryTaskStatus.accepted:
        return 'accepted';
      case DeliveryTaskStatus.pickedUp:
        return 'picked_up';
      case DeliveryTaskStatus.delivered:
        return 'delivered';
      case DeliveryTaskStatus.cancelled:
        return 'cancelled';
    }
  }

  String get label {
    switch (this) {
      case DeliveryTaskStatus.assigned:
        return 'Assigned';
      case DeliveryTaskStatus.accepted:
        return 'Accepted';
      case DeliveryTaskStatus.pickedUp:
        return 'Picked Up';
      case DeliveryTaskStatus.delivered:
        return 'Delivered';
      case DeliveryTaskStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get hindiLabel {
    switch (this) {
      case DeliveryTaskStatus.assigned:
        return 'असाइन किया गया';
      case DeliveryTaskStatus.accepted:
        return 'स्वीकार किया';
      case DeliveryTaskStatus.pickedUp:
        return 'पिकअप संपन्न (रास्ते में)';
      case DeliveryTaskStatus.delivered:
        return 'डिलीवर किया गया';
      case DeliveryTaskStatus.cancelled:
        return 'रद्द किया गया';
    }
  }

  static DeliveryTaskStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'assigned':
        return DeliveryTaskStatus.assigned;
      case 'accepted':
        return DeliveryTaskStatus.accepted;
      case 'pickedup':
      case 'picked_up':
      case 'out for delivery':
      case 'out_for_delivery':
        return DeliveryTaskStatus.pickedUp;
      case 'delivered':
        return DeliveryTaskStatus.delivered;
      case 'cancelled':
        return DeliveryTaskStatus.cancelled;
      default:
        return DeliveryTaskStatus.assigned;
    }
  }
}

/// Registered delivery partner profile for a Kirana store
class DeliveryPartner {
  final String id;
  final String shopId;
  final String name;
  final String phone;
  final String vehicleNumber;
  final DeliveryPartnerStatus status;
  final int activeOrdersCount;
  final int totalDeliveredCount;
  final double rating;
  final double cashCollected; // COD cash currently in hand
  final DateTime createdAt;
  final DateTime? lastActiveAt;

  const DeliveryPartner({
    required this.id,
    required this.shopId,
    required this.name,
    required this.phone,
    this.vehicleNumber = '',
    this.status = DeliveryPartnerStatus.available,
    this.activeOrdersCount = 0,
    this.totalDeliveredCount = 0,
    this.rating = 5.0,
    this.cashCollected = 0.0,
    required this.createdAt,
    this.lastActiveAt,
  });

  bool get isOnline => status != DeliveryPartnerStatus.offline;
  bool get isAvailable => status == DeliveryPartnerStatus.available;

  Map<String, dynamic> toMap() {
    return {
      'shop_id': shopId,
      'name': name,
      'phone': phone,
      'vehicle_number': vehicleNumber,
      'status': status.key,
      'active_orders_count': activeOrdersCount,
      'total_delivered_count': totalDeliveredCount,
      'rating': rating,
      'cash_collected': cashCollected,
      'created_at': Timestamp.fromDate(createdAt),
      if (lastActiveAt != null)
        'last_active_at': Timestamp.fromDate(lastActiveAt!),
    };
  }

  factory DeliveryPartner.fromMap(Map<String, dynamic> data, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return DeliveryPartner(
      id: id,
      shopId: data['shop_id']?.toString() ?? '',
      name: data['name']?.toString() ?? 'Partner',
      phone: data['phone']?.toString() ?? '',
      vehicleNumber: data['vehicle_number']?.toString() ?? '',
      status: DeliveryPartnerStatus.fromString(data['status']?.toString()),
      activeOrdersCount: (data['active_orders_count'] as num?)?.toInt() ?? 0,
      totalDeliveredCount: (data['total_delivered_count'] as num?)?.toInt() ?? 0,
      rating: (data['rating'] as num?)?.toDouble() ?? 5.0,
      cashCollected: (data['cash_collected'] as num?)?.toDouble() ?? 0.0,
      createdAt: parseDate(data['created_at']),
      lastActiveAt: data['last_active_at'] != null ? parseDate(data['last_active_at']) : null,
    );
  }

  DeliveryPartner copyWith({
    String? id,
    String? shopId,
    String? name,
    String? phone,
    String? vehicleNumber,
    DeliveryPartnerStatus? status,
    int? activeOrdersCount,
    int? totalDeliveredCount,
    double? rating,
    double? cashCollected,
    DateTime? createdAt,
    DateTime? lastActiveAt,
  }) {
    return DeliveryPartner(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      status: status ?? this.status,
      activeOrdersCount: activeOrdersCount ?? this.activeOrdersCount,
      totalDeliveredCount: totalDeliveredCount ?? this.totalDeliveredCount,
      rating: rating ?? this.rating,
      cashCollected: cashCollected ?? this.cashCollected,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }
}

/// Delivery task representation of an order assigned to a delivery partner
class DeliveryOrderTask {
  final String orderId;
  final String shopId;
  final String shopName;
  final String shopAddress;
  final double? shopLat;
  final double? shopLng;
  final String partnerId;
  final String partnerName;
  final String partnerPhone;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final double? customerLat;
  final double? customerLng;
  final double totalAmount;
  final String paymentMode;
  final String paymentStatus;
  final String orderStatus;
  final DeliveryTaskStatus deliveryTaskStatus;
  final DateTime assignedAt;
  final DateTime? acceptedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final int itemsCount;
  final List<String> itemsSummary;
  final String? deliveryNotes;
  final String deliveryPin;

  const DeliveryOrderTask({
    required this.orderId,
    required this.shopId,
    this.shopName = '',
    this.shopAddress = '',
    this.shopLat,
    this.shopLng,
    required this.partnerId,
    this.partnerName = '',
    this.partnerPhone = '',
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    this.customerLat,
    this.customerLng,
    required this.totalAmount,
    this.paymentMode = 'COD',
    this.paymentStatus = 'Pending',
    required this.orderStatus,
    required this.deliveryTaskStatus,
    required this.assignedAt,
    this.acceptedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.itemsCount = 0,
    this.itemsSummary = const [],
    this.deliveryNotes,
    this.deliveryPin = '',
  });

  bool get isCOD => paymentMode.toUpperCase() == 'COD' || paymentStatus.toLowerCase() == 'unpaid';
  bool get isPickedUp => deliveryTaskStatus == DeliveryTaskStatus.pickedUp;
  bool get isDelivered => deliveryTaskStatus == DeliveryTaskStatus.delivered;

  factory DeliveryOrderTask.fromFirestoreDoc(Map<String, dynamic> data, String id) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? (fallback ?? DateTime.now());
      return fallback ?? DateTime.now();
    }

    final itemsRaw = data['items'];
    int count = 0;
    List<String> summary = [];
    if (itemsRaw is List) {
      count = itemsRaw.length;
      summary = itemsRaw.take(4).map((item) {
        if (item is Map) {
          final name = item['name'] ?? item['product_name'] ?? 'Item';
          final qty = item['quantity'] ?? item['qty'] ?? 1;
          return '$qty x $name';
        }
        return item.toString();
      }).toList();
    }

    final rawDeliveryStatus = data['delivery_status']?.toString();
    final rawOrderStatus = data['status']?.toString() ?? 'Ready';

    DeliveryTaskStatus taskStatus;
    if (rawOrderStatus.toLowerCase() == 'delivered' || rawDeliveryStatus == 'delivered') {
      taskStatus = DeliveryTaskStatus.delivered;
    } else if (rawOrderStatus.toLowerCase() == 'out for delivery' || rawDeliveryStatus == 'picked_up') {
      taskStatus = DeliveryTaskStatus.pickedUp;
    } else if (rawDeliveryStatus == 'accepted') {
      taskStatus = DeliveryTaskStatus.accepted;
    } else if (rawOrderStatus.toLowerCase() == 'cancelled') {
      taskStatus = DeliveryTaskStatus.cancelled;
    } else {
      taskStatus = DeliveryTaskStatus.assigned;
    }

    return DeliveryOrderTask(
      orderId: id,
      shopId: data['shop_id']?.toString() ?? '',
      shopName: data['shop_name']?.toString() ?? data['store_name']?.toString() ?? '',
      shopAddress: data['shop_address']?.toString() ?? data['store_address']?.toString() ?? '',
      shopLat: (data['shop_lat'] as num?)?.toDouble() ??
          (data['store_lat'] as num?)?.toDouble() ??
          (data['shop_latitude'] as num?)?.toDouble() ??
          (data['store_latitude'] as num?)?.toDouble(),
      shopLng: (data['shop_lng'] as num?)?.toDouble() ??
          (data['store_lng'] as num?)?.toDouble() ??
          (data['shop_longitude'] as num?)?.toDouble() ??
          (data['store_longitude'] as num?)?.toDouble(),
      partnerId: data['delivery_boy_id']?.toString() ?? '',
      partnerName: data['delivery_boy_name']?.toString() ?? '',
      partnerPhone: data['delivery_boy_phone']?.toString() ?? '',
      customerName: data['customer_name']?.toString() ?? data['name']?.toString() ?? 'Customer',
      customerPhone: data['phone_number']?.toString() ?? data['customer_phone']?.toString() ?? '',
      deliveryAddress: data['delivery_address']?.toString() ?? data['address']?.toString() ?? 'Address not specified',
      customerLat: (data['customer_lat'] as num?)?.toDouble() ??
          (data['selected_address']?['latitude'] as num?)?.toDouble() ??
          (data['selected_address']?['lat'] as num?)?.toDouble() ??
          (data['delivery_location']?['latitude'] as num?)?.toDouble() ??
          (data['delivery_location']?['lat'] as num?)?.toDouble() ??
          (data['address_lat'] as num?)?.toDouble() ??
          (data['lat'] as num?)?.toDouble(),
      customerLng: (data['customer_lng'] as num?)?.toDouble() ??
          (data['selected_address']?['longitude'] as num?)?.toDouble() ??
          (data['selected_address']?['lng'] as num?)?.toDouble() ??
          (data['delivery_location']?['longitude'] as num?)?.toDouble() ??
          (data['delivery_location']?['lng'] as num?)?.toDouble() ??
          (data['address_lng'] as num?)?.toDouble() ??
          (data['lng'] as num?)?.toDouble(),
      totalAmount: (data['total_amount'] as num?)?.toDouble() ?? 0.0,
      paymentMode: data['payment_mode']?.toString() ?? data['payment_method']?.toString() ?? 'COD',
      paymentStatus: data['payment_status']?.toString() ?? 'Pending',
      orderStatus: rawOrderStatus,
      deliveryTaskStatus: taskStatus,
      assignedAt: parseDate(data['delivery_assigned_at'] ?? data['assigned_at'] ?? data['created_at']),
      acceptedAt: data['delivery_accepted_at'] != null ? parseDate(data['delivery_accepted_at']) : null,
      pickedUpAt: data['delivery_picked_up_at'] != null || data['picked_up_at'] != null
          ? parseDate(data['delivery_picked_up_at'] ?? data['picked_up_at'])
          : null,
      deliveredAt: data['delivered_at'] != null ? parseDate(data['delivered_at']) : null,
      itemsCount: count,
      itemsSummary: summary,
      deliveryNotes: data['delivery_notes']?.toString(),
      deliveryPin: data['delivery_pin']?.toString() ?? '',
    );
  }
}
