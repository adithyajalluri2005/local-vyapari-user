import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/features/favorites/providers/favorites_provider.dart';

enum FavoriteType { product, shop }

class FavoriteButton extends ConsumerStatefulWidget {
  final String itemId;
  final FavoriteType type;
  final double size;
  final Color? color;

  const FavoriteButton({
    super.key,
    required this.itemId,
    required this.type,
    this.size = 28.0,
    this.color,
  });

  @override
  ConsumerState<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<FavoriteButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favoritesStateAsync = ref.watch(favoritesProvider);

    if (favoritesStateAsync.isLoading) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: const Padding(
          padding: EdgeInsets.all(4.0),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final favoritesState = favoritesStateAsync.value;
    final isFavorite = favoritesState != null && 
        (widget.type == FavoriteType.product 
            ? favoritesState.productIds.contains(widget.itemId) 
            : favoritesState.shopIds.contains(widget.itemId));

    return GestureDetector(
      onTap: () {
        _controller.forward(from: 0.0);
        if (widget.type == FavoriteType.product) {
          ref.read(favoritesProvider.notifier).toggleFavoriteProduct(widget.itemId);
        } else {
          ref.read(favoritesProvider.notifier).toggleFavoriteShop(widget.itemId);
        }
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? Colors.red : (widget.color ?? Colors.grey),
              size: widget.size,
            ),
          );
        },
      ),
    );
  }
}
