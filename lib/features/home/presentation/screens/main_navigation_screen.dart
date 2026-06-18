import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/features/chat/providers/chat_provider.dart';
import 'package:local_vyapari_user/features/chat/presentation/screens/chats_list_screen.dart';
import 'package:local_vyapari_user/features/favorites/presentation/screens/favorites_screen.dart';
import 'package:local_vyapari_user/features/home/presentation/screens/home_screen.dart';
import 'package:local_vyapari_user/features/home/providers/navigation_provider.dart';
import 'package:local_vyapari_user/features/offers/presentation/screens/offers_screen.dart';
import 'package:local_vyapari_user/features/profile/presentation/screens/profile_screen.dart';
import 'package:local_vyapari_user/features/search/presentation/screens/search_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:local_vyapari_user/core/providers/notification_route_provider.dart';
import 'package:local_vyapari_user/shared/widgets/app_animations.dart';
import 'package:local_vyapari_user/shared/widgets/custom_snack_bar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:local_vyapari_user/services/location/location_service.dart';

export 'package:local_vyapari_user/features/home/providers/navigation_provider.dart';

// ── Root scaffold ─────────────────────────────────────────────────────────────

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  DateTime? _lastBackPressed;

  @override
  void initState() {
    super.initState();
    // Consume any pending notification captured before auth completed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = ref.read(pendingNotificationRouteProvider);
      if (pending != null && mounted) {
        ref.read(pendingNotificationRouteProvider.notifier).set(null);
        context.push(pending.route, extra: pending.extra);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Also react to notifications set AFTER this screen mounts (e.g. background tap
    // while the screen is already on screen). ref.listen fires on every state change.
    ref.listen<PendingNotification?>(pendingNotificationRouteProvider, (_, pending) {
      if (pending == null || !mounted) return;
      ref.read(pendingNotificationRouteProvider.notifier).set(null);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.push(pending.route, extra: pending.extra);
      });
    });

    final locationState = ref.watch(activeBrowsingLocationProvider);

    return locationState.when(
      loading: () => const _LocationLoadingGate(),
      error: (err, stack) => _LocationOnboardingGate(
        error: err.toString().replaceFirst('Exception: ', ''),
      ),
      data: (location) {
        if (location == null) {
          return const _LocationOnboardingGate();
        }

        final currentIndex = ref.watch(navigationIndexProvider);
        void onTap(int i) => ref.read(navigationIndexProvider.notifier).setIndex(i);

        final screens = [
          HomeScreen(onSearchTap: () => onTap(1)),
          const SearchScreen(),
          const OffersScreen(),
          const FavoritesScreen(),
          const ChatsListScreen(),
          const ProfileScreen(),
        ];

        final body = Responsive.useNavRail(context)
            ? _TabletScaffold(
                currentIndex: currentIndex,
                onTap: onTap,
                screens: screens,
              )
            : Scaffold(
                extendBody: true,
                body: FadeIndexedStack(index: currentIndex, children: screens),
                bottomNavigationBar: _FloatingPillNav(
                  currentIndex: currentIndex,
                  onTap: onTap,
                  ref: ref,
                ),
              );

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;

            if (currentIndex != 0) {
              ref.read(navigationIndexProvider.notifier).setIndex(0);
              return;
            }

            final now = DateTime.now();
            if (_lastBackPressed != null &&
                now.difference(_lastBackPressed!) < const Duration(seconds: 2)) {
              SystemNavigator.pop();
              return;
            }
            _lastBackPressed = now;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Press back again to exit'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: body,
        );
      },
    );
  }
}

// ── Tab index → label ─────────────────────────────────────────────────────────

String _navLabel(BuildContext context, int index) {
  switch (index) {
    case 0: return 'Home';
    case 1: return 'Explore';
    case 2: return 'Offers';
    case 3: return 'Favourites';
    case 4: return 'Chats';
    case 5: return 'Profile';
    default: return '';
  }
}

// ── Tablet layout with NavigationRail ─────────────────────────────────────────

class _TabletScaffold extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<Widget> screens;

  const _TabletScaffold({
    required this.currentIndex,
    required this.onTap,
    required this.screens,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extended = Responsive.useExtendedRail(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final railBg = isDark ? AppColors.darkSurface : AppColors.surface;

    final chatsAsync = ref.watch(userChatsStreamProvider);
    final unreadCount = chatsAsync.whenOrNull(
          data: (sessions) => sessions.where((s) => s.unread).length,
        ) ??
        0;

    return Scaffold(
      body: Row(
        children: [
          SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height,
              ),
              child: IntrinsicHeight(
                child: NavigationRail(
                  backgroundColor: railBg,
                  extended: extended,
                  selectedIndex: currentIndex,
                  onDestinationSelected: onTap,
                  indicatorColor: AppColors.primary.withValues(alpha: 0.12),
                  indicatorShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  selectedIconTheme: IconThemeData(
                    color: isDark ? Colors.white : AppColors.primary,
                    size: 22,
                  ),
                  unselectedIconTheme: const IconThemeData(
                    color: AppColors.textHint,
                    size: 22,
                  ),
                  selectedLabelTextStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.primary,
                  ),
                  unselectedLabelTextStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(Icons.home_outlined),
                      selectedIcon: const Icon(Icons.home_rounded),
                      label: Text(_navLabel(context, 0)),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.search_outlined),
                      selectedIcon: const Icon(Icons.search_rounded),
                      label: Text(_navLabel(context, 1)),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.local_offer_outlined),
                      selectedIcon: const Icon(Icons.local_offer_rounded),
                      label: Text(_navLabel(context, 2)),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.favorite_outline_rounded),
                      selectedIcon: const Icon(Icons.favorite_rounded),
                      label: Text(_navLabel(context, 3)),
                    ),
                    NavigationRailDestination(
                      icon: Badge(
                        isLabelVisible: unreadCount > 0,
                        label: Text(unreadCount > 9 ? '9+' : '$unreadCount'),
                        child: const Icon(Icons.chat_bubble_outline_rounded),
                      ),
                      selectedIcon: Badge(
                        isLabelVisible: unreadCount > 0,
                        label: Text(unreadCount > 9 ? '9+' : '$unreadCount'),
                        child: const Icon(Icons.chat_bubble_rounded),
                      ),
                      label: Text(_navLabel(context, 4)),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.person_outline_rounded),
                      selectedIcon: const Icon(Icons.person_rounded),
                      label: Text(_navLabel(context, 5)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: FadeIndexedStack(index: currentIndex, children: screens)),
        ],
      ),
    );
  }
}

// ── Floating pill bottom nav ───────────────────────────────────────────────────

const _kNavItems = [
  _NavItemData(icon: Icons.home_outlined,             activeIcon: Icons.home_rounded,             tabIndex: 0),
  _NavItemData(icon: Icons.search_outlined,           activeIcon: Icons.search_rounded,           tabIndex: 1),
  _NavItemData(icon: Icons.local_offer_outlined,      activeIcon: Icons.local_offer_rounded,      tabIndex: 2),
  _NavItemData(icon: Icons.favorite_outline_rounded,  activeIcon: Icons.favorite_rounded,         tabIndex: 3),
  _NavItemData(icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded,    tabIndex: 4),
  _NavItemData(icon: Icons.person_outline_rounded,    activeIcon: Icons.person_rounded,           tabIndex: 5),
];

class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final int tabIndex;
  const _NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.tabIndex,
  });
}

class _FloatingPillNav extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final WidgetRef ref;

  const _FloatingPillNav({
    required this.currentIndex,
    required this.onTap,
    required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : AppColors.surface;
    final shadow = Colors.black.withValues(alpha: isDark ? 0.22 : 0.055);
    final bottom = MediaQuery.of(context).padding.bottom;

    final chatsAsync = ref.watch(userChatsStreamProvider);
    final unreadCount = chatsAsync.whenOrNull(
          data: (sessions) => sessions.where((s) => s.unread).length,
        ) ??
        0;

    final isSmall = Responsive.isSmallPhone(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(isSmall ? 10 : 16, 0, isSmall ? 10 : 16, (bottom > 0 ? bottom : 12)),
      child: Container(
        height: isSmall ? 56.0 : 62.0,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.full),
          boxShadow: [
            BoxShadow(color: shadow, blurRadius: 14, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: _kNavItems.map((item) {
            final active = currentIndex == item.tabIndex;
            final badge = item.tabIndex == 4 && unreadCount > 0 ? unreadCount : 0;
            return _NavButton(
              item: item,
              active: active,
              badge: badge,
              onTap: () => onTap(item.tabIndex),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final _NavItemData item;
  final bool active;
  final int badge;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.active,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSmall = Responsive.isSmallPhone(context);
    final circleSize = isSmall ? 30.0 : 36.0;
    final iconSize = isSmall ? 16.0 : 19.0;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  width: circleSize,
                  height: circleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? AppColors.primary : Colors.transparent,
                  ),
                  child: Icon(
                    active ? item.activeIcon : item.icon,
                    size: iconSize,
                    color: active ? Colors.white : AppColors.textHint,
                  ),
                ),
                if (badge > 0)
                  Positioned(
                    top: -2,
                    right: -4,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          badge > 9 ? '9+' : '$badge',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: active
                  ? Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _navLabel(context, item.tabIndex),
                        style: GoogleFonts.poppins(
                          fontSize: isSmall ? 8.5 : 9.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.primary,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Location Loading Gate ───────────────────────────────────────────────────

class _LocationLoadingGate extends StatelessWidget {
  const _LocationLoadingGate();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTablet = Responsive.isTablet(context);
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkScaffold : AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const PulsingRadarIcon(),
            const SizedBox(height: 28),
            Text(
              'Identifying your location...',
              style: GoogleFonts.poppins(
                fontSize: isTablet ? 19.0 : 16.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Looking for nearby shops and deals',
              style: GoogleFonts.poppins(
                fontSize: isTablet ? 15.0 : 13.0,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pulsing Radar Icon Animation ──────────────────────────────────────────────

class PulsingRadarIcon extends StatefulWidget {
  const PulsingRadarIcon({super.key});

  @override
  State<PulsingRadarIcon> createState() => _PulsingRadarIconState();
}

class _PulsingRadarIconState extends State<PulsingRadarIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            for (int i = 0; i < 3; i++)
              Container(
                width: 70.0 + (i * 35.0) * _controller.value,
                height: 70.0 + (i * 35.0) * _controller.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(
                    alpha: (0.15 * (1.0 - _controller.value)).clamp(0.0, 1.0),
                  ),
                ),
              ),
            Container(
              width: 65,
              height: 65,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
              child: const Icon(
                Icons.my_location_rounded,
                size: 28,
                color: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Location Onboarding / Request Gate ────────────────────────────────────────

class _LocationOnboardingGate extends ConsumerStatefulWidget {
  final String? error;
  const _LocationOnboardingGate({super.key, this.error});

  @override
  ConsumerState<_LocationOnboardingGate> createState() => _LocationOnboardingGateState();
}

class _LocationOnboardingGateState extends ConsumerState<_LocationOnboardingGate> {
  bool _loading = false;

  void _useGps() async {
    setState(() => _loading = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() => _loading = false);
          CustomSnackBar.showError(
            context: context,
            title: 'Location Services Disabled',
            message: 'Please enable GPS/location services in your device settings.',
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _loading = false);
          CustomSnackBar.showError(
            context: context,
            title: 'Permission Denied',
            message: 'Location permissions are permanently denied. Please enable them in settings or search manually.',
          );
        }
        return;
      }

      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() => _loading = false);
          CustomSnackBar.showError(
            context: context,
            title: 'Permission Denied',
            message: 'Location permission was denied. We need it to find nearby stores.',
          );
        }
        return;
      }

      final ok = await ref.read(activeBrowsingLocationProvider.notifier).locateAndSetGPS();
      if (mounted) {
        setState(() => _loading = false);
        if (!ok) {
          CustomSnackBar.showError(
            context: context,
            title: 'Location Fetch Failed',
            message: 'Could not retrieve GPS coordinates. Please select manually.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        CustomSnackBar.showError(
          context: context,
          title: 'Error',
          message: 'An unexpected error occurred: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hPad = Responsive.horizontalPadding(context);
    final isTablet = Responsive.isTablet(context);
    final isSmall = Responsive.isSmallPhone(context);
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkScaffold : AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad + 8, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              FadeInSlide(
                duration: const Duration(milliseconds: 500),
                child: Icon(
                  Icons.location_on_rounded,
                  size: isTablet ? 108.0 : (isSmall ? 68.0 : 84.0),
                  color: AppColors.primary.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 32),
              FadeInSlide(
                delay: const Duration(milliseconds: 100),
                child: Text(
                  'Where are you shopping from?',
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 28.0 : (isSmall ? 20.0 : 24.0),
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    height: 1.25,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              FadeInSlide(
                delay: const Duration(milliseconds: 200),
                child: Text(
                  'To show you nearby local stores, exclusive deals, and fast delivery, we need your shopping location.',
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 15.5 : (isSmall ? 13.0 : 14.0),
                    color: isDark ? Colors.white70 : AppColors.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (widget.error != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.error!,
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            color: AppColors.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(flex: 2),
              FadeInSlide(
                delay: const Duration(milliseconds: 300),
                child: ScaleOnTap(
                  child: ElevatedButton(
                    onPressed: _loading ? null : _useGps,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.my_location_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Use Current Location (GPS)',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.5,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FadeInSlide(
                delay: const Duration(milliseconds: 400),
                child: OutlinedButton(
                  onPressed: () => context.push('/location_search'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(
                      color: isDark ? Colors.white24 : AppColors.border,
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: isDark ? Colors.white70 : AppColors.textPrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Select Location Manually',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
          ),
        ),
      ),
    );
  }
}
