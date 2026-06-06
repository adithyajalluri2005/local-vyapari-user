import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:local_vyapari_user/shared/models/product.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';
import 'package:local_vyapari_user/services/location/location_service.dart';

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

        final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
            .httpsCallable('hyperlocalSearch');
        final response = await callable.call({
          'query': trimmedQuery,
          'category': category,
          'latitude': centerLat,
          'longitude': centerLng,
          'radiusKm': searchRadiusKm,
        });

        final data = response.data;
        if (data is! Map) {
          state = const AsyncValue.data(HybridSearchResult());
          return;
        }

        final List<Product> products = [];
        final List<Shop> shops = [];
        final bool isCapped = data['isCapped'] as bool? ?? false;

        if (data['products'] is List) {
          for (final item in data['products']) {
            if (item is Map) {
              try {
                final id = item['id']?.toString() ?? '';
                final shopId = item['shopId']?.toString() ?? '';
                products.add(Product.fromRTDB(
                  id,
                  shopId,
                  Map<dynamic, dynamic>.from(item),
                ));
              } catch (e) {
                debugPrint('Error parsing product from search result: $e');
              }
            }
          }
        }

        if (data['shops'] is List) {
          for (final item in data['shops']) {
            if (item is Map) {
              try {
                final id = item['id']?.toString() ?? '';
                shops.add(Shop.fromRTDB(
                  id,
                  Map<dynamic, dynamic>.from(item),
                ));
              } catch (e) {
                debugPrint('Error parsing shop from search result: $e');
              }
            }
          }
        }

        state = AsyncValue.data(HybridSearchResult(
          products: products,
          shops: shops,
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
