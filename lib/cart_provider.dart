import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CartItem {
  final String id;
  final String name;
  final double price;
  final bool isLoose;
  final double maxStock;
  double quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.isLoose,
    required this.maxStock,
    this.quantity = 1.0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'isLoose': isLoose,
    'maxStock': maxStock,
    'quantity': quantity,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    id: json['id'],
    name: json['name'],
    price: (json['price'] as num).toDouble(),
    isLoose: json['isLoose'],
    maxStock: (json['maxStock'] as num).toDouble(),
    quantity: (json['quantity'] as num).toDouble(),
  );
}

class CartProvider with ChangeNotifier {
  Map<String, CartItem> _items = {};

  CartProvider() {
    _loadCart();
  }

  Future<void> _loadCart() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cartJson = prefs.getString('cart_items');
    if (cartJson != null) {
      try {
        final Map<String, dynamic> decodedData = json.decode(cartJson);
        _items = decodedData.map(
          (key, value) => MapEntry(key, CartItem.fromJson(value)),
        );
        notifyListeners();
      } catch (e) {
        if (kDebugMode) print('Error loading cart: $e');
      }
    }
  }

  Future<void> _saveCart() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = json.encode(
      _items.map((key, value) => MapEntry(key, value.toJson())),
    );
    await prefs.setString('cart_items', encodedData);
  }

  Map<String, CartItem> get items => _items;

  List<CartItem> get itemsList => _items.values.toList();

  int get itemCount =>
      _items.values.fold(0, (total, item) => total + item.quantity.ceil());

  Future<void> syncPricesWithServer() async {
    if (_items.isEmpty) return;

    bool changed = false;
    final keys = _items.keys.toList();

    // Process in batches of 10 (Firestore 'whereIn' limit)
    for (var i = 0; i < keys.length; i += 10) {
      final end = (i + 10 < keys.length) ? i + 10 : keys.length;
      final batchKeys = keys.sublist(i, end);

      final querySnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where(FieldPath.documentId, whereIn: batchKeys)
          .get();

      final Map<String, Map<String, dynamic>> fetchedDocs = {
        for (var doc in querySnapshot.docs) doc.id: doc.data(),
      };

      for (var key in batchKeys) {
        if (fetchedDocs.containsKey(key)) {
          final data = fetchedDocs[key]!;
          final livePrice = (data['price'] as num?)?.toDouble() ?? 0.0;
          final liveStock = (data['stock_quantity'] as num?)?.toDouble() ?? 0.0;

          if (_items[key]!.price != livePrice ||
              _items[key]!.maxStock != liveStock) {
            
            final updatedQuantity = _items[key]!.quantity > liveStock
                  ? liveStock
                  : _items[key]!.quantity;

            if (updatedQuantity <= 0) {
              // FIX-30: Remove ghost items entirely if stock drops to 0
              _items.remove(key);
              changed = true;
            } else {
              _items[key] = CartItem(
                id: _items[key]!.id,
                name: _items[key]!.name,
                price: livePrice,
                isLoose: _items[key]!.isLoose,
                maxStock: liveStock,
                quantity: updatedQuantity,
              );
              changed = true;
            }
          }
        } else {
          _items.remove(key); // Product deleted
          changed = true;
        }
      }
    }

    if (changed) {
      notifyListeners();
      _saveCart();
    }
  }

  double get cartTotal {
    double total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.price * cartItem.quantity;
    });
    return total;
  }

  bool addItem(
    String productId,
    String name,
    double price,
    bool isLoose,
    double maxStock,
  ) {
    bool success = true;
    if (_items.containsKey(productId)) {
      final existingCartItem = _items[productId]!;
      final double increment = isLoose ? 0.5 : 1.0;
      final double newQty = existingCartItem.quantity + increment;

      if (newQty > maxStock) {
        success = false;
      } else {
        _items.update(
          productId,
          (_) => CartItem(
            id: existingCartItem.id,
            name: existingCartItem.name,
            price: existingCartItem.price,
            isLoose: existingCartItem.isLoose,
            maxStock: maxStock,
            quantity: newQty,
          ),
        );
      }
    } else {
      final double initialQty = isLoose ? 0.5 : 1.0;
      if (initialQty > maxStock) {
        success = false;
      } else {
        _items.putIfAbsent(
          productId,
          () => CartItem(
            id: productId,
            name: name,
            price: price,
            isLoose: isLoose,
            maxStock: maxStock,
            quantity: initialQty,
          ),
        );
      }
    }
    notifyListeners();
    _saveCart();
    return success;
  }

  void updatePrice(String id, double newPrice) {
    if (_items.containsKey(id)) {
      final oldItem = _items[id]!;
      _items[id] = CartItem(
        id: oldItem.id,
        name: oldItem.name,
        price: newPrice,
        isLoose: oldItem.isLoose,
        maxStock: oldItem.maxStock,
        quantity: oldItem.quantity,
      );
      notifyListeners();
      _saveCart();
    }
  }

  void setQuantity(String productId, double qty) {
    if (_items.containsKey(productId)) {
      if (qty <= 0) {
        _items.remove(productId);
      } else {
        final existing = _items[productId]!;
        _items[productId] = CartItem(
          id: existing.id,
          name: existing.name,
          price: existing.price,
          isLoose: existing.isLoose,
          maxStock: existing.maxStock,
          quantity: qty,
        );
      }
      notifyListeners();
      _saveCart();
    }
  }

  void removeItem(String productId) {
    _items.remove(productId);
    notifyListeners();
    _saveCart();
  }

  bool updateQuantity(String productId, double change) {
    if (!_items.containsKey(productId)) return false;

    final existingCartItem = _items[productId]!;
    final double currentQty = existingCartItem.quantity;
    final double newQty = currentQty + change;

    if (newQty <= 0) {
      _items.remove(productId);
      notifyListeners();
      _saveCart();
      return true;
    }

    if (newQty > existingCartItem.maxStock) {
      return false; // Reached max stock
    }

    _items.update(
      productId,
      (_) => CartItem(
        id: existingCartItem.id,
        name: existingCartItem.name,
        price: existingCartItem.price,
        isLoose: existingCartItem.isLoose,
        maxStock: existingCartItem.maxStock,
        quantity: newQty,
      ),
    );
    notifyListeners();
    _saveCart();
    return true;
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
    _saveCart();
  }
}
