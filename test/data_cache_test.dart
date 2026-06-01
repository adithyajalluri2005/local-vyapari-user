import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:local_vyapari_user/services/cache/data_cache_service.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';
import 'package:local_vyapari_user/shared/models/product.dart';
import 'package:local_vyapari_user/shared/models/offer.dart';

class MockPathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, String> secureStorageValues = {};

  setUp(() {
    PathProviderPlatform.instance = MockPathProviderPlatform();
    secureStorageValues.clear();
    
    const MethodChannel channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'read') {
        return secureStorageValues[methodCall.arguments['key']];
      } else if (methodCall.method == 'write') {
        secureStorageValues[methodCall.arguments['key']] = methodCall.arguments['value'] as String;
        return true;
      } else if (methodCall.method == 'delete') {
        secureStorageValues.remove(methodCall.arguments['key']);
        return true;
      }
      return null;
    });
  });

  group('DataCacheService Tests', () {
    test('Cache and retrieve Shops', () async {
      final shop = Shop(
        id: 'shop_123',
        ownerId: 'owner_456',
        shopName: 'Super Mart',
        description: 'Quality Goods',
        phone: '9876543210',
        shopLogo: 'https://logo.png',
        shopBanner: 'https://banner.png',
        isVerified: true,
        isOpen: true,
        storedIsOpen: true,
        rating: 4.8,
        totalReviews: 42,
        createdAt: DateTime(2026, 5, 21),
        location: ShopLocation(
          latitude: 16.75,
          longitude: 81.68,
          geohash: 'tgce',
          address: 'Main Rd',
          city: 'Tanuku',
          state: 'AP',
          pincode: '534211',
          placeId: 'place_id_123',
        ),
      );

      await DataCacheService.cacheShops([shop]);
      await Future.delayed(const Duration(seconds: 3)); // wait for 2-second debounce timer
      final retrieved = await DataCacheService.getCachedShops();

      expect(retrieved, isNotEmpty);
      expect(retrieved.first.id, 'shop_123');
      expect(retrieved.first.shopName, 'Super Mart');
      expect(retrieved.first.location.city, 'Tanuku');
      expect(retrieved.first.rating, 4.8);
      expect(retrieved.first.isVerified, isTrue);
    });

    test('Cache and retrieve Products', () async {
      final product = Product(
        id: 'prod_99',
        shopId: 'shop_123',
        ownerId: 'owner_456',
        name: 'Fresh Apples',
        description: 'Organic apples from farms',
        category: 'Fruits',
        actualPrice: 120.0,
        offerPrice: 99.0,
        stockQuantity: 50,
        isLowStock: false,
        isOutOfStock: false,
        isActive: true,
        images: ['https://apple.png'],
        searchKeywords: ['apple', 'fruit'],
        createdAt: DateTime(2026, 5, 21),
      );

      await DataCacheService.cacheProducts([product]);
      await Future.delayed(const Duration(seconds: 3)); // wait for 2-second debounce timer
      final retrieved = await DataCacheService.getCachedProducts();

      expect(retrieved, isNotEmpty);
      expect(retrieved.first.id, 'prod_99');
      expect(retrieved.first.name, 'Fresh Apples');
      expect(retrieved.first.offerPrice, 99.0);
      expect(retrieved.first.category, 'Fruits');
    });

    test('Cache and retrieve Offers', () async {
      final offer = Offer(
        id: 'off_77',
        shopId: 'shop_123',
        productId: 'prod_99',
        ownerId: 'owner_456',
        title: 'Super Deal',
        description: 'Limited period deal',
        discountPercentage: 20.0,
        startDate: DateTime(2026, 5, 20),
        endDate: DateTime(2026, 5, 25),
        isActive: true,
        isFeatured: true,
        createdAt: DateTime(2026, 5, 21),
      );

      await DataCacheService.cacheOffers([offer]);
      await Future.delayed(const Duration(seconds: 3)); // wait for 2-second debounce timer
      final retrieved = await DataCacheService.getCachedOffers();

      expect(retrieved, isNotEmpty);
      expect(retrieved.first.id, 'off_77');
      expect(retrieved.first.title, 'Super Deal');
      expect(retrieved.first.discountPercentage, 20.0);
      expect(retrieved.first.isFeatured, isTrue);
    });
  });
}
