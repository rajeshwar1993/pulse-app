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
      // The Supabase SDK automatically handles auth callbacks from deep links
      // when the app is opened with the auth URL.
      // We just need to log that we received it.
      print('Auth callback received: $uri');
      print('Query parameters: ${uri.queryParameters}');
      
      // The auth state listener in SplashScreen will handle navigation
      // once the SDK completes the authentication
    } catch (e) {
      print('Error handling auth callback: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _linkSubscription?.cancel();
  }
}
