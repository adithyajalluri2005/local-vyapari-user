import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/core/theme/app_sizes.dart';
import 'package:local_vyapari_user/core/theme/app_text_styles.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_offers_provider.dart';

class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Responsive.init(context);
    final offersAsync = ref.watch(nearbyOffersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Nearby Offers',
          style: AppTextStyles.titleMedium(context, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: offersAsync.when(
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
                      style: AppTextStyles.titleLarge(context, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }
            
            final padding = AppSizes.paddingMedium(context);

            if (Responsive.isTablet(context)) {
              // Grid layout for tablets to prevent stretched mobile UI
              final crossAxisCount = MediaQuery.of(context).orientation == Orientation.portrait ? 2 : 3;
              return GridView.builder(
                padding: EdgeInsets.all(padding),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: padding,
                  mainAxisSpacing: padding,
                  mainAxisExtent: 150,
                ),
                itemCount: offers.length,
                itemBuilder: (context, index) {
                  return _buildOfferCard(context, offers[index]);
                },
              );
            }

            // ListView for phones
            return ListView.separated(
              padding: EdgeInsets.all(padding),
              itemCount: offers.length,
              separatorBuilder: (context, index) => SizedBox(height: padding),
              itemBuilder: (context, index) {
                return _buildOfferCard(context, offers[index]);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('Failed to load offers')),
        ),
      ),
    );
  }

  Widget _buildOfferCard(BuildContext context, dynamic offer) {
    final hasEndDate = offer.endDate != null;
    final daysLeft = hasEndDate ? offer.endDate!.difference(DateTime.now()).inDays : null;
    final padding = AppSizes.paddingMedium(context);

    return GestureDetector(
      onTap: () => context.push('/offer_details', extra: offer),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
          child: Row(
            children: [
              // Vibrant Discount Banner (Left Side)
              Container(
                width: Responsive.isSmallPhone(context) ? 90.0 : 110.0,
                height: 140,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryLight, AppTheme.primaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${offer.discountPercentage.toInt()}%',
                      style: TextStyle(
                        fontSize: Responsive.isSmallPhone(context) ? 26.0 : 32.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      'OFF',
                      style: TextStyle(
                        fontSize: Responsive.isSmallPhone(context) ? 14.0 : 18.0,
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
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              offer.title,
                              style: AppTextStyles.titleSmall(context, fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (offer.isFeatured)
                            const Icon(Icons.star, color: Colors.amber, size: 20),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Text(
                          offer.description,
                          style: AppTextStyles.bodyMedium(context, color: Colors.grey[600]).copyWith(
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
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
