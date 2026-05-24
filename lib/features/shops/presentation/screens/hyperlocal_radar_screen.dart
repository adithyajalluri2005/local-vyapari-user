import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/core/theme/app_sizes.dart';
import 'package:local_vyapari_user/core/theme/app_text_styles.dart';
import 'package:local_vyapari_user/core/theme/app_spacing.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_shops_provider.dart';
import 'package:local_vyapari_user/services/location/location_service.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';
import 'package:local_vyapari_user/features/reviews/presentation/widgets/dynamic_shop_rating.dart';

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
        title: Text(
          'Hyperlocal Radar',
          style: AppTextStyles.titleMedium(context, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      backgroundColor: Colors.grey[950],
      body: SafeArea(
        child: locationAsync.when(
          data: (userLoc) {
            if (userLoc == null) {
              return Center(
                child: Text(
                  'Please set your location to activate radar.',
                  style: AppTextStyles.bodyLarge(context, color: Colors.white70),
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
                        padding: EdgeInsets.all(AppSizes.paddingLarge(context)),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final size = math.min(constraints.maxWidth, constraints.maxHeight);
                            final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
                            final radarRadius = size / 2;

                            // Compute radar positions for shops
                            final List<RadarShopPoint> shopPoints = [];
                            for (final shop in shops) {
                              final deltaLat = shop.location.latitude - userLoc.latitude;
                              final deltaLng = shop.location.longitude - userLoc.longitude;

                              final dy = deltaLat * 111139.0;
                              final dx = deltaLng * 111139.0 * math.cos(userLoc.latitude * math.pi / 180.0);
                              final distance = math.sqrt(dx * dx + dy * dy);

                              if (distance <= 15000) {
                                final ratio = distance / 15000.0;
                                final angle = math.atan2(dy, dx);
                                
                                final shopX = center.dx + (ratio * radarRadius) * math.cos(angle);
                                final shopY = center.dy - (ratio * radarRadius) * math.sin(angle);

                                shopPoints.add(RadarShopPoint(
                                  shop: shop,
                                  position: Offset(shopX, shopY),
                                  distance: distance,
                                ));
                              }
                            }

                            return GestureDetector(
                              onTapUp: (details) {
                                Shop? closestShop;
                                double minDistance = 24.0;

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
                                  // Static Background Layer
                                  Positioned.fill(
                                    child: RepaintBoundary(
                                      child: CustomPaint(
                                        painter: RadarBackgroundPainter(
                                          center: center,
                                          radius: radarRadius,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Animated Sweep Layer
                                  Positioned.fill(
                                    child: AnimatedBuilder(
                                      animation: _sweepController,
                                      builder: (context, child) {
                                        return RepaintBoundary(
                                          child: CustomPaint(
                                            painter: RadarSweepPainter(
                                              sweepAngle: _sweepController.value * 2 * math.pi,
                                              center: center,
                                              radius: radarRadius,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  // Shop Dots Layer
                                  Positioned.fill(
                                    child: RepaintBoundary(
                                      child: CustomPaint(
                                        painter: RadarDotsPainter(
                                          shopPoints: shopPoints,
                                          selectedShop: _selectedShop,
                                          center: center,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Overlay labels for radar bounds
                                  RepaintBoundary(
                                    child: Stack(
                                      children: [
                                  Positioned(
                                    left: center.dx + 4,
                                    top: center.dy - (radarRadius * 0.33) - 10,
                                    child: const Text('5 km', style: TextStyle(color: Colors.white38, fontSize: 10)),
                                  ),
                                  Positioned(
                                    left: center.dx + 4,
                                    top: center.dy - (radarRadius * 0.66) - 10,
                                    child: const Text('10 km', style: TextStyle(color: Colors.white38, fontSize: 10)),
                                  ),
                                  Positioned(
                                    left: center.dx + 4,
                                    top: center.dy - radarRadius - 10,
                                    child: const Text('15 km', style: TextStyle(color: Colors.white38, fontSize: 10)),
                                  ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // Bottom Shop Preview Drawer (Constrained and Centered for tablets)
                    if (_selectedShop != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 16,
                        child: RepaintBoundary(
                          child: Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 500),
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: EdgeInsets.all(AppSizes.paddingSmall(context)),
                            decoration: BoxDecoration(
                              color: Colors.grey[900]?.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                if (_selectedShop!.shopLogo.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(AppRadius.sm),
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
                                      borderRadius: BorderRadius.circular(AppRadius.sm),
                                    ),
                                    child: const Icon(Icons.store, color: Colors.white54),
                                  ),
                                AppSpacing.horizontalMd,
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
                                      DynamicShopRating(
                                        shopId: _selectedShop!.id,
                                        initialRating: _selectedShop!.rating,
                                        initialTotalReviews: _selectedShop!.totalReviews,
                                        builder: (context, rating, count) {
                                          return Row(
                                            children: [
                                              const Icon(Icons.star, color: Colors.amber, size: 16),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  '${rating.toStringAsFixed(1)} • ${_selectedShop!.location.city}',
                                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                AppSpacing.horizontalSm,
                                ElevatedButton(
                                  onPressed: () {
                                    context.push('/shop_details', extra: _selectedShop);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppRadius.sm),
                                    ),
                                  ),
                                  child: const Text('View'),
                                ),
                              ],
                            ),
                          ),
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
                  'Error loading radar shops',
                  style: AppTextStyles.bodyLarge(context, color: Colors.white70),
                ),
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (err, _) => Center(
            child: Text(
              'Error loading location',
              style: AppTextStyles.bodyLarge(context, color: Colors.white70),
            ),
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

class RadarBackgroundPainter extends CustomPainter {
  final Offset center;
  final double radius;

  RadarBackgroundPainter({required this.center, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, radius * 0.33, gridPaint);
    canvas.drawCircle(center, radius * 0.66, gridPaint);
    canvas.drawCircle(center, radius, gridPaint);

    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), gridPaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), gridPaint);
  }

  @override
  bool shouldRepaint(covariant RadarBackgroundPainter oldDelegate) => false;
}

class RadarSweepPainter extends CustomPainter {
  final double sweepAngle;
  final Offset center;
  final double radius;

  RadarSweepPainter({required this.sweepAngle, required this.center, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          Colors.green.withValues(alpha: 0.01),
          Colors.green.withValues(alpha: 0.15),
          Colors.green.withValues(alpha: 0.4),
        ],
        stops: const [0.0, 0.5, 0.75, 1.0],
        transform: GradientRotation(sweepAngle),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant RadarSweepPainter oldDelegate) => oldDelegate.sweepAngle != sweepAngle;
}

class RadarDotsPainter extends CustomPainter {
  final List<RadarShopPoint> shopPoints;
  final Shop? selectedShop;
  final Offset center;

  RadarDotsPainter({required this.shopPoints, required this.selectedShop, required this.center});

  @override
  void paint(Canvas canvas, Size size) {
    final userPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 6.0, userPaint);
    
    final userRingPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, 12.0, userRingPaint);

    final dotPaint = Paint()..style = PaintingStyle.fill;
    final haloPaint = Paint()..style = PaintingStyle.fill;

    for (final point in shopPoints) {
      final isSelected = selectedShop?.id == point.shop.id;

      if (isSelected) {
        dotPaint.color = Colors.redAccent;
        haloPaint.color = Colors.redAccent.withValues(alpha: 0.3);
        canvas.drawCircle(point.position, 12.0, haloPaint);
        canvas.drawCircle(point.position, 6.0, dotPaint);
      } else {
        dotPaint.color = Colors.greenAccent;
        haloPaint.color = Colors.greenAccent.withValues(alpha: 0.2);
        canvas.drawCircle(point.position, 8.0, haloPaint);
        canvas.drawCircle(point.position, 4.0, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant RadarDotsPainter oldDelegate) {
    return oldDelegate.selectedShop?.id != selectedShop?.id ||
        oldDelegate.shopPoints.length != shopPoints.length;
  }
}
