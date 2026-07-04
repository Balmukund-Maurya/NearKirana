import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'search_utils.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> getProduct(String barcode) async {
    try {
      DocumentSnapshot doc = await _db
          .collection('products')
          .doc(barcode)
          .get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching product: $e');
      return null;
    }
  }

  Future<void> addNewProduct(
    String barcode,
    String name,
    double price,
    bool isLoose, [
    double stockQuantity = 0.0,
    String? imageUrl,
    Map<String, dynamic>? extraDetails,
    String? shopId,
  ]) async {
    try {
      final docRef = _db.collection('products').doc(barcode);
      final docSnap = await docRef.get();
      
      if (docSnap.exists) {
        throw Exception('Product with this barcode already exists. Please use the Edit option.');
      }

      final productData = <String, dynamic>{
        'name': name,
        'searchKeywords': generateSearchKeywords(name),
        'price': price,
        'is_loose': isLoose,
        'stock_quantity': stockQuantity,
        if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
        if (shopId != null && shopId.isNotEmpty) 'shop_id': shopId,
        'created_at': FieldValue.serverTimestamp(),
      };

      if (extraDetails != null) {
        productData.addAll(extraDetails);
      }

      await docRef.set(productData);
    } catch (e) {
      debugPrint('Error adding new product: $e');
      rethrow;
    }
  }

  Future<void> updateProduct(
    String barcode,
    String name,
    double price,
    bool isLoose, [
    double stockQuantity = 0.0,
    String? imageUrl,
    Map<String, dynamic>? extraDetails,
    String? shopId,
  ]) async {
    try {
      final productData = <String, dynamic>{
        'name': name,
        'searchKeywords': generateSearchKeywords(name),
        'price': price,
        'is_loose': isLoose,
        'stock_quantity': stockQuantity,
        if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
        if (shopId != null && shopId.isNotEmpty) 'shop_id': shopId,
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (extraDetails != null) {
        // Merge the extra details into the document
        productData.addAll(extraDetails);
      }

      await _db.collection('products').doc(barcode).set(productData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error adding product: $e');
      rethrow;
    }
  }

  // MIGRATION: Convert single string 'category' to 'categories' list for all products
  Future<void> migrateCategories() async {
    try {
      debugPrint('Starting category migration...');
      final snapshot = await _db.collection('products').get();
      int migratedCount = 0;
      final batch = _db.batch();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('category') && !data.containsKey('categories')) {
          final oldCat = data['category'] as String?;
          if (oldCat != null && oldCat.isNotEmpty) {
            batch.update(doc.reference, {
              'categories': [oldCat],
              'category': FieldValue.delete(), // Remove the old field to avoid confusion
            });
            migratedCount++;
          }
        }
      }

      if (migratedCount > 0) {
        await batch.commit();
        debugPrint('Successfully migrated $migratedCount products to new categories array.');
      } else {
        debugPrint('No products needed migration.');
      }
    } catch (e) {
      debugPrint('Migration error: $e');
    }
  }
}
