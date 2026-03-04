import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Top-level background message handler.
///
/// Must be a top-level function (not a method) per Firebase requirement.
/// Decorated with @pragma to prevent tree-shaking in release builds.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message received: ${message.messageId}');
}

/// Service for managing FCM push notifications.
///
/// Handles permission requests, token registration/unregistration,
/// and foreground message configuration. Tokens are stored in the
/// `fcm_tokens` Supabase table for server-side notification delivery.
class NotificationService {
  final SupabaseClient _supabase;
  final SharedPreferences _prefs;
  final FirebaseMessaging _messaging;

  static const _permissionRequestedKey = 'fcm_permission_requested';
  static const _cachedTokenKey = 'fcm_cached_token';

  NotificationService(
    this._supabase,
    this._prefs, [
    FirebaseMessaging? messaging,
  ]) : _messaging = messaging ?? FirebaseMessaging.instance;

  /// Whether the permission dialog has been shown before.
  bool get hasRequestedPermission =>
      _prefs.getBool(_permissionRequestedKey) ?? false;

  /// Initialize FCM listeners and foreground presentation options.
  ///
  /// Call once during app startup. Sets up:
  /// - Foreground notification display (iOS)
  /// - Foreground message listener
  /// - Notification tap handler (app opened from notification)
  /// - Token refresh listener
  Future<void> initialize() async {
    try {
      // iOS: show notifications when app is in foreground
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Listen for foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Foreground message: ${message.notification?.title}');
      });

      // Handle notification taps (app opened from background/terminated)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('Notification tapped: ${message.data}');
      });

      // Listen for token refreshes and re-register
      _messaging.onTokenRefresh.listen((newToken) {
        _upsertToken(newToken);
      });
    } catch (e) {
      debugPrint('NotificationService.initialize: $e');
    }
  }

  /// Show the system permission dialog for notifications.
  ///
  /// On iOS, this shows the native permission alert.
  /// On Android 13+, this requests the POST_NOTIFICATIONS permission.
  /// Tracks that the dialog was shown via SharedPreferences so it
  /// is not re-shown on subsequent launches.
  Future<bool> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission();
      await _prefs.setBool(_permissionRequestedKey, true);

      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;

      debugPrint('Notification permission: ${settings.authorizationStatus}');
      return granted;
    } catch (e) {
      debugPrint('NotificationService.requestPermission: $e');
      return false;
    }
  }

  /// Get the FCM token and register it with Supabase.
  ///
  /// Compares the current token with the locally cached one.
  /// If unchanged, skips the DB call. If new or changed, upserts
  /// to the `fcm_tokens` table.
  Future<bool> registerToken() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        debugPrint('NotificationService.registerToken: no auth user');
        return false;
      }

      final token = await _messaging.getToken();
      if (token == null) {
        debugPrint('NotificationService.registerToken: null token');
        return false;
      }

      // Skip DB call if token hasn't changed
      final cachedToken = _prefs.getString(_cachedTokenKey);
      if (cachedToken == token) {
        debugPrint('NotificationService.registerToken: token unchanged');
        return true;
      }

      await _upsertToken(token);
      return true;
    } catch (e) {
      debugPrint('NotificationService.registerToken: $e');
      return false;
    }
  }

  /// Remove the current device's FCM token from Supabase.
  ///
  /// Call on sign-out to stop receiving notifications on this device.
  Future<bool> unregisterToken() async {
    try {
      final cachedToken = _prefs.getString(_cachedTokenKey);
      if (cachedToken == null) {
        debugPrint('NotificationService.unregisterToken: no cached token');
        return true;
      }

      await _supabase
          .from('fcm_tokens')
          .delete()
          .eq('token', cachedToken);

      await _prefs.remove(_cachedTokenKey);
      debugPrint('NotificationService.unregisterToken: token removed');
      return true;
    } catch (e) {
      debugPrint('NotificationService.unregisterToken: $e');
      return false;
    }
  }

  /// Upsert a token to the fcm_tokens table and cache it locally.
  Future<void> _upsertToken(String token) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final deviceType = Platform.isIOS ? 'ios' : 'android';

    await _supabase.from('fcm_tokens').upsert(
      {
        'user_id': user.id,
        'token': token,
        'device_type': deviceType,
      },
      onConflict: 'token',
    );

    await _prefs.setString(_cachedTokenKey, token);
    debugPrint('NotificationService._upsertToken: registered $deviceType token');
  }
}

/// Riverpod provider for NotificationService.
///
/// Must be overridden in ProviderScope with SupabaseClient and SharedPreferences.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  throw UnimplementedError(
    'notificationServiceProvider must be overridden',
  );
});
