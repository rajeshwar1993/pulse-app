import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';

/// WebView wrapper for loading Next.js Dashboard
///
/// This widget wraps the webview_flutter package and provides:
/// - Loading of Next.js Dashboard URL
/// - JavaScript channel for Flutter ↔ WebView communication
/// - Handling of window.isReady signal from WebView
class PulseWebView extends StatefulWidget {
  final VoidCallback? onReady;
  final String dashboardUrl;

  const PulseWebView({
    super.key,
    this.onReady,
    this.dashboardUrl = 'http://localhost:3000/dashboard',
  });

  @override
  State<PulseWebView> createState() => _PulseWebViewState();
}

class _PulseWebViewState extends State<PulseWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  StreamSubscription? _authSubscription;
  bool _hasInjectedSession = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _listenToAuthChanges();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  /// Listen to auth state changes and re-inject session when it changes
  void _listenToAuthChanges() {
    _authSubscription = SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;

      // Re-inject session when signed in or token refreshed
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed) {
        // Reset flag to allow re-injection
        _hasInjectedSession = false;
        _injectSupabaseSession();
      }
    });
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF8FAFC)) // AppColors.offWhite
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading state
            if (progress == 100 && _isLoading) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
          },
          onPageFinished: (String url) async {
            setState(() {
              _isLoading = false;
            });

            // Inject Supabase session after page loads
            await _injectSupabaseSession();
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _hasError = true;
              _errorMessage = error.description;
              _isLoading = false;
            });
            debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (JavaScriptMessage message) {
          _handleMessage(message.message);
        },
      )
      ..loadRequest(Uri.parse(widget.dashboardUrl));
  }

  /// Inject Supabase session from Flutter into WebView
  Future<void> _injectSupabaseSession() async {
    try {
      // Only inject once per page load to avoid infinite reload loop
      if (_hasInjectedSession) {
        return;
      }

      final session = SupabaseConfig.client.auth.currentSession;

      if (session == null) {
        return;
      }

      // Get session data
      final accessToken = session.accessToken;
      final refreshToken = session.refreshToken;
      final expiresAt = session.expiresAt;
      final user = session.user;

      // Create session object for WebView
      final sessionJson = '''
      {
        "access_token": "$accessToken",
        "refresh_token": "$refreshToken",
        "expires_at": $expiresAt,
        "expires_in": ${expiresAt != null ? expiresAt - DateTime.now().millisecondsSinceEpoch ~/ 1000 : 3600},
        "token_type": "bearer",
        "user": {
          "id": "${user.id}",
          "email": "${user.email}",
          "aud": "authenticated",
          "role": "authenticated"
        }
      }
      ''';

      // Inject session into localStorage
      // Supabase stores session in localStorage with key format:
      // sb-<project-ref>-auth-token
      final supabaseUrl = SupabaseConfig.supabaseUrl;
      final projectRef = _getProjectRef(supabaseUrl);
      final storageKey = 'sb-$projectRef-auth-token';

      final jsCode = '''
        (function() {
          try {
            // Set in localStorage
            localStorage.setItem('$storageKey', JSON.stringify($sessionJson));

            // Set session in cookies (required for server-side auth)
            const sessionString = JSON.stringify($sessionJson);
            const encodedSession = encodeURIComponent(sessionString);

            // Set the main session cookie
            document.cookie = '$storageKey=' + encodedSession + '; path=/; max-age=3600; SameSite=Lax';

            // Set individual token cookies
            const session = $sessionJson;
            document.cookie = 'sb-access-token=' + encodeURIComponent(session.access_token) + '; path=/; max-age=3600; SameSite=Lax';
            document.cookie = 'sb-refresh-token=' + encodeURIComponent(session.refresh_token) + '; path=/; max-age=' + (60 * 60 * 24 * 30) + '; SameSite=Lax';

            // Dispatch storage event to notify Supabase client
            window.dispatchEvent(new StorageEvent('storage', {
              key: '$storageKey',
              newValue: JSON.stringify($sessionJson),
              url: window.location.href
            }));

            return 'success';
          } catch (error) {
            console.error('Error injecting session:', error);
            return 'error: ' + error.message;
          }
        })();
      ''';

      final result = await _controller.runJavaScriptReturningResult(jsCode);

      // Mark as injected and reload the page to apply the session
      if (result.toString().contains('success')) {
        _hasInjectedSession = true;
        await _controller.reload();
      }
    } catch (e) {
      debugPrint('Error injecting Supabase session: $e');
    }
  }

  /// Handle messages from WebView
  void _handleMessage(String message) {
    try {
      // Check if it's a JSON message (for more complex communication)
      if (message.startsWith('{')) {
        // Parse JSON message
        // For now, we'll just check for the 'ready' type
        if (message.contains('"type":"ready"') ||
            message.contains('"type": "ready"')) {
          _handleReadySignal();
        }
      } else if (message == 'ready') {
        // Simple string message
        _handleReadySignal();
      }
    } catch (e) {
      debugPrint('Error handling WebView message: $e');
    }
  }

  /// Handle the window.isReady signal from WebView
  void _handleReadySignal() {
    widget.onReady?.call();
  }

  /// Extract project reference from Supabase URL
  /// Example: https://abcdefg.supabase.co -> abcdefg
  String _getProjectRef(String supabaseUrl) {
    try {
      final uri = Uri.parse(supabaseUrl);
      final host = uri.host;
      // Extract the subdomain (project ref)
      final parts = host.split('.');
      return parts.isNotEmpty ? parts.first : 'default';
    } catch (e) {
      debugPrint('Error parsing Supabase URL: $e');
      return 'default';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorView();
    }

    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          Container(
            color: const Color(0xFFF8FAFC),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF62B1AD)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Color(0xFFF28C8C), // AppColors.rose
              ),
              const SizedBox(height: 16),
              const Text(
                'Failed to load Dashboard',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'Unknown error occurred',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                  });
                  _controller.reload();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF62B1AD),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
