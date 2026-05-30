import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shimmer/shimmer.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/features/search/providers/hybrid_search_provider.dart';
import 'package:local_vyapari_user/shared/models/product.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';
import 'package:local_vyapari_user/services/cache/app_cache_manager.dart';
import 'package:local_vyapari_user/shared/widgets/app_animations.dart';
import 'package:local_vyapari_user/shared/widgets/shop_card.dart';

// ── Filter state ──────────────────────────────────────────────────────────────

enum _SearchFilter { all, openNow, topRated }

const _kCategories = [
  'Electronics', 'Groceries', 'Clothing', 'Pharmacy', 'Food & Drinks',
  'Stationary', 'Hardware', 'Beauty',
];

// ── Screen ────────────────────────────────────────────────────────────────────

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';
  _SearchFilter _filter = _SearchFilter.all;

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _search(String value) {
    setState(() => _query = value.trim());
    ref.read(hybridSearchProvider.notifier).search(value.trim());
  }

  void _clear() {
    _ctrl.clear();
    _search('');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hPad = Responsive.horizontalPadding(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkScaffold : AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Search header ────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 10),
              child: _SearchBar(
                ctrl: _ctrl,
                focusNode: _focusNode,
                hasQuery: _query.isNotEmpty,
                onChanged: _search,
                onClear: _clear,
              ),
            ),

            // ── Filter chips ─────────────────────────────────────────
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: hPad),
                children: [
                  _FilterChip(
                    label: 'All',
                    active: _filter == _SearchFilter.all,
                    onTap: () => setState(() => _filter = _SearchFilter.all),
                  ),
                  _FilterChip(
                    label: 'Open Now',
                    icon: Icons.circle,
                    active: _filter == _SearchFilter.openNow,
                    onTap: () => setState(() => _filter = _SearchFilter.openNow),
                  ),
                  _FilterChip(
                    label: '4★ & above',
                    icon: Icons.star_rounded,
                    active: _filter == _SearchFilter.topRated,
                    onTap: () => setState(() => _filter = _SearchFilter.topRated),
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: AppColors.border.withValues(alpha: 0.6)),

            // ── Body ────────────────────────────────────────────────
            Expanded(
              child: _query.isEmpty
                  ? _SuggestionsView(onCategoryTap: _search)
                  : _ResultsView(
                      query: _query,
                      filter: _filter,
                      onClearFilters: () => setState(() => _filter = _SearchFilter.all),
                      onRetry: () => _search(_query),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focusNode;
  final bool hasQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.ctrl,
    required this.focusNode,
    required this.hasQuery,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkElevated : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isDark ? Colors.white12 : AppColors.border,
          width: 0.7,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.search_rounded, size: 20, color: AppColors.textHint),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: ctrl,
              focusNode: focusNode,
              onChanged: onChanged,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search shops, products…',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textHint,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
          if (hasQuery)
            GestureDetector(
              onTap: onClear,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.close_rounded, size: 18, color: AppColors.textHint),
              ),
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({required this.label, this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
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
                size: icon == Icons.circle ? 8 : 13,
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

// ── Suggestions (empty state) ─────────────────────────────────────────────────

class _SuggestionsView extends StatelessWidget {
  final ValueChanged<String> onCategoryTap;
  const _SuggestionsView({required this.onCategoryTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hPad = Responsive.horizontalPadding(context);

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 20),
      children: [
        Text(
          'Browse categories',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textHint,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kCategories.map((cat) {
            return ScaleOnTap(
              onTap: () => onCategoryTap(cat),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkElevated : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border, width: 0.7),
                ),
                child: Text(
                  cat,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 28),
        Text(
          'Quick searches',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textHint,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        ...['Mobile phones', 'Fresh vegetables', 'Medicines', 'Snacks']
            .map((q) => _QuickSearchItem(label: q, onTap: () => onCategoryTap(q))),
      ],
    );
  }
}

class _QuickSearchItem extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickSearchItem({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ScaleOnTap(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(Icons.north_west_rounded, size: 16, color: AppColors.textHint),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Results ───────────────────────────────────────────────────────────────────

class _ResultsView extends ConsumerWidget {
  final String query;
  final _SearchFilter filter;
  final VoidCallback onClearFilters;
  final VoidCallback onRetry;

  const _ResultsView({
    required this.query,
    required this.filter,
    required this.onClearFilters,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultAsync = ref.watch(hybridSearchProvider);
    final hPad = Responsive.horizontalPadding(context);

    return resultAsync.when(
      skipLoadingOnReload: true,
      loading: () => _ShimmerResults(hPad: hPad),
      error: (err, _) => _ErrorState(error: err, onRetry: onRetry),
      data: (result) {
        List<Shop> shops = result.shops;
        List<Product> products = result.products;

        // Apply client-side filters
        if (filter == _SearchFilter.openNow) {
          shops = shops.where((s) => s.isOpen).toList();
        } else if (filter == _SearchFilter.topRated) {
          shops = shops.where((s) => s.rating >= 4.0).toList();
        }

        if (shops.isEmpty && products.isEmpty) {
          return _EmptyState(
            query: query,
            hasFilter: filter != _SearchFilter.all,
            onClearFilters: onClearFilters,
          );
        }

        final useGrid = Responsive.useNavRail(context);
        final cols = useGrid ? 2 : 1;

        return ListView(
          padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 90),
          children: [
            if (result.isCapped)
              _CappedBanner(hPad: hPad),

            if (shops.isNotEmpty) ...[
              _SectionLabel(label: 'Shops', count: shops.length),
              const SizedBox(height: 8),
              if (cols == 1)
                ...shops.asMap().entries.map((e) => FadeInSlide(
                      delay: Duration(milliseconds: 60 * e.key),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ShopCard(
                          shop: e.value,
                          onTap: () => context.push('/shop_details', extra: e.value),
                        ),
                      ),
                    ))
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.4,
                  ),
                  itemCount: shops.length,
                  itemBuilder: (_, i) => FadeInSlide(
                    delay: Duration(milliseconds: 60 * i),
                    child: ShopCard(
                      shop: shops[i],
                      onTap: () => context.push('/shop_details', extra: shops[i]),
                    ),
                  ),
                ),
            ],

            if (products.isNotEmpty) ...[
              const SizedBox(height: 8),
              _SectionLabel(label: 'Products', count: products.length),
              const SizedBox(height: 8),
              ...products.asMap().entries.map((e) => FadeInSlide(
                    delay: Duration(milliseconds: 60 * e.key),
                    child: _ProductTile(product: e.value),
                  )),
            ],
          ],
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final int count;
  const _SectionLabel({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _CappedBanner extends StatelessWidget {
  final double hPad;
  const _CappedBanner({required this.hPad});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25), width: 0.7),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Results limited to your 10 nearest shops.',
              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;
  const _ProductTile({required this.product});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ScaleOnTap(
      onTap: () => context.push('/product_details', extra: product),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border, width: 0.7),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: SizedBox(
                width: 52,
                height: 52,
                child: product.images.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: product.images.first,
                        fit: BoxFit.cover,
                        cacheManager: AppCacheManager(),
                        placeholder: (_, _) => Container(color: AppColors.surfaceElevated),
                        errorWidget: (_, _, _) => _ProductImageFallback(),
                      )
                    : _ProductImageFallback(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.category,
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${product.offerPrice.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
                if (product.actualPrice > product.offerPrice)
                  Text(
                    '₹${product.actualPrice.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textHint,
                      decoration: TextDecoration.lineThrough,
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

class _ProductImageFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceElevated,
      child: const Icon(Icons.image_outlined, color: AppColors.textHint, size: 22),
    );
  }
}

// ── Empty / Error states ──────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String query;
  final bool hasFilter;
  final VoidCallback onClearFilters;

  const _EmptyState({required this.query, required this.hasFilter, required this.onClearFilters});

  @override
  Widget build(BuildContext context) {
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
              child: const Icon(Icons.search_off_rounded, size: 34, color: AppColors.textHint),
            ),
            const SizedBox(height: 16),
            Text(
              'No results for "$query"',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              hasFilter
                  ? 'Try removing filters or search with broader terms.'
                  : 'Try different keywords or check your location.',
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textHint),
              textAlign: TextAlign.center,
            ),
            if (hasFilter) ...[
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: onClearFilters,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: Text(
                  'Clear filters',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isLocation = error is LocationUnavailableException;
    final isOffline = error is NetworkOfflineException;

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
              child: Icon(
                isLocation
                    ? Icons.location_off_rounded
                    : isOffline
                        ? Icons.wifi_off_rounded
                        : Icons.error_outline_rounded,
                size: 34,
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isLocation
                  ? 'Location required'
                  : isOffline
                      ? "You're offline"
                      : 'Search failed',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isLocation
                  ? 'Enable location to search nearby shops.'
                  : isOffline
                      ? 'Connect to the internet and try again.'
                      : 'Something went wrong. Please try again.',
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textHint),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: isLocation ? () => Geolocator.openLocationSettings() : onRetry,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: Text(
                isLocation ? 'Open settings' : 'Retry',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shimmer ───────────────────────────────────────────────────────────────────

class _ShimmerResults extends StatelessWidget {
  final double hPad;
  const _ShimmerResults({required this.hPad});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.border,
      highlightColor: AppColors.surfaceElevated,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 12),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, _) => Container(
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }
}
