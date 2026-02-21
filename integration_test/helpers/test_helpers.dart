import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_app/main.dart';

/// Create the app widget wrapped in ProviderScope for integration tests.
///
/// Use this in patrol tests:
/// ```dart
/// patrolTest('my test', ($) async {
///   await $.pumpWidgetAndSettle(createTestApp());
///   // ...
/// });
/// ```
Widget createTestApp({List<Override>? overrides}) {
  return ProviderScope(
    overrides: overrides ?? [],
    child: const PulseApp(),
  );
}

/// Wait for animations to complete with a generous timeout.
Future<void> settleWithTimeout(dynamic $, {Duration? duration}) async {
  await $.pumpAndSettle(timeout: duration ?? const Duration(seconds: 10));
}
