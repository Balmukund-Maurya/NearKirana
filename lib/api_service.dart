import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ApiService {
  static const String _baseUrl =
      'https://world.openfoodfacts.org/api/v2/product/';

  /// Fetches product data from Open Food Facts API using a barcode.
  /// Returns a Map with details if found, else null.
  static Future<Map<String, dynamic>?> fetchProductData(String barcode) async {
    try {
      final url = Uri.parse('$_baseUrl$barcode.json');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 1) {
          final product = data['product'];

          final String name =
              product['product_name'] ?? product['product_name_en'] ?? '';
          final String imageUrl =
              product['image_url'] ?? product['image_front_url'] ?? '';
          final String quantity = product['quantity']?.toString() ?? '';

          // Get the first brand
          String brandsStr = product['brands']?.toString() ?? '';
          final String brand = brandsStr.split(',').first.trim();

          final String ingredients =
              product['ingredients_text']?.toString() ?? '';

          // Check vegetarian status in tags. Default to true (Veg) for Indian context unless explicitly non-veg.
          bool isVegetarian = true;
          final List<dynamic>? tags = product['ingredients_analysis_tags'];
          if (tags != null) {
            if (tags.contains('en:non-vegetarian') ||
                tags.contains('en:vegan-status-unknown')) {
              // Only mark false if explicitly non-vegetarian. We can ignore vegan-status-unknown.
              if (tags.contains('en:non-vegetarian')) {
                isVegetarian = false;
              }
            }
          }

          return {
            'name': name,
            'imageUrl': imageUrl,
            'quantity': quantity,
            'brand': brand,
            'ingredients': ingredients,
            'isVegetarian': isVegetarian,
          };
        }
      }
    } catch (e) {
      debugPrint('Error fetching product from API: $e');
    }
    return null;
  }
}
