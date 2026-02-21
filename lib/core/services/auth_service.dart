import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase;

  AuthService(this._supabase);

  /// Sign in with Google OAuth
  Future<bool> signInWithGoogle() async {
    try {
      final response = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'pulse://auth/callback',
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Sign up with email and password
  Future<AuthResponse> signUp(String email, String password) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      return response;
    } on AuthException {
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  /// Sign in with email and password
  Future<AuthResponse> signInWithPassword(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } on AuthException {
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  /// Get current user
  User? get currentUser => _supabase.auth.currentUser;

  /// Auth state changes stream
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(Supabase.instance.client);
});
