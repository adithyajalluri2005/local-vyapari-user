import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/shared/models/product.dart';

final shopProductsProvider = StreamProvider.family<List<Product>, String>((ref, shopId) {
  final dbRef = FirebaseDatabase.instance.ref('products/$shopId');

  return dbRef.onValue.map((event) {
    final snapshot = event.snapshot;
    if (!snapshot.exists || snapshot.value == null) {
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
  }).handleError((error) {
    debugPrint('Error in shopProductsProvider stream for shop $shopId: $error');
    return <Product>[];
  });
});
