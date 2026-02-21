import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pulse_app/features/auth/auth_screen.dart';
import 'package:pulse_app/core/services/auth_service.dart';
import 'package:pulse_app/core/theme/colors.dart';
import 'package:pulse_app/l10n/app_localizations.dart';

@GenerateNiceMocks([
  MockSpec<AuthService>(),
])
import 'auth_screen_test.mocks.dart';

void main() {
  late MockAuthService mockAuthService;

  setUp(() {
    mockAuthService = MockAuthService();
  });

  Widget buildTestWidget() {
    final router = GoRouter(
      initialLocation: '/auth',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('Splash')),
        ),
        GoRoute(
          path: '/auth',
          builder: (_, __) => const AuthScreen(),
        ),
        GoRoute(
          path: '/profile-setup',
          builder: (_, __) => const Scaffold(body: Text('Profile Setup')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(mockAuthService),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        routerConfig: router,
      ),
    );
  }

  group('AuthScreen Initial State', () {
    testWidgets('renders logo, title, tagline, and auth buttons',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Logo
      expect(find.byIcon(Icons.favorite), findsOneWidget);

      // Title
      expect(find.text('Pulse'), findsOneWidget);

      // Tagline
      expect(find.text('Effortless peace of mind'), findsOneWidget);

      // Google sign-in button
      expect(find.text('Sign in with Google'), findsOneWidget);

      // Email sign-in button
      expect(find.text('Sign in with Email'), findsOneWidget);

      // No form fields visible initially
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('has correct background color', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, equals(AppColors.offWhite));
    });
  });

  group('Email Form Display', () {
    testWidgets('tapping email button shows email and password fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap "Sign in with Email"
      await tester.tap(find.text('Sign in with Email'));
      await tester.pumpAndSettle();

      // Email and password fields should be visible
      expect(find.byType(TextField), findsNWidgets(2));

      // Sign In button should be visible
      expect(find.text('Sign In'), findsOneWidget);

      // Cancel button should be visible
      expect(find.text('Cancel'), findsOneWidget);

      // Toggle link should be visible
      expect(find.text("Don't have an account? Sign Up"), findsOneWidget);
    });

    testWidgets('sign-in mode does not show confirm password field',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in with Email'));
      await tester.pumpAndSettle();

      // Only 2 fields: email + password (no confirm password)
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('toggling to sign up mode shows confirm password field',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in with Email'));
      await tester.pumpAndSettle();

      // Toggle to sign up mode - scroll to make visible
      await tester.ensureVisible(
          find.text("Don't have an account? Sign Up"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Don't have an account? Sign Up"));
      await tester.pumpAndSettle();

      // 3 fields: email + password + confirm password
      expect(find.byType(TextField), findsNWidgets(3));

      // Sign Up button
      expect(find.text('Sign Up'), findsOneWidget);

      // Toggle text changes
      expect(find.text('Already have an account? Sign In'), findsOneWidget);
    });

    testWidgets('toggling back to sign in mode hides confirm password',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in with Email'));
      await tester.pumpAndSettle();

      // Toggle to sign up - scroll to make it visible first
      await tester.ensureVisible(
          find.text("Don't have an account? Sign Up"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Don't have an account? Sign Up"));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(3));

      // Toggle back to sign in - scroll to make it visible first
      await tester.ensureVisible(
          find.text('Already have an account? Sign In'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Already have an account? Sign In'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('cancel button resets form and hides fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in with Email'));
      await tester.pumpAndSettle();

      // Type some text
      await tester.enterText(find.byType(TextField).first, 'test@test.com');
      await tester.pumpAndSettle();

      // Tap cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Form should be hidden
      expect(find.byType(TextField), findsNothing);

      // "Sign in with Email" button should be back
      expect(find.text('Sign in with Email'), findsOneWidget);
    });
  });

  group('Validation', () {
    testWidgets('shows error for empty email', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in with Email'));
      await tester.pumpAndSettle();

      // Tap Sign In without entering anything
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email'), findsOneWidget);
    });

    testWidgets('shows error for invalid email format',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in with Email'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'not-an-email');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('shows error for empty password', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in with Email'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'test@test.com');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('shows error for short password', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in with Email'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'test@test.com');
      await tester.enterText(find.byType(TextField).last, '12345');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(
          find.text('Password must be at least 6 characters'), findsOneWidget);
    });

    testWidgets('shows error for mismatched passwords in sign up mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in with Email'));
      await tester.pumpAndSettle();

      // Toggle to sign up
      await tester.ensureVisible(
          find.text("Don't have an account? Sign Up"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Don't have an account? Sign Up"));
      await tester.pumpAndSettle();

      // Enter email
      await tester.enterText(find.byType(TextField).at(0), 'test@test.com');
      // Enter password
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      // Enter different confirm password
      await tester.enterText(find.byType(TextField).at(2), 'different');

      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });
  });

  group('Auth Actions', () {
    testWidgets('successful sign in navigates to splash',
        (WidgetTester tester) async {
      final mockResponse = AuthResponse(session: null, user: null);
      when(mockAuthService.signInWithPassword(
        any,
        any,
      )).thenAnswer((_) async => mockResponse);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in with Email'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'test@test.com');
      await tester.enterText(find.byType(TextField).at(1), 'password123');

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      // Should navigate to splash ('/')
      expect(find.text('Splash'), findsOneWidget);
    });

    testWidgets('successful sign up navigates to profile setup',
        (WidgetTester tester) async {
      final mockUser = User(
        id: 'new-user-id',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        identities: [
          UserIdentity(
            id: 'identity-1',
            userId: 'new-user-id',
            identityData: {},
            identityId: 'identity-1',
            provider: 'email',
            createdAt: DateTime.now().toIso8601String(),
            lastSignInAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        ],
      );
      final mockResponse = AuthResponse(session: null, user: mockUser);
      when(mockAuthService.signUp(
        any,
        any,
      )).thenAnswer((_) async => mockResponse);
      // When session is null after signup, auth_screen signs in explicitly
      when(mockAuthService.signInWithPassword(
        any,
        any,
      )).thenAnswer(
          (_) async => AuthResponse(session: null, user: mockUser));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in with Email'));
      await tester.pumpAndSettle();

      // Toggle to sign up
      await tester.ensureVisible(
          find.text("Don't have an account? Sign Up"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Don't have an account? Sign Up"));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'new@test.com');
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      await tester.enterText(find.byType(TextField).at(2), 'password123');

      await tester.ensureVisible(find.text('Sign Up'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      // Should navigate to profile setup (not splash)
      expect(find.text('Profile Setup'), findsOneWidget);
    });

    testWidgets('shows error on AuthException during sign in',
        (WidgetTester tester) async {
      when(mockAuthService.signInWithPassword(
        any,
        any,
      )).thenAnswer((_) async {
        throw AuthException('Invalid login credentials');
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in with Email'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'test@test.com');
      await tester.enterText(find.byType(TextField).at(1), 'wrongpassword');

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid email or password'), findsOneWidget);
    });

    testWidgets('shows error for existing user on sign up',
        (WidgetTester tester) async {
      // Supabase returns user with empty identities for existing email
      final mockResponse = AuthResponse(
        session: null,
        user: User(
          id: 'fake-id',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
          identities: [],
        ),
      );
      when(mockAuthService.signUp(
        any,
        any,
      )).thenAnswer((_) async => mockResponse);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in with Email'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
          find.text("Don't have an account? Sign Up"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Don't have an account? Sign Up"));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextField).at(0), 'existing@test.com');
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      await tester.enterText(find.byType(TextField).at(2), 'password123');

      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      expect(
        find.text(
            'An account with this email already exists. Try signing in instead.'),
        findsOneWidget,
      );
    });
  });

  group('Loading State', () {
    testWidgets('shows loading indicator during auth',
        (WidgetTester tester) async {
      final completer = Completer<AuthResponse>();

      when(mockAuthService.signInWithPassword(
        any,
        any,
      )).thenAnswer((_) => completer.future);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in with Email'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'test@test.com');
      await tester.enterText(find.byType(TextField).at(1), 'password123');

      await tester.tap(find.text('Sign In'));
      await tester.pump();

      // Loading indicator should be visible
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the future to clean up
      completer.complete(AuthResponse(session: null, user: null));
      await tester.pumpAndSettle();
    });
  });

  group('Password Visibility Toggle', () {
    testWidgets('password field is obscured by default',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in with Email'));
      await tester.pumpAndSettle();

      // Find the password TextField (second one)
      final passwordField = tester.widget<TextField>(
        find.byType(TextField).at(1),
      );
      expect(passwordField.obscureText, isTrue);
    });

    testWidgets('tapping visibility icon toggles password visibility',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in with Email'));
      await tester.pumpAndSettle();

      // Tap the visibility toggle on the password field
      await tester.tap(find.byIcon(Icons.visibility_off).first);
      await tester.pumpAndSettle();

      // Password should now be visible
      final passwordField = tester.widget<TextField>(
        find.byType(TextField).at(1),
      );
      expect(passwordField.obscureText, isFalse);
    });
  });
}
