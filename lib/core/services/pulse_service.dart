import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing daily pulse check-ins
///
/// A "Pulse Day" starts at 4:00 AM local time and resets daily.
/// Users can pulse once per Pulse Day by opening the app.
///
/// Caching: After a successful pulse, the timestamp is cached locally.
/// Reopens within 30 minutes skip all Supabase calls. After 30 minutes,
/// the existing row's created_at is updated (not a duplicate insert).
class PulseService {
  final SupabaseClient _supabase;
  final SharedPreferences _prefs;

  static const _lastPulseTimestampKey = 'pulse_last_timestamp';
  static const _cacheDuration = Duration(minutes: 30);

  PulseService(this._supabase, this._prefs);

  /// Check if the local cache is still fresh (within 30 minutes)
  bool isCacheFresh() {
    final cached = _prefs.getInt(_lastPulseTimestampKey);
    if (cached == null) return false;
    return DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(cached),
    ) < _cacheDuration;
  }

  /// Calculate the start of the current Pulse Day (4:00 AM local time)
  ///
  /// If current time is >= 4:00 AM: Returns today at 4:00 AM
  /// If current time is < 4:00 AM: Returns yesterday at 4:00 AM
  DateTime getStartOfPulseDay() {
    final now = DateTime.now();
    final today4AM = DateTime(now.year, now.month, now.day, 4, 0, 0);

    if (now.isBefore(today4AM)) {
      // It's before 4 AM, so the Pulse Day started yesterday at 4 AM
      return today4AM.subtract(const Duration(days: 1));
    } else {
      // It's after 4 AM, so the Pulse Day started today at 4 AM
      return today4AM;
    }
  }

  /// Get the pulse row ID for today (within current Pulse Day), or null if none exists
  Future<String?> getTodayPulseId() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      final startOfDay = getStartOfPulseDay();

      final response = await _supabase
          .from('daily_pulses')
          .select('id')
          .eq('user_id', user.id)
          .gte('created_at', startOfDay.toIso8601String())
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return response['id'] as String?;
    } catch (e) {
      debugPrint('Error checking pulse status: $e');
      return null;
    }
  }

  /// Check if the current user has pulsed today (within current Pulse Day)
  Future<bool> hasPulsedToday() async {
    return (await getTodayPulseId()) != null;
  }

  /// Update the created_at timestamp on an existing pulse row
  Future<bool> refreshPulse(String pulseId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      await _supabase
          .from('daily_pulses')
          .update({'created_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', pulseId)
          .eq('user_id', user.id);

      return true;
    } catch (e) {
      debugPrint('Error refreshing pulse: $e');
      return false;
    }
  }

  /// Send a pulse (insert a new row into daily_pulses table)
  ///
  /// Returns the pulse row ID if successful, null otherwise.
  Future<String?> sendPulse() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      final response = await _supabase.from('daily_pulses').insert({
        'user_id': user.id,
        'status': 'active',
      }).select('id').single();

      return response['id'] as String?;
    } catch (e) {
      debugPrint('Error sending pulse: $e');
      return null;
    }
  }

  /// Check if user has pulsed today, and if not, send a pulse.
  /// If already pulsed and cache is stale, refresh the pulse timestamp.
  ///
  /// This is the main orchestration method called during app launch.
  /// Returns true if a pulse was sent or refreshed, false if cached or error.
  Future<bool> checkAndPulse() async {
    try {
      // 1. Check local cache — skip all DB calls if fresh
      if (isCacheFresh()) {
        debugPrint('Pulse cache is fresh, skipping DB calls');
        return false;
      }

      // 2. Check if already pulsed today
      final existingPulseId = await getTodayPulseId();

      bool success;
      if (existingPulseId != null) {
        // 3a. Pulse exists — refresh its timestamp (UPDATE)
        success = await refreshPulse(existingPulseId);
        if (success) {
          debugPrint('Pulse refreshed successfully');
        } else {
          debugPrint('Failed to refresh pulse');
        }
      } else {
        // 3b. No pulse today — insert new one
        final pulseId = await sendPulse();
        success = pulseId != null;
        if (success) {
          debugPrint('Pulse sent successfully');
        } else {
          debugPrint('Failed to send pulse');
        }
      }

      // 4. Update cache on success
      if (success) {
        await _prefs.setInt(
          _lastPulseTimestampKey,
          DateTime.now().millisecondsSinceEpoch,
        );
      }

      return success;
    } catch (e) {
      debugPrint('Error in checkAndPulse: $e');
      return false;
    }
  }
}

/// Riverpod provider for PulseService
///
/// Must be overridden with a SharedPreferences instance in ProviderScope.
final pulseServiceProvider = Provider<PulseService>((ref) {
  throw UnimplementedError(
    'pulseServiceProvider must be overridden with a SharedPreferences instance',
  );
});
