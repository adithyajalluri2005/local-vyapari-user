import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';

/// Base primitive rendered inside a [Shimmer.fromColors].
/// Layout: avatar circle | title line + subtitle line.
/// Mirrors the ShopCard / ChatTile card layout.
class SkeletonCard extends StatelessWidget {
  final double avatarRadius;
  final EdgeInsetsGeometry padding;

  const SkeletonCard({
    super.key,
    this.avatarRadius = 24,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          CircleAvatar(radius: avatarRadius, backgroundColor: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 13,
                  width: 130,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 11,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmer-animated list of [count] [SkeletonCard]s.
/// Drop-in replacement for a [CircularProgressIndicator] in list screens.
class SkeletonListView extends StatelessWidget {
  final int count;
  final EdgeInsets listPadding;
  final double avatarRadius;

  const SkeletonListView({
    super.key,
    this.count = 6,
    this.listPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.avatarRadius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF222C36) : AppColors.border,
      highlightColor: isDark ? const Color(0xFF2C3742) : AppColors.surfaceElevated,
      child: ListView.builder(
        padding: listPadding,
        itemCount: count,
        itemBuilder: (context, i) => SkeletonCard(avatarRadius: avatarRadius),
      ),
    );
  }
}

/// Shimmer-animated product grid: image block + title + price lines.
/// Pass [shrinkWrap: false] when used inside an [Expanded] (tablet layout).
class SkeletonProductGrid extends StatelessWidget {
  final int crossAxisCount;
  final double aspectRatio;
  final double spacing;
  final EdgeInsets padding;
  final bool shrinkWrap;
  /// Number of skeleton rows to render (default 2).
  final int rowCount;

  const SkeletonProductGrid({
    super.key,
    this.crossAxisCount = 2,
    this.aspectRatio = 0.70,
    this.spacing = 12,
    this.padding = EdgeInsets.zero,
    this.shrinkWrap = true,
    this.rowCount = 2,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF222C36) : AppColors.border,
      highlightColor: isDark ? const Color(0xFF2C3742) : AppColors.surfaceElevated,
      child: GridView.builder(
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
        padding: padding,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: aspectRatio,
        ),
        itemCount: crossAxisCount * rowCount,
        itemBuilder: (context, i) => const _ProductSkeleton(),
      ),
    );
  }
}

class _ProductSkeleton extends StatelessWidget {
  const _ProductSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  height: 10,
                  width: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmer-animated chat message bubble placeholders.
class SkeletonChatMessages extends StatelessWidget {
  const SkeletonChatMessages({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF222C36) : AppColors.border,
      highlightColor: isDark ? const Color(0xFF2C3742) : AppColors.surfaceElevated,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          children: [
            _BubbleSkeleton(fromUser: false, widthFraction: 0.60),
            _BubbleSkeleton(fromUser: true, widthFraction: 0.44),
            _BubbleSkeleton(fromUser: false, widthFraction: 0.72),
            _BubbleSkeleton(fromUser: true, widthFraction: 0.36),
            _BubbleSkeleton(fromUser: false, widthFraction: 0.55),
          ],
        ),
      ),
    );
  }
}

class _BubbleSkeleton extends StatelessWidget {
  final bool fromUser;
  final double widthFraction;

  const _BubbleSkeleton({required this.fromUser, required this.widthFraction});

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * widthFraction;
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        width: maxWidth,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
    );
  }
}
