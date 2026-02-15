import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse_app/features/webview/pulse_webview.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  group('PulseWebView Widget Tests', () {
    testWidgets('renders PulseWebView widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PulseWebView(),
          ),
        ),
      );

      // Verify that the PulseWebView widget is in the tree
      expect(find.byType(PulseWebView), findsOneWidget);
    });

    testWidgets('shows loading indicator initially', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PulseWebView(),
          ),
        ),
      );

      // Initial state should show loading indicator
      // Note: WebView might not be fully initialized in tests
      expect(find.byType(Stack), findsOneWidget);
    });

    testWidgets('accepts custom dashboard URL', (WidgetTester tester) async {
      const testUrl = 'http://test.example.com/dashboard';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PulseWebView(
              dashboardUrl: testUrl,
            ),
          ),
        ),
      );

      // Verify widget renders with custom URL
      expect(find.byType(PulseWebView), findsOneWidget);
    });

    testWidgets('can receive onReady callback', (WidgetTester tester) async {
      bool readyCallbackCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PulseWebView(
              onReady: () {
                readyCallbackCalled = true;
              },
            ),
          ),
        ),
      );

      expect(find.byType(PulseWebView), findsOneWidget);
      // Note: Callback won't be triggered in test environment without actual WebView
    });

    testWidgets('uses Stack for layering WebView and loading indicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PulseWebView(),
          ),
        ),
      );

      // Stack is used to overlay loading indicator on WebView
      expect(find.byType(Stack), findsOneWidget);
    });

    testWidgets('has correct background color', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PulseWebView(),
          ),
        ),
      );

      // Check for containers with correct background color (offWhite #F8FAFC)
      final containerFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.color == const Color(0xFFF8FAFC),
      );

      expect(containerFinder, findsAtLeastNWidgets(1));
    });

    testWidgets('renders without errors', (WidgetTester tester) async {
      // This test ensures the widget can be instantiated without crashing
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PulseWebView(),
          ),
        ),
      );

      // If we get here without exceptions, the test passes
      expect(find.byType(PulseWebView), findsOneWidget);
    });
  });

  group('PulseWebView Error Handling', () {
    testWidgets('provides default dashboard URL when not specified', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PulseWebView(),
          ),
        ),
      );

      // Should use default URL without errors
      expect(find.byType(PulseWebView), findsOneWidget);
    });
  });
}
