import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an individual item in a saved shopping list.
class ShoppingListItem {
  final String productId;
  final String name;
  final double price;
  final double quantity;
  final bool isLoose;
  final String? imageUrl;
  final String? category;
  final String? unit;

  const ShoppingListItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    this.isLoose = false,
    this.imageUrl,
    this.category,
    this.unit,
  });

  double get totalPrice => price * quantity;

  ShoppingListItem copyWith({
    String? productId,
    String? name,
    double? price,
    double? quantity,
    bool? isLoose,
    String? imageUrl,
    String? category,
    String? unit,
  }) {
    return ShoppingListItem(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      isLoose: isLoose ?? this.isLoose,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      unit: unit ?? this.unit,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'is_loose': isLoose,
      'image_url': imageUrl,
      'category': category,
      'unit': unit,
    };
  }

  factory ShoppingListItem.fromMap(Map<String, dynamic> map) {
    return ShoppingListItem(
      productId: (map['product_id'] ?? map['id'] ?? '').toString(),
      name: (map['name'] ?? 'Item').toString(),
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      isLoose: (map['is_loose'] ?? map['isLoose']) == true,
      imageUrl: map['image_url'] ?? map['imageUrl'],
      category: map['category']?.toString(),
      unit: map['unit']?.toString(),
    );
  }
}

/// Represents a customer's saved shopping list (e.g. "Weekly Grocery", "Monthly Ration").
class ShoppingListModel {
  final String id;
  final String name;
  final String customerPhone;
  final String shopId;
  final List<ShoppingListItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? colorTag; // Optional color or emoji tag

  const ShoppingListModel({
    required this.id,
    required this.name,
    required this.customerPhone,
    required this.shopId,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
    this.colorTag,
  });

  double get totalEstimatedCost =>
      items.fold(0.0, (total, item) => total + item.totalPrice);

  int get itemCount => items.length;

  ShoppingListModel copyWith({
    String? id,
    String? name,
    String? customerPhone,
    String? shopId,
    List<ShoppingListItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? colorTag,
  }) {
    return ShoppingListModel(
      id: id ?? this.id,
      name: name ?? this.name,
      customerPhone: customerPhone ?? this.customerPhone,
      shopId: shopId ?? this.shopId,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      colorTag: colorTag ?? this.colorTag,
    );
  }

  Map<String, dynamic> toMap({bool forCache = false}) {
    return {
      'id': id,
      'name': name,
      'customer_phone': customerPhone,
      'shop_id': shopId,
      'items': items.map((item) => item.toMap()).toList(),
      'created_at': forCache ? createdAt.toIso8601String() : Timestamp.fromDate(createdAt),
      'updated_at': forCache ? updatedAt.toIso8601String() : Timestamp.fromDate(updatedAt),
      'color_tag': colorTag,
    };
  }

  factory ShoppingListModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawItems = map['items'] as List<dynamic>? ?? [];
    DateTime created = DateTime.now();
    DateTime updated = DateTime.now();

    if (map['created_at'] is Timestamp) {
      created = (map['created_at'] as Timestamp).toDate();
    } else if (map['created_at'] is String) {
      created = DateTime.tryParse(map['created_at']) ?? DateTime.now();
    }

    if (map['updated_at'] is Timestamp) {
      updated = (map['updated_at'] as Timestamp).toDate();
    } else if (map['updated_at'] is String) {
      updated = DateTime.tryParse(map['updated_at']) ?? DateTime.now();
    }

    return ShoppingListModel(
      id: docId ?? (map['id'] ?? '').toString(),
      name: (map['name'] ?? 'My Shopping List').toString(),
      customerPhone: (map['customer_phone'] ?? '').toString(),
      shopId: (map['shop_id'] ?? '').toString(),
      items: rawItems
          .map((item) =>
              ShoppingListItem.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList(),
      createdAt: created,
      updatedAt: updated,
      colorTag: map['color_tag']?.toString(),
    );
  }
}

/// Status of an individual item when validated for reordering.
enum ReorderItemStatus {
  available,
  priceChanged,
  partialStock,
  outOfStock,
  discontinued,
}

/// Validation details for an item during Reorder.
class ReorderItemValidation {
  final String productId;
  final String name;
  final double requestedQuantity;
  final double availableQuantity;
  final double originalPrice;
  final double currentPrice;
  final bool isLoose;
  final String? imageUrl;
  final ReorderItemStatus status;
  final String? notes;

  const ReorderItemValidation({
    required this.productId,
    required this.name,
    required this.requestedQuantity,
    required this.availableQuantity,
    required this.originalPrice,
    required this.currentPrice,
    required this.isLoose,
    this.imageUrl,
    required this.status,
    this.notes,
  });

  bool get isFullyAvailable =>
      status == ReorderItemStatus.available ||
      (status == ReorderItemStatus.priceChanged &&
          availableQuantity >= requestedQuantity);

  bool get hasPriceChange =>
      originalPrice != currentPrice && status != ReorderItemStatus.outOfStock && status != ReorderItemStatus.discontinued;

  double get priceDifference => currentPrice - originalPrice;

  bool get isPriceHigher => currentPrice > originalPrice;

  bool get isPriceLower => currentPrice < originalPrice;

  bool get isOutOfStock =>
      status == ReorderItemStatus.outOfStock || availableQuantity <= 0;

  bool get isDiscontinued => status == ReorderItemStatus.discontinued;

  bool get isPartial =>
      status == ReorderItemStatus.partialStock ||
      (availableQuantity > 0 && availableQuantity < requestedQuantity);
}

/// Complete validation result for a past order or shopping list reorder.
class ReorderValidationResult {
  final String shopId;
  final List<ReorderItemValidation> items;

  const ReorderValidationResult({
    required this.shopId,
    required this.items,
  });

  List<ReorderItemValidation> get availableItems =>
      items.where((i) => i.availableQuantity > 0 && !i.isDiscontinued).toList();

  List<ReorderItemValidation> get priceChangedItems =>
      items.where((i) => i.hasPriceChange && i.availableQuantity > 0).toList();

  List<ReorderItemValidation> get partialStockItems =>
      items.where((i) => i.isPartial).toList();

  List<ReorderItemValidation> get outOfStockItems =>
      items.where((i) => i.isOutOfStock && !i.isDiscontinued).toList();

  List<ReorderItemValidation> get discontinuedItems =>
      items.where((i) => i.isDiscontinued).toList();

  bool get allAvailable =>
      items.isNotEmpty &&
      items.every((i) =>
          i.status == ReorderItemStatus.available &&
          i.availableQuantity >= i.requestedQuantity);

  bool get canReorderAny => availableItems.isNotEmpty;

  double get totalOriginalCost => items.fold(
      0.0, (acc, i) => acc + (i.originalPrice * i.requestedQuantity));

  double get totalCurrentCost => availableItems.fold(
      0.0, (acc, i) => acc + (i.currentPrice * i.availableQuantity));
}
