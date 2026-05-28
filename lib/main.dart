import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:local_vyapari_user/core/router/app_router.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/core/theme/theme_provider.dart';
import 'package:local_vyapari_user/firebase_options.dart';
import 'package:local_vyapari_user/services/notifications/notification_service.dart';
import 'package:local_vyapari_user/shared/widgets/global_error_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
  
  // Register background handler for push notifications when the app is closed/backgrounded
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(
    const ProviderScope(
      child: LocalVyapariApp(),
    ),
  );
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
          child: child!,
        );
      },
    );
  }
}
