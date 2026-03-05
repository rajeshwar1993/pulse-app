import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized configuration for observability services (Sentry, PostHog).
///
/// Reads DSNs and API keys from environment variables via flutter_dotenv.
/// Guards against uninitialized dotenv for test safety.
class ObservabilityConfig {
  static String? get sentryDsn {
    if (!dotenv.isInitialized) return null;
    final dsn = dotenv.env['SENTRY_DSN'];
    return (dsn != null && dsn.isNotEmpty) ? dsn : null;
  }

  static String? get posthogApiKey {
    if (!dotenv.isInitialized) return null;
    final key = dotenv.env['POSTHOG_API_KEY'];
    return (key != null && key.isNotEmpty) ? key : null;
  }

  static String get posthogHost {
    if (!dotenv.isInitialized) return 'https://us.i.posthog.com';
    return dotenv.env['POSTHOG_HOST'] ?? 'https://us.i.posthog.com';
  }

  static bool get hasSentry => sentryDsn != null;
  static bool get hasPosthog => posthogApiKey != null;
}
