import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/shared/models/product.dart';

abstract class ProductRepository {
  Stream<List<Product>> getShopProducts(String shopId);
  Future<List<Product>> getNearbyProducts(List<String> shopIds);
  Future<Product?> getProductDetails(String shopId, String productId);
  Stream<Product?> streamProductDetails(String shopId, String productId);
}

final productRepositoryProvider = Provider<ProductRepository>((ref) => FirebaseProductRepository());

class FirebaseProductRepository implements ProductRepository {
  final FirebaseDatabase _database;

  FirebaseProductRepository({
    FirebaseDatabase? database,
  })  : _database = database ?? FirebaseDatabase.instance;

  @override
  Stream<List<Product>> getShopProducts(String shopId) {
    final dbRef = _database.ref('products/$shopId');

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
  }

  @override
  Future<List<Product>> getNearbyProducts(List<String> shopIds) async {
    final targetShopIds = shopIds.take(15).toList();
    final snapshots = await Future.wait(
      targetShopIds.map((id) => _database.ref('products/$id').get()),
    );

    final Map<String, List<Product>> byShop = {};
    for (int i = 0; i < snapshots.length; i++) {
      final shopId = targetShopIds[i];
      final snapshot = snapshots[i];
      if (!snapshot.exists || snapshot.value == null) continue;

      final productsMap = snapshot.value as Map<dynamic, dynamic>;
      productsMap.forEach((productIdKey, productValue) {
        if (productValue is Map) {
          try {
            final product = Product.fromRTDB(
              productIdKey.toString(),
              shopId,
              Map<dynamic, dynamic>.from(productValue),
            );
            if (product.isActive && !product.isOutOfStock) {
              byShop.putIfAbsent(shopId, () => []).add(product);
            }
          } catch (e) {
            debugPrint('Error parsing product: $e');
          }
        }
      });
    }

    const kMaxPerShop = 6;
    final shopBuckets = byShop.values.map((products) {
      products.sort((a, b) {
        final dA = a.actualPrice > 0 ? (a.actualPrice - a.offerPrice) / a.actualPrice : 0.0;
        final dB = b.actualPrice > 0 ? (b.actualPrice - b.offerPrice) / b.actualPrice : 0.0;
        return dB.compareTo(dA);
      });
      return products.take(kMaxPerShop).toList();
    }).toList();

    final List<Product> allProducts = [];
    final maxLen = shopBuckets.fold(0, (m, b) => b.length > m ? b.length : m);
    for (int i = 0; i < maxLen; i++) {
      for (final bucket in shopBuckets) {
        if (i < bucket.length) allProducts.add(bucket[i]);
      }
    }

    return allProducts;
  }

  @override
  Future<Product?> getProductDetails(String shopId, String productId) async {
    final event = await _database.ref('products/$shopId/$productId').once();
    final snapshot = event.snapshot;
    if (!snapshot.exists || snapshot.value is! Map) return null;
    final productData = Map<dynamic, dynamic>.from(snapshot.value as Map);
    return Product.fromRTDB(productId, shopId, productData);
  }

  @override
  Stream<Product?> streamProductDetails(String shopId, String productId) {
    return _database
        .ref('products/$shopId/$productId')
        .onValue
        .map((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists || snapshot.value is! Map) return null;
      final productData = Map<dynamic, dynamic>.from(snapshot.value as Map);
      return Product.fromRTDB(productId, shopId, productData);
    });
  }
}
