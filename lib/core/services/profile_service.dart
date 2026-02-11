import '../config/supabase_config.dart';
import '../models/profile.dart';

class ProfileService {
  final _supabase = SupabaseConfig.client;

  /// Get profile for a specific user ID
  Future<Profile?> getProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;

      return Profile.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Get current user's profile
  Future<Profile?> getCurrentUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    return getProfile(user.id);
  }

  /// Create a new profile
  Future<Profile> createProfile({
    required String displayName,
    required String avatarUrl,
    required String timezone,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }

      final response = await _supabase
          .from('profiles')
          .insert({
            'id': user.id,
            'email': user.email!,
            'display_name': displayName,
            'avatar_url': avatarUrl,
            'timezone': timezone,
          })
          .select()
          .single();

      return Profile.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Update existing profile
  Future<Profile> updateProfile({
    required String userId,
    String? displayName,
    String? avatarUrl,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (displayName != null) updates['display_name'] = displayName;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      if (updates.isEmpty) {
        throw Exception('No fields to update');
      }

      final response = await _supabase
          .from('profiles')
          .update(updates)
          .eq('id', userId)
          .select()
          .single();

      return Profile.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }
}
