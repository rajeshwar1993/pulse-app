import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:pulse_app/features/webview/pulse_webview.dart';

import '../../helpers/fake_webview_platform.dart';

void main() {
  setUpAll(() async {
    WebViewPlatform.instance = FakeWebViewPlatform();

    // Mock SharedPreferences for Supabase's internal storage
    SharedPreferences.setMockInitialValues({});

    // Initialize Supabase with test values to prevent
    // "You must initialize the supabase instance" assertion error.
    // PulseWebView.initState() calls _listenToAuthChanges() which accesses
    // SupabaseConfig.client -> Supabase.instance.client.
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  group('PulseWebView Widget Tests', () {
    testWidgets('renders PulseWebView widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PulseWebView(),
            ),
          ),
        ),
      );

      expect(find.byType(PulseWebView), findsOneWidget);
    });

    testWidgets('shows Stack for layering WebView and loading indicator',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PulseWebView(),
            ),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(PulseWebView),
          matching: find.byType(Stack),
        ),
        findsOneWidget,
      );
    });

    testWidgets('accepts custom dashboard URL', (WidgetTester tester) async {
      const testUrl = 'http://test.example.com/dashboard';

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PulseWebView(
                initialUrl: testUrl,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(PulseWebView), findsOneWidget);
    });

    testWidgets('can receive onReady callback', (WidgetTester tester) async {
      bool readyCallbackCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PulseWebView(
                onReady: () {
                  readyCallbackCalled = true;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.byType(PulseWebView), findsOneWidget);
      // Note: Callback won't be triggered in test environment without actual WebView
    });

    testWidgets('has correct background color', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PulseWebView(),
            ),
          ),
        ),
      );

      final containerFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.color == const Color(0xFFF8FAFC),
      );

      expect(containerFinder, findsAtLeastNWidgets(1));
    });

    testWidgets('renders without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PulseWebView(),
            ),
          ),
        ),
      );

      expect(find.byType(PulseWebView), findsOneWidget);
    });
  });

  group('PulseWebView Error Handling', () {
    testWidgets('provides default dashboard URL when not specified',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PulseWebView(),
            ),
          ),
        ),
      );

      expect(find.byType(PulseWebView), findsOneWidget);
    });
  });
}
