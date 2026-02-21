import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/invite_code.dart';

class ConnectionService {
  final SupabaseClient _supabase;

  ConnectionService(this._supabase);

  // ============================================================================
  // CONNECTION MANAGEMENT
  // ============================================================================

  /// Get all active connections for the current user (bidirectional)
  Future<List<Map<String, dynamic>>> getActiveConnections() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Fetch connections where user is from_user OR to_user
    final response = await _supabase
        .from('connections')
        .select('''
          id,
          from_user_id,
          to_user_id,
          created_at,
          removed_at,
          from_profile:profiles!connections_from_user_id_fkey(id, display_name, avatar_url),
          to_profile:profiles!connections_to_user_id_fkey(id, display_name, avatar_url)
        ''')
        .or('from_user_id.eq.${user.id},to_user_id.eq.${user.id}')
        .isFilter('removed_at', null)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get connection count for current user
  Future<int> getConnectionCount() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 0;

    final count = await _supabase
        .from('connections')
        .count(CountOption.exact)
        .or('from_user_id.eq.${user.id},to_user_id.eq.${user.id}')
        .isFilter('removed_at', null);

    return count;
  }

  /// Check if connection exists between two users
  Future<bool> connectionExists(String userId1, String userId2) async {
    final count = await _supabase
        .from('connections')
        .count(CountOption.exact)
        .or(
          'and(from_user_id.eq.$userId1,to_user_id.eq.$userId2),'
          'and(from_user_id.eq.$userId2,to_user_id.eq.$userId1)',
        )
        .isFilter('removed_at', null);

    return count > 0;
  }

  /// Remove (soft delete) a connection
  Future<void> removeConnection(String connectionId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    await _supabase.from('connections').update({
      'removed_at': DateTime.now().toIso8601String(),
      'removed_by': user.id,
    }).eq('id', connectionId);
  }

  /// Restore a removed connection (within 30-day window)
  Future<void> restoreConnection(String connectionId) async {
    // First, check if connection is in restore window
    final history = await _supabase
        .from('connection_history')
        .select()
        .eq('connection_id', connectionId)
        .isFilter('restored_at', null)
        .maybeSingle();

    if (history == null) {
      throw Exception('Connection not found in history');
    }

    final permanentDeleteAt = DateTime.parse(history['permanent_delete_at']);
    if (DateTime.now().isAfter(permanentDeleteAt)) {
      throw Exception('Restore window expired');
    }

    // Restore connection
    await _supabase.from('connections').update({
      'removed_at': null,
      'removed_by': null,
    }).eq('id', connectionId);

    // Mark history as restored
    await _supabase
        .from('connection_history')
        .update({'restored_at': DateTime.now().toIso8601String()})
        .eq('connection_id', connectionId);
  }

  // ============================================================================
  // INVITE CODE MANAGEMENT
  // ============================================================================

  /// Generate a new invite code
  Future<InviteCode> generateInviteCode() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Call database function to generate unique code
    final codeResponse = await _supabase.rpc('generate_invite_code');
    final code = codeResponse as String;

    // Insert invite code
    final response = await _supabase
        .from('invite_codes')
        .insert({
          'code': code,
          'creator_id': user.id,
          'expires_at':
              DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        })
        .select()
        .single();

    return InviteCode.fromJson(response);
  }

  /// Validate an invite code
  Future<InviteCode?> validateInviteCode(String code) async {
    final response = await _supabase
        .from('invite_codes')
        .select()
        .eq('code', code)
        .isFilter('accepted_by', null)
        .gte('expires_at', DateTime.now().toIso8601String())
        .maybeSingle();

    return response != null ? InviteCode.fromJson(response) : null;
  }

  /// Accept an invite code and create bidirectional connection
  Future<void> acceptInviteCode(String code) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Validate code
    final inviteCode = await validateInviteCode(code);
    if (inviteCode == null) {
      throw Exception('Invalid or expired invite code');
    }

    // Prevent self-connection
    if (inviteCode.creatorId == user.id) {
      throw Exception('Cannot connect to yourself');
    }

    // Check if connection already exists
    if (await connectionExists(user.id, inviteCode.creatorId)) {
      throw Exception('Connection already exists');
    }

    // Create bidirectional connections (TWO records)
    final now = DateTime.now().toIso8601String();

    await _supabase.from('connections').insert([
      {
        'from_user_id': inviteCode.creatorId,
        'to_user_id': user.id,
        'created_at': now,
      },
      {
        'from_user_id': user.id,
        'to_user_id': inviteCode.creatorId,
        'created_at': now,
      },
    ]);

    // Mark invite as accepted
    await _supabase.from('invite_codes').update({
      'accepted_by': user.id,
      'accepted_at': now,
    }).eq('code', code);
  }

  /// Get active invite codes for current user
  Future<List<InviteCode>> getMyInviteCodes() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final response = await _supabase
        .from('invite_codes')
        .select()
        .eq('creator_id', user.id)
        .gte('expires_at', DateTime.now().toIso8601String())
        .isFilter('accepted_by', null)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response)
        .map((json) => InviteCode.fromJson(json))
        .toList();
  }
}

/// Riverpod provider for ConnectionService
final connectionServiceProvider = Provider<ConnectionService>((ref) {
  return ConnectionService(Supabase.instance.client);
});
