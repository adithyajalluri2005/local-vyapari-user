import 'package:flutter/material.dart';

// ── FadeInSlide ─────────────────────────────────────────────────────────────
// Fade + vertical slide-in on mount. Stagger with delay = 50ms × index.
class FadeInSlide extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double slideOffset;

  const FadeInSlide({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.delay = Duration.zero,
    this.slideOffset = 20,
  });

  @override
  State<FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<FadeInSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: widget.duration, vsync: this);
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<double>(begin: widget.slideOffset, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _slide.value),
        child: FadeTransition(opacity: _opacity, child: child),
      ),
      child: widget.child,
    );
  }
}

// ── ScaleOnTap ──────────────────────────────────────────────────────────────
// Wraps any tappable widget — scales to 0.97 on press.
class ScaleOnTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  const ScaleOnTap({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
  });

  @override
  State<ScaleOnTap> createState() => _ScaleOnTapState();
}

class _ScaleOnTapState extends State<ScaleOnTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 90),
      vsync: this,
    );
    _anim = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, child) => Transform.scale(scale: _anim.value, child: child),
        child: widget.child,
      ),
    );
  }
}

// ── FadeIndexedStack ─────────────────────────────────────────────────────────
// Cross-fades between bottom-nav screens.
class FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const FadeIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 180),
  });

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.index;
    _ctrl = AnimationController(duration: widget.duration, vsync: this, value: 1.0);
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void didUpdateWidget(FadeIndexedStack old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _ctrl.reverse().then((_) {
        if (mounted) {
          setState(() => _currentIndex = widget.index);
          _ctrl.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: IndexedStack(index: _currentIndex, children: widget.children),
    );
  }
}

// ── AppPageRoute ─────────────────────────────────────────────────────────────
class AppPageRoute {
  static Route<T> slideUp<T>({required Widget page}) => PageRouteBuilder<T>(
        pageBuilder: (_, _, _) => page,
        transitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (_, anim, _, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOutCubic))
              .animate(anim),
          child: child,
        ),
      );

  static Route<T> slideRight<T>({required Widget page}) => PageRouteBuilder<T>(
        pageBuilder: (_, _, _) => page,
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (_, anim, _, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOutCubic))
              .animate(anim),
          child: child,
        ),
      );
}
