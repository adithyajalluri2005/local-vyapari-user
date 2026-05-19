import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_vyapari_user/features/auth/presentation/screens/splash_screen.dart';
import 'package:local_vyapari_user/features/auth/presentation/screens/login_screen.dart';
import 'package:local_vyapari_user/features/auth/presentation/screens/register_screen.dart';
import 'package:local_vyapari_user/features/home/presentation/screens/main_navigation_screen.dart';
import 'package:local_vyapari_user/features/location/presentation/screens/location_search_screen.dart';
import 'package:local_vyapari_user/features/shops/presentation/screens/shop_details_screen.dart';
import 'package:local_vyapari_user/features/products/presentation/screens/product_details_screen.dart';
import 'package:local_vyapari_user/shared/models/shop.dart';
import 'package:local_vyapari_user/shared/models/product.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const MainNavigationScreen(),
      ),
      GoRoute(
        path: '/location_search',
        builder: (context, state) => const LocationSearchScreen(),
      ),
      GoRoute(
        path: '/shop_details',
        builder: (context, state) {
          final shop = state.extra as Shop;
          return ShopDetailsScreen(shop: shop);
        },
      ),
      GoRoute(
        path: '/product_details',
        builder: (context, state) {
          final product = state.extra as Product;
          return ProductDetailsScreen(product: product);
        },
      ),
    ],
  );
});
