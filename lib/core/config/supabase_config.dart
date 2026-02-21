import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static String? _supabaseUrl;
  static String? _supabaseAnonKey;

  static Future<void> initialize() async {
    _supabaseUrl = dotenv.env['SUPABASE_URL'];
    _supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (_supabaseUrl == null || _supabaseUrl!.isEmpty) {
      throw StateError('SUPABASE_URL is not set in .env file');
    }
    if (_supabaseAnonKey == null || _supabaseAnonKey!.isEmpty) {
      throw StateError('SUPABASE_ANON_KEY is not set in .env file');
    }

    await Supabase.initialize(
      url: _supabaseUrl!,
      anonKey: _supabaseAnonKey!,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;

  /// Get the Supabase URL
  static String get supabaseUrl {
    if (_supabaseUrl != null) return _supabaseUrl!;
    if (!dotenv.isInitialized) {
      throw StateError('SupabaseConfig.initialize() must be called before accessing supabaseUrl');
    }
    final url = dotenv.env['SUPABASE_URL'];
    if (url == null || url.isEmpty) {
      throw StateError('SUPABASE_URL is not set in .env file');
    }
    return url;
  }

  /// Get the Supabase Anon Key
  static String get supabaseAnonKey {
    if (_supabaseAnonKey != null) return _supabaseAnonKey!;
    if (!dotenv.isInitialized) {
      throw StateError('SupabaseConfig.initialize() must be called before accessing supabaseAnonKey');
    }
    final key = dotenv.env['SUPABASE_ANON_KEY'];
    if (key == null || key.isEmpty) {
      throw StateError('SUPABASE_ANON_KEY is not set in .env file');
    }
    return key;
  }

  static const _defaultWebViewUrl = 'http://localhost:3000/appview/dashboard';

  /// Get the WebView URL for the Next.js dashboard
  static String get webViewUrl {
    if (!dotenv.isInitialized) return _defaultWebViewUrl;
    return dotenv.env['WEBVIEW_URL'] ?? _defaultWebViewUrl;
  }
}
