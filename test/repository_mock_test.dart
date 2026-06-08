import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';
import 'package:local_vyapari_user/shared/models/product.dart';
import 'package:local_vyapari_user/shared/models/offer.dart';
import 'package:local_vyapari_user/repositories/shop_repository.dart';
import 'package:local_vyapari_user/repositories/product_repository.dart';
import 'package:local_vyapari_user/repositories/offer_repository.dart';

// Define Mock Repositories
class MockShopRepository implements ShopRepository {
  final List<Shop> shops;
  MockShopRepository({required this.shops});

  @override
  Stream<List<Shop>> getNearbyShops({
    required double latitude,
    required double longitude,
    required double radiusInKm,
  }) {
    return Stream.value(shops);
  }

  @override
  Stream<List<String>> streamNearbyShopIds({
    required double latitude,
    required double longitude,
    required double radiusInKm,
  }) {
    return Stream.value(shops.map((s) => s.id).toList());
  }

  @override
  Stream<List<Shop>> streamShopsByIds(List<String> shopIds) {
    return Stream.value(shops.where((s) => shopIds.contains(s.id)).toList());
  }

  @override
  Future<Shop?> getShopDetails(String shopId) async {
    return shops.firstWhere((s) => s.id == shopId, orElse: () => throw Exception('Shop not found'));
  }

  @override
  Stream<Shop?> streamShopDetails(String shopId) {
    return Stream.value(shops.firstWhere((s) => s.id == shopId, orElse: () => throw Exception('Shop not found')));
  }
}

class MockProductRepository implements ProductRepository {
  final List<Product> products;
  MockProductRepository({required this.products});

  @override
  Stream<List<Product>> getShopProducts(String shopId) {
    return Stream.value(products.where((p) => p.shopId == shopId).toList());
  }

  @override
  Future<List<Product>> getNearbyProducts(List<String> shopIds) async {
    return products.where((p) => shopIds.contains(p.shopId)).toList();
  }

  @override
  Future<Product?> getProductDetails(String shopId, String productId) async {
    return products.firstWhere((p) => p.shopId == shopId && p.id == productId);
  }

  @override
  Stream<Product?> streamProductDetails(String shopId, String productId) {
    return Stream.value(products.firstWhere((p) => p.shopId == shopId && p.id == productId));
  }
}

class MockOfferRepository implements OfferRepository {
  final List<Offer> offers;
  MockOfferRepository({required this.offers});

  @override
  Future<List<Offer>> getShopOffers(String shopId) async {
    return offers.where((o) => o.shopId == shopId).toList();
  }

  @override
  Future<List<Offer>> getNearbyOffers(List<String> shopIds) async {
    return offers.where((o) => shopIds.contains(o.shopId)).toList();
  }

  @override
  Future<Offer?> getOfferDetails(String shopId, String offerId) async {
    return offers.firstWhere((o) => o.shopId == shopId && o.id == offerId);
  }

  @override
  Stream<Offer?> streamOfferDetails(String shopId, String offerId) {
    return Stream.value(offers.firstWhere((o) => o.shopId == shopId && o.id == offerId));
  }
}

void main() {
  group('Repository Pattern Mocking Tests', () {
    test('MockShopRepository returns mocked shops', () async {
      final mockShop = Shop(
        id: 'shop_1',
        ownerId: 'owner_1',
        shopName: 'Test Shop',
        description: 'Test Description',
        shopLogo: '',
        shopBanner: '',
        phone: '1234567890',
        location: ShopLocation(
          latitude: 12.0,
          longitude: 77.0,
          address: 'Test Address',
          city: 'Test City',
          geohash: '',
          state: 'Test State',
          pincode: '123456',
          placeId: 'place_1',
        ),
        isVerified: true,
        isOpen: true,
        storedIsOpen: true,
        rating: 4.5,
        totalReviews: 10,
        createdAt: DateTime.now(),
      );

      final container = ProviderContainer(
        overrides: [
          shopRepositoryProvider.overrideWithValue(MockShopRepository(shops: [mockShop])),
        ],
      );

      final repo = container.read(shopRepositoryProvider);
      final list = await repo.getNearbyShops(latitude: 12.0, longitude: 77.0, radiusInKm: 15.0).first;
      expect(list, hasLength(1));
      expect(list.first.shopName, 'Test Shop');
      expect(list.first.isVerified, isTrue);
    });

    test('MockProductRepository returns mocked products', () async {
      final mockProduct = Product(
        id: 'prod_1',
        shopId: 'shop_1',
        ownerId: 'owner_1',
        name: 'Test Product',
        description: 'Test Description',
        actualPrice: 100.0,
        offerPrice: 80.0,
        images: [],
        category: 'Test Category',
        isActive: true,
        isOutOfStock: false,
        stockQuantity: 10,
        isLowStock: false,
        searchKeywords: [],
        rating: 4.0,
        totalReviews: 5,
        createdAt: DateTime.now(),
      );

      final container = ProviderContainer(
        overrides: [
          productRepositoryProvider.overrideWithValue(MockProductRepository(products: [mockProduct])),
        ],
      );

      final repo = container.read(productRepositoryProvider);
      final list = await repo.getNearbyProducts(['shop_1']);
      expect(list, hasLength(1));
      expect(list.first.name, 'Test Product');
      expect(list.first.offerPrice, 80.0);
    });

    test('MockOfferRepository returns mocked offers', () async {
      final mockOffer = Offer(
        id: 'offer_1',
        shopId: 'shop_1',
        productId: 'prod_1',
        ownerId: 'owner_1',
        title: 'Test Offer',
        description: 'Test Offer Description',
        discountPercentage: 20.0,
        isActive: true,
        isFeatured: false,
        startDate: DateTime.now().subtract(const Duration(days: 1)),
        endDate: DateTime.now().add(const Duration(days: 1)),
        createdAt: DateTime.now(),
      );

      final container = ProviderContainer(
        overrides: [
          offerRepositoryProvider.overrideWithValue(MockOfferRepository(offers: [mockOffer])),
        ],
      );

      final repo = container.read(offerRepositoryProvider);
      final list = await repo.getNearbyOffers(['shop_1']);
      expect(list, hasLength(1));
      expect(list.first.title, 'Test Offer');
      expect(list.first.discountPercentage, 20.0);
    });
  });
}
