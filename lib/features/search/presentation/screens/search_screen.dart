import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shimmer/shimmer.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/core/theme/app_dimensions.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/features/favorites/presentation/widgets/favorite_button.dart';
import 'package:local_vyapari_user/features/search/providers/hybrid_search_provider.dart';
import 'package:local_vyapari_user/shared/models/product.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';
import 'package:local_vyapari_user/services/cache/app_cache_manager.dart';
import 'package:local_vyapari_user/shared/widgets/app_animations.dart';
import 'package:local_vyapari_user/shared/widgets/shop_card.dart';


const _kCategories = [
  'Groceries & Staples',
  'Fruits & Vegetables',
  'Dairy & Eggs',
  'Meat & Seafood',
  'Bakery & Sweets',
  'Snacks & Beverages',
  'Electronics',
  'Mobile & Accessories',
  'Clothing & Apparel',
  'Sarees & Ethnic Wear',
  'Footwear',
  'Jewellery & Accessories',
  'Home & Kitchen',
  'Furniture & Decor',
  'Pharmacy & Healthcare',
  'Beauty & Personal Care',
  'Books & Stationery',
  'Toys & Games',
  'Sports & Fitness',
  'Hardware & Tools',
  'Auto Parts & Accessories',
  'Agriculture & Farming',
  'Flowers & Plants',
  'Gifts & Handicrafts',
  'Pet Supplies',
  'Office Supplies',
  'Other',
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
  String? _selectedCategory;

  bool get _hasActiveSearch => _query.isNotEmpty || _selectedCategory != null;

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _triggerSearch() {
    ref.read(hybridSearchProvider.notifier).search(
      _query,
      category: _selectedCategory,
    );
  }

  void _onTextChanged(String value) {
    setState(() => _query = value.trim());
    _triggerSearch();
  }

  void _onCategorySelected(String category) {
    setState(() => _selectedCategory = category);
    _triggerSearch();
  }

  void _clearCategory() {
    setState(() => _selectedCategory = null);
    _triggerSearch();
  }

  void _clearAll() {
    _ctrl.clear();
    setState(() {
      _query = '';
      _selectedCategory = null;
    });
    _triggerSearch();
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
            // ── Search bar ───────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 10),
              child: _SearchBar(
                ctrl: _ctrl,
                focusNode: _focusNode,
                hasQuery: _hasActiveSearch,
                onChanged: _onTextChanged,
                onClear: _clearAll,
              ),
            ),

            // ── Filter chips ─────────────────────────────────────────
            SizedBox(
              height: Responsive.isSmallPhone(context) ? 32.0 : 36.0,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: hPad),
                children: [
                  if (_selectedCategory != null)
                    _CategoryFilterChip(
                      label: _selectedCategory!,
                      onDismiss: _clearCategory,
                    ),
                ],
              ),
            ),

            Divider(height: 1, color: AppColors.border.withValues(alpha: 0.6)),

            // ── Body ────────────────────────────────────────────────
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: AppDimensions.maxWideContentWidth),
                  child: !_hasActiveSearch
                      ? _SuggestionsView(onCategorySelect: _onCategorySelected)
                      : _ResultsView(
                          query: _query,
                          selectedCategory: _selectedCategory,
                          onClearFilters: () {
                            setState(() => _selectedCategory = null);
                            _triggerSearch();
                          },
                          onRetry: _triggerSearch,
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
    final isSmall = Responsive.isSmallPhone(context);
    final barHeight = isSmall ? 42.0 : 46.0;
    final fontSize = isSmall ? 13.0 : 14.0;
    return Container(
      height: barHeight,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkElevated : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          SizedBox(width: isSmall ? 10 : 12),
          Icon(Icons.search_rounded, size: isSmall ? 18.0 : 20.0, color: AppColors.textHint),
          SizedBox(width: isSmall ? 6 : 8),
          Expanded(
            child: TextField(
              controller: ctrl,
              focusNode: focusNode,
              onChanged: onChanged,
              style: GoogleFonts.poppins(
                fontSize: fontSize,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search shops, products…',
                hintStyle: GoogleFonts.poppins(
                  fontSize: fontSize,
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
                padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 10),
                child: Icon(Icons.close_rounded, size: 18, color: AppColors.textHint),
              ),
            )
          else
            SizedBox(width: isSmall ? 10 : 12),
        ],
      ),
    );
  }
}


// ── Dismissible category chip ─────────────────────────────────────────────────

class _CategoryFilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onDismiss;

  const _CategoryFilterChip({required this.label, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.primaryLight : AppColors.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.5),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.category_rounded, size: 12, color: primaryColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 5),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close_rounded, size: 14, color: primaryColor),
          ),
        ],
      ),
    );
  }
}

// ── Suggestions (empty state) ─────────────────────────────────────────────────

class _SuggestionsView extends StatelessWidget {
  final ValueChanged<String> onCategorySelect;
  const _SuggestionsView({required this.onCategorySelect});

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
              onTap: () => onCategorySelect(cat),
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
        ...[
          'Mobile & Accessories',
          'Fruits & Vegetables',
          'Pharmacy & Healthcare',
          'Snacks & Beverages',
        ].map((q) => _QuickSearchItem(label: q, onTap: () => onCategorySelect(q))),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                  color: isDark ? Colors.white : AppColors.textPrimary,
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
  final String? selectedCategory;
  final VoidCallback onClearFilters;
  final VoidCallback onRetry;

  const _ResultsView({
    required this.query,
    required this.selectedCategory,
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

        if (shops.isEmpty && products.isEmpty) {
          return _EmptyState(
            query: query,
            selectedCategory: selectedCategory,
            onClearFilters: onClearFilters,
          );
        }

        final useGrid = Responsive.useNavRail(context);
        final cols = useGrid ? 2 : 1;

        return ListView(
          padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 90),
          children: [
            if (result.isCapped) _CappedBanner(hPad: hPad),

            if (shops.isNotEmpty) ...[
              _SectionLabel(label: 'Shops', count: shops.length),
              const SizedBox(height: 8),
              if (cols == 1)
                ...shops.asMap().entries.map((e) => FadeInSlide(
                      delay: Duration(milliseconds: (60 * e.key).clamp(0, 300)),
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
                    delay: Duration(milliseconds: (60 * i).clamp(0, 300)),
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
                    delay: Duration(milliseconds: (60 * e.key).clamp(0, 300)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.primaryLight : AppColors.primary;
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: primaryColor,
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
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '₹${product.offerPrice.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                      if (product.actualPrice > product.offerPrice) ...[
                        const SizedBox(width: 6),
                        Text(
                          '₹${product.actualPrice.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.textHint,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FavoriteButton(
              itemId: product.id,
              type: FavoriteType.product,
              shopId: product.shopId,
              size: 20,
              color: isDark ? Colors.white38 : AppColors.textHint,
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
  final String? selectedCategory;
  final VoidCallback onClearFilters;

  const _EmptyState({
    required this.query,
    required this.selectedCategory,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayTerm = selectedCategory ?? query;
    final subtitle = selectedCategory != null
        ? 'No products found in this category nearby.'
        : 'Try different keywords or check your location.';

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
              'No results for "$displayTerm"',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textHint),
              textAlign: TextAlign.center,
            ),
            if (selectedCategory != null) ...[
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
                    color: isDark ? Colors.white : AppColors.primary,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                      ? 'You\'re offline'
                      : 'Search failed',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textPrimary,
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
                  color: isDark ? Colors.white : AppColors.primary,
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
