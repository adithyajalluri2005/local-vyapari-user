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
          ? AndroidAppCheckProvider.playIntegrity
          : AndroidAppCheckProvider.debug,
      providerApple: kReleaseMode
          ? AppleAppCheckProvider.deviceCheck
          : AppleAppCheckProvider.debug,
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

    FlutterNativeSplash.remove();
    runApp(
      const ProviderScope(
        child: LocalVyapariApp(),
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
