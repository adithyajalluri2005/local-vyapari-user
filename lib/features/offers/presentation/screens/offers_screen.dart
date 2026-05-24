import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/core/theme/app_sizes.dart';
import 'package:local_vyapari_user/core/theme/app_text_styles.dart';
import 'package:local_vyapari_user/core/theme/app_spacing.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_offers_provider.dart';
import 'package:local_vyapari_user/shared/models/offer.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';
import 'package:local_vyapari_user/features/shops/providers/shop_details_provider.dart';

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

            // Group offers by shopId
            final Map<String, List<Offer>> shopOffers = {};
            for (var offer in offers) {
              shopOffers.putIfAbsent(offer.shopId, () => []).add(offer);
            }
            final shopIds = shopOffers.keys.toList();
            final padding = AppSizes.paddingMedium(context);

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView.builder(
                  padding: EdgeInsets.all(padding),
                  itemCount: shopIds.length,
                  itemBuilder: (context, index) {
                    final shopId = shopIds[index];
                    return ShopOffersCard(
                      shopId: shopId,
                      offers: shopOffers[shopId]!,
                    );
                  },
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('Failed to load offers')),
        ),
      ),
    );
  }
}

class ShopOffersCard extends ConsumerStatefulWidget {
  final String shopId;
  final List<Offer> offers;

  const ShopOffersCard({
    super.key,
    required this.shopId,
    required this.offers,
  });

  @override
  ConsumerState<ShopOffersCard> createState() => _ShopOffersCardState();
}

class _ShopOffersCardState extends ConsumerState<ShopOffersCard> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(shopDetailsProvider(widget.shopId));
    final padding = AppSizes.paddingMedium(context);

    return Card(
      elevation: 2,
      shadowColor: AppTheme.primaryColor.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Shop Header
          shopAsync.when(
            data: (shop) {
              if (shop == null) return const SizedBox();
              return InkWell(
                onTap: () => context.push('/shop_details', extra: shop),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
                child: Padding(
                  padding: EdgeInsets.all(padding),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                        backgroundImage: shop.shopLogo.isNotEmpty ? CachedNetworkImageProvider(shop.shopLogo) : null,
                        child: shop.shopLogo.isEmpty
                            ? const Icon(Icons.store, color: AppTheme.primaryColor, size: 20)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shop.shopName,
                              style: AppTextStyles.bodyLarge(context, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (shop.location.address.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                shop.location.address,
                                style: AppTextStyles.bodyMedium(context, color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              );
            },
            loading: () => Padding(
              padding: EdgeInsets.all(padding),
              child: Row(
                children: [
                  CircleAvatar(radius: 20, backgroundColor: Colors.grey[200]),
                  const SizedBox(width: 12),
                  Container(width: 100, height: 16, color: Colors.grey[200]),
                ],
              ),
            ),
            error: (_, __) => const SizedBox(),
          ),

          const Divider(height: 1),

          // 2. Swipable Offers PageView
          SizedBox(
            height: 155,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.offers.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                final offer = widget.offers[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: _buildOfferCarouselCard(context, offer),
                );
              },
            ),
          ),

          // 3. Dot Indicators if more than 1 offer
          if (widget.offers.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.offers.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentPage == index ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _currentPage == index ? AppTheme.primaryColor : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOfferCarouselCard(BuildContext context, Offer offer) {
    final hasEndDate = offer.endDate != null;
    final daysLeft = hasEndDate ? offer.endDate!.difference(DateTime.now()).inDays : null;

    return GestureDetector(
      onTap: () => _showOfferDetailsDialog(context, offer),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
          child: Row(
            children: [
              // Left side - Discount Badge
              Container(
                width: 90.0,
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
                      style: const TextStyle(
                        fontSize: 26.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                    const Text(
                      'OFF',
                      style: TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w800,
                        color: Colors.white70,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              // Dotted Line Divider
              Container(
                width: 1,
                color: Colors.white,
                child: CustomPaint(
                  painter: DottedLinePainter(),
                ),
              ),
              // Right side - Text Details
              Expanded(
                child: Container(
                  color: Theme.of(context).colorScheme.surface,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              offer.title,
                              style: AppTextStyles.bodyLarge(context, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (offer.isFeatured)
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        offer.description,
                        style: AppTextStyles.bodyMedium(context, color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (daysLeft != null && daysLeft >= 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: daysLeft <= 2
                                    ? AppTheme.errorColor.withValues(alpha: 0.1)
                                    : Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                daysLeft == 0 ? 'Ends Today' : '$daysLeft days left',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: daysLeft <= 2 ? AppTheme.errorColor : Colors.orange.shade800,
                                ),
                              ),
                            )
                          else
                            const SizedBox(),
                          Text(
                            'Tap for details',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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

  void _showOfferDetailsDialog(BuildContext context, Offer offer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top notch
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Discount Tag and Title
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryLight, AppTheme.primaryColor],
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      '${offer.discountPercentage.toInt()}% OFF',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      offer.title,
                      style: AppTextStyles.titleMedium(context, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (offer.endDate != null) ...[
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Valid until ${offer.endDate!.day}/${offer.endDate!.month}/${offer.endDate!.year}',
                      style: AppTextStyles.bodyMedium(context, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Description',
                style: AppTextStyles.bodyLarge(context, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                offer.description,
                style: AppTextStyles.bodyLarge(context, color: Colors.grey.shade700, height: 1.5),
              ),
              const SizedBox(height: 24),
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ref.read(shopDetailsProvider(widget.shopId)).whenData((shop) {
                          if (shop != null) {
                            context.push('/shop_details', extra: shop);
                          }
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: const Text('Visit Shop'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

class DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.4)
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
