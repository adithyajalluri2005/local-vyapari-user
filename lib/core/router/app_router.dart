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

CustomTransitionPage<T> buildFadeThroughPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final enterFade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      final enterScale = Tween<double>(begin: 0.94, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

      final exitFade = Tween<double>(begin: 1.0, end: 0.85).animate(
          CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeIn));
      final exitScale = Tween<double>(begin: 1.0, end: 0.96).animate(
          CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeIn));

      return FadeTransition(
        opacity: exitFade,
        child: ScaleTransition(
          scale: exitScale,
          child: FadeTransition(
            opacity: enterFade,
            child: ScaleTransition(scale: enterScale, child: child),
          ),
        ),
      );
    },
  );
}

CustomTransitionPage<T> buildSlideRightPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final enterSlide = Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ));

      final exitSlide = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.3, 0.0),
      ).animate(
          CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOut));
      final exitDim = Tween<double>(begin: 1.0, end: 0.85).animate(
          CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeIn));

      return SlideTransition(
        position: exitSlide,
        child: FadeTransition(
          opacity: exitDim,
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 24,
                  offset: const Offset(-6, 0),
                ),
              ],
            ),
            child: SlideTransition(position: enterSlide, child: child),
          ),
        ),
      );
    },
  );
}

CustomTransitionPage<T> buildSlideUpPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final enterSlide = Tween<Offset>(
        begin: const Offset(0.0, 0.12),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutQuart,
        reverseCurve: Curves.easeInQuint,
      ));
      final enterFade = CurvedAnimation(parent: animation, curve: Curves.easeOut);

      final secScale = Tween<double>(begin: 1.0, end: 0.94).animate(
          CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeIn));
      final secDim = Tween<double>(begin: 1.0, end: 0.78).animate(
          CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeIn));

      return ScaleTransition(
        scale: secScale,
        child: FadeTransition(
          opacity: secDim,
          child: FadeTransition(
            opacity: enterFade,
            child: SlideTransition(position: enterSlide, child: child),
          ),
        ),
      );
    },
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
    initialLocation: '/splash',
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
      final isGoingToSplash = state.matchedLocation == '/splash';

      final isAuthScreen = isGoingToLogin || isGoingToRegister;

      // Allow splash screen to display and complete its intro sequences
      if (state.matchedLocation == '/splash') {
        return null;
      }

      if (authState is AuthInitial || authState is AuthLoading) {
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
          return '/';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => buildFadeThroughPage(
          key: state.pageKey,
          child: const SplashScreen(),
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => buildFadeThroughPage(
          key: state.pageKey,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => buildSlideRightPage(
          key: state.pageKey,
          child: const RegisterScreen(),
        ),
      ),
      GoRoute(
        path: '/display_name',
        pageBuilder: (context, state) => buildFadeThroughPage(
          key: state.pageKey,
          child: const DisplayNameScreen(),
        ),
      ),
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => buildFadeThroughPage(
          key: state.pageKey,
          child: const MainNavigationScreen(),
        ),
      ),
      GoRoute(
        path: '/location_search',
        pageBuilder: (context, state) => buildSlideUpPage(
          key: state.pageKey,
          child: const LocationSearchScreen(),
        ),
      ),
      GoRoute(
        path: '/shop_details',
        pageBuilder: (context, state) {
          final shop = state.extra as Shop?;
          final shopId = state.uri.queryParameters['shopId'] ?? state.uri.queryParameters['id'];
          return buildSlideRightPage(
            key: state.pageKey,
            child: ShopDetailsScreen(shop: shop, shopId: shopId),
          );
        },
      ),
      GoRoute(
        path: '/product_details',
        pageBuilder: (context, state) {
          final product = state.extra as Product?;
          final productId = state.uri.queryParameters['productId'] ?? state.uri.queryParameters['id'];
          final shopId = state.uri.queryParameters['shopId'];
          return buildSlideRightPage(
            key: state.pageKey,
            child: ProductDetailsScreen(
              product: product,
              productId: productId,
              shopId: shopId,
            ),
          );
        },
      ),
      GoRoute(
        path: '/offer_details',
        pageBuilder: (context, state) {
          final offer = state.extra as Offer?;
          final offerId = state.uri.queryParameters['offerId'] ?? state.uri.queryParameters['id'];
          final shopId = state.uri.queryParameters['shopId'];
          return buildSlideRightPage(
            key: state.pageKey,
            child: OfferDetailsScreen(
              offer: offer,
              offerId: offerId,
              shopId: shopId,
            ),
          );
        },
      ),
      GoRoute(
        path: '/radar',
        pageBuilder: (context, state) => buildSlideUpPage(
          key: state.pageKey,
          child: const HyperlocalRadarScreen(),
        ),
      ),
      GoRoute(
        path: '/all_offers',
        pageBuilder: (context, state) => buildSlideRightPage(
          key: state.pageKey,
          child: const AllOffersScreen(),
        ),
      ),
      GoRoute(
        path: '/chat',
        redirect: (context, state) => state.extra == null ? '/' : null,
        pageBuilder: (context, state) {
          final extras = state.extra as Map<dynamic, dynamic>;
          final shopId = extras['shopId']?.toString() ?? '';
          final shopName = extras['shopName']?.toString() ?? '';
          final shopLogo = extras['shopLogo']?.toString() ?? '';
          return buildSlideRightPage(
            key: state.pageKey,
            child: ChatScreen(
              shopId: shopId,
              shopName: shopName,
              shopLogo: shopLogo,
            ),
          );
        },
      ),
      GoRoute(
        path: '/chats',
        pageBuilder: (context, state) => buildSlideRightPage(
          key: state.pageKey,
          child: const ChatsListScreen(),
        ),
      ),
      GoRoute(
        path: '/security',
        pageBuilder: (context, state) => buildSlideRightPage(
          key: state.pageKey,
          child: const SecuritySettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/product_image_fullscreen',
        redirect: (context, state) => state.extra == null ? '/' : null,
        pageBuilder: (context, state) {
          final extras = state.extra as Map<dynamic, dynamic>;
          final images = List<String>.from(extras['images'] as List? ?? []);
          final initialIndex = (extras['initialIndex'] as int?) ?? 0;
          return buildFadeThroughPage(
            key: state.pageKey,
            child: ProductImageFullscreenScreen(
              images: images,
              initialIndex: initialIndex,
            ),
          );
        },
      ),
    ],
  );
});
