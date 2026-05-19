import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:local_vyapari_user/core/router/app_router.dart';
import 'package:local_vyapari_user/core/theme/app_theme.dart';
import 'package:local_vyapari_user/firebase_options.dart';
import 'package:local_vyapari_user/services/notifications/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Failed to load .env file: $e");
  }
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
    ref.watch(notificationServiceProvider);

    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Local Vyapari',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
