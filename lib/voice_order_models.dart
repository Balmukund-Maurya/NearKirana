// Domain models for Feature 61: Voice-Based Grocery Ordering (वॉइस-बेस्ड ग्रॉसरी ऑर्डरिंग)

import 'package:flutter/foundation.dart';

/// Lightweight product representation for catalog matching
@immutable
class VoiceCatalogProduct {
  final String id;
  final String name;
  final double price;
  final double stockQuantity;
  final bool isLoose;
  final String? imageUrl;
  final String? unit;
  final String? category;
  final List<String> searchKeywords;

  const VoiceCatalogProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.stockQuantity,
    this.isLoose = false,
    this.imageUrl,
    this.unit,
    this.category,
    this.searchKeywords = const [],
  });

  bool get isAvailable => stockQuantity > 0;

  factory VoiceCatalogProduct.fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    List<String> keywords = [];
    if (data['searchKeywords'] is List) {
      keywords = (data['searchKeywords'] as List)
          .map((e) => e.toString().toLowerCase())
          .toList();
    }

    return VoiceCatalogProduct(
      id: id,
      name: (data['name'] ?? 'Item').toString(),
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      stockQuantity: (data['stock_quantity'] as num?)?.toDouble() ?? 0.0,
      isLoose: (data['is_loose'] ?? data['isLoose']) == true,
      imageUrl: (data['imageUrl'] ?? data['image_url'])?.toString(),
      unit: data['unit']?.toString(),
      category: data['category']?.toString(),
      searchKeywords: keywords,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'price': price,
    'stock_quantity': stockQuantity,
    'is_loose': isLoose,
    if (imageUrl != null) 'imageUrl': imageUrl,
    if (unit != null) 'unit': unit,
    if (category != null) 'category': category,
    'searchKeywords': searchKeywords,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceCatalogProduct &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Status of an individual parsed voice item
enum VoiceItemStatus {
  /// Exactly 1 available matching product found
  ready,

  /// Multiple matching products found; customer must pick one
  ambiguous,

  /// Matched product is out of stock in current store inventory
  outOfStock,

  /// Product not found in store catalog
  notFound,
}

extension VoiceItemStatusExtension on VoiceItemStatus {
  String get label {
    switch (this) {
      case VoiceItemStatus.ready:
        return 'Ready to Add (तैयार है)';
      case VoiceItemStatus.ambiguous:
        return 'Choose Variant (ब्रांड चुनें)';
      case VoiceItemStatus.outOfStock:
        return 'Out of Stock (स्टॉक में नहीं)';
      case VoiceItemStatus.notFound:
        return 'Not in Store (दुकान में नहीं मिला)';
    }
  }
}

/// Individual item extracted from a voice phrase
@immutable
class ParsedVoiceItem {
  final String rawSegment;
  final String rawItemName;
  final double requestedQuantity;
  final String? unit;
  final VoiceCatalogProduct? matchedProduct;
  final List<VoiceCatalogProduct> candidateProducts;
  final VoiceItemStatus status;
  final String? clarificationReason;
  final double finalQuantity;
  final VoiceCatalogProduct? selectedProduct;
  final String? notes;

  const ParsedVoiceItem({
    required this.rawSegment,
    required this.rawItemName,
    required this.requestedQuantity,
    this.unit,
    this.matchedProduct,
    this.candidateProducts = const [],
    required this.status,
    this.clarificationReason,
    required this.finalQuantity,
    this.selectedProduct,
    this.notes,
  });

  VoiceCatalogProduct? get effectiveProduct => selectedProduct ?? matchedProduct;

  double get effectivePrice =>
      (effectiveProduct?.price ?? 0.0) * finalQuantity;

  bool get isReadyToAdd {
    final prod = effectiveProduct;
    if (prod == null) return false;
    if (!prod.isAvailable) return false;
    if (finalQuantity <= 0) return false;
    if (status == VoiceItemStatus.ready) return true;
    if (status == VoiceItemStatus.ambiguous && selectedProduct != null) {
      return true;
    }
    return false;
  }

  ParsedVoiceItem copyWith({
    String? rawSegment,
    String? rawItemName,
    double? requestedQuantity,
    String? unit,
    VoiceCatalogProduct? matchedProduct,
    List<VoiceCatalogProduct>? candidateProducts,
    VoiceItemStatus? status,
    String? clarificationReason,
    double? finalQuantity,
    VoiceCatalogProduct? selectedProduct,
    String? notes,
  }) {
    return ParsedVoiceItem(
      rawSegment: rawSegment ?? this.rawSegment,
      rawItemName: rawItemName ?? this.rawItemName,
      requestedQuantity: requestedQuantity ?? this.requestedQuantity,
      unit: unit ?? this.unit,
      matchedProduct: matchedProduct ?? this.matchedProduct,
      candidateProducts: candidateProducts ?? this.candidateProducts,
      status: status ?? this.status,
      clarificationReason: clarificationReason ?? this.clarificationReason,
      finalQuantity: finalQuantity ?? this.finalQuantity,
      selectedProduct: selectedProduct ?? this.selectedProduct,
      notes: notes ?? this.notes,
    );
  }
}

/// Full parse result from a spoken audio query
@immutable
class VoiceOrderParseResult {
  final String spokenText;
  final String detectedLanguage;
  final List<ParsedVoiceItem> parsedItems;

  const VoiceOrderParseResult({
    required this.spokenText,
    required this.detectedLanguage,
    required this.parsedItems,
  });

  bool get hasAmbiguity => parsedItems.any(
    (item) =>
        item.status == VoiceItemStatus.ambiguous && item.selectedProduct == null,
  );

  int get readyCount => parsedItems.where((i) => i.isReadyToAdd).length;

  int get ambiguousCount => parsedItems
      .where(
        (i) =>
            i.status == VoiceItemStatus.ambiguous && i.selectedProduct == null,
      )
      .length;

  int get outOfStockCount =>
      parsedItems.where((i) => i.status == VoiceItemStatus.outOfStock).length;

  int get notFoundCount =>
      parsedItems.where((i) => i.status == VoiceItemStatus.notFound).length;

  double get totalEstimatedCost => parsedItems
      .where((i) => i.isReadyToAdd)
      .fold(0.0, (sum, i) => sum + i.effectivePrice);

  bool get allResolved =>
      parsedItems.isNotEmpty && !hasAmbiguity && readyCount > 0;
}

/// Log for auditing / customer convenience of voice orders
class VoiceOrderSessionLog {
  final String id;
  final String shopId;
  final String customerPhone;
  final String spokenText;
  final int itemCount;
  final List<String> matchedItemNames;
  final DateTime createdAt;

  VoiceOrderSessionLog({
    required this.id,
    required this.shopId,
    required this.customerPhone,
    required this.spokenText,
    required this.itemCount,
    required this.matchedItemNames,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'shop_id': shopId,
    'customer_phone': customerPhone,
    'spoken_text': spokenText,
    'item_count': itemCount,
    'matched_item_names': matchedItemNames,
    'created_at': createdAt.toIso8601String(),
  };

  factory VoiceOrderSessionLog.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return VoiceOrderSessionLog(
      id: documentId,
      shopId: (map['shop_id'] ?? '').toString(),
      customerPhone: (map['customer_phone'] ?? '').toString(),
      spokenText: (map['spoken_text'] ?? '').toString(),
      itemCount: (map['item_count'] as num?)?.toInt() ?? 0,
      matchedItemNames: (map['matched_item_names'] is List)
          ? (map['matched_item_names'] as List)
              .map((e) => e.toString())
              .toList()
          : [],
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
