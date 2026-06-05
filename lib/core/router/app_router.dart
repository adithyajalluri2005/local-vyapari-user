import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_vyapari_user/features/auth/models/auth_state.dart';
import 'package:local_vyapari_user/features/auth/providers/auth_provider.dart';
import 'package:local_vyapari_user/features/auth/presentation/screens/splash_screen.dart';
import 'package:local_vyapari_user/features/auth/presentation/screens/login_screen.dart';
import 'package:local_vyapari_user/features/auth/presentation/screens/register_screen.dart';
import 'package:local_vyapari_user/features/auth/presentation/screens/display_name_screen.dart';
import 'package:local_vyapari_user/features/home/presentation/screens/main_navigation_screen.dart';
import 'package:local_vyapari_user/features/location/presentation/screens/location_search_screen.dart';
import 'package:local_vyapari_user/features/shops/presentation/screens/shop_details_screen.dart';
import 'package:local_vyapari_user/features/products/presentation/screens/product_details_screen.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';
import 'package:local_vyapari_user/shared/models/product.dart';
import 'package:local_vyapari_user/features/offers/presentation/screens/offer_details_screen.dart';
import 'package:local_vyapari_user/shared/models/offer.dart';
import 'package:local_vyapari_user/features/shops/presentation/screens/hyperlocal_radar_screen.dart';
import 'package:local_vyapari_user/features/chat/presentation/screens/chat_screen.dart';
import 'package:local_vyapari_user/features/chat/presentation/screens/chats_list_screen.dart';
import 'package:local_vyapari_user/features/security/presentation/screens/security_settings_screen.dart';
import 'package:local_vyapari_user/features/products/presentation/screens/product_image_fullscreen_screen.dart';
import 'package:local_vyapari_user/features/offers/presentation/screens/all_offers_screen.dart';

enum TransitionType { slide, fade, scale, slideUp }

CustomTransitionPage<T> buildPageWithTransition<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
  TransitionType transitionType = TransitionType.slide,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      switch (transitionType) {
        case TransitionType.fade:
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        case TransitionType.scale:
          return ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        case TransitionType.slideUp:
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.15),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        case TransitionType.slide:
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
      }
    },
    transitionDuration: const Duration(milliseconds: 300),
  );
}

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  String? _lastAccountStatus;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(
      authProvider,
      (_, _) => notifyListeners(),
    );
    // Only force a re-route when the account status changes to banned/suspended.
    // Listening to every profile field update would rebuild the GoRouter stack
    // on every RTDB stream event, corrupting pushed navigation history.
    _ref.listen<AsyncValue<Map<String, dynamic>?>>(
      userProfileProvider,
      (_, next) {
        final status = next.value?['status']?.toString();
        if (status != _lastAccountStatus) {
          _lastAccountStatus = status;
          if (status == 'suspended' || status == 'banned') {
            notifyListeners();
          }
        }
      },
    );
  }
}

final routerNotifierProvider = Provider((ref) => RouterNotifier(ref));

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final routerNotifier = ref.read(routerNotifierProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: routerNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final profileState = ref.read(userProfileProvider);

      // Check account status (gating for banned/suspended accounts)
      if (profileState.hasValue && profileState.value != null) {
        final status = profileState.value!['status']?.toString();
        if (status == 'suspended' || status == 'banned') {
          // Immediately log out suspended/banned user
          ref.read(authProvider.notifier).logout();
          return '/login';
        }
      }

      final isGoingToLogin = state.matchedLocation == '/login';
      final isGoingToRegister = state.matchedLocation == '/register';
      final isGoingToSplash = state.matchedLocation == '/';

      final isAuthScreen = isGoingToLogin || isGoingToRegister;

      if (authState is AuthInitial) {
        return '/';
      }

      if (authState is AuthLoading) {
        return null;
      }

      if (authState is Unauthenticated) {
        if (isAuthScreen) return null;
        return '/login';
      }

      if (authState is NeedsDisplayName) {
        if (state.matchedLocation == '/display_name') return null;
        return '/display_name';
      }

      if (authState is Authenticated) {
        if (isAuthScreen || isGoingToSplash || state.matchedLocation == '/display_name') {
          return '/home';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => buildPageWithTransition(
          context: context,
          state: state,
          child: const SplashScreen(),
          transitionType: TransitionType.fade,
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => buildPageWithTransition(
          context: context,
          state: state,
          child: const LoginScreen(),
          transitionType: TransitionType.fade,
        ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => buildPageWithTransition(
          context: context,
          state: state,
          child: const RegisterScreen(),
          transitionType: TransitionType.slide,
        ),
      ),
      GoRoute(
        path: '/display_name',
        pageBuilder: (context, state) => buildPageWithTransition(
          context: context,
          state: state,
          child: const DisplayNameScreen(),
          transitionType: TransitionType.fade,
        ),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (context, state) => buildPageWithTransition(
          context: context,
          state: state,
          child: const MainNavigationScreen(),
          transitionType: TransitionType.fade,
        ),
      ),
      GoRoute(
        path: '/location_search',
        pageBuilder: (context, state) => buildPageWithTransition(
          context: context,
          state: state,
          child: const LocationSearchScreen(),
          transitionType: TransitionType.slideUp,
        ),
      ),
      GoRoute(
        path: '/shop_details',
        redirect: (context, state) => state.extra == null ? '/home' : null,
        pageBuilder: (context, state) {
          final shop = state.extra as Shop;
          return buildPageWithTransition(
            context: context,
            state: state,
            child: ShopDetailsScreen(shop: shop),
            transitionType: TransitionType.slide,
          );
        },
      ),
      GoRoute(
        path: '/product_details',
        redirect: (context, state) => state.extra == null ? '/home' : null,
        pageBuilder: (context, state) {
          final product = state.extra as Product;
          return buildPageWithTransition(
            context: context,
            state: state,
            child: ProductDetailsScreen(product: product),
            transitionType: TransitionType.slide,
          );
        },
      ),
      GoRoute(
        path: '/offer_details',
        redirect: (context, state) => state.extra == null ? '/home' : null,
        pageBuilder: (context, state) {
          final offer = state.extra as Offer;
          return buildPageWithTransition(
            context: context,
            state: state,
            child: OfferDetailsScreen(offer: offer),
            transitionType: TransitionType.slide,
          );
        },
      ),
      GoRoute(
        path: '/radar',
        pageBuilder: (context, state) => buildPageWithTransition(
          context: context,
          state: state,
          child: const HyperlocalRadarScreen(),
          transitionType: TransitionType.slideUp,
        ),
      ),
      GoRoute(
        path: '/all_offers',
        pageBuilder: (context, state) => buildPageWithTransition(
          context: context,
          state: state,
          child: const AllOffersScreen(),
          transitionType: TransitionType.slide,
        ),
      ),
      GoRoute(
        path: '/chat',
        redirect: (context, state) => state.extra == null ? '/home' : null,
        pageBuilder: (context, state) {
          final extras = state.extra as Map<dynamic, dynamic>;
          final shopId = extras['shopId']?.toString() ?? '';
          final shopName = extras['shopName']?.toString() ?? '';
          final shopLogo = extras['shopLogo']?.toString() ?? '';
          return buildPageWithTransition(
            context: context,
            state: state,
            child: ChatScreen(
              shopId: shopId,
              shopName: shopName,
              shopLogo: shopLogo,
            ),
            transitionType: TransitionType.slide,
          );
        },
      ),
      GoRoute(
        path: '/chats',
        pageBuilder: (context, state) => buildPageWithTransition(
          context: context,
          state: state,
          child: const ChatsListScreen(),
          transitionType: TransitionType.slide,
        ),
      ),
      GoRoute(
        path: '/security',
        pageBuilder: (context, state) => buildPageWithTransition(
          context: context,
          state: state,
          child: const SecuritySettingsScreen(),
          transitionType: TransitionType.slide,
        ),
      ),
      GoRoute(
        path: '/product_image_fullscreen',
        redirect: (context, state) => state.extra == null ? '/home' : null,
        pageBuilder: (context, state) {
          final extras = state.extra as Map<dynamic, dynamic>;
          final images = List<String>.from(extras['images'] as List? ?? []);
          final initialIndex = (extras['initialIndex'] as int?) ?? 0;
          return buildPageWithTransition(
            context: context,
            state: state,
            child: ProductImageFullscreenScreen(
              images: images,
              initialIndex: initialIndex,
            ),
            transitionType: TransitionType.fade,
          );
        },
      ),
    ],
  );
});
