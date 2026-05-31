import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/services/cache/app_cache_manager.dart';

/// A consistent network image with a shimmer placeholder and a branded
/// fallback. Safely handles empty/invalid URLs (which would otherwise throw
/// or render broken-image icons).
class AppNetworkImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final IconData fallbackIcon;
  final BorderRadius? borderRadius;

  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.image_outlined,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkSurfaceMuted : AppTheme.surfaceMuted;
    final shimmerBase = isDark ? const Color(0xFF222C36) : const Color(0xFFE9ECEF);
    final shimmerHi = isDark ? const Color(0xFF2C3742) : const Color(0xFFF4F6F8);

    Widget child;
    if (url.trim().isEmpty) {
      child = _fallback(muted);
    } else {
      child = CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        cacheManager: AppCacheManager(),
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (context, _) => Shimmer.fromColors(
          baseColor: shimmerBase,
          highlightColor: shimmerHi,
          child: Container(width: width, height: height, color: shimmerBase),
        ),
        errorWidget: (context, _, _) => _fallback(muted),
      );
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }

  Widget _fallback(Color bg) {
    return Container(
      width: width,
      height: height,
      color: bg,
      alignment: Alignment.center,
      child: Icon(fallbackIcon, color: AppTheme.inkFaint, size: 28),
    );
  }
}
