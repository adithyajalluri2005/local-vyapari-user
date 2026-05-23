import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/core/theme/app_sizes.dart';
import 'package:local_vyapari_user/core/theme/app_text_styles.dart';
import 'package:local_vyapari_user/shared/models/offer.dart';
import 'package:local_vyapari_user/features/shops/providers/shop_details_provider.dart';

class OfferDetailsScreen extends ConsumerWidget {
  final Offer offer;

  const OfferDetailsScreen({super.key, required this.offer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Responsive.init(context);
    final shopAsync = ref.watch(shopDetailsProvider(offer.shopId));
    final padding = AppSizes.paddingLarge(context);

    final bannerWidget = _buildBannerHeader(context);
    final detailsWidget = _buildDetailsColumn(context, shopAsync);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Offer Details',
          style: AppTextStyles.titleMedium(context, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Responsive.isTablet(context)
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 4,
                    child: bannerWidget,
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    flex: 6,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(padding),
                      child: detailsWidget,
                    ),
                  ),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 200,
                      child: bannerWidget,
                    ),
                    Padding(
                      padding: EdgeInsets.all(padding),
                      child: detailsWidget,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildBannerHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryLight, AppTheme.primaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${offer.discountPercentage.toInt()}% OFF',
              style: TextStyle(
                fontSize: Responsive.isTablet(context) ? 56 : 48,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            if (offer.endDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Valid until ${offer.endDate!.day}/${offer.endDate!.month}/${offer.endDate!.year}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsColumn(BuildContext context, AsyncValue<dynamic> shopAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          offer.title,
          style: AppTextStyles.titleLarge(context, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text(
          'Description',
          style: AppTextStyles.titleMedium(context, color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          offer.description,
          style: AppTextStyles.bodyLarge(context, color: Colors.grey.shade700, height: 1.5),
        ),
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 16),
        Text(
          'Available At',
          style: AppTextStyles.titleMedium(context, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        
        // Shop Details Card Integration
        shopAsync.when(
          data: (shop) {
            if (shop == null) return const Text('Shop details not available');
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: InkWell(
                onTap: () => context.push('/shop_details', extra: shop),
                borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
                child: Padding(
                  padding: EdgeInsets.all(AppSizes.paddingMedium(context)),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                        backgroundImage: shop.shopLogo.isNotEmpty ? NetworkImage(shop.shopLogo) : null,
                        child: shop.shopLogo.isEmpty ? const Icon(Icons.store, color: AppTheme.primaryColor, size: 30) : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shop.shopName,
                              style: AppTextStyles.titleSmall(context, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.star, size: 16, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(
                                  '${shop.rating} (${shop.totalReviews} reviews)',
                                  style: AppTextStyles.bodyMedium(context, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                            if (shop.location.address.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.location_on, size: 14, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      shop.location.address,
                                      style: AppTextStyles.bodyMedium(context, color: Colors.grey.shade600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Text('Error loading shop details'),
        ),
      ],
    );
  }
}
