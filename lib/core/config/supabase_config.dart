import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static String? _supabaseUrl;
  static String? _supabaseAnonKey;

  static Future<void> initialize() async {
    _supabaseUrl = dotenv.env['SUPABASE_URL']!;
    _supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']!;

    await Supabase.initialize(
      url: _supabaseUrl!,
      anonKey: _supabaseAnonKey!,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;

  /// Get the Supabase URL
  static String get supabaseUrl => _supabaseUrl ?? dotenv.env['SUPABASE_URL']!;

  /// Get the Supabase Anon Key
  static String get supabaseAnonKey => _supabaseAnonKey ?? dotenv.env['SUPABASE_ANON_KEY']!;
}
