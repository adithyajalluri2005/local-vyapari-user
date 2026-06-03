import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/shared/models/product.dart';

const kProductPageSize = 10;

final shopProductsProvider = StreamProvider.family<List<Product>, String>((ref, shopId) {
  final dbRef = FirebaseDatabase.instance.ref('products/$shopId');

  return dbRef.onValue.map((event) {
    final snapshot = event.snapshot;
    if (!snapshot.exists || snapshot.value is! Map) {
      return <Product>[];
    }

    final productsMap = snapshot.value as Map<dynamic, dynamic>;
    final List<Product> products = [];

    productsMap.forEach((productIdKey, productValue) {
      if (productValue is Map) {
        try {
          final productId = productIdKey.toString();
          final productData = Map<dynamic, dynamic>.from(productValue);
          final product = Product.fromRTDB(productId, shopId, productData);
          if (product.isActive && !product.isOutOfStock) {
            products.add(product);
          }
        } catch (e) {
          debugPrint('Error parsing product $productIdKey: $e');
        }
      }
    });

    return products;
  });
  // Per-item parse failures are already swallowed above; connection/permission
  // errors are intentionally left to propagate so the UI shows an error state
  // (via AsyncValue.error) instead of an indefinite loading spinner.
});
