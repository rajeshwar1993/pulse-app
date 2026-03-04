import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'core/config/supabase_config.dart';
import 'core/providers/locale_provider.dart';
import 'core/services/deep_link_service.dart';
import 'core/services/locale_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/pulse_service.dart';
import 'core/services/wisdom_service.dart';
import 'features/splash/splash_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error handler for uncaught Flutter framework errors
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  // Global error handler for uncaught async errors
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught error: $error\n$stack');
    return true;
  };

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Firebase (before Supabase)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize Supabase
  await SupabaseConfig.initialize();

  // Initialize deep link handling
  await DeepLinkService().initialize();

  // Initialize SharedPreferences for locale persistence
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        localeServiceProvider.overrideWithValue(LocaleService(prefs)),
        wisdomServiceProvider.overrideWithValue(
          WisdomService(SupabaseConfig.client, prefs),
        ),
        pulseServiceProvider.overrideWithValue(
          PulseService(SupabaseConfig.client, prefs),
        ),
        notificationServiceProvider.overrideWithValue(
          NotificationService(SupabaseConfig.client, prefs),
        ),
      ],
      child: const PulseApp(),
    ),
  );
}

// GoRouter configuration
final _router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    // Ignore deep link URLs - let DeepLinkService handle them
    final uri = state.uri;
    if (uri.scheme == 'pulse') {
      // This is a deep link, don't try to route it
      // Return null to stay on current route
      return null;
    }
    return null; // No redirect needed
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
  ],
);

class PulseApp extends ConsumerWidget {
  const PulseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'Pulse',
      theme: AppTheme.lightTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
