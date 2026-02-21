import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:pulse_app/features/splash/splash_screen.dart';
import 'package:pulse_app/core/theme/colors.dart';
import 'package:pulse_app/core/services/locale_service.dart';
import 'package:pulse_app/l10n/app_localizations.dart';

import '../../helpers/fake_webview_platform.dart';

void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    WebViewPlatform.instance = FakeWebViewPlatform();

    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    await Supabase.initialize(
      url: 'https://test.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  Widget buildTestWidget() {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const SplashScreen(),
        ),
        GoRoute(
          path: '/auth',
          builder: (_, __) => const Scaffold(body: Text('Auth Page')),
        ),
        GoRoute(
          path: '/profile-setup',
          builder: (_, __) => const Scaffold(body: Text('Profile Setup')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        localeServiceProvider.overrideWithValue(LocaleService(prefs)),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        routerConfig: router,
      ),
    );
  }

  /// Pumps past all pending timers (2s delay + navigation settle).
  /// Since currentUser is null, _checkAuthAndPulse waits 2s then navigates
  /// to /auth, which disposes the SplashScreen and its animation controller.
  Future<void> drainTimers(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  group('SplashScreen Widget Tests', () {
    testWidgets('renders splash screen with Pulse branding',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.text('Pulse'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await drainTimers(tester);
    });

    testWidgets('displays heartbeat animation container',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      final containerFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == AppColors.teal,
      );

      expect(containerFinder, findsAtLeastNWidgets(1));

      await drainTimers(tester);
    });

    testWidgets('has correct background color', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, equals(AppColors.offWhite));

      await drainTimers(tester);
    });

    testWidgets('animation updates over time', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Advance animation by 500ms
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('Pulse'), findsOneWidget);

      await drainTimers(tester);
    });

    testWidgets('contains AnimatedBuilder for heartbeat effect',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.byType(AnimatedBuilder), findsAtLeastNWidgets(1));

      await drainTimers(tester);
    });

    testWidgets('renders WebView components in widget tree',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.byType(Offstage), findsAtLeastNWidgets(1));

      await drainTimers(tester);
    });

    testWidgets('uses Stack for layering splash and webview',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(SplashScreen),
          matching: find.byType(Stack),
        ),
        findsAtLeastNWidgets(1),
      );

      await drainTimers(tester);
    });
  });
}
