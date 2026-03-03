import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for fetching and caching wisdom phrases from Supabase.
///
/// Phrases are fetched from the `wisdom_phrases` table and cached in
/// SharedPreferences for offline access. A random phrase is selected
/// each time, avoiding the last-shown phrase.
class WisdomService {
  final SupabaseClient _supabase;
  final SharedPreferences _prefs;

  static const _cacheKey = 'wisdom_phrases_cache';
  static const _lastIndexKey = 'wisdom_last_index';

  WisdomService(this._supabase, this._prefs);

  /// Fetch wisdom phrases from Supabase, falling back to cache on error.
  ///
  /// Returns a list of phrase strings. On success, updates the local cache.
  /// On failure, returns cached phrases (or empty list if no cache exists).
  Future<List<String>> getWisdomPhrases({String locale = 'en'}) async {
    try {
      final response = await _supabase
          .from('wisdom_phrases')
          .select('phrase')
          .eq('locale', locale)
          .order('id');

      final phrases = (response as List<dynamic>)
          .map((row) => row['phrase'] as String)
          .toList();

      if (phrases.isNotEmpty) {
        // Cache the fetched phrases
        await _prefs.setString(_cacheKey, jsonEncode(phrases));
      }

      return phrases;
    } catch (e) {
      debugPrint('WisdomService.getWisdomPhrases: $e');
      return _getCachedPhrases();
    }
  }

  /// Pick a random phrase from the list, avoiding the last-shown phrase.
  ///
  /// Returns null if the list is empty.
  String? getRandomPhrase(List<String> phrases) {
    if (phrases.isEmpty) return null;
    if (phrases.length == 1) return phrases[0];

    final lastIndex = _prefs.getInt(_lastIndexKey);
    final random = Random();
    int index;

    // Try up to 10 times to get a different index
    int attempts = 0;
    do {
      index = random.nextInt(phrases.length);
      attempts++;
    } while (index == lastIndex && attempts < 10);

    _prefs.setInt(_lastIndexKey, index);
    return phrases[index];
  }

  List<String> _getCachedPhrases() {
    final cached = _prefs.getString(_cacheKey);
    if (cached == null) return [];

    try {
      final decoded = jsonDecode(cached) as List<dynamic>;
      return decoded.map((e) => e as String).toList();
    } catch (e) {
      debugPrint('WisdomService._getCachedPhrases: $e');
      return [];
    }
  }
}

/// Riverpod provider for WisdomService.
///
/// Must be overridden in ProviderScope with SharedPreferences instance.
final wisdomServiceProvider = Provider<WisdomService>((ref) {
  throw UnimplementedError(
    'wisdomServiceProvider must be overridden with a SharedPreferences instance',
  );
});
