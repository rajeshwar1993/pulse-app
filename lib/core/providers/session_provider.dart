import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cross-platform session ID for correlating Flutter native events
/// with WebView web events in Sentry, Crashlytics, and PostHog.
///
/// Generated once per app launch in main.dart and injected into
/// the WebView via cookie, CustomEvent, and query param.
final pulseSessionIdProvider = StateProvider<String>((ref) {
  return ''; // Overridden in ProviderScope with Uuid().v4()
});
