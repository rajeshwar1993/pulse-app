import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';
import '../utils/error_reporter.dart';

class LocaleService {
  static const _storageKey = 'pulse_locale';
  final SharedPreferences _prefs;

  LocaleService(this._prefs);

  /// Get stored locale from SharedPreferences
  Locale getStoredLocale() {
    final stored = _prefs.getString(_storageKey);
    if (stored != null && stored.isNotEmpty) {
      return Locale(stored);
    }
    return const Locale('en');
  }

  /// Save locale to SharedPreferences
  Future<void> setStoredLocale(Locale locale) async {
    await _prefs.setString(_storageKey, locale.languageCode);
  }

  /// Sync locale to Supabase profile (fire-and-forget, don't block UI)
  Future<void> syncToProfile(Locale locale) async {
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) return;

      await SupabaseConfig.client
          .from('profiles')
          .update({'language_preference': locale.languageCode})
          .eq('id', user.id);
    } catch (e) {
      ErrorReporter.captureException(e, reason: 'LocaleService.syncToProfile');
    }
  }

  /// Fetch locale from Supabase profile
  Future<Locale?> getProfileLocale() async {
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) return null;

      final response = await SupabaseConfig.client
          .from('profiles')
          .select('language_preference')
          .eq('id', user.id)
          .single();

      final lang = response['language_preference'] as String?;
      return lang != null && lang.isNotEmpty ? Locale(lang) : null;
    } catch (e) {
      ErrorReporter.captureException(e, reason: 'LocaleService.getProfileLocale');
      return null;
    }
  }
}

/// Riverpod provider for LocaleService
final localeServiceProvider = Provider<LocaleService>((ref) {
  throw UnimplementedError('localeServiceProvider must be overridden with a SharedPreferences instance');
});
