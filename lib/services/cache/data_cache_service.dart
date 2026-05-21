import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';
import 'package:local_vyapari_user/shared/models/product.dart';
import 'package:local_vyapari_user/shared/models/offer.dart';

class DataCacheService {
  static Future<File> _getFile(String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$filename');
  }

  // Caching Shops
  static Future<void> cacheShops(List<Shop> shops) async {
    try {
      final file = await _getFile('cached_shops.json');
      final list = shops.map((shop) => {
        'id': shop.id,
        'ownerId': shop.ownerId,
        'name': shop.shopName,
        'description': shop.description,
        'phone': shop.phone,
        'logoUrl': shop.shopLogo,
        'bannerUrl': shop.shopBanner,
        'isVerified': shop.isVerified,
        'isOpen': shop.isOpen,
        'rating': shop.rating,
        'totalReviews': shop.totalReviews,
        'createdAt': shop.createdAt?.toIso8601String(),
        'latitude': shop.location.latitude,
        'longitude': shop.location.longitude,
        'geohash': shop.location.geohash,
        'address': shop.location.address,
        'city': shop.location.city,
        'state': shop.location.state,
        'pincode': shop.location.pincode,
        'placeId': shop.location.placeId,
      }).toList();
      await file.writeAsString(json.encode(list));
    } catch (e) {
      debugPrint('Error caching shops: $e');
    }
  }

  static Future<List<Shop>> getCachedShops() async {
    try {
      final file = await _getFile('cached_shops.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isEmpty) return [];
        final list = json.decode(content) as List<dynamic>;
        return list.map((item) => Shop.fromRTDB(item['id'].toString(), Map<dynamic, dynamic>.from(item))).toList();
      }
    } catch (e) {
      debugPrint('Error loading cached shops: $e');
    }
    return [];
  }

  // Caching Products
  static Future<void> cacheProducts(List<Product> products) async {
    try {
      final file = await _getFile('cached_products.json');
      final list = products.map((p) => {
        'id': p.id,
        'shopId': p.shopId,
        'ownerId': p.ownerId,
        'name': p.name,
        'description': p.description,
        'category': p.category,
        'actualPrice': p.actualPrice,
        'offerPrice': p.offerPrice,
        'stockQuantity': p.stockQuantity,
        'isLowStock': p.isLowStock,
        'isOutOfStock': p.isOutOfStock,
        'isActive': p.isActive,
        'images': p.images,
        'searchKeywords': p.searchKeywords,
        'createdAt': p.createdAt?.toIso8601String(),
      }).toList();
      await file.writeAsString(json.encode(list));
    } catch (e) {
      debugPrint('Error caching products: $e');
    }
  }

  static Future<List<Product>> getCachedProducts() async {
    try {
      final file = await _getFile('cached_products.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isEmpty) return [];
        final list = json.decode(content) as List<dynamic>;
        return list.map((item) => Product.fromRTDB(item['id'].toString(), item['shopId'].toString(), Map<dynamic, dynamic>.from(item))).toList();
      }
    } catch (e) {
      debugPrint('Error loading cached products: $e');
    }
    return [];
  }

  // Caching Offers
  static Future<void> cacheOffers(List<Offer> offers) async {
    try {
      final file = await _getFile('cached_offers.json');
      final list = offers.map((o) => {
        'id': o.id,
        'shopId': o.shopId,
        'productId': o.productId,
        'ownerId': o.ownerId,
        'title': o.title,
        'description': o.description,
        'discountPercentage': o.discountPercentage,
        'startDate': o.startDate?.toIso8601String(),
        'endDate': o.endDate?.toIso8601String(),
        'isActive': o.isActive,
        'isFeatured': o.isFeatured,
        'createdAt': o.createdAt?.toIso8601String(),
      }).toList();
      await file.writeAsString(json.encode(list));
    } catch (e) {
      debugPrint('Error caching offers: $e');
    }
  }

  static Future<List<Offer>> getCachedOffers() async {
    try {
      final file = await _getFile('cached_offers.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isEmpty) return [];
        final list = json.decode(content) as List<dynamic>;
        return list.map((item) => Offer.fromRTDB(item['id'].toString(), item['shopId'].toString(), Map<dynamic, dynamic>.from(item))).toList();
      }
    } catch (e) {
      debugPrint('Error loading cached offers: $e');
    }
    return [];
  }

  // Caching Sync Queue
  static Future<void> saveSyncQueue(List<Map<String, dynamic>> queue) async {
    try {
      final file = await _getFile('sync_queue.json');
      await file.writeAsString(json.encode(queue));
    } catch (e) {
      debugPrint('Error saving sync queue: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getSyncQueue() async {
    try {
      final file = await _getFile('sync_queue.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isEmpty) return [];
        final list = json.decode(content) as List<dynamic>;
        return list.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } catch (e) {
      debugPrint('Error loading sync queue: $e');
    }
    return [];
  }
}
