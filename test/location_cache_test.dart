import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_vyapari_user/features/location/models/location_result.dart';
import 'package:local_vyapari_user/services/location/location_cache.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PathProviderPlatform.instance = MockPathProviderPlatform();
  });

  test('LocationCache saves and retrieves active location', () async {
    final location = LocationResult(
      name: 'Tanuku',
      formattedAddress: 'Tanuku, Andhra Pradesh, India',
      latitude: 16.751491,
      longitude: 81.687432,
      geohash: 'tgcebh83h',
    );

    await LocationCache.saveActiveLocation(location);
    final retrieved = await LocationCache.getActiveLocation();

    expect(retrieved, isNotNull);
    expect(retrieved!.name, 'Tanuku');
    expect(retrieved.latitude, 16.751491);
    expect(retrieved.longitude, 81.687432);
    expect(retrieved.geohash, 'tgcebh83h');
  });

  test('LocationCache saves and retrieves recent locations', () async {
    final location = LocationResult(
      name: 'Bhimavaram',
      formattedAddress: 'Bhimavaram, Andhra Pradesh, India',
      latitude: 16.544893,
      longitude: 81.522234,
      geohash: 'tgc9yheq3',
    );

    await LocationCache.saveRecentLocation(location);
    final retrieved = await LocationCache.getRecentLocations();

    expect(retrieved, isNotEmpty);
    expect(retrieved.first.name, 'Bhimavaram');
  });
}
