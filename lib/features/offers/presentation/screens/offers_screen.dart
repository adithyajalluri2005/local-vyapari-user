import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/core/theme/app_sizes.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_offers_provider.dart';
import 'package:local_vyapari_user/shared/models/offer.dart';
import 'package:local_vyapari_user/features/shops/providers/shop_details_provider.dart';

class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Responsive.init(context);
    final offersAsync = ref.watch(nearbyOffersProvider);
    final padding = AppSizes.paddingMedium(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Nearby Offers',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: -0.2),
        ),
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
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      ),
                      child: const Icon(Icons.local_offer_outlined, size: 34, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No active offers nearby',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Check back later — shops update their deals regularly.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13.5, color: AppTheme.inkMuted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            final Map<String, List<Offer>> shopOffers = {};
            for (final offer in offers) {
              shopOffers.putIfAbsent(offer.shopId, () => []).add(offer);
            }
            final shopIds = shopOffers.keys.toList();

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView.builder(
                  padding: EdgeInsets.all(padding),
                  itemCount: shopIds.length,
                  itemBuilder: (context, index) => ShopOffersCard(
                    shopId: shopIds[index],
                    offers: shopOffers[shopIds[index]]!,
                  ),
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          error: (_, __) => Center(
            child: Text(
              'Failed to load offers',
              style: GoogleFonts.plusJakartaSans(color: AppTheme.inkMuted),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-shop card with swipeable offers
// ─────────────────────────────────────────────────────────────────────────────

class ShopOffersCard extends ConsumerStatefulWidget {
  final String shopId;
  final List<Offer> offers;

  const ShopOffersCard({super.key, required this.shopId, required this.offers});

  @override
  ConsumerState<ShopOffersCard> createState() => _ShopOffersCardState();
}

class _ShopOffersCardState extends ConsumerState<ShopOffersCard> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(shopDetailsProvider(widget.shopId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Shop header ──────────────────────────────────────
            shopAsync.when(
              data: (shop) {
                if (shop == null) return const SizedBox.shrink();
                return InkWell(
                  onTap: () => context.push('/shop_details', extra: shop),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryColor.withValues(alpha: 0.08),
                            image: shop.shopLogo.isNotEmpty
                                ? DecorationImage(
                                    image: CachedNetworkImageProvider(shop.shopLogo),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: shop.shopLogo.isEmpty
                              ? const Icon(Icons.storefront_outlined, size: 20, color: AppTheme.primaryColor)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shop.shopName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (shop.location.address.isNotEmpty)
                                Text(
                                  shop.location.address,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: AppTheme.inkMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.inkFaint),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(radius: 20, backgroundColor: Color(0xFFECEBE6)),
                    SizedBox(width: 12),
                    Expanded(child: SizedBox(height: 14)),
                  ],
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),

            Divider(
              height: 1,
              color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
            ),

            // ── Offer carousel ───────────────────────────────────
            SizedBox(
              height: 160,
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.offers.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: _OfferTile(offer: widget.offers[index], shopId: widget.shopId, ref: ref),
                ),
              ),
            ),

            // ── Dot indicators ───────────────────────────────────
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
                      width: _currentPage == i ? 18 : 6,
                      height: 5,
                      decoration: BoxDecoration(
                        color: _currentPage == i
                            ? AppTheme.primaryColor
                            : AppTheme.inkFaint.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single offer tile inside the carousel
// ─────────────────────────────────────────────────────────────────────────────

class _OfferTile extends ConsumerWidget {
  final Offer offer;
  final String shopId;
  final WidgetRef ref;
  const _OfferTile({required this.offer, required this.shopId, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHighDiscount = offer.discountPercentage >= 40;
    final daysLeft = offer.endDate?.difference(DateTime.now()).inDays;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _showOfferSheet(context, ref),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // Left — discount badge
            Container(
              width: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isHighDiscount
                      ? [const Color(0xFFBF5210), const Color(0xFFDB7020)]
                      : [const Color(0xFF2A5E18), const Color(0xFF3E8A28)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${offer.discountPercentage.toInt()}%',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    'OFF',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
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
              painter: _DottedLinePainter(
                color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
              ),
            ),
            // Right — details
            Expanded(
              child: Container(
                color: isDark ? AppTheme.darkSurface : AppTheme.surfaceColor,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            offer.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (offer.isFeatured)
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      offer.description,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: AppTheme.inkMuted,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (daysLeft != null && daysLeft >= 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: daysLeft <= 2
                                  ? AppTheme.errorColor.withValues(alpha: 0.1)
                                  : AppTheme.accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              daysLeft == 0 ? 'Ends today' : '$daysLeft days left',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: daysLeft <= 2 ? AppTheme.errorColor : AppTheme.accentColor,
                              ),
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        const Spacer(),
                        Text(
                          'Tap for details',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
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

  void _showOfferSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor,
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
                      colors: [Color(0xFF2A5E18), Color(0xFF3E8A28)],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    '${offer.discountPercentage.toInt()}% OFF',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    offer.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
            if (offer.endDate != null) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 14, color: AppTheme.inkMuted),
                  const SizedBox(width: 8),
                  Text(
                    'Valid until ${offer.endDate!.day}/${offer.endDate!.month}/${offer.endDate!.year}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppTheme.inkMuted),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Divider(color: AppTheme.borderColor),
            const SizedBox(height: 12),
            Text(
              offer.description,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.5,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
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
                    child: const Text('Visit shop'),
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

class _DottedLinePainter extends CustomPainter {
  final Color color;
  const _DottedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashH = 5.0;
    const gap = 5.0;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, y + dashH), paint);
      y += dashH + gap;
    }
  }

  @override
  bool shouldRepaint(_DottedLinePainter old) => old.color != color;
}
