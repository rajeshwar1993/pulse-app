import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import 'connection_service.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();
  final _connectionService = ConnectionService();
  StreamSubscription<Uri>? _linkSubscription;

  String? _pendingInviteCode;

  /// Initialize deep link handling
  Future<void> initialize() async {
    // Handle initial link if app was opened from a deep link
    try {
      final initialUri = await _appLinks.getInitialAppLink();
      if (initialUri != null) {
        await _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Error getting initial link: $e');
    }

    // Listen for deep links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) async {
        await _handleDeepLink(uri);
      },
      onError: (err) {
        debugPrint('Deep link error: $err');
      },
    );
  }

  /// Handle incoming deep link
  /// Supported formats:
  /// - pulse://auth/callback (OAuth/Magic Link)
  /// - pulse://invite?code=ABC12345
  /// - pulse://invite/ABC12345
  Future<void> _handleDeepLink(Uri uri) async {
    debugPrint('Deep link received: $uri');

    // Check if this is an auth callback
    if (uri.path == '/auth/callback') {
      await _handleAuthCallback(uri);
    }
    // Check if this is an invite link
    else if (uri.host == 'invite' || uri.path == '/invite') {
      // Extract invite code from query param or path
      String? inviteCode = uri.queryParameters['code'];
      if (inviteCode == null && uri.pathSegments.isNotEmpty) {
        inviteCode = uri.pathSegments.last;
      }

      if (inviteCode != null) {
        await _handleInviteDeepLink(inviteCode);
      }
    }
  }

  /// Handle auth callback from magic link or OAuth
  Future<void> _handleAuthCallback(Uri uri) async {
    try {
      // The Supabase SDK automatically handles auth callbacks from deep links
      // when the app is opened with the auth URL.
      // We just need to log that we received it.
      debugPrint('Auth callback received: $uri');
      debugPrint('Query parameters: ${uri.queryParameters}');

      // The auth state listener in SplashScreen will handle navigation
      // once the SDK completes the authentication
    } catch (e) {
      debugPrint('Error handling auth callback: $e');
    }
  }

  /// Handle invite code deep link
  Future<void> _handleInviteDeepLink(String code) async {
    final user = SupabaseConfig.client.auth.currentUser;

    if (user == null) {
      // User NOT authenticated - store code for later processing
      _pendingInviteCode = code;
      debugPrint('User not authenticated. Pending invite code: $code');
      // Navigator will handle redirect to auth screen
      // After auth, call processPendingInvite()
    } else {
      // User IS authenticated - accept invite immediately
      try {
        await _connectionService.acceptInviteCode(code);
        debugPrint('Invite code accepted successfully: $code');
        // Show success message and navigate to connections
        // This will be handled in the UI layer via callback
      } catch (e) {
        debugPrint('Failed to accept invite: $e');
        // Show error message in UI
      }
    }
  }

  /// Process pending invite after authentication
  /// Returns true if invite was processed successfully
  Future<bool> processPendingInvite() async {
    if (_pendingInviteCode == null) return false;

    try {
      await _connectionService.acceptInviteCode(_pendingInviteCode!);
      debugPrint('Pending invite processed successfully: $_pendingInviteCode');
      _pendingInviteCode = null;
      return true;
    } catch (e) {
      debugPrint('Failed to process pending invite: $e');
      _pendingInviteCode = null;
      return false;
    }
  }

  /// Check if there's a pending invite
  bool get hasPendingInvite => _pendingInviteCode != null;

  /// Get pending invite code
  String? get pendingInviteCode => _pendingInviteCode;

  /// Clear pending invite (e.g., user cancels)
  void clearPendingInvite() {
    _pendingInviteCode = null;
  }

  /// Dispose resources
  void dispose() {
    _linkSubscription?.cancel();
  }
}
