import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';
import 'package:local_vyapari_user/core/providers/notification_route_provider.dart';
import 'package:local_vyapari_user/core/router/app_router.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/core/theme/theme_provider.dart';
import 'package:local_vyapari_user/firebase_options.dart';
import 'package:local_vyapari_user/services/notifications/notification_service.dart';
import 'package:local_vyapari_user/shared/widgets/global_error_screen.dart';
import 'package:local_vyapari_user/shared/widgets/connectivity_banner.dart';

// Holds a pending navigation that arrived from onMessageOpenedApp when the navigator was not
// yet ready. MainNavigationScreen reads and clears it via pendingNotificationRouteProvider.
PendingNotification? _pendingFcm;

void main() {
  runZonedGuarded(() async {
    final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Intercept layout and render-time errors to show a premium error screen instead of standard crash layout
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return GlobalErrorScreen(details: details);
    };

    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      debugPrint("Failed to load .env file: $e");
    }
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // App Check: attests that requests come from a genuine, untampered build.
    // Debug provider in debug builds; Play Integrity / DeviceCheck in release.
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kReleaseMode
          ? const AndroidPlayIntegrityProvider()
          : const AndroidDebugProvider(),
      providerApple: kReleaseMode
          ? const AppleDeviceCheckProvider()
          : const AppleDebugProvider(),
    );

    // Crashlytics: collect only in release builds.
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);

    // Catch Flutter framework errors (layout overflow, assertion failures, etc.)
    // and forward them to Crashlytics in release builds.
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      if (kDebugMode) {
        debugPrint('Flutter error: ${details.exceptionAsString()}\n${details.stack}');
      } else {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      }
    };

    // Cap Firestore local persistence at 20 MB (default is 100 MB)
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 20 * 1024 * 1024,
    );

    // Register background handler for push notifications when the app is closed/backgrounded
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // ── Capture FCM notification tap intent BEFORE runApp ──────────────────
    // getInitialMessage: app was TERMINATED and user tapped a FCM notification.
    // Must be called here — by the time auth completes the message is gone.
    PendingNotification? initialNotification;
    try {
      final initialMsg = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMsg != null) {
        initialNotification = _pendingFcmFrom(initialMsg);
        debugPrint('[Main] getInitialMessage — type=${initialMsg.data['type']} route=${initialNotification.route} extra=${initialNotification.extra}');
      }
    } catch (e) {
      debugPrint('[Main] getInitialMessage error: $e');
    }

    // onMessageOpenedApp: app was BACKGROUNDED and user tapped a FCM notification.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) {
      debugPrint('[Main] onMessageOpenedApp — type=${msg.data['type']} shopId=${msg.data['shopId']} shopName=${msg.data['shopName']}');
      final context = rootNavigatorKey.currentContext;
      if (context != null) {
        // ignore: use_build_context_synchronously
        _pushFcmRoute(context, msg);
      } else {
        // Navigator not yet mounted (e.g. activity recreated). MainNavigationScreen will consume it.
        final pending = _pendingFcmFrom(msg);
        debugPrint('[Main] onMessageOpenedApp — context null, storing pending: route=${pending.route} extra=${pending.extra}');
        _pendingFcm = pending;
      }
    });

    FlutterNativeSplash.remove();
    final startupNotification = initialNotification ?? _pendingFcm;
    _pendingFcm = null;
    runApp(
      ProviderScope(
        overrides: [
          if (startupNotification != null)
            pendingNotificationRouteProvider.overrideWith(
              () => PendingNotificationRouteNotifier(startupNotification),
            ),
        ],
        child: const LocalVyapariApp(),
      ),
    );
  }, (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('Uncaught error: $error\n$stackTrace');
    } else {
      FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: true);
    }
  });
}

/// Builds the correct route + GoRouter extras from an FCM message, choosing the
/// most specific destination available given the payload fields.
PendingNotification _pendingFcmFrom(RemoteMessage msg) {
  final type = msg.data['type'] ?? '';
  if (type == 'chat') {
    final shopId = msg.data['shopId'] ?? '';
    final shopName = msg.data['shopName'] ?? 'Shop';
    if (shopId.isNotEmpty) {
      return PendingNotification(
        '/chat',
        extra: {'shopId': shopId, 'shopName': shopName, 'shopLogo': msg.data['shopLogo'] ?? ''},
      );
    }
    return const PendingNotification('/chats');
  }
  if (type == 'offer' || msg.data.isNotEmpty) return const PendingNotification('/all_offers');
  // No data payload — fall back on notification channel ID.
  final channelId = msg.notification?.android?.channelId ?? '';
  return PendingNotification(channelId.contains('chat') ? '/chats' : '/all_offers');
}

/// Pushes the correct screen for an FCM tap when a navigator context is available.
void _pushFcmRoute(BuildContext context, RemoteMessage msg) {
  final pending = _pendingFcmFrom(msg);
  GoRouter.of(context).push(pending.route, extra: pending.extra);
}

class LocalVyapariApp extends ConsumerWidget {
  const LocalVyapariApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize Notification Service
    
    
    // NOTE: Client-side syncing of all shops to Firestore is deprecated to preserve 
    // write security and network query limits. Production index syncing should reside 
    // inside a Firebase Cloud Function.
    // ref.watch(searchIndexerServiceProvider).syncShopsToFirestore();

    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Local Vyapari',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final mediaQueryData = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQueryData.copyWith(
            textScaler: mediaQueryData.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.4,
            ),
          ),
          child: ConnectivityBanner(child: child!),
        );
      },
    );
  }
}
