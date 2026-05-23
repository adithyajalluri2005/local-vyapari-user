import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/core/theme/app_sizes.dart';
import 'package:local_vyapari_user/core/theme/app_text_styles.dart';
import 'package:local_vyapari_user/core/theme/app_spacing.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/shared/models/product.dart';
import 'package:go_router/go_router.dart';
import 'package:local_vyapari_user/features/shops/providers/shop_details_provider.dart';
import 'package:local_vyapari_user/features/favorites/presentation/widgets/favorite_button.dart';

class ProductDetailsScreen extends ConsumerWidget {
  final Product product;
  const ProductDetailsScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Responsive.init(context);
    final padding = AppSizes.paddingLarge(context);

    final galleryWidget = Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ProductImageGallery(images: product.images),
    );

    final detailsWidget = _buildDetailsColumn(context, ref);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Product Details',
          style: AppTextStyles.titleMedium(context, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Responsive.isTablet(context)
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 5,
                    child: Center(
                      child: SingleChildScrollView(
                        child: galleryWidget,
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    flex: 5,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(padding),
                      child: detailsWidget,
                    ),
                  ),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    galleryWidget,
                    Padding(
                      padding: EdgeInsets.all(padding),
                      child: detailsWidget,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildDetailsColumn(BuildContext context, WidgetRef ref) {
    final discountPercent = product.actualPrice > 0 
        ? (((product.actualPrice - product.offerPrice) / product.actualPrice) * 100).toInt()
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Text(
                product.category,
                style: AppTextStyles.bodyMedium(context, color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
              ),
            ),
            if (product.isOutOfStock)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  'OUT OF STOCK',
                  style: AppTextStyles.bodyMedium(context, color: AppTheme.errorColor, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        AppSpacing.verticalSm,
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                product.name,
                style: AppTextStyles.titleLarge(context, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            FavoriteButton(
              itemId: product.id,
              type: FavoriteType.product,
            ),
          ],
        ),
        AppSpacing.verticalMd,
        Row(
          children: [
            Text(
              '₹${product.offerPrice}',
              style: AppTextStyles.titleLarge(context, color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
            ),
            AppSpacing.horizontalSm,
            Text(
              '₹${product.actualPrice}',
              style: AppTextStyles.bodyLarge(context, color: Colors.grey).copyWith(
                decoration: TextDecoration.lineThrough,
              ),
            ),
            if (discountPercent > 0) ...[
              AppSpacing.horizontalSm,
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  '$discountPercent% OFF',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
        AppSpacing.verticalLg,
        const Divider(),
        AppSpacing.verticalMd,
        Text(
          'Description',
          style: AppTextStyles.titleSmall(context, fontWeight: FontWeight.bold),
        ),
        AppSpacing.verticalSm,
        Text(
          product.description,
          style: AppTextStyles.bodyLarge(context, color: Colors.grey[800], height: 1.5),
        ),
        AppSpacing.verticalLg,
        const Divider(),
        AppSpacing.verticalMd,
        Text(
          'Sold by',
          style: AppTextStyles.titleSmall(context, fontWeight: FontWeight.bold),
        ),
        AppSpacing.verticalSm,
        ref.watch(shopDetailsProvider(product.shopId)).when(
          data: (shop) {
            if (shop == null) return const Text('Shop details not available');
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.all(AppSizes.paddingMedium(context)),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundImage: shop.shopLogo.isNotEmpty ? NetworkImage(shop.shopLogo) : null,
                  child: shop.shopLogo.isEmpty ? const Icon(Icons.store) : null,
                ),
                title: Text(
                  shop.shopName, 
                  style: AppTextStyles.bodyLarge(context, fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          '${shop.rating} (${shop.totalReviews} reviews)', 
                          style: AppTextStyles.bodyMedium(context),
                        ),
                      ],
                    ),
                    if (shop.location.address.isNotEmpty || shop.location.city.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        shop.location.address.isNotEmpty ? shop.location.address : shop.location.city,
                        style: AppTextStyles.bodyMedium(context, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ]
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/shop_details', extra: shop),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const SizedBox(),
        ),
      ],
    );
  }
}

class ProductImageGallery extends StatefulWidget {
  final List<String> images;
  const ProductImageGallery({super.key, required this.images});

  @override
  State<ProductImageGallery> createState() => _ProductImageGalleryState();
}

class _ProductImageGalleryState extends State<ProductImageGallery> {
  late final PageController _pageController;
  late final ScrollController _thumbnailScrollController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _thumbnailScrollController = ScrollController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbnailScrollController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    if (_thumbnailScrollController.hasClients) {
      final targetOffset = index * 70.0;
      final maxScrollExtent = _thumbnailScrollController.position.maxScrollExtent;
      final minScrollExtent = _thumbnailScrollController.position.minScrollExtent;
      
      final screenWidth = MediaQuery.of(context).size.width;
      final centeredOffset = targetOffset - (screenWidth / 2) + 35.0;
      
      final double scrollPosition = centeredOffset.clamp(minScrollExtent, maxScrollExtent);
      
      _thumbnailScrollController.animateTo(
        scrollPosition,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _openFullscreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullscreenImageGallery(
          images: widget.images,
          initialIndex: _currentIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return Container(
        height: 300,
        width: double.infinity,
        color: Colors.grey[200],
        child: const Icon(Icons.image, size: 50, color: Colors.grey),
      );
    }

    final galleryHeight = Responsive.isTablet(context) ? 400.0 : 320.0;

    return Column(
      children: [
        Stack(
          children: [
            GestureDetector(
              onTap: () => _openFullscreen(context),
              child: SizedBox(
                height: galleryHeight,
                width: double.infinity,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: widget.images.length,
                  itemBuilder: (context, index) {
                    return Hero(
                      tag: 'product_image_${widget.images[index]}',
                      child: CachedNetworkImage(
                        imageUrl: widget.images[index],
                        fit: BoxFit.contain,
                        placeholder: (context, url) => Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(color: Colors.white),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.image, size: 50, color: Colors.grey),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (widget.images.length > 1)
              Positioned(
                right: 16,
                bottom: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: Text(
                    '${_currentIndex + 1}/${widget.images.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (widget.images.length > 1) ...[
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              height: 64,
              child: ListView.builder(
                controller: _thumbnailScrollController,
                shrinkWrap: true,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: widget.images.length,
                itemBuilder: (context, index) {
                  final isSelected = index == _currentIndex;
                  return GestureDetector(
                    onTap: () => _goToPage(index),
                    child: Container(
                      width: 60,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
                          width: isSelected ? 2.5 : 1.0,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(0.3),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm - 2),
                        child: CachedNetworkImage(
                          imageUrl: widget.images[index],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[100],
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.image,
                            size: 20,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class FullscreenImageGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const FullscreenImageGallery({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<FullscreenImageGallery> createState() => _FullscreenImageGalleryState();
}

class _FullscreenImageGalleryState extends State<FullscreenImageGallery> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemCount: widget.images.length,
            itemBuilder: (context, index) {
              return Center(
                child: Hero(
                  tag: 'product_image_${widget.images[index]}',
                  child: _FullscreenImageItem(imageUrl: widget.images[index]),
                ),
              );
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.black.withOpacity(0.5),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentIndex + 1} of ${widget.images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FullscreenImageItem extends StatefulWidget {
  final String imageUrl;
  const _FullscreenImageItem({required this.imageUrl});

  @override
  State<_FullscreenImageItem> createState() => _FullscreenImageItemState();
}

class _FullscreenImageItemState extends State<_FullscreenImageItem> {
  final TransformationController _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      _transformationController.value = Matrix4.identity();
    } else {
      final position = _doubleTapDetails!.localPosition;
      _transformationController.value = Matrix4.identity()
        ..translate(-position.dx * 1.5, -position.dy * 1.5)
        ..scale(2.5);
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 0.5,
        maxScale: 4.0,
        child: CachedNetworkImage(
          imageUrl: widget.imageUrl,
          fit: BoxFit.contain,
          placeholder: (context, url) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          errorWidget: (context, url, error) => const Icon(
            Icons.image,
            size: 100,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}
