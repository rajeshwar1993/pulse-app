import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  /// Initialize deep link handling
  Future<void> initialize() async {
    // Handle initial link if app was opened from a deep link
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      await _handleDeepLink(initialUri);
    }

    // Listen for deep links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) async {
        await _handleDeepLink(uri);
      },
      onError: (err) {
        print('Deep link error: $err');
      },
    );
  }

  /// Handle incoming deep link
  Future<void> _handleDeepLink(Uri uri) async {
    print('Deep link received: $uri');

    // Check if this is an auth callback
    if (uri.path == '/auth/callback') {
      await _handleAuthCallback(uri);
    }
  }

  /// Handle auth callback from magic link or OAuth
  Future<void> _handleAuthCallback(Uri uri) async {
    try {
      // Extract the auth code or token from the URL
      final code = uri.queryParameters['code'];
      final accessToken = uri.queryParameters['access_token'];
      final refreshToken = uri.queryParameters['refresh_token'];

      if (code != null) {
        // OAuth flow - exchange code for session
        print('Exchanging code for session...');
        // The Supabase SDK should handle this automatically
        // when the deep link is opened
      } else if (accessToken != null && refreshToken != null) {
        // Direct token flow - set session
        print('Setting session from tokens...');
        await SupabaseConfig.client.auth.setSession(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
      } else {
        print('No auth code or tokens found in deep link');
      }
    } catch (e) {
      print('Error handling auth callback: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _linkSubscription?.cancel();
  }
}
