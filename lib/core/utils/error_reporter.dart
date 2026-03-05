import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Unified error reporting to Sentry, Firebase Crashlytics, and PostHog.
///
/// All service catch blocks should use this instead of raw debugPrint.
class ErrorReporter {
  /// Report an exception to all configured observability backends.
  static Future<void> captureException(
    dynamic exception, {
    StackTrace? stackTrace,
    String? reason,
    Map<String, dynamic>? extras,
  }) async {
    debugPrint('${reason ?? 'Error'}: $exception');

    try {
      await Sentry.captureException(
        exception,
        stackTrace: stackTrace,
        hint: reason != null ? Hint.withMap({'reason': reason}) : null,
      );
    } catch (_) {}

    try {
      FirebaseCrashlytics.instance.recordError(
        exception,
        stackTrace,
        reason: reason ?? 'ErrorReporter.captureException',
      );
    } catch (_) {}
  }

  /// Set the current user across all observability backends.
  static Future<void> setUser({
    required String id,
    String? email,
  }) async {
    try {
      Sentry.configureScope((scope) {
        scope.setUser(SentryUser(id: id, email: email));
      });
    } catch (_) {}

    try {
      FirebaseCrashlytics.instance.setUserIdentifier(id);
    } catch (_) {}

    try {
      Posthog().identify(
        userId: id,
        userProperties:
            email != null ? {'email': email} : {},
      );
    } catch (_) {}
  }

  /// Clear user identity across all backends (e.g., on sign-out).
  static Future<void> clearUser() async {
    try {
      Sentry.configureScope((scope) => scope.setUser(null));
    } catch (_) {}

    try {
      Posthog().reset();
    } catch (_) {}
  }
}
