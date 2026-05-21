import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_shops_provider.dart';
import 'package:local_vyapari_user/services/location/location_service.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';

class HyperlocalRadarScreen extends ConsumerStatefulWidget {
  const HyperlocalRadarScreen({super.key});

  @override
  ConsumerState<HyperlocalRadarScreen> createState() => _HyperlocalRadarScreenState();
}

class _HyperlocalRadarScreenState extends ConsumerState<HyperlocalRadarScreen> with SingleTickerProviderStateMixin {
  late AnimationController _sweepController;
  Shop? _selectedShop;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationAsync = ref.watch(activeBrowsingLocationProvider);
    final shopsAsync = ref.watch(nearbyShopsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hyperlocal Radar'),
        centerTitle: true,
      ),
      backgroundColor: Colors.grey[950],
      body: locationAsync.when(
        data: (userLoc) {
          if (userLoc == null) {
            return const Center(
              child: Text(
                'Please set your location to activate radar.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return shopsAsync.when(
            data: (shops) {
              return Stack(
                children: [
                  // Radar Screen Background & Visuals
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final size = math.min(constraints.maxWidth, constraints.maxHeight);
                          final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
                          final radarRadius = size / 2;

                          // Compute radar positions for shops
                          final List<RadarShopPoint> shopPoints = [];
                          for (final shop in shops) {
                            // Calculate delta in meters using simple equirectangular projection approximation
                            final deltaLat = shop.location.latitude - userLoc.latitude;
                            final deltaLng = shop.location.longitude - userLoc.longitude;

                            final dy = deltaLat * 111139.0;
                            final dx = deltaLng * 111139.0 * math.cos(userLoc.latitude * math.pi / 180.0);
                            final distance = math.sqrt(dx * dx + dy * dy);

                            if (distance <= 15000) {
                              // Map distance onto radar coordinates
                              final ratio = distance / 15000.0;
                              final angle = math.atan2(dy, dx);
                              
                              final shopX = center.dx + (ratio * radarRadius) * math.cos(angle);
                              final shopY = center.dy - (ratio * radarRadius) * math.sin(angle); // Flutter Y is down

                              shopPoints.add(RadarShopPoint(
                                shop: shop,
                                position: Offset(shopX, shopY),
                                distance: distance,
                              ));
                            }
                          }

                          return GestureDetector(
                            onTapUp: (details) {
                              // Find closest shop tapped
                              Shop? closestShop;
                              double minDistance = 24.0; // Tap hit-box radius

                              for (final point in shopPoints) {
                                final dist = (details.localPosition - point.position).distance;
                                if (dist < minDistance) {
                                  minDistance = dist;
                                  closestShop = point.shop;
                                }
                              }

                              setState(() {
                                _selectedShop = closestShop;
                              });
                            },
                            child: Stack(
                              children: [
                                // Radar Drawing Layer
                                Positioned.fill(
                                  child: AnimatedBuilder(
                                    animation: _sweepController,
                                    builder: (context, child) {
                                      return CustomPaint(
                                        painter: RadarPainter(
                                          sweepAngle: _sweepController.value * 2 * math.pi,
                                          shopPoints: shopPoints,
                                          selectedShop: _selectedShop,
                                          center: center,
                                          radius: radarRadius,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                // Overlay labels for radar bounds
                                Positioned(
                                  left: center.dx + 4,
                                  top: center.y - (radarRadius * 0.33) - 10,
                                  child: const Text('5 km', style: TextStyle(color: Colors.white38, fontSize: 10)),
                                ),
                                Positioned(
                                  left: center.dx + 4,
                                  top: center.y - (radarRadius * 0.66) - 10,
                                  child: const Text('10 km', style: TextStyle(color: Colors.white38, fontSize: 10)),
                                ),
                                Positioned(
                                  left: center.dx + 4,
                                  top: center.y - radarRadius - 10,
                                  child: const Text('15 km', style: TextStyle(color: Colors.white38, fontSize: 10)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Bottom Shop Preview Drawer
                  if (_selectedShop != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[900]?.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            if (_selectedShop!.shopLogo.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  _selectedShop!.shopLogo,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                              )
                            else
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.grey[800],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.store, color: Colors.white54),
                              ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _selectedShop!.shopName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.star, color: Colors.amber, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${_selectedShop!.rating} • ${_selectedShop!.location.city}',
                                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                context.push('/shop_details', extra: _selectedShop);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('View'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (err, _) => Center(
              child: Text(
                'Error loading radar shops: $err',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (err, _) => Center(
          child: Text(
            'Error loading location: $err',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }
}

class RadarShopPoint {
  final Shop shop;
  final Offset position;
  final double distance;

  RadarShopPoint({
    required this.shop,
    required this.position,
    required this.distance,
  });
}

class RadarPainter extends CustomPainter {
  final double sweepAngle;
  final List<RadarShopPoint> shopPoints;
  final Shop? selectedShop;
  final Offset center;
  final double radius;

  RadarPainter({
    required this.sweepAngle,
    required this.shopPoints,
    required this.selectedShop,
    required this.center,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Background Grid
    final gridPaint = Paint()
      ..color = Colors.green.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw concentric circles (5km, 10km, 15km)
    canvas.drawCircle(center, radius * 0.33, gridPaint);
    canvas.drawCircle(center, radius * 0.66, gridPaint);
    canvas.drawCircle(center, radius, gridPaint);

    // Draw crosshairs
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), gridPaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), gridPaint);

    // 2. Draw Sweep Effect
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          Colors.green.withOpacity(0.01),
          Colors.green.withOpacity(0.15),
          Colors.green.withOpacity(0.4),
        ],
        stops: const [0.0, 0.5, 0.75, 1.0],
        transform: GradientRotation(sweepAngle),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, sweepPaint);

    // 3. Draw Center Dot (User Location)
    final userPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 6.0, userPaint);
    
    // Draw outer pulsing ring for user location
    final userRingPaint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, 12.0, userRingPaint);

    // 4. Draw Shop Points
    final dotPaint = Paint()..style = PaintingStyle.fill;
    final haloPaint = Paint()..style = PaintingStyle.fill;

    for (final point in shopPoints) {
      final isSelected = selectedShop?.id == point.shop.id;

      if (isSelected) {
        dotPaint.color = Colors.redAccent;
        haloPaint.color = Colors.redAccent.withOpacity(0.3);
        canvas.drawCircle(point.position, 12.0, haloPaint);
        canvas.drawCircle(point.position, 6.0, dotPaint);
      } else {
        dotPaint.color = Colors.greenAccent;
        haloPaint.color = Colors.greenAccent.withOpacity(0.2);
        canvas.drawCircle(point.position, 8.0, haloPaint);
        canvas.drawCircle(point.position, 4.0, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle ||
        oldDelegate.selectedShop?.id != selectedShop?.id ||
        oldDelegate.shopPoints.length != shopPoints.length;
  }
}
