import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_utils.dart';
import 'shopping_list_model.dart';
import 'cart_provider.dart';

/// Business service managing Customer Saved Shopping Lists & 1-Tap Reorder Validation.
class ShoppingListService {
  final FirebaseFirestore _firestore;

  ShoppingListService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseUtils.firestore;

  CollectionReference<Map<String, dynamic>> get _listsRef =>
      _firestore.collection('shopping_lists');

  static const String _prefCacheKey = 'cached_shopping_lists_v1';

  /// Generate a unique list ID (e.g. LST-169827364)
  static String generateListId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return 'LST-$now';
  }

  /// Save or update a shopping list in Firestore and local storage.
  Future<ShoppingListModel> saveList(ShoppingListModel list) async {
    final id = list.id.isEmpty ? generateListId() : list.id;
    final now = DateTime.now();

    final toSave = list.copyWith(
      id: id,
      updatedAt: now,
      createdAt: list.createdAt.year < 2020 ? now : list.createdAt,
    );

    await _listsRef.doc(id).set(toSave.toMap(), SetOptions(merge: true));
    await _updateLocalCache(toSave);

    return toSave;
  }

  /// Stream customer lists in real-time, filtered by customer phone and optional shop ID.
  Stream<List<ShoppingListModel>> streamCustomerLists(
    String customerPhone, {
    String? shopId,
  }) {
    Query<Map<String, dynamic>> query =
        _listsRef.where('customer_phone', isEqualTo: customerPhone);

    if (shopId != null && shopId.isNotEmpty) {
      query = query.where('shop_id', isEqualTo: shopId);
    }

    return query.snapshots().map((snapshot) {
      final lists = snapshot.docs
          .map((doc) => ShoppingListModel.fromMap(doc.data(), doc.id))
          .toList();
      lists.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return lists;
    });
  }

  /// Get lists for customer with local cache fallback if offline.
  Future<List<ShoppingListModel>> getListsForCustomer(
    String customerPhone, {
    String? shopId,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          _listsRef.where('customer_phone', isEqualTo: customerPhone);

      if (shopId != null && shopId.isNotEmpty) {
        query = query.where('shop_id', isEqualTo: shopId);
      }

      final snapshot = await query.get();
      final lists = snapshot.docs
          .map((doc) => ShoppingListModel.fromMap(doc.data(), doc.id))
          .toList();
      lists.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return lists;
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching shopping lists from Firestore: $e');
      return _getLocalCachedLists(customerPhone, shopId: shopId);
    }
  }

  /// Delete a saved shopping list.
  Future<void> deleteList(String listId) async {
    await _listsRef.doc(listId).delete();
    await _removeFromLocalCache(listId);
  }

  /// Create a saved shopping list directly from a past order.
  Future<ShoppingListModel> createListFromOrder({
    required String orderId,
    required String name,
    required String customerPhone,
    required String shopId,
    required List<dynamic> items,
    String? colorTag,
  }) async {
    final listItems = items.map((raw) {
      final map = Map<String, dynamic>.from(raw as Map);
      return ShoppingListItem(
        productId: (map['id'] ?? map['product_id'] ?? '').toString(),
        name: (map['name'] ?? 'Item').toString(),
        price: (map['price'] as num?)?.toDouble() ?? 0.0,
        quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
        isLoose: (map['is_loose'] ?? map['isLoose']) == true,
        imageUrl: map['imageUrl'] ?? map['image_url'],
        category: map['category']?.toString(),
        unit: map['unit']?.toString(),
      );
    }).toList();

    final now = DateTime.now();
    final model = ShoppingListModel(
      id: generateListId(),
      name: name.trim().isEmpty ? 'Order $orderId List' : name.trim(),
      customerPhone: customerPhone,
      shopId: shopId,
      items: listItems,
      createdAt: now,
      updatedAt: now,
      colorTag: colorTag,
    );

    return saveList(model);
  }

  /// Create a saved shopping list directly from the current cart items.
  Future<ShoppingListModel> createListFromCart({
    required String name,
    required String customerPhone,
    required String shopId,
    required List<CartItem> cartItems,
    String? colorTag,
  }) async {
    final listItems = cartItems.map((c) {
      return ShoppingListItem(
        productId: c.id,
        name: c.name,
        price: c.price,
        quantity: c.quantity,
        isLoose: c.isLoose,
        imageUrl: c.imageUrl,
      );
    }).toList();

    final now = DateTime.now();
    final model = ShoppingListModel(
      id: generateListId(),
      name: name.trim().isEmpty ? 'My Grocery List' : name.trim(),
      customerPhone: customerPhone,
      shopId: shopId,
      items: listItems,
      createdAt: now,
      updatedAt: now,
      colorTag: colorTag,
    );

    return saveList(model);
  }

  /// Validates past order items or saved shopping list items against live stock, live prices,
  /// and current shop inventory.
  Future<ReorderValidationResult> validateItemsForReorder({
    required String currentShopId,
    required List<Map<String, dynamic>> items,
  }) async {
    final List<ReorderItemValidation> validatedItems = [];

    for (final raw in items) {
      final productId = (raw['product_id'] ?? raw['id'] ?? '').toString();
      final name = (raw['name'] ?? 'Item').toString();
      final origPrice = (raw['price'] as num?)?.toDouble() ?? 0.0;
      final reqQty = (raw['quantity'] as num?)?.toDouble() ?? 1.0;
      final isLoose = (raw['is_loose'] ?? raw['isLoose']) == true;
      final imageUrl = (raw['image_url'] ?? raw['imageUrl'])?.toString();

      Map<String, dynamic>? liveProductData;
      String matchedProductId = productId;

      // 1. Attempt direct ID lookup in products collection
      if (productId.isNotEmpty) {
        final doc = await _firestore.collection('products').doc(productId).get();
        if (doc.exists) {
          final data = doc.data() ?? {};
          final pShopId = data['shop_id']?.toString() ?? '';
          if (currentShopId.isEmpty || pShopId.isEmpty || pShopId == currentShopId) {
            liveProductData = data;
          }
        }
      }

      // 2. If not found by ID or belongs to a different shop, search by exact name in current shop
      if (liveProductData == null && currentShopId.isNotEmpty) {
        final nameQuery = await _firestore
            .collection('products')
            .where('shop_id', isEqualTo: currentShopId)
            .where('name', isEqualTo: name)
            .limit(1)
            .get();

        if (nameQuery.docs.isNotEmpty) {
          liveProductData = nameQuery.docs.first.data();
          matchedProductId = nameQuery.docs.first.id;
        }
      }

      // 3. Evaluate availability, stock, and price
      if (liveProductData == null) {
        validatedItems.add(
          ReorderItemValidation(
            productId: productId,
            name: name,
            requestedQuantity: reqQty,
            availableQuantity: 0.0,
            originalPrice: origPrice,
            currentPrice: origPrice,
            isLoose: isLoose,
            imageUrl: imageUrl,
            status: ReorderItemStatus.discontinued,
            notes: 'Product not found in current shop inventory',
          ),
        );
        continue;
      }

      final isActive = liveProductData['is_active'] != false;
      final livePrice = (liveProductData['price'] as num?)?.toDouble() ?? origPrice;
      final liveStock = (liveProductData['stock_quantity'] as num?)?.toDouble() ?? 0.0;
      final liveImg = liveProductData['imageUrl'] ?? liveProductData['image_url'] ?? imageUrl;

      if (!isActive || liveStock <= 0) {
        validatedItems.add(
          ReorderItemValidation(
            productId: matchedProductId,
            name: name,
            requestedQuantity: reqQty,
            availableQuantity: 0.0,
            originalPrice: origPrice,
            currentPrice: livePrice,
            isLoose: isLoose,
            imageUrl: liveImg?.toString(),
            status: ReorderItemStatus.outOfStock,
            notes: 'Out of stock at this shop',
          ),
        );
      } else if (liveStock < reqQty) {
        validatedItems.add(
          ReorderItemValidation(
            productId: matchedProductId,
            name: name,
            requestedQuantity: reqQty,
            availableQuantity: liveStock,
            originalPrice: origPrice,
            currentPrice: livePrice,
            isLoose: isLoose,
            imageUrl: liveImg?.toString(),
            status: ReorderItemStatus.partialStock,
            notes: 'Only $liveStock left in stock',
          ),
        );
      } else if (livePrice != origPrice) {
        validatedItems.add(
          ReorderItemValidation(
            productId: matchedProductId,
            name: name,
            requestedQuantity: reqQty,
            availableQuantity: reqQty,
            originalPrice: origPrice,
            currentPrice: livePrice,
            isLoose: isLoose,
            imageUrl: liveImg?.toString(),
            status: ReorderItemStatus.priceChanged,
            notes: livePrice > origPrice
                ? 'Price increased by ₹${(livePrice - origPrice).toStringAsFixed(1)}'
                : 'Price decreased by ₹${(origPrice - livePrice).toStringAsFixed(1)}',
          ),
        );
      } else {
        validatedItems.add(
          ReorderItemValidation(
            productId: matchedProductId,
            name: name,
            requestedQuantity: reqQty,
            availableQuantity: reqQty,
            originalPrice: origPrice,
            currentPrice: livePrice,
            isLoose: isLoose,
            imageUrl: liveImg?.toString(),
            status: ReorderItemStatus.available,
          ),
        );
      }
    }

    return ReorderValidationResult(
      shopId: currentShopId,
      items: validatedItems,
    );
  }

  /// Bulk add validated reorder items into CartProvider.
  /// Sets quantity to availableQuantity with updated live price and live max stock.
  int applyItemsToCart({
    required CartProvider cartProvider,
    required List<ReorderItemValidation> itemsToAdd,
  }) {
    int addedCount = 0;
    for (final item in itemsToAdd) {
      if (item.availableQuantity <= 0 || item.isDiscontinued) continue;

      // Add or update in cart
      final existing = cartProvider.items[item.productId];
      final targetQty = item.availableQuantity;

      if (existing != null) {
        cartProvider.setQuantity(item.productId, targetQty);
        cartProvider.updatePrice(item.productId, item.currentPrice);
      } else {
        // addItem with live values
        cartProvider.addItem(
          item.productId,
          item.name,
          item.currentPrice,
          item.isLoose,
          item.availableQuantity, // maxStock
          imageUrl: item.imageUrl,
        );
        // Ensure quantity matches targetQty
        cartProvider.setQuantity(item.productId, targetQty);
      }
      addedCount++;
    }
    return addedCount;
  }

  // --- Local Cache Helpers ---

  Future<void> _updateLocalCache(ShoppingListModel list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefCacheKey);
      List<dynamic> cachedList = [];
      if (raw != null) {
        cachedList = json.decode(raw) as List<dynamic>;
      }

      // Remove existing if any
      cachedList.removeWhere((item) => item['id'] == list.id);
      cachedList.insert(0, list.toMap(forCache: true));

      await prefs.setString(_prefCacheKey, json.encode(cachedList));
    } catch (e) {
      if (kDebugMode) debugPrint('Error updating local shopping list cache: $e');
    }
  }

  Future<void> _removeFromLocalCache(String listId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefCacheKey);
      if (raw == null) return;

      final List<dynamic> cachedList = json.decode(raw) as List<dynamic>;
      cachedList.removeWhere((item) => item['id'] == listId);
      await prefs.setString(_prefCacheKey, json.encode(cachedList));
    } catch (e) {
      if (kDebugMode) debugPrint('Error removing from local shopping list cache: $e');
    }
  }

  Future<List<ShoppingListModel>> _getLocalCachedLists(
    String customerPhone, {
    String? shopId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefCacheKey);
      if (raw == null) return [];

      final List<dynamic> list = json.decode(raw) as List<dynamic>;
      return list
          .map((item) => ShoppingListModel.fromMap(Map<String, dynamic>.from(item as Map)))
          .where((m) =>
              m.customerPhone == customerPhone &&
              (shopId == null || shopId.isEmpty || m.shopId == shopId))
          .toList();
    } catch (e) {
      return [];
    }
  }
}
