import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_shops_provider.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_products_provider.dart';
import 'package:local_vyapari_user/features/home/providers/nearby_offers_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart';

import 'package:local_vyapari_user/services/location/location_service.dart';

class HomeScreen extends ConsumerWidget {
  final VoidCallback? onSearchTap;
  const HomeScreen({super.key, this.onSearchTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(activeBrowsingLocationProvider);
    final shopsAsync = ref.watch(nearbyShopsProvider);
    final productsAsync = ref.watch(nearbyProductsProvider);
    final offersAsync = ref.watch(nearbyOffersProvider);

    // Invalidate nearby providers when active browsing location actually changes
    ref.listen(activeBrowsingLocationProvider, (previous, next) {
      if (previous?.value != next?.value) {
        ref.invalidate(nearbyShopsProvider);
        ref.invalidate(nearbyProductsProvider);
        ref.invalidate(nearbyOffersProvider);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => context.push('/location_search'),
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on, color: AppTheme.primaryColor, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    'Current Location',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down, size: 20),
                ],
              ),
              locationAsync.when(
                data: (loc) => Text(
                  loc != null ? loc.name : 'Location not available',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                loading: () => Text(
                  'Fetching location...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
                error: (_, __) => Text(
                  'Error fetching location',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GestureDetector(
                onTap: onSearchTap,
                child: AbsorbPointer(
                  child: SearchBar(
                    hintText: 'Search for nearby products, shops...',
                    leading: const Icon(Icons.search, color: Colors.grey),
                    elevation: MaterialStateProperty.all(0),
                    backgroundColor: MaterialStateProperty.resolveWith((states) => Theme.of(context).colorScheme.surface),
                    textStyle: MaterialStateProperty.resolveWith((states) => TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                    shape: MaterialStateProperty.all(
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ),
            
            _buildSectionHeader(context, 'Trending Offers Nearby', () {}),
            SizedBox(
              height: 140,
              child: offersAsync.when(
                skipLoadingOnReload: false,
                data: (offers) {
                  if (offers.isEmpty) return const Center(child: Text('No active offers nearby.'));
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: offers.length,
                    itemBuilder: (context, index) {
                      final offer = offers[index];
                      return Container(
                        width: 250,
                        margin: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${offer.discountPercentage.toInt()}% OFF',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              offer.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              offer.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => _buildShimmerList(height: 140, width: 250),
                error: (_, __) => const Center(child: Text('Failed to load offers.')),
              ),
            ),
            
            _buildSectionHeader(context, 'Nearby Shops', () => context.push('/radar')),
            SizedBox(
              height: 180,
              child: shopsAsync.when(
                skipLoadingOnReload: false,
                data: (shops) {
                  if (shops.isEmpty) return const Center(child: Text('No shops found nearby.'));
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: shops.length,
                    itemBuilder: (context, index) {
                      final shop = shops[index];
                      return GestureDetector(
                        onTap: () => context.push('/shop_details', extra: shop),
                        child: Container(
                          width: 140,
                          margin: const EdgeInsets.only(right: 16),
                          child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: shop.shopLogo.isNotEmpty ? shop.shopLogo : 'https://via.placeholder.com/150',
                                width: 140,
                                height: 100,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Shimmer.fromColors(
                                  baseColor: Colors.grey[300]!,
                                  highlightColor: Colors.grey[100]!,
                                  child: Container(color: Colors.white),
                                ),
                                errorWidget: (context, url, error) => Container(color: Colors.grey[200], child: const Icon(Icons.store)),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              shop.shopName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '${shop.rating} (${shop.totalReviews})',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                        ),
                      );
                    },
                  );
                },
                loading: () => _buildShimmerList(height: 180, width: 140),
                error: (error, stackTrace) {
                  debugPrint('Error loading shops on home screen: $error\n$stackTrace');
                  return const Center(child: Text('Failed to load shops.'));
                },
              ),
            ),
            
            _buildSectionHeader(context, 'Recommended Products', () {}),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: productsAsync.when(
                skipLoadingOnReload: false,
                data: (products) {
                  if (products.isEmpty) return const Center(child: Text('No products found nearby.'));
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.7,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return GestureDetector(
                        onTap: () => context.push('/product_details', extra: product),
                        child: Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                  child: CachedNetworkImage(
                                    imageUrl: product.images.isNotEmpty ? product.images.first : 'https://via.placeholder.com/150',
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Shimmer.fromColors(
                                      baseColor: Colors.grey[300]!,
                                      highlightColor: Colors.grey[100]!,
                                      child: Container(color: Colors.white),
                                    ),
                                    errorWidget: (context, url, error) => Container(color: Colors.grey[200], child: const Icon(Icons.image)),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          '₹${product.offerPrice}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '₹${product.actualPrice}',
                                          style: const TextStyle(
                                            decoration: TextDecoration.lineThrough,
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: Text('Failed to load products.')),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          TextButton(
            onPressed: onTap,
            child: const Text('See All'),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerList({required double height, required double width}) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            width: width,
            height: height,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }
}
