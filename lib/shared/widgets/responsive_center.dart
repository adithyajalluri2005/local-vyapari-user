import 'package:flutter/material.dart';
import 'package:local_vyapari_user/core/theme/app_dimensions.dart';

/// Centers [child] horizontally and caps its width on wide screens (tablets),
/// while staying full-width on phones. Pairs with [Responsive] breakpoint helper.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  /// Content width cap (default [AppDimensions.maxContentWidth] = 600).
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = AppDimensions.maxContentWidth,
    this.padding,
  });

  /// Narrower cap for forms (sign-in, onboarding, etc.) = 480.
  const ResponsiveCenter.form({
    super.key,
    required this.child,
    this.padding,
  }) : maxWidth = AppDimensions.maxFormWidth;

  /// Wide cap for content-rich screens (home feed, shop detail) = 900.
  const ResponsiveCenter.wide({
    super.key,
    required this.child,
    this.padding,
  }) : maxWidth = AppDimensions.maxWideContentWidth;

  @override
  Widget build(BuildContext context) {
    Widget content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    );
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }
    return Align(alignment: Alignment.topCenter, child: content);
  }
}
