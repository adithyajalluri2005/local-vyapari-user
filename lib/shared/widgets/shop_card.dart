import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/features/favorites/presentation/widgets/favorite_button.dart';
import 'package:local_vyapari_user/services/cache/app_cache_manager.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';
import 'package:local_vyapari_user/shared/widgets/app_animations.dart';
import 'package:local_vyapari_user/shared/widgets/status_pill.dart';
import 'package:local_vyapari_user/shared/widgets/rating_chip.dart';

// ── List / grid variant ────────────────────────────────────────────────────
// Horizontal card: logo | name + category + rating | status pill + chevron
class ShopCard extends StatelessWidget {
  final Shop shop;
  final VoidCallback? onTap;

  const ShopCard({super.key, required this.shop, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : AppColors.surface;
    final border = isDark ? Colors.white10 : AppColors.border.withValues(alpha: 0.8);
    final shadow = Colors.black.withValues(alpha: isDark ? 0.2 : 0.055);

    return ScaleOnTap(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: border, width: 0.7),
          boxShadow: [
            BoxShadow(color: shadow, blurRadius: 14, offset: const Offset(0, 4)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _ShopAvatar(logoUrl: shop.shopLogo, radius: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.shopName,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (shop.location.city.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        shop.location.city,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    if (shop.rating > 0)
                      RatingChip(rating: shop.rating, totalReviews: shop.totalReviews),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  StatusPill(isOpen: shop.isOpen),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FavoriteButton(
                        itemId: shop.id,
                        type: FavoriteType.shop,
                        size: 20,
                        color: isDark ? Colors.white38 : AppColors.textHint,
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: isDark ? Colors.white38 : AppColors.textHint,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShopAvatar extends StatelessWidget {
  final String logoUrl;
  final double radius;
  const _ShopAvatar({required this.logoUrl, required this.radius});

  @override
  Widget build(BuildContext context) {
    if (logoUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.primary.withValues(alpha: 0.08),
        child: Icon(
          Icons.storefront_outlined,
          size: radius,
          color: AppColors.primary,
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surfaceElevated,
      backgroundImage: CachedNetworkImageProvider(logoUrl, cacheManager: AppCacheManager()),
    );
  }
}
