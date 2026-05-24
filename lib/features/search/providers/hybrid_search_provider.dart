import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:string_similarity/string_similarity.dart';

import 'package:local_vyapari_user/shared/models/product.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';
import 'package:local_vyapari_user/services/location/location_service.dart';

class HybridSearchResult {
  final List<Product> products;
  final List<Shop> shops;
  final bool isCapped;

  const HybridSearchResult({this.products = const [], this.shops = const [], this.isCapped = false});
}

class LocationUnavailableException implements Exception {}
class NetworkOfflineException implements Exception {}

class HybridSearchNotifier extends Notifier<AsyncValue<HybridSearchResult>> {
  Timer? _debounceTimer;
  StreamSubscription? _searchSubscription;
  final double searchRadiusKm = 15.0; // Fixed 15km radius

  @override
  AsyncValue<HybridSearchResult> build() {
    ref.onDispose(() {
      _debounceTimer?.cancel();
      _searchSubscription?.cancel();
    });
    return const AsyncValue.data(HybridSearchResult());
  }

  void search(String query) {
    if (query.trim().isEmpty) {
      _searchSubscription?.cancel();
      state = const AsyncValue.data(HybridSearchResult());
      return;
    }

    _debounceTimer?.cancel();
    _searchSubscription?.cancel();
    state = const AsyncValue.loading();
    
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final locationResult = ref.read(activeBrowsingLocationProvider).value;
        if (locationResult == null) {
          state = AsyncValue.error(LocationUnavailableException(), StackTrace.current);
          return;
        }

        final center = GeoFirePoint(GeoPoint(locationResult.latitude, locationResult.longitude));
        
        // 1. Fetch nearby shops from Firestore using GeoHash
        final stream = GeoCollectionReference(FirebaseFirestore.instance.collection('searchable_shops'))
            .subscribeWithin(
              center: center,
              radiusInKm: searchRadiusKm,
              field: 'geo',
              geopointFrom: (data) => (data['geo']['geopoint'] as GeoPoint),
              strictMode: true,
            );

        _searchSubscription = stream.listen((shopDocs) async {
          try {
            if (shopDocs.isEmpty) {
              state = const AsyncValue.data(HybridSearchResult());
              return;
            }

            final List<Shop> nearbyShops = [];
            final Map<String, double> shopDistances = {};

            for (var doc in shopDocs) {
              final data = doc.data();
              if (data != null) {
                final shopId = doc.id;
                final shopSnapshot = await FirebaseDatabase.instance.ref().child('shop/').get();
                if (shopSnapshot.exists && shopSnapshot.value != null) {
                  final shopData = shopSnapshot.value as Map<dynamic, dynamic>;
                  final shop = Shop.fromRTDB(shopId, shopData);
                  nearbyShops.add(shop);

                  final distance = Geolocator.distanceBetween(
                    center.latitude, center.longitude,
                    shop.location.latitude, shop.location.longitude,
                  );
                  shopDistances[shopId] = distance;
                }
              }
            }

            // Rank shops by distance
            nearbyShops.sort((a, b) => shopDistances[a.id]!.compareTo(shopDistances[b.id]!));

            final bool isCapped = nearbyShops.length > 10;
            final closestShops = nearbyShops.take(10).toList();

            // 2. Fetch products for these nearby shops
            final List<Product> nearbyProducts = [];
            for (var shop in closestShops) {
              final productsSnapshot = await FirebaseDatabase.instance.ref().child('products/').limitToFirst(50).get();
              if (productsSnapshot.exists && productsSnapshot.value != null) {
                final productsMap = productsSnapshot.value as Map<dynamic, dynamic>;
                productsMap.forEach((key, value) {
                  if (value is Map) {
                    nearbyProducts.add(Product.fromRTDB(key.toString(), shop.id, Map<dynamic, dynamic>.from(value)));
                  }
                });
              }
            }

            // 3. Fuzzy Search Filtering
            final normalizedQuery = query.toLowerCase().trim();
            
            final filteredShops = nearbyShops.where((shop) {
              final searchableText = ' '.toLowerCase();
              return searchableText.contains(normalizedQuery) || 
                     searchableText.similarityTo(normalizedQuery) > 0.4 || 
                     normalizedQuery.similarityTo(shop.shopName.toLowerCase()) > 0.3;
            }).take(15).toList();

            final filteredProducts = nearbyProducts.where((product) {
              final searchableText = '   '.toLowerCase();
              return searchableText.contains(normalizedQuery) || 
                     searchableText.similarityTo(normalizedQuery) > 0.4 ||
                     normalizedQuery.similarityTo(product.name.toLowerCase()) > 0.3;
            }).toList();

            filteredProducts.sort((a, b) {
              final distA = shopDistances[a.shopId] ?? double.infinity;
              final distB = shopDistances[b.shopId] ?? double.infinity;
              return distA.compareTo(distB);
            });

            state = AsyncValue.data(HybridSearchResult(
              products: filteredProducts.take(30).toList(),
              shops: filteredShops,
              isCapped: isCapped,
            ));
          } catch (e, st) {
            if (e.toString().contains('unavailable') || e.toString().contains('SocketException')) {
               state = AsyncValue.error(NetworkOfflineException(), st);
            } else {
               state = AsyncValue.error(e, st);
            }
          }
        }, onError: (e, st) {
          state = AsyncValue.error(e, st);
        });
      } catch (e, st) {
        state = AsyncValue.error(e, st);
      }
    });
  }
}

final hybridSearchProvider = NotifierProvider<HybridSearchNotifier, AsyncValue<HybridSearchResult>>(() {
  return HybridSearchNotifier();
});
