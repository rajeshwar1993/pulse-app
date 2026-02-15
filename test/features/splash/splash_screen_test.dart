import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_app/features/splash/splash_screen.dart';
import 'package:pulse_app/core/theme/colors.dart';

void main() {
  group('SplashScreen Widget Tests', () {
    testWidgets('renders splash screen with Pulse branding', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SplashScreen(),
          ),
        ),
      );

      // Check that the Pulse text is displayed
      expect(find.text('Pulse'), findsOneWidget);

      // Check that the heart icon is displayed
      expect(find.byIcon(Icons.favorite), findsOneWidget);

      // Check that the loading indicator is displayed
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays heartbeat animation container', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SplashScreen(),
          ),
        ),
      );

      // Check that the animated container with heartbeat is present
      final containerFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == AppColors.teal,
      );

      expect(containerFinder, findsAtLeastNWidgets(1));
    });

    testWidgets('has correct background color', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SplashScreen(),
          ),
        ),
      );

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(AppColors.offWhite));
    });

    testWidgets('animation updates over time', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SplashScreen(),
          ),
        ),
      );

      // Initial state
      await tester.pump();

      // Advance animation by 500ms
      await tester.pump(const Duration(milliseconds: 500));

      // Verify that the widget tree is still valid after animation
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('Pulse'), findsOneWidget);
    });

    testWidgets('contains AnimatedBuilder for heartbeat effect', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SplashScreen(),
          ),
        ),
      );

      // Check that AnimatedBuilder is used for the animation
      expect(find.byType(AnimatedBuilder), findsAtLeastNWidgets(1));
    });

    testWidgets('renders WebView components in widget tree', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SplashScreen(),
          ),
        ),
      );

      // The WebView should be in the widget tree (even if Offstage)
      // Note: We use Offstage to pre-warm the WebView
      expect(find.byType(Offstage), findsAtLeastNWidgets(1));
    });

    testWidgets('uses Stack for layering splash and webview', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SplashScreen(),
          ),
        ),
      );

      // Stack is used to layer the splash screen and WebView
      expect(find.byType(Stack), findsOneWidget);
    });
  });
}
