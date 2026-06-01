import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';
import 'package:local_vyapari_user/shared/models/product.dart';
import 'package:local_vyapari_user/shared/models/offer.dart';
import 'security_helper.dart';

// SecurityHelper calls FlutterSecureStorage (a platform channel). Platform
// channels are only accessible from the root isolate, so we must NOT wrap
// these calls in compute() — invoke them directly on the main isolate instead.

class DataCacheService {
  static Timer? _shopCacheTimer;
  static Timer? _productCacheTimer;
  static Timer? _offerCacheTimer;

  static Future<File> _getFile(String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$filename');
  }

  // Caching Shops
  static Future<void> cacheShops(List<Shop> shops) async {
    _shopCacheTimer?.cancel();
    _shopCacheTimer = Timer(const Duration(seconds: 2), () async {
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
          'isOpen': shop.storedIsOpen, // raw vendor toggle — NOT computed, so schedule re-evaluates correctly on next load
          'openingTime': shop.openingTime,
          'closingTime': shop.closingTime,
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
        
        final jsonString = json.encode(list);
        final encryptedString = await SecurityHelper.encryptData(jsonString);
        await file.writeAsString(encryptedString);
      } catch (e) {
        debugPrint('Error caching shops: $e');
      }
    });
  }

  static Future<List<Shop>> getCachedShops() async {
    try {
      final file = await _getFile('cached_shops.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isEmpty) return [];
        
        String decryptedContent;
        try {
          decryptedContent = await SecurityHelper.decryptData(content);
        } catch (e) {
          // If decryption fails (e.g. key changed or legacy unencrypted file)
          await file.delete();
          return [];
        }

        final list = json.decode(decryptedContent) as List<dynamic>;
        return list.map((item) => Shop.fromRTDB(item['id'].toString(), Map<dynamic, dynamic>.from(item))).toList();
      }
    } catch (e) {
      debugPrint('Error loading cached shops: $e');
    }
    return [];
  }

  // Caching Products
  static Future<void> cacheProducts(List<Product> products) async {
    _productCacheTimer?.cancel();
    _productCacheTimer = Timer(const Duration(seconds: 2), () async {
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

        final jsonString = json.encode(list);
        final encryptedString = await SecurityHelper.encryptData(jsonString);
        await file.writeAsString(encryptedString);
      } catch (e) {
        debugPrint('Error caching products: $e');
      }
    });
  }

  static Future<List<Product>> getCachedProducts() async {
    try {
      final file = await _getFile('cached_products.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isEmpty) return [];

        String decryptedContent;
        try {
          decryptedContent = await SecurityHelper.decryptData(content);
        } catch (e) {
          await file.delete();
          return [];
        }

        final list = json.decode(decryptedContent) as List<dynamic>;
        return list.map((item) => Product.fromRTDB(item['id'].toString(), item['shopId'].toString(), Map<dynamic, dynamic>.from(item))).toList();
      }
    } catch (e) {
      debugPrint('Error loading cached products: $e');
    }
    return [];
  }

  // Caching Offers
  static Future<void> cacheOffers(List<Offer> offers) async {
    _offerCacheTimer?.cancel();
    _offerCacheTimer = Timer(const Duration(seconds: 2), () async {
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
        'shopName': o.shopName,
      }).toList();

      final jsonString = json.encode(list);
      final encryptedString = await SecurityHelper.encryptData(jsonString);
      await file.writeAsString(encryptedString);
    } catch (e) {
      debugPrint('Error caching offers: $e');
    }
    }); // end Timer
  }

  static Future<List<Offer>> getCachedOffers() async {
    try {
      final file = await _getFile('cached_offers.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isEmpty) return [];

        String decryptedContent;
        try {
          decryptedContent = await SecurityHelper.decryptData(content);
        } catch (e) {
          await file.delete();
          return [];
        }

        final list = json.decode(decryptedContent) as List<dynamic>;
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
      final jsonString = json.encode(queue);
      final encryptedString = await SecurityHelper.encryptData(jsonString);
      await file.writeAsString(encryptedString);
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

        String decryptedContent;
        try {
          decryptedContent = await SecurityHelper.decryptData(content);
        } catch (e) {
          await file.delete();
          return [];
        }

        final list = json.decode(decryptedContent) as List<dynamic>;
        return list.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } catch (e) {
      debugPrint('Error loading sync queue: $e');
    }
    return [];
  }

  // Caching Location at caching time
  static Future<void> cacheLastLocation(double latitude, double longitude) async {
    try {
      final file = await _getFile('cached_location.json');
      final data = {'latitude': latitude, 'longitude': longitude};
      final jsonString = json.encode(data);
      final encryptedString = await SecurityHelper.encryptData(jsonString);
      await file.writeAsString(encryptedString);
    } catch (e) {
      debugPrint('Error caching last location: $e');
    }
  }

  static Future<Map<String, double>?> getCachedLastLocation() async {
    try {
      final file = await _getFile('cached_location.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isEmpty) return null;

        String decryptedContent;
        try {
          decryptedContent = await SecurityHelper.decryptData(content);
        } catch (e) {
          await file.delete();
          return null;
        }

        final map = json.decode(decryptedContent) as Map<String, dynamic>;
        return {
          'latitude': (map['latitude'] as num).toDouble(),
          'longitude': (map['longitude'] as num).toDouble(),
        };
      }
    } catch (e) {
      debugPrint('Error loading cached location: $e');
    }
    return null;
  }

  // Clear only location-specific cached files
  static Future<void> clearLocationCache() async {
    try {
      final files = ['cached_shops.json', 'cached_products.json', 'cached_offers.json', 'cached_location.json'];
      for (final filename in files) {
        final file = await _getFile(filename);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('Error clearing location cache: $e');
    }
  }

  // Clear all cached files upon secure logout
  static Future<void> clearCache() async {
    try {
      final files = ['cached_shops.json', 'cached_products.json', 'cached_offers.json', 'sync_queue.json', 'cached_location.json'];
      for (final filename in files) {
        final file = await _getFile(filename);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }
}
