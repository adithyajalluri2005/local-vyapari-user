import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:string_similarity/string_similarity.dart';

import 'package:local_vyapari_user/shared/models/product.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';
import 'package:local_vyapari_user/services/location/location_service.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_shops_provider.dart';

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

        final double centerLat = locationResult.latitude;
        final double centerLng = locationResult.longitude;

        // 1. Fetch nearby shops from RTDB
        final nearbyShops = ref.read(nearbyShopsProvider).value ?? [];
        if (nearbyShops.isEmpty) {
          state = const AsyncValue.data(HybridSearchResult());
          return;
        }

        final Map<String, double> shopDistances = {};
        for (final shop in nearbyShops) {
          shopDistances[shop.id] = Geolocator.distanceBetween(
            centerLat,
            centerLng,
            shop.location.latitude,
            shop.location.longitude,
          );
        }

        final bool isCapped = nearbyShops.length > 10;
        final closestShops = nearbyShops.take(10).toList();

        // 2. Fetch products for these nearby shops
        final List<Product> nearbyProducts = [];
        for (var shop in closestShops) {
          final productsSnapshot = await FirebaseDatabase.instance.ref().child('products').child(shop.id).get();
          if (productsSnapshot.exists && productsSnapshot.value != null) {
            final productsMap = productsSnapshot.value as Map<dynamic, dynamic>;
            productsMap.forEach((key, value) {
              if (value is Map) {
                try {
                  nearbyProducts.add(Product.fromRTDB(key.toString(), shop.id, Map<dynamic, dynamic>.from(value)));
                } catch (e) {
                  debugPrint('Error parsing product in search: $e');
                }
              }
            });
          }
        }

        // 3. Fuzzy Search Filtering
        final normalizedQuery = query.toLowerCase().trim();
        
        final filteredShops = nearbyShops.where((shop) {
          final searchableText = '${shop.shopName} ${shop.description}'.toLowerCase();
          return searchableText.contains(normalizedQuery) || 
                 searchableText.similarityTo(normalizedQuery) > 0.4 || 
                 normalizedQuery.similarityTo(shop.shopName.toLowerCase()) > 0.3;
        }).take(15).toList();

        final filteredProducts = nearbyProducts.where((product) {
          final searchableText = '${product.name} ${product.description}'.toLowerCase();
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
    });
  }
}

final hybridSearchProvider = NotifierProvider<HybridSearchNotifier, AsyncValue<HybridSearchResult>>(() {
  return HybridSearchNotifier();
});
