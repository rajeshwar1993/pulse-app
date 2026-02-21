import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse_app/core/providers/locale_provider.dart';

void main() {
  group('localeProvider', () {
    test('has default value of Locale("en")', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final locale = container.read(localeProvider);

      expect(locale, const Locale('en'));
    });

    test('can be updated to a different locale', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(localeProvider.notifier).state = const Locale('hi');

      expect(container.read(localeProvider), const Locale('hi'));
    });

    test('notifies listeners when locale changes', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final locales = <Locale>[];
      container.listen(
        localeProvider,
        (previous, next) => locales.add(next),
        fireImmediately: false,
      );

      container.read(localeProvider.notifier).state = const Locale('hi');
      container.read(localeProvider.notifier).state = const Locale('ja');

      expect(locales, [const Locale('hi'), const Locale('ja')]);
    });
  });
}
