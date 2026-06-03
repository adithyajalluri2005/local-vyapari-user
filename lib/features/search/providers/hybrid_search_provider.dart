import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:string_similarity/string_similarity.dart';

import 'package:local_vyapari_user/shared/models/product.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';
import 'package:local_vyapari_user/services/location/location_service.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_shops_provider.dart';

class HybridSearchResult {
  final List<Product> products;
  final List<Shop> shops;
  final bool isCapped;

  const HybridSearchResult({
    this.products = const [],
    this.shops = const [],
    this.isCapped = false,
  });
}

class LocationUnavailableException implements Exception {}
class NetworkOfflineException implements Exception {}

class HybridSearchNotifier extends Notifier<AsyncValue<HybridSearchResult>> {
  Timer? _debounceTimer;
  StreamSubscription? _searchSubscription;
  final double searchRadiusKm = 15.0;

  @override
  AsyncValue<HybridSearchResult> build() {
    ref.onDispose(() {
      _debounceTimer?.cancel();
      _searchSubscription?.cancel();
    });
    return const AsyncValue.data(HybridSearchResult());
  }

  void search(String query, {String? category}) {
    final trimmedQuery = query.trim();
    final bool hasQuery = trimmedQuery.isNotEmpty;
    final bool hasCategory = category != null && category.isNotEmpty;

    if (!hasQuery && !hasCategory) {
      _debounceTimer?.cancel();
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

        final nearbyShops = ref.read(nearbyShopsProvider).value ?? [];
        if (nearbyShops.isEmpty) {
          state = const AsyncValue.data(HybridSearchResult());
          return;
        }

        final Map<String, double> shopDistances = {};
        for (final shop in nearbyShops) {
          shopDistances[shop.id] = Geolocator.distanceBetween(
            centerLat, centerLng,
            shop.location.latitude, shop.location.longitude,
          );
        }

        final bool isCapped = nearbyShops.length > 10;
        final closestShops = nearbyShops.take(10).toList();

        // Fetch products for nearby shops in parallel
        final futures = closestShops.map(
          (shop) => FirebaseDatabase.instance.ref('products/${shop.id}').get(),
        );
        final snapshots = await Future.wait(futures);

        final List<Product> nearbyProducts = [];
        for (int i = 0; i < snapshots.length; i++) {
          final snap = snapshots[i];
          final shopId = closestShops[i].id;
          if (snap.exists && snap.value != null) {
            final map = snap.value as Map<dynamic, dynamic>;
            map.forEach((key, value) {
              if (value is Map) {
                try {
                  final p = Product.fromRTDB(
                    key.toString(), shopId, Map<dynamic, dynamic>.from(value));
                  if (p.isActive) nearbyProducts.add(p);
                } catch (e) {
                  debugPrint('Error parsing product: $e');
                }
              }
            });
          }
        }

        final normalizedQuery = trimmedQuery.toLowerCase();

        // ── Product filtering ───────────────────────────────────────
        // Category is an exact match; text is fuzzy on name + description + searchKeywords.
        final filteredProducts = nearbyProducts.where((p) {
          if (hasCategory && p.category.toLowerCase() != category.toLowerCase()) return false;
          if (!hasQuery) return true;
          final keywords = p.searchKeywords.join(' ').toLowerCase();
          final text = '${p.name} ${p.description} $keywords'.toLowerCase();
          return text.contains(normalizedQuery) ||
              text.similarityTo(normalizedQuery) > 0.4 ||
              normalizedQuery.similarityTo(p.name.toLowerCase()) > 0.3;
        }).toList();

        filteredProducts.sort((a, b) {
          final dA = shopDistances[a.shopId] ?? double.infinity;
          final dB = shopDistances[b.shopId] ?? double.infinity;
          return dA.compareTo(dB);
        });

        // ── Shop filtering ──────────────────────────────────────────
        // Text search: fuzzy match on shop name + description.
        // Category-only: show shops that carry matching products.
        List<Shop> filteredShops;
        if (hasQuery) {
          filteredShops = nearbyShops.where((s) {
            final text = '${s.shopName} ${s.description}'.toLowerCase();
            return text.contains(normalizedQuery) ||
                text.similarityTo(normalizedQuery) > 0.4 ||
                normalizedQuery.similarityTo(s.shopName.toLowerCase()) > 0.3;
          }).take(15).toList();
        } else {
          final shopIds = filteredProducts.map((p) => p.shopId).toSet();
          filteredShops = nearbyShops.where((s) => shopIds.contains(s.id)).toList();
        }

        state = AsyncValue.data(HybridSearchResult(
          products: filteredProducts.take(30).toList(),
          shops: filteredShops,
          isCapped: isCapped,
        ));
      } catch (e, st) {
        if (e.toString().contains('unavailable') ||
            e.toString().contains('SocketException')) {
          state = AsyncValue.error(NetworkOfflineException(), st);
        } else {
          state = AsyncValue.error(e, st);
        }
      }
    });
  }
}

final hybridSearchProvider =
    NotifierProvider<HybridSearchNotifier, AsyncValue<HybridSearchResult>>(
  HybridSearchNotifier.new,
);
