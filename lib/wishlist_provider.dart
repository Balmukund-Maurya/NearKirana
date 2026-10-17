import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages customer wishlist items strictly scoped per store (shop_id).
/// Prevents cross-store wishlist leakage so Shop A's items never appear in Shop B.
class WishlistProvider extends ChangeNotifier {
  String? _currentShopId;
  final Map<String, List<String>> _shopWishlists = {};

  String? get currentShopId => _currentShopId;

  /// Returns wishlist items for the currently active shop
  List<String> get wishlistItems {
    final key = _effectiveShopKey(_currentShopId);
    return List.unmodifiable(_shopWishlists[key] ?? []);
  }

  WishlistProvider() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentShopId = prefs.getString('current_shop_id');
    await loadWishlistForShop(_currentShopId);
  }

  String _effectiveShopKey(String? shopId) {
    if (shopId != null && shopId.trim().isNotEmpty) {
      return shopId.trim();
    }
    if (_currentShopId != null && _currentShopId!.trim().isNotEmpty) {
      return _currentShopId!.trim();
    }
    return 'default_shop';
  }

  Future<void> setCurrentShopId(String? shopId) async {
    final newKey = shopId?.trim();
    if (_currentShopId != newKey) {
      _currentShopId = newKey;
      await loadWishlistForShop(newKey);
    }
  }

  Future<void> loadWishlistForShop(String? shopId) async {
    final key = _effectiveShopKey(shopId);
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('wishlist_$key');
    if (stored != null) {
      _shopWishlists[key] = List<String>.from(stored);
    } else {
      _shopWishlists[key] = [];
    }
    notifyListeners();
  }

  List<String> getWishlistForShop(String? shopId) {
    final key = _effectiveShopKey(shopId);
    if (!_shopWishlists.containsKey(key)) {
      // Lazy load from prefs if not loaded yet
      SharedPreferences.getInstance().then((prefs) {
        final stored = prefs.getStringList('wishlist_$key');
        if (stored != null) {
          _shopWishlists[key] = List<String>.from(stored);
          notifyListeners();
        }
      });
      return const [];
    }
    return List.unmodifiable(_shopWishlists[key] ?? []);
  }

  int getCount([String? shopId]) {
    final key = _effectiveShopKey(shopId);
    return (_shopWishlists[key] ?? []).length;
  }

  bool isInWishlist(String productId, [String? shopId]) {
    final key = _effectiveShopKey(shopId);
    final items = _shopWishlists[key] ?? [];
    return items.contains(productId);
  }

  Future<void> toggleWishlist(String productId, [String? shopId]) async {
    final key = _effectiveShopKey(shopId);
    final list = _shopWishlists.putIfAbsent(key, () => []);
    
    if (list.contains(productId)) {
      list.remove(productId);
    } else {
      list.add(productId);
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('wishlist_$key', list);
    notifyListeners();
  }

  Future<void> clearWishlist([String? shopId]) async {
    final key = _effectiveShopKey(shopId);
    _shopWishlists[key]?.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('wishlist_$key');
    notifyListeners();
  }
}
