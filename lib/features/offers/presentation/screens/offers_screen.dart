import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_offers_provider.dart';

class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(nearbyOffersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Offers'),
        centerTitle: true,
      ),
      body: offersAsync.when(
        skipLoadingOnReload: false,
        data: (offers) {
          if (offers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_offer_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No active offers nearby',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: offers.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final offer = offers[index];
              final hasEndDate = offer.endDate != null;
              final daysLeft = hasEndDate ? offer.endDate!.difference(DateTime.now()).inDays : null;
              
              return GestureDetector(
                onTap: () => context.push('/offer_details', extra: offer),
                child: Container(
                  decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.15),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Row(
                    children: [
                      // Vibrant Discount Banner (Left Side)
                      Container(
                        width: 110,
                        height: 140,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${offer.discountPercentage.toInt()}%',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.0,
                              ),
                            ),
                            const Text(
                              'OFF',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white70,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Dotted divider effect
                      Container(
                        width: 1,
                        height: 140,
                        color: Colors.white,
                        child: CustomPaint(
                          painter: DottedLinePainter(),
                        ),
                      ),
                      // Offer Details (Right Side)
                      Expanded(
                        child: Container(
                          height: 140,
                          color: Theme.of(context).colorScheme.surface,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      offer.title,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (offer.isFeatured)
                                    const Icon(Icons.star, color: Colors.amber, size: 20),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child: Text(
                                  offer.description,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                    height: 1.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  if (daysLeft != null && daysLeft >= 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: daysLeft <= 2 ? AppTheme.errorColor.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.timer_outlined, 
                                            size: 12, 
                                            color: daysLeft <= 2 ? AppTheme.errorColor : Colors.orange.shade800
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            daysLeft == 0 ? 'Ends Today' : '$daysLeft days left',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: daysLeft <= 2 ? AppTheme.errorColor : Colors.orange.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    const SizedBox(),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Failed to load offers')),
      ),
    );
  }
}

class DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.4)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
      
    const dashHeight = 6.0;
    const dashSpace = 6.0;
    double startY = 0;
    
    while (startY < size.height) {
      canvas.drawLine(
        Offset(0, startY),
        Offset(0, startY + dashHeight),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
