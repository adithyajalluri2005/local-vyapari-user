import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:local_vyapari_user/features/location/models/location_result.dart';
import 'package:local_vyapari_user/services/location/location_cache.dart';

final locationServiceProvider = Provider((ref) => LocationService());

// Notifier to manage active browsing location, with auto-initialization fallback to GPS
class ActiveBrowsingLocationNotifier extends Notifier<AsyncValue<LocationResult?>> {
  @override
  AsyncValue<LocationResult?> build() {
    final service = ref.watch(locationServiceProvider);
    
    service.streamActiveBrowsingLocation().listen((location) async {
      if (location == null) {
        try {
          final gpsLoc = await service.getGPSLocationResult();
          if (gpsLoc != null) {
            await service.saveActiveBrowsingLocation(gpsLoc);
            state = AsyncValue.data(gpsLoc);
          } else {
            state = const AsyncValue.data(null);
          }
        } catch (e, stack) {
          state = AsyncValue.error(e, stack);
        }
      } else {
        state = AsyncValue.data(location);
      }
    }, onError: (err, stack) {
      state = AsyncValue.error(err, stack);
    });

    return const AsyncValue.loading();
  }

  Future<void> changeLocation(LocationResult location) async {
    state = const AsyncValue.loading();
    await ref.read(locationServiceProvider).saveActiveBrowsingLocation(location);
    state = AsyncValue.data(location);
  }

  Future<bool> locateAndSetGPS() async {
    state = const AsyncValue.loading();
    try {
      final gpsLoc = await ref.read(locationServiceProvider).getGPSLocationResult();
      if (gpsLoc != null) {
        await ref.read(locationServiceProvider).saveActiveBrowsingLocation(gpsLoc);
        state = AsyncValue.data(gpsLoc);
        return true;
      } else {
        state = AsyncValue.error('Could not retrieve GPS location. Please check your settings or permissions.', StackTrace.current);
        return false;
      }
    } catch (e, stack) {
      state = AsyncValue.error('Error fetching GPS: $e', stack);
      return false;
    }
  }
}

final activeBrowsingLocationProvider = NotifierProvider<ActiveBrowsingLocationNotifier, AsyncValue<LocationResult?>>(() {
  return ActiveBrowsingLocationNotifier();
});

// Streams recent locations
final recentLocationsStreamProvider = StreamProvider<List<LocationResult>>((ref) {
  final service = ref.watch(locationServiceProvider);
  return service.streamRecentLocations();
});

class LocationService {
  final _activeLocationController = StreamController<LocationResult?>.broadcast();
  final _recentLocationsController = StreamController<List<LocationResult>>.broadcast();

  String get _apiKey => dotenv.env['GEOAPIFY_API_KEY'] ?? '';

  // Autocomplete search via Geoapify API
  Future<List<LocationResult>> searchAutocomplete(String query) async {
    if (query.trim().isEmpty) return [];
    if (_apiKey.isEmpty) {
      debugPrint('Geoapify API key is missing. Make sure GEOAPIFY_API_KEY is defined in .env');
      return [];
    }

    final url = Uri.parse(
      'https://api.geoapify.com/v1/geocode/autocomplete?text=${Uri.encodeComponent(query)}&apiKey=$_apiKey&limit=5',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List? ?? [];
        return features
            .map((f) => LocationResult.fromGeoapify(f['properties'] ?? {}))
            .toList();
      } else {
        debugPrint('Geoapify autocomplete error: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Geoapify request exception: $e');
      return [];
    }
  }

  // Save selected location as active browsing location
  Future<void> saveActiveBrowsingLocation(LocationResult location) async {
    try {
      await LocationCache.saveActiveLocation(location);
      _activeLocationController.add(location);

      await LocationCache.saveRecentLocation(location);
      final recents = await LocationCache.getRecentLocations();
      _recentLocationsController.add(recents);
    } catch (e) {
      debugPrint('Failed to save active location: $e');
    }
  }

  // Stream active browsing location
  Stream<LocationResult?> streamActiveBrowsingLocation() async* {
    final initial = await LocationCache.getActiveLocation();
    yield initial;
    yield* _activeLocationController.stream;
  }

  // Stream recent locations (ordered by date)
  Stream<List<LocationResult>> streamRecentLocations() async* {
    final initial = await LocationCache.getRecentLocations();
    yield initial;
    yield* _recentLocationsController.stream;
  }

  // Request GPS position and convert to LocationResult
  Future<LocationResult?> getGPSLocationResult() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled.');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied.');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 5));

      // Use reverse geocoding via Geoapify to fetch details or fall back to coordinates
      if (_apiKey.isNotEmpty) {
        final url = Uri.parse(
          'https://api.geoapify.com/v1/geocode/reverse?lat=${position.latitude}&lon=${position.longitude}&apiKey=$_apiKey',
        );
        final response = await http.get(url).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final features = data['features'] as List? ?? [];
          if (features.isNotEmpty) {
            return LocationResult.fromGeoapify(features.first['properties'] ?? {});
          }
        }
      }

      // Fallback geohash generation if reverse geocoding fails
      final geoPoint = GeoPoint(position.latitude, position.longitude);
      final geoFirePoint = GeoFirePoint(geoPoint);
      return LocationResult(
        name: 'GPS Location',
        formattedAddress: 'Current Coordinates: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
        latitude: position.latitude,
        longitude: position.longitude,
        geohash: geoFirePoint.geohash,
      );
    } catch (e) {
      debugPrint('Failed to get GPS location: $e');
      return null;
    }
  }
}
