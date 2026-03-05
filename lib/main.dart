import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'core/config/supabase_config.dart';
import 'core/config/observability_config.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/session_provider.dart';
import 'core/services/deep_link_service.dart';
import 'core/services/locale_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/pulse_service.dart';
import 'core/services/wisdom_service.dart';
import 'features/splash/splash_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables first (DSN needed for Sentry init)
  await dotenv.load(fileName: '.env');

  // Initialize Firebase (before Sentry — Crashlytics needs it)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Enable Crashlytics collection
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

  // Initialize Supabase
  await SupabaseConfig.initialize();

  // Initialize deep link handling
  await DeepLinkService().initialize();

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Generate cross-platform session ID for event correlation
  final sessionId = const Uuid().v4();

  // Initialize Sentry (wraps runApp to capture all errors)
  final sentryDsn = ObservabilityConfig.sentryDsn;
  if (sentryDsn != null) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.tracesSampleRate = 1.0;
        options.attachScreenshot = true;
        options.environment = const String.fromEnvironment(
          'SENTRY_ENVIRONMENT',
          defaultValue: 'development',
        );
      },
      appRunner: () => _runApp(prefs, sessionId),
    );

    // Chain Crashlytics on top of Sentry's error handlers
    final sentryFlutterOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      sentryFlutterOnError?.call(details);
    };

    final sentryPlatformOnError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return sentryPlatformOnError?.call(error, stack) ?? true;
    };
  } else {
    // No Sentry DSN — fallback error handlers (local dev)
    _setupFallbackErrorHandlers();
    _runApp(prefs, sessionId);
  }
}

/// Run the app with ProviderScope and observability setup.
void _runApp(SharedPreferences prefs, String sessionId) {
  // Initialize PostHog if configured
  if (ObservabilityConfig.hasPosthog) {
    final config = PostHogConfig(ObservabilityConfig.posthogApiKey!);
    config.host = ObservabilityConfig.posthogHost;
    config.captureApplicationLifecycleEvents = true;
    Posthog().setup(config);

    // Register session ID as a super property
    Posthog().register('pulse_session_id', sessionId);
  }

  // Tag session ID across all backends
  if (ObservabilityConfig.hasSentry) {
    Sentry.configureScope((scope) {
      scope.setTag('pulse_session_id', sessionId);
    });
  }
  FirebaseCrashlytics.instance.setCustomKey('pulse_session_id', sessionId);

  runApp(
    ProviderScope(
      overrides: [
        pulseSessionIdProvider.overrideWith((_) => sessionId),
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

/// Fallback error handlers when Sentry DSN is not configured (local dev).
void _setupFallbackErrorHandlers() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught error: $error\n$stack');
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
}

// GoRouter configuration
final _router = GoRouter(
  initialLocation: '/',
  observers: [
    if (ObservabilityConfig.hasSentry) SentryNavigatorObserver(),
  ],
  redirect: (context, state) {
    // Ignore deep link URLs - let DeepLinkService handle them
    final uri = state.uri;
    if (uri.scheme == 'pulse') {
      return null;
    }
    return null;
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
