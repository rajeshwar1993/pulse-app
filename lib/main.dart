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
import 'features/splash/splash_screen.dart';
import 'features/auth/auth_screen.dart';
import 'features/profile/profile_setup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: '.env');
  
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
    GoRoute(
      path: '/auth',
      builder: (context, state) => const AuthScreen(),
    ),
    GoRoute(
      path: '/profile-setup',
      builder: (context, state) => const ProfileSetupScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) {
        final l10n = AppLocalizations.of(context);
        return Scaffold(
          body: Center(
            child: Text(l10n.dashboardComingSoon),
          ),
        );
      },
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
