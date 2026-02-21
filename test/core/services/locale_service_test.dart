import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulse_app/core/services/locale_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<LocaleService> createService([Map<String, Object>? values]) async {
    SharedPreferences.setMockInitialValues(values ?? {});
    final prefs = await SharedPreferences.getInstance();
    return LocaleService(prefs);
  }

  group('getStoredLocale', () {
    test('returns default Locale("en") when no locale is stored', () async {
      final service = await createService();

      final result = service.getStoredLocale();

      expect(result, const Locale('en'));
    });

    test('returns stored locale when one exists', () async {
      final service = await createService({'pulse_locale': 'hi'});

      final result = service.getStoredLocale();

      expect(result, const Locale('hi'));
    });

    test('returns default locale when stored value is empty', () async {
      final service = await createService({'pulse_locale': ''});

      final result = service.getStoredLocale();

      expect(result, const Locale('en'));
    });
  });

  group('setStoredLocale', () {
    test('stores locale language code in SharedPreferences', () async {
      final service = await createService();

      await service.setStoredLocale(const Locale('hi'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pulse_locale'), 'hi');
    });

    test('overwrites existing stored locale', () async {
      final service = await createService({'pulse_locale': 'en'});

      await service.setStoredLocale(const Locale('hi'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pulse_locale'), 'hi');
    });
  });

  group('syncToProfile', () {
    test('does not throw when Supabase client is not initialized', () async {
      // syncToProfile depends on SupabaseConfig.client which requires
      // Supabase.initialize(). In unit tests without a running Supabase
      // instance, we verify it handles the error gracefully.
      final service = await createService();

      // Should not throw — the method catches all exceptions
      await expectLater(
        service.syncToProfile(const Locale('en')),
        completes,
      );
    });
  });

  group('getProfileLocale', () {
    test('returns null when Supabase client is not initialized', () async {
      final service = await createService();

      // Should return null gracefully when Supabase is not available
      final result = await service.getProfileLocale();

      expect(result, isNull);
    });
  });
}
