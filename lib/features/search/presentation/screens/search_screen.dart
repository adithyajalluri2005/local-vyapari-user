import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/features/search/providers/hybrid_search_provider.dart';
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
    final searchResultAsync = ref.watch(hybridSearchProvider);

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
                      ref.read(hybridSearchProvider.notifier).search('');
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
              onChanged: (value) {
                setState(() => _query = value.trim());
                ref.read(hybridSearchProvider.notifier).search(value.trim());
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _query.isEmpty
                ? _buildSuggestions(context)
                : _buildResults(context, searchResultAsync),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(
    BuildContext context,
    AsyncValue<HybridSearchResult> searchResultAsync,
  ) {
    if (searchResultAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (searchResultAsync.hasError) {
      return Center(child: Text('Failed to load search results: ${searchResultAsync.error}'));
    }

    final result = searchResultAsync.value ?? const HybridSearchResult();
    
    if (result.products.isEmpty && result.shops.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'No results found for "$_query" within 15km.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        if (result.products.isNotEmpty) ...[
          _buildSectionTitle(context, 'Products'),
          ...result.products.map(_buildProductResult),
        ],
        if (result.shops.isNotEmpty) ...[
          _buildSectionTitle(context, 'Shops'),
          ...result.shops.map(_buildShopResult),
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
    ref.read(hybridSearchProvider.notifier).search(value.trim());
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
