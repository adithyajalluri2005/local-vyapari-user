import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/features/shops/presentation/screens/hyperlocal_radar_screen.dart';
import 'package:local_vyapari_user/services/location/location_service.dart';
import 'package:local_vyapari_user/features/location/models/location_result.dart';

class MockActiveBrowsingLocationNotifier extends ActiveBrowsingLocationNotifier {
  final AsyncValue<LocationResult?> mockValue;
  MockActiveBrowsingLocationNotifier(this.mockValue);

  @override
  AsyncValue<LocationResult?> build() => mockValue;
}

void main() {
  testWidgets('HyperlocalRadarScreen shows warning when location is null', (WidgetTester tester) async {
    // Render the radar screen with location provider returning null
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeBrowsingLocationProvider.overrideWith(() => MockActiveBrowsingLocationNotifier(const AsyncValue.data(null))),
        ],
        child: const MaterialApp(
          home: HyperlocalRadarScreen(),
        ),
      ),
    );

    // Pump a single frame instead of pumpAndSettle, since repeating animations (radar sweep) prevent settling
    await tester.pump();

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
          activeBrowsingLocationProvider.overrideWith(() => MockActiveBrowsingLocationNotifier(AsyncValue.data(mockLocation))),
        ],
        child: const MaterialApp(
          home: HyperlocalRadarScreen(),
        ),
      ),
    );

    // Let the animations start running
    await tester.pump(const Duration(milliseconds: 100));

    // Verify CustomPaint is present in the tree (drawing the radar)
    expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
    
    // Verify that the null warning text is NOT shown
    expect(find.text('Please set your location to activate radar.'), findsNothing);
  });
}
