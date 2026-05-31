import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/core/theme/app_sizes.dart';
import 'package:local_vyapari_user/core/theme/app_text_styles.dart';
import 'package:local_vyapari_user/features/favorites/providers/favorites_provider.dart';
import 'package:local_vyapari_user/features/home/presentation/screens/main_navigation_screen.dart';
import 'package:local_vyapari_user/services/cache/app_cache_manager.dart';
import 'package:local_vyapari_user/shared/models/product.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';
import 'package:shimmer/shimmer.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Responsive.init(context);
    final favoriteProductsAsync = ref.watch(favoriteProductsProvider);
    final favoriteShopsAsync = ref.watch(favoriteShopsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Favorites',
            style: AppTextStyles.titleMedium(context, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          bottom: const TabBar(
            indicatorColor: AppTheme.primaryColor,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Products'),
              Tab(text: 'Shops'),
            ],
          ),
        ),
        body: SafeArea(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              child: TabBarView(
                children: [
                  _buildProductsTab(context, ref, favoriteProductsAsync),
                  _buildShopsTab(context, ref, favoriteShopsAsync),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductsTab(BuildContext context, WidgetRef ref, AsyncValue<List<Product>> productsAsync) {
    final padding = AppSizes.paddingMedium(context);
    return productsAsync.when(
      data: (products) {
        if (products.isEmpty) {
          return _buildEmptyState(
            context,
            ref,
            icon: Icons.favorite_border,
            title: 'No favorite products yet',
            subtitle: 'Products you heart will show up here.',
          );
        }
        return ListView.separated(
          padding: EdgeInsets.all(padding),
          itemCount: products.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) => _buildProductItem(context, products[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Failed to load favorites', style: AppTextStyles.bodyLarge(context))),
    );
  }

  Widget _buildShopsTab(BuildContext context, WidgetRef ref, AsyncValue<List<Shop>> shopsAsync) {
    final padding = AppSizes.paddingMedium(context);
    return shopsAsync.when(
      data: (shops) {
        if (shops.isEmpty) {
          return _buildEmptyState(
            context,
            ref,
            icon: Icons.storefront_outlined,
            title: 'No favorite shops yet',
            subtitle: 'Shops you follow will appear here.',
          );
        }
        return ListView.separated(
          padding: EdgeInsets.all(padding),
          itemCount: shops.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) => _buildShopItem(context, shops[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Failed to load favorites', style: AppTextStyles.bodyLarge(context))),
    );
  }

  Widget _buildProductItem(BuildContext context, Product product) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _buildImage(product.images.isNotEmpty ? product.images.first : '', Icons.image, context),
      title: Text(
        product.name,
        style: AppTextStyles.bodyLarge(context, fontWeight: FontWeight.bold),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '₹${product.offerPrice}',
        style: AppTextStyles.bodyMedium(context, color: Colors.grey[700]),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/product_details', extra: product),
    );
  }

  Widget _buildShopItem(BuildContext context, Shop shop) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _buildImage(shop.shopLogo.isNotEmpty ? shop.shopLogo : shop.shopBanner, Icons.store, context),
      title: Text(
        shop.shopName,
        style: AppTextStyles.bodyLarge(context, fontWeight: FontWeight.bold),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        shop.location.address,
        style: AppTextStyles.bodyMedium(context, color: Colors.grey[700]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/shop_details', extra: shop),
    );
  }

  Widget _buildImage(String url, IconData fallbackIcon, BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
      child: Container(
        width: 60,
        height: 60,
        color: cs.surfaceContainerHighest,
        child: url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                cacheManager: AppCacheManager(),
                placeholder: (ctx, url) => Shimmer.fromColors(
                  baseColor: isDark ? const Color(0xFF222C36) : Colors.grey.shade300,
                  highlightColor: isDark ? const Color(0xFF2C3742) : Colors.grey.shade100,
                  child: Container(color: isDark ? const Color(0xFF1E1E2E) : Colors.white),
                ),
                errorWidget: (ctx, url, error) => Icon(fallbackIcon, color: cs.onSurfaceVariant),
              )
            : Icon(fallbackIcon, color: cs.onSurfaceVariant),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTextStyles.titleMedium(context, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: AppTextStyles.bodyMedium(context, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ref.read(navigationIndexProvider.notifier).setIndex(0);
              },
              child: const Text('Start Exploring'),
            ),
          ],
        ),
      ),
    );
  }
}
