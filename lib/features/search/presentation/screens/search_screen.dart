import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_products_provider.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_shops_provider.dart';
import 'package:local_vyapari_user/shared/models/product.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shopsAsync = ref.watch(nearbyShopsProvider);
    final productsAsync = ref.watch(nearbyProductsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Search Nearby'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search products, shops, categories...',
              leading: const Icon(Icons.search, color: Colors.grey),
              trailing: [
                if (_query.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
              ],
              elevation: WidgetStateProperty.all(0),
              backgroundColor: WidgetStateProperty.resolveWith(
                (_) => Theme.of(context).colorScheme.surface,
              ),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _query.isEmpty
                ? _buildSuggestions(context)
                : _buildResults(context, shopsAsync, productsAsync),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(
    BuildContext context,
    AsyncValue<List<Shop>> shopsAsync,
    AsyncValue<List<Product>> productsAsync,
  ) {
    final isLoading = shopsAsync.isLoading || productsAsync.isLoading;
    final error = shopsAsync.error ?? productsAsync.error;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return const Center(child: Text('Failed to load search results.'));
    }

    final shops = shopsAsync.value ?? <Shop>[];
    final products = productsAsync.value ?? <Product>[];
    final matchingShops = shops
        .where((shop) => _matchesShop(shop, _query))
        .toList();
    final matchingProducts = products
        .where((product) => _matchesProduct(product, _query))
        .toList();

    if (matchingShops.isEmpty && matchingProducts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'No results found for "$_query".',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        if (matchingProducts.isNotEmpty) ...[
          _buildSectionTitle(context, 'Products'),
          ...matchingProducts.map(_buildProductResult),
        ],
        if (matchingShops.isNotEmpty) ...[
          _buildSectionTitle(context, 'Shops'),
          ...matchingShops.map(_buildShopResult),
        ],
      ],
    );
  }

  Widget _buildSuggestions(BuildContext context) {
    return ListView(
      children: [
        _buildSectionTitle(context, 'Trending Categories'),
        _buildCategories(context),
        const SizedBox(height: 16),
        _buildSectionTitle(context, 'Quick Searches'),
        _buildSuggestionItem(Icons.search, 'Electronics'),
        _buildSuggestionItem(Icons.search, 'Groceries'),
        _buildSuggestionItem(Icons.search, 'Pharmacy'),
        _buildSuggestionItem(Icons.search, 'Food'),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildCategories(BuildContext context) {
    final categories = [
      'Electronics',
      'Groceries',
      'Clothing',
      'Pharmacy',
      'Food',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: categories.map((category) {
          return ActionChip(
            label: Text(category),
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
            side: BorderSide.none,
            onPressed: () => _applyQuery(category),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSuggestionItem(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () => _applyQuery(title),
    );
  }

  Widget _buildProductResult(Product product) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: _ResultImage(
        imageUrl: product.images.isNotEmpty ? product.images.first : '',
        fallbackIcon: Icons.image,
      ),
      title: Text(
        product.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${product.category} - Rs. ${product.offerPrice}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/product_details', extra: product),
    );
  }

  Widget _buildShopResult(Shop shop) {
    final location = shop.location.city.isNotEmpty
        ? shop.location.city
        : shop.location.address;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: _ResultImage(
        imageUrl: shop.shopLogo.isNotEmpty ? shop.shopLogo : shop.shopBanner,
        fallbackIcon: Icons.store,
      ),
      title: Text(
        shop.shopName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        location.isNotEmpty ? location : 'Shop nearby',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/shop_details', extra: shop),
    );
  }

  void _applyQuery(String value) {
    _searchController.text = value;
    setState(() => _query = value.trim());
  }

  bool _matchesProduct(Product product, String query) {
    final normalizedQuery = query.toLowerCase();
    final searchableText = [
      product.name,
      product.description,
      product.category,
      ...product.searchKeywords,
    ].join(' ').toLowerCase();

    return searchableText.contains(normalizedQuery);
  }

  bool _matchesShop(Shop shop, String query) {
    final normalizedQuery = query.toLowerCase();
    final searchableText = [
      shop.shopName,
      shop.description,
      shop.location.city,
      shop.location.address,
    ].join(' ').toLowerCase();

    return searchableText.contains(normalizedQuery);
  }
}

class _ResultImage extends StatelessWidget {
  const _ResultImage({required this.imageUrl, required this.fallbackIcon});

  final String imageUrl;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 52,
        height: 52,
        child: imageUrl.isEmpty
            ? _buildFallback()
            : CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: Colors.grey[200]),
                errorWidget: (context, url, error) => _buildFallback(),
              ),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      color: Colors.grey[200],
      child: Icon(fallbackIcon, color: Colors.grey),
    );
  }
}
