import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/features/shops/presentation/screens/hyperlocal_radar_screen.dart';
import 'package:local_vyapari_user/services/location/location_service.dart';
import 'package:local_vyapari_user/features/location/models/location_result.dart';

void main() {
  testWidgets('HyperlocalRadarScreen shows warning when location is null', (WidgetTester tester) async {
    // Render the radar screen with location provider returning null
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeBrowsingLocationProvider.overrideWith((ref) => const AsyncValue.data(null)),
        ],
        child: const MaterialApp(
          home: HyperlocalRadarScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify warning text is displayed
    expect(find.text('Please set your location to activate radar.'), findsOneWidget);
  });

  testWidgets('HyperlocalRadarScreen draws radar grid when location is loaded', (WidgetTester tester) async {
    final mockLocation = LocationResult(
      name: 'Tanuku',
      formattedAddress: 'Tanuku, AP, India',
      latitude: 16.75,
      longitude: 81.68,
      geohash: 'tgce',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeBrowsingLocationProvider.overrideWith((ref) => AsyncValue.data(mockLocation)),
        ],
        child: const MaterialApp(
          home: HyperlocalRadarScreen(),
        ),
      ),
    );

    // Let the animations start running
    await tester.pump(const Duration(milliseconds: 100));

    // Verify CustomPaint is present in the tree (drawing the radar)
    expect(find.byType(CustomPaint), findsOneWidget);
    
    // Verify that the null warning text is NOT shown
    expect(find.text('Please set your location to activate radar.'), findsNothing);
  });
}
