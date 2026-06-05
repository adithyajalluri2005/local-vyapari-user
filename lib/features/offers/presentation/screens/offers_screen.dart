import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_offers_provider.dart';
import 'package:local_vyapari_user/features/shops/providers/shop_details_provider.dart';
import 'package:local_vyapari_user/services/cache/app_cache_manager.dart';
import 'package:local_vyapari_user/shared/models/offer.dart';
import 'package:local_vyapari_user/shared/widgets/app_animations.dart';

class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final offersAsync = ref.watch(nearbyOffersProvider);
    final hPad = Responsive.horizontalPadding(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkScaffold : AppColors.background,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Offers & Deals',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border.withValues(alpha: 0.5)),
        ),
      ),
      body: offersAsync.when(
        skipLoadingOnReload: true,
        loading: () => _ShimmerOffers(hPad: hPad),
        error: (_, _) => Center(
          child: Text(
            'Failed to load offers',
            style: GoogleFonts.poppins(color: AppColors.textHint),
          ),
        ),
        data: (offers) {
          if (offers.isEmpty) return const _EmptyView();

          final Map<String, List<Offer>> byShop = {};
          for (final o in offers) {
            byShop.putIfAbsent(o.shopId, () => []).add(o);
          }
          final shopIds = byShop.keys.toList();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 90),
                itemCount: shopIds.length,
                itemBuilder: (_, i) => FadeInSlide(
                  delay: Duration(milliseconds: 80 * i),
                  child: _ShopOffersCard(
                    shopId: shopIds[i],
                    offers: byShop[shopIds[i]]!,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Per-shop card with swipeable offers ───────────────────────────────────────

class _ShopOffersCard extends ConsumerStatefulWidget {
  final String shopId;
  final List<Offer> offers;
  const _ShopOffersCard({required this.shopId, required this.offers});

  @override
  ConsumerState<_ShopOffersCard> createState() => _ShopOffersCardState();
}

class _ShopOffersCardState extends ConsumerState<_ShopOffersCard> {
  late final PageController _page;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _page = PageController();
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shopAsync = ref.watch(shopDetailsProvider(widget.shopId));
    final cardBg = isDark ? AppColors.darkSurface : AppColors.surface;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.border,
          width: 0.7,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.055),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Shop header ──────────────────────────────────────────
          shopAsync.when(
            data: (shop) {
              if (shop == null) return const SizedBox.shrink();
              return ScaleOnTap(
                onTap: () => context.push('/shop_details', extra: shop),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.08),
                          image: shop.shopLogo.isNotEmpty
                              ? DecorationImage(
                                  image: CachedNetworkImageProvider(shop.shopLogo, cacheManager: AppCacheManager()),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: shop.shopLogo.isEmpty
                            ? const Icon(Icons.storefront_outlined, size: 18, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 10),
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (shop.location.address.isNotEmpty)
                              Text(
                                shop.location.address,
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  color: AppColors.textHint,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textHint),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(radius: 19, backgroundColor: AppColors.surfaceElevated),
                  SizedBox(width: 10),
                  Expanded(child: SizedBox(height: 14)),
                ],
              ),
            ),
            error: (_, _) => const SizedBox.shrink(),
          ),

          Divider(height: 1, color: isDark ? Colors.white12 : AppColors.border),

          // ── Offer carousel ────────────────────────────────────────
          SizedBox(
            height: 152,
            child: PageView.builder(
              controller: _page,
              itemCount: widget.offers.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: _OfferTile(offer: widget.offers[i], shopId: widget.shopId),
              ),
            ),
          ),

          // ── Dot indicators ─────────────────────────────────────────
          if (widget.offers.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.offers.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _current == i ? 16 : 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _current == i
                          ? AppColors.primary
                          : AppColors.textHint.withValues(alpha: 0.3),
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
}

// ── Offer tile ────────────────────────────────────────────────────────────────

class _OfferTile extends ConsumerWidget {
  final Offer offer;
  final String shopId;
  const _OfferTile({required this.offer, required this.shopId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isHighDiscount = offer.discountPercentage >= 40;
    final daysLeft = offer.endDate?.difference(DateTime.now()).inDays;

    return ScaleOnTap(
      onTap: () => _showSheet(context, ref),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.border,
            width: 0.7,
          ),
          boxShadow: isDark
              ? null
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // Discount badge
            Container(
              width: 92,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isHighDiscount
                      ? [const Color(0xFFBF5210), const Color(0xFFDB7020)]
                      : [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${offer.discountPercentage.toInt()}%',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    'OFF',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.75),
                      letterSpacing: 2.5,
                    ),
                  ),
                ],
              ),
            ),

            // Dotted divider
            CustomPaint(
              size: const Size(1, double.infinity),
              painter: _DottedLine(
                color: isDark ? Colors.white12 : AppColors.border,
              ),
            ),

            // Details
            Expanded(
              child: Container(
                color: isDark ? AppColors.darkSurface : AppColors.surface,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            offer.title,
                            style: GoogleFonts.poppins(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (offer.isFeatured)
                          const Icon(Icons.star_rounded, color: AppColors.warning, size: 15),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      offer.description,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : AppColors.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        if (daysLeft != null && daysLeft >= 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: daysLeft <= 2
                                  ? AppColors.error.withValues(alpha: 0.08)
                                  : AppColors.accent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              daysLeft == 0 ? 'Ends today' : '$daysLeft days left',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: daysLeft <= 2 ? AppColors.error : AppColors.accent,
                              ),
                            ),
                          ),
                        const Spacer(),
                        Text(
                          'View details',
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
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
    );
  }

  void _showSheet(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(ctx).padding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    '${offer.discountPercentage.toInt()}% OFF',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    offer.title,
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            if (offer.endDate != null) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.textHint),
                  const SizedBox(width: 8),
                  Text(
                    'Valid until ${offer.endDate!.day}/${offer.endDate!.month}/${offer.endDate!.year}',
                    style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textHint),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Divider(color: AppColors.border),
            const SizedBox(height: 12),
            Text(
              offer.description,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: Text('Close', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ref.read(shopDetailsProvider(shopId)).whenData((shop) {
                        if (shop != null && context.mounted) {
                          context.push('/shop_details', extra: shop);
                        }
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: Text('Visit shop',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dotted line ───────────────────────────────────────────────────────────────

class _DottedLine extends CustomPainter {
  final Color color;
  const _DottedLine({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    const dash = 5.0, gap = 5.0;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, y + dash), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DottedLine old) => old.color != color;
}

// ── States ────────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_offer_outlined,
                size: 32,
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No active offers nearby',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Check back soon for deals from local shops.',
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textHint),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerOffers extends StatelessWidget {
  final double hPad;
  const _ShimmerOffers({required this.hPad});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.border,
      highlightColor: AppColors.surfaceElevated,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
        itemCount: 4,
        itemBuilder: (_, _) => Container(
          height: 210,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
    );
  }
}
