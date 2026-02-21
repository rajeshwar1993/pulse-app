import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pulse_app/core/services/auth_service.dart';

@GenerateNiceMocks([
  MockSpec<SupabaseClient>(),
  MockSpec<GoTrueClient>(),
])
import 'auth_service_test.mocks.dart';

void main() {
  late AuthService authService;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    when(mockSupabase.auth).thenReturn(mockAuth);
    authService = AuthService(mockSupabase);
  });

  group('signInWithPassword', () {
    test('calls supabase signInWithPassword with correct params', () async {
      final mockResponse = AuthResponse(session: null, user: null);
      when(mockAuth.signInWithPassword(
        email: 'test@example.com',
        password: 'password123',
      )).thenAnswer((_) async => mockResponse);

      final result = await authService.signInWithPassword(
        'test@example.com',
        'password123',
      );

      expect(result, equals(mockResponse));
      verify(mockAuth.signInWithPassword(
        email: 'test@example.com',
        password: 'password123',
      )).called(1);
    });

    test('rethrows AuthException on invalid credentials', () async {
      when(mockAuth.signInWithPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenThrow(AuthException('Invalid login credentials'));

      expect(
        () => authService.signInWithPassword('test@example.com', 'wrong'),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('signUp', () {
    test('calls supabase signUp with correct params', () async {
      final mockResponse = AuthResponse(session: null, user: null);
      when(mockAuth.signUp(
        email: 'new@example.com',
        password: 'password123',
      )).thenAnswer((_) async => mockResponse);

      final result = await authService.signUp(
        'new@example.com',
        'password123',
      );

      expect(result, equals(mockResponse));
      verify(mockAuth.signUp(
        email: 'new@example.com',
        password: 'password123',
      )).called(1);
    });

    test('rethrows AuthException on weak password', () async {
      when(mockAuth.signUp(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenThrow(AuthException('Password is too short'));

      expect(
        () => authService.signUp('test@example.com', '123'),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('signInWithGoogle', () {
    test('calls getOAuthSignInUrl with google provider', () async {
      // signInWithOAuth is an extension method that internally calls
      // getOAuthSignInUrl, so we stub that instead.
      when(mockAuth.getOAuthSignInUrl(
        provider: OAuthProvider.google,
        redirectTo: 'pulse://auth/callback',
      )).thenAnswer((_) async => OAuthResponse(
            provider: OAuthProvider.google,
            url: 'https://accounts.google.com/o/oauth2/auth',
          ));

      // The method will call getOAuthSignInUrl, then try to launch the URL.
      // In test environment, URL launching won't work, so we just verify
      // the mock was called correctly.
      try {
        await authService.signInWithGoogle();
      } catch (_) {
        // URL launching may fail in test environment
      }

      verify(mockAuth.getOAuthSignInUrl(
        provider: OAuthProvider.google,
        redirectTo: 'pulse://auth/callback',
      )).called(1);
    });
  });

  group('signOut', () {
    test('calls supabase signOut', () async {
      when(mockAuth.signOut()).thenAnswer((_) async {});

      await authService.signOut();

      verify(mockAuth.signOut()).called(1);
    });

    test('rethrows exception on failure', () async {
      when(mockAuth.signOut()).thenThrow(Exception('Sign out failed'));

      expect(
        () => authService.signOut(),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('currentUser', () {
    test('returns current user from supabase auth', () {
      when(mockAuth.currentUser).thenReturn(null);

      final result = authService.currentUser;

      expect(result, isNull);
    });
  });
}
