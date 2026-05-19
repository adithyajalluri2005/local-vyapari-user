import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_shops_provider.dart';
import 'package:local_vyapari_user/shared/models/product.dart';

final nearbyProductsProvider = StreamProvider<List<Product>>((ref) {
  final shopsAsyncValue = ref.watch(nearbyShopsProvider);
  final shops = shopsAsyncValue.value ?? [];

  if (shops.isEmpty) {
    return Stream.value(<Product>[]);
  }

  final shopIds = shops.map((s) => s.id).toSet();
  final dbRef = FirebaseDatabase.instance.ref('products');

  return dbRef.onValue.map((event) {
    final snapshot = event.snapshot;
    if (!snapshot.exists || snapshot.value == null) {
      return <Product>[];
    }

    final Map<dynamic, dynamic> shopsProductsMap = snapshot.value as Map<dynamic, dynamic>;
    final List<Product> products = [];

    shopsProductsMap.forEach((shopIdKey, productsValue) {
      final shopId = shopIdKey.toString();
      if (shopIds.contains(shopId) && productsValue is Map) {
        productsValue.forEach((productIdKey, productValue) {
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
      }
    });

    return products;
  }).handleError((error) {
    debugPrint('Error in nearbyProductsProvider stream: $error');
    return <Product>[];
  });
});
