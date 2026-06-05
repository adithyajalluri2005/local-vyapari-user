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
    String? initialNotificationRoute;
    try {
      final initialMsg = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMsg != null) {
        initialNotificationRoute = _fcmRoute(initialMsg);
      }
    } catch (e) {
      debugPrint('getInitialMessage error: $e');
    }

    // onMessageOpenedApp: app was BACKGROUNDED and user tapped a FCM notification.
    // The app is already running so the navigator is mounted — navigate directly.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) {
      final route = _fcmRoute(msg);
      if (route == null) return;
      final context = rootNavigatorKey.currentContext;
      // ignore: use_build_context_synchronously
      if (context != null) GoRouter.of(context).push(route);
    });

    FlutterNativeSplash.remove();
    runApp(
      ProviderScope(
        overrides: [
          if (initialNotificationRoute != null)
            pendingNotificationRouteProvider.overrideWith(
              () => PendingNotificationRouteNotifier(initialNotificationRoute),
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

String? _fcmRoute(RemoteMessage msg) {
  if (msg.data['type'] == 'chat') return '/chats';
  if (msg.data.isNotEmpty) return '/all_offers';
  return null;
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
