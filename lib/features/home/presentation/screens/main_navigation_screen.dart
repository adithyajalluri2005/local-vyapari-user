import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_vyapari_user/core/theme/app_colors.dart';
import 'package:local_vyapari_user/core/theme/app_radius.dart';
import 'package:local_vyapari_user/core/theme/responsive.dart';
import 'package:local_vyapari_user/features/chat/providers/chat_provider.dart';
import 'package:local_vyapari_user/features/chat/presentation/screens/chats_list_screen.dart';
import 'package:local_vyapari_user/features/home/presentation/screens/home_screen.dart';
import 'package:local_vyapari_user/features/offers/presentation/screens/offers_screen.dart';
import 'package:local_vyapari_user/features/profile/presentation/screens/profile_screen.dart';
import 'package:local_vyapari_user/features/search/presentation/screens/search_screen.dart';
import 'package:local_vyapari_user/shared/widgets/app_animations.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class NavigationIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) => state = index;
}

final navigationIndexProvider = NotifierProvider<NavigationIndexNotifier, int>(
  NavigationIndexNotifier.new,
);

// ── Root scaffold ─────────────────────────────────────────────────────────────

class MainNavigationScreen extends ConsumerWidget {
  const MainNavigationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationIndexProvider);
    void onTap(int i) => ref.read(navigationIndexProvider.notifier).setIndex(i);

    final screens = [
      HomeScreen(onSearchTap: () => onTap(1)),
      const SearchScreen(),
      const OffersScreen(),
      const ChatsListScreen(),
      const ProfileScreen(),
    ];

    if (Responsive.useNavRail(context)) {
      return _TabletScaffold(
        currentIndex: currentIndex,
        onTap: onTap,
        screens: screens,
        ref: ref,
      );
    }

    return Scaffold(
      extendBody: true,
      body: FadeIndexedStack(index: currentIndex, children: screens),
      bottomNavigationBar: _FloatingPillNav(
        currentIndex: currentIndex,
        onTap: onTap,
        ref: ref,
      ),
    );
  }
}

// ── Tablet layout with NavigationRail ─────────────────────────────────────────

class _TabletScaffold extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<Widget> screens;
  final WidgetRef ref;

  const _TabletScaffold({
    required this.currentIndex,
    required this.onTap,
    required this.screens,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final extended = Responsive.useExtendedRail(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final railBg = isDark ? AppColors.darkSurface : AppColors.surface;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: railBg,
            extended: extended,
            selectedIndex: currentIndex,
            onDestinationSelected: onTap,
            indicatorColor: AppColors.primary.withValues(alpha: 0.12),
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            selectedIconTheme: const IconThemeData(color: AppColors.primary, size: 22),
            unselectedIconTheme: const IconThemeData(color: AppColors.textHint, size: 22),
            selectedLabelTextStyle: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
            unselectedLabelTextStyle: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textHint,
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: Text('Home'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search_rounded),
                label: Text('Explore'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.local_offer_outlined),
                selectedIcon: Icon(Icons.local_offer_rounded),
                label: Text('Offers'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.chat_bubble_outline_rounded),
                selectedIcon: Icon(Icons.chat_bubble_rounded),
                label: Text('Chats'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: Text('Profile'),
              ),
            ],
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
  _NavItemData(
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    label: 'Home',
    tabIndex: 0,
  ),
  _NavItemData(
    icon: Icons.search_outlined,
    activeIcon: Icons.search_rounded,
    label: 'Explore',
    tabIndex: 1,
  ),
  _NavItemData(
    icon: Icons.local_offer_outlined,
    activeIcon: Icons.local_offer_rounded,
    label: 'Offers',
    tabIndex: 2,
  ),
  _NavItemData(
    icon: Icons.chat_bubble_outline_rounded,
    activeIcon: Icons.chat_bubble_rounded,
    label: 'Chats',
    tabIndex: 3,
  ),
  _NavItemData(
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person_rounded,
    label: 'Profile',
    tabIndex: 4,
  ),
];

class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int tabIndex;
  const _NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
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

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, (bottom > 0 ? bottom : 12)),
      child: Container(
        height: 62,
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
            final badge = item.tabIndex == 3 && unreadCount > 0 ? unreadCount : 0;
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
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? AppColors.primary : Colors.transparent,
                  ),
                  child: Icon(
                    active ? item.activeIcon : item.icon,
                    size: 19,
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
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        item.label,
                        style: GoogleFonts.poppins(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
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
