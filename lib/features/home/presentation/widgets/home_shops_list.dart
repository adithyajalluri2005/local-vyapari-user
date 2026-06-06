import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';
import 'package:local_vyapari_user/shared/widgets/shop_card.dart';
import 'package:local_vyapari_user/shared/widgets/empty_section.dart';
import 'package:local_vyapari_user/shared/widgets/app_animations.dart';

const _kShimmerDark = Color(0xFF2A2A3E);
const _kShimmerDarkHL = Color(0xFF3A3A4E);

enum ShopFilter { all, openNow }

class ShopsList extends StatefulWidget {
  final AsyncValue<List<Shop>> shopsAsync;
  const ShopsList({super.key, required this.shopsAsync});

  @override
  State<ShopsList> createState() => _ShopsListState();
}

class _ShopsListState extends State<ShopsList> {
  ShopFilter _filter = ShopFilter.all;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final columns = Responsive.shopGridColumns(context);

    return widget.shopsAsync.when(
      skipLoadingOnReload: false,
      data: (allShops) {
        List<Shop> filtered = allShops;
        if (_filter == ShopFilter.openNow) {
          filtered = allShops.where((s) => s.isOpen).toList();
        }

        final displayShops = filtered.take(6).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  HomeFilterChip(
                    label: 'All',
                    active: _filter == ShopFilter.all,
                    onTap: () => setState(() => _filter = ShopFilter.all),
                  ),
                  const SizedBox(width: 8),
                  HomeFilterChip(
                    label: 'Open Now',
                    icon: Icons.circle,
                    active: _filter == ShopFilter.openNow,
                    onTap: () => setState(() => _filter = ShopFilter.openNow),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (displayShops.isEmpty)
              EmptySection(
                icon: _filter == ShopFilter.openNow
                    ? Icons.store_mall_directory_outlined
                    : Icons.storefront_outlined,
                message: _filter == ShopFilter.openNow
                    ? 'No shops open right now'
                    : 'No shops found nearby',
              )
            else if (columns >= 2)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 2.5,
                ),
                itemCount: displayShops.length,
                itemBuilder: (ctx, i) => FadeInSlide(
                  delay: Duration(milliseconds: 50 * i),
                  child: ShopCard(
                    shop: displayShops[i],
                    onTap: () => context.push('/shop_details', extra: displayShops[i]),
                  ),
                ),
              )
            else
              Column(
                children: displayShops.asMap().entries.map((e) {
                  return FadeInSlide(
                    delay: Duration(milliseconds: 50 * e.key),
                    child: ShopCard(
                      shop: e.value,
                      onTap: () => context.push('/shop_details', extra: e.value),
                    ),
                  );
                }).toList(),
              ),
          ],
        );
      },
      loading: () => Column(
        children: List.generate(
          3,
          (_) => Shimmer.fromColors(
            baseColor: isDark ? _kShimmerDark : Colors.grey.shade300,
            highlightColor: isDark ? _kShimmerDarkHL : Colors.grey.shade100,
            child: Container(
              height: 80,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
          ),
        ),
      ),
      error: (_, _) => const EmptySection(
        icon: Icons.error_outline,
        message: 'Could not load shops',
      ),
    );
  }
}

class HomeFilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool active;
  final VoidCallback onTap;

  const HomeFilterChip({
    super.key,
    required this.label,
    this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary
              : isDark
                  ? AppColors.darkElevated
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: icon == Icons.circle ? 7 : 12,
                color: active
                    ? Colors.white
                    : icon == Icons.circle
                        ? AppColors.accent
                        : AppColors.warning,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
