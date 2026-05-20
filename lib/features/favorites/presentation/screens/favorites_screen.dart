import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/features/favorites/providers/favorites_provider.dart';
import 'package:local_vyapari_user/shared/models/product.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';
import 'package:shimmer/shimmer.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteProductsAsync = ref.watch(favoriteProductsProvider);
    final favoriteShopsAsync = ref.watch(favoriteShopsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Favorites'),
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
        body: TabBarView(
          children: [
            _buildProductsTab(context, favoriteProductsAsync),
            _buildShopsTab(context, favoriteShopsAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsTab(BuildContext context, AsyncValue<List<Product>> productsAsync) {
    return productsAsync.when(
      data: (products) {
        if (products.isEmpty) {
          return _buildEmptyState(
            context,
            icon: Icons.favorite_border,
            title: 'No favorite products yet',
            subtitle: 'Products you heart will show up here.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: products.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) => _buildProductItem(context, products[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Failed to load favorites: $error')),
    );
  }

  Widget _buildShopsTab(BuildContext context, AsyncValue<List<Shop>> shopsAsync) {
    return shopsAsync.when(
      data: (shops) {
        if (shops.isEmpty) {
          return _buildEmptyState(
            context,
            icon: Icons.storefront_outlined,
            title: 'No favorite shops yet',
            subtitle: 'Shops you follow will appear here.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: shops.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) => _buildShopItem(context, shops[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Failed to load favorites: $error')),
    );
  }

  Widget _buildProductItem(BuildContext context, Product product) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _buildImage(product.images.isNotEmpty ? product.images.first : '', Icons.image),
      title: Text(
        product.name,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text('₹${product.offerPrice}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/product_details', extra: product),
    );
  }

  Widget _buildShopItem(BuildContext context, Shop shop) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _buildImage(shop.shopLogo.isNotEmpty ? shop.shopLogo : shop.shopBanner, Icons.store),
      title: Text(
        shop.shopName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(shop.location.address),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/shop_details', extra: shop),
    );
  }

  Widget _buildImage(String url, IconData fallbackIcon) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 60,
        height: 60,
        color: Colors.grey[200],
        child: url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(color: Colors.white),
                ),
                errorWidget: (context, url, error) => Icon(fallbackIcon, color: Colors.grey),
              )
            : Icon(fallbackIcon, color: Colors.grey),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, {required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.grey[800],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              context.go('/');
            },
            child: const Text('Start Exploring'),
          ),
        ],
      ),
    );
  }
}
