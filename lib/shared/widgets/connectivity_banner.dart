import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_user/services/connectivity/connectivity_provider.dart';

class ConnectivityBanner extends ConsumerStatefulWidget {
  final Widget child;
  const ConnectivityBanner({super.key, required this.child});

  @override
  ConsumerState<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends ConsumerState<ConnectivityBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;

  bool _wasOffline = false;
  bool _showBackOnline = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onConnectivityChanged(bool isOnline) {
    if (!isOnline) {
      _hideTimer?.cancel();
      setState(() {
        _showBackOnline = false;
        _wasOffline = true;
      });
      _controller.forward();
    } else if (_wasOffline) {
      setState(() => _showBackOnline = true);
      // keep banner visible briefly so user sees "Back online"
      _hideTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          _controller.reverse().then((_) {
            if (mounted) {
              setState(() {
                _wasOffline = false;
                _showBackOnline = false;
              });
            }
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<bool>>(connectivityProvider, (_, next) {
      next.whenData(_onConnectivityChanged);
    });

    final isOnline = ref.watch(isOnlineProvider);

    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SlideTransition(
            position: _slideAnimation,
            child: _BannerContent(
              isOnline: isOnline || _showBackOnline,
              showBackOnline: _showBackOnline,
            ),
          ),
        ),
      ],
    );
  }
}

class _BannerContent extends StatelessWidget {
  final bool isOnline;
  final bool showBackOnline;

  const _BannerContent({required this.isOnline, required this.showBackOnline});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final backgroundColor =
        showBackOnline ? const Color(0xFF15803D) : const Color(0xFF1A2433);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      color: backgroundColor,
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            showBackOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            showBackOnline ? 'Back online' : 'No internet connection',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
