import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/features/home/presentation/screens/home_screen.dart';
import 'package:local_vyapari_user/features/profile/presentation/screens/profile_screen.dart';
import 'package:local_vyapari_user/features/search/presentation/screens/search_screen.dart';
import 'package:local_vyapari_user/features/offers/presentation/screens/offers_screen.dart';
import 'package:local_vyapari_user/features/favorites/presentation/screens/favorites_screen.dart';

class NavigationIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) => state = index;
}

final navigationIndexProvider = NotifierProvider<NavigationIndexNotifier, int>(
  NavigationIndexNotifier.new,
);

class MainNavigationScreen extends ConsumerWidget {
  const MainNavigationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationIndexProvider);

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: [
          HomeScreen(
            onSearchTap: () => ref.read(navigationIndexProvider.notifier).setIndex(1),
          ),
          const SearchScreen(),
          const OffersScreen(),
          const FavoritesScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: currentIndex,
        onTap: (i) => ref.read(navigationIndexProvider.notifier).setIndex(i),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom bottom navigation — pill indicator above icon, no Material chip
// ─────────────────────────────────────────────────────────────────────────────

const _kNavItems = [
  _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
  _NavItem(icon: Icons.search_outlined, activeIcon: Icons.search_rounded, label: 'Search'),
  _NavItem(icon: Icons.local_offer_outlined, activeIcon: Icons.local_offer_rounded, label: 'Offers'),
  _NavItem(icon: Icons.favorite_outline_rounded, activeIcon: Icons.favorite_rounded, label: 'Saved'),
  _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
];

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkSurface : AppTheme.surfaceColor;
    final border = isDark ? AppTheme.darkBorder : AppTheme.borderColor;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border, width: 0.8)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(
              _kNavItems.length,
              (i) => _NavButton(
                item: _kNavItems[i],
                active: currentIndex == i,
                onTap: () => onTap(i),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool active;
  final VoidCallback onTap;
  const _NavButton({required this.item, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Active indicator — thin pill above icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: active ? 22.0 : 0.0,
              height: 3,
              margin: const EdgeInsets.only(bottom: 5),
              decoration: BoxDecoration(
                color: active ? AppTheme.primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Icon(
              active ? item.activeIcon : item.icon,
              size: 22,
              color: active ? AppTheme.primaryColor : AppTheme.inkFaint,
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? AppTheme.primaryColor : AppTheme.inkFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
