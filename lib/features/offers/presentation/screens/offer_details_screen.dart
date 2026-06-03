import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/services/cache/app_cache_manager.dart';
import 'package:local_vyapari_user/shared/models/offer.dart';
import 'package:local_vyapari_user/features/shops/providers/shop_details_provider.dart';

class OfferDetailsScreen extends ConsumerWidget {
  final Offer offer;

  const OfferDetailsScreen({super.key, required this.offer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Responsive.init(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shopAsync = ref.watch(shopDetailsProvider(offer.shopId));

    final bannerWidget = _buildBannerHeader(context);
    final detailsWidget = _buildDetailsColumn(context, ref, shopAsync, isDark);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkScaffold : AppColors.background,
      appBar: AppBar(
        title: Text(
          'Offer Details',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        centerTitle: true,
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      ),
      body: SafeArea(
        child: Responsive.isTablet(context)
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 4, child: bannerWidget),
                  const VerticalDivider(width: 1),
                  Expanded(
                    flex: 6,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: detailsWidget,
                    ),
                  ),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 200, child: bannerWidget),
                    Padding(
                      padding: const EdgeInsets.all(20),
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
          colors: [AppColors.primaryDark, AppColors.primary],
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
              style: GoogleFonts.poppins(
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
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    'Valid until ${offer.endDate!.day}/${offer.endDate!.month}/${offer.endDate!.year}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsColumn(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<dynamic> shopAsync,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          offer.title,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Description',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          offer.description,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: isDark ? AppColors.textSecondary : const Color(0xFF475569),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 28),
        Divider(color: isDark ? Colors.white12 : AppColors.border),
        const SizedBox(height: 16),
        Text(
          'Available At',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        shopAsync.when(
          data: (shop) {
            if (shop == null) {
              return Text(
                'Shop details not available',
                style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textHint),
              );
            }
            return GestureDetector(
              onTap: () => context.push('/shop_details', extra: shop),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: isDark ? Colors.white12 : AppColors.border,
                    width: 0.8,
                  ),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                      backgroundImage: shop.shopLogo.isNotEmpty
                          ? CachedNetworkImageProvider(
                              shop.shopLogo,
                              cacheManager: AppCacheManager(),
                            )
                          : null,
                      child: shop.shopLogo.isEmpty
                          ? const Icon(Icons.store_rounded, color: AppColors.primary, size: 26)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shop.shopName,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                '${shop.rating} (${shop.totalReviews} reviews)',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.textHint,
                                ),
                              ),
                            ],
                          ),
                          if (shop.location.address.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined,
                                    size: 13, color: AppColors.textHint),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    shop.location.address,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11.5,
                                      color: AppColors.textHint,
                                    ),
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
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: isDark ? Colors.white38 : AppColors.textHint,
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Text(
            'Error loading shop details',
            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textHint),
          ),
        ),
      ],
    );
  }
}
