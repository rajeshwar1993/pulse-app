import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/observability_config.dart';
import '../../core/config/supabase_config.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/providers/session_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/locale_service.dart';
import '../../core/services/profile_service.dart';
import '../../core/utils/error_reporter.dart';
import '../../l10n/app_localizations.dart';

/// WebView wrapper for loading Next.js pages (auth, dashboard, etc.)
///
/// This widget wraps the webview_flutter package and provides:
/// - Loading of any appview URL (auth, dashboard, profile-setup)
/// - JavaScript channel for Flutter <-> WebView communication
/// - Handling of ready signal, auth messages, and locale changes
class PulseWebView extends ConsumerStatefulWidget {
  final VoidCallback? onReady;
  final String initialUrl;

  const PulseWebView({
    super.key,
    this.onReady,
    this.initialUrl = 'http://localhost:3000/appview/dashboard',
  });

  @override
  ConsumerState<PulseWebView> createState() => PulseWebViewState();
}

class PulseWebViewState extends ConsumerState<PulseWebView> {
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

  /// Navigate the WebView to a new URL
  void navigateTo(String url) {
    _hasInjectedSession = false;
    _controller.loadRequest(Uri.parse(url));
  }

  /// Extract base URL (scheme + host + port) from a full URL
  String _getBaseUrl() {
    final uri = Uri.parse(widget.initialUrl);
    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  }

  /// Listen to auth state changes and re-inject session when it changes
  void _listenToAuthChanges() {
    _authSubscription = SupabaseConfig.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;

      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed) {
        // Reset flag to allow re-injection
        _hasInjectedSession = false;
        await _injectSupabaseSession();

        // If this was a Google OAuth sign-in (deep link callback),
        // navigate WebView to the correct page
        if (event == AuthChangeEvent.signedIn) {
          await _handlePostGoogleAuth();
        }
      }
    });
  }

  /// After Google OAuth completes, check profile and navigate WebView
  Future<void> _handlePostGoogleAuth() async {
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) return;

      final profileService = ref.read(profileServiceProvider);
      final profile = await profileService.getProfile(user.id);
      final baseUrl = _getBaseUrl();

      final redirectTo = profile != null
          ? '$baseUrl/appview/dashboard'
          : '$baseUrl/appview/profile-setup';

      // Dispatch success event to web
      await _controller.runJavaScript('''
        window.dispatchEvent(new CustomEvent('flutter-google-auth-success', {
          detail: { redirectTo: '$redirectTo' }
        }));
      ''');

      if (ObservabilityConfig.hasPosthog) {
        Posthog().capture(eventName: 'google_sign_in_completed');
      }

      // Navigate WebView to the target page
      navigateTo(redirectTo);
    } catch (e, stackTrace) {
      await ErrorReporter.captureException(e,
          stackTrace: stackTrace, reason: 'PulseWebView._handlePostGoogleAuth');
      // Dispatch error event to web
      try {
        await _controller.runJavaScript('''
          window.dispatchEvent(new CustomEvent('flutter-google-auth-error', {
            detail: { error: 'Failed to complete sign-in' }
          }));
        ''');
      } catch (_) {}
    }
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
            Sentry.addBreadcrumb(Breadcrumb(
              message: 'WebView page started',
              category: 'webview.navigation',
              data: {'url': url},
            ));
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
          },
          onPageFinished: (String url) async {
            Sentry.addBreadcrumb(Breadcrumb(
              message: 'WebView page finished',
              category: 'webview.navigation',
              data: {'url': url},
            ));
            setState(() {
              _isLoading = false;
            });

            // Inject Supabase session after page loads
            await _injectSupabaseSession();

            // Inject session ID for cross-platform correlation
            await _injectSessionId();

            // Send current locale to WebView
            await _sendLocaleToWebView();
          },
          onWebResourceError: (WebResourceError error) {
            Sentry.captureException(
              Exception('WebView resource error: ${error.description}'),
              stackTrace: StackTrace.current,
              hint: Hint.withMap({
                'errorCode': error.errorCode.toString(),
                'errorType': error.errorType?.name ?? 'unknown',
                'url': error.url ?? 'unknown',
              }),
            );
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
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  /// Inject session correlation ID into the WebView via cookie + CustomEvent.
  Future<void> _injectSessionId() async {
    try {
      final sessionId = ref.read(pulseSessionIdProvider);
      if (sessionId.isEmpty) return;

      await _controller.runJavaScript('''
        (function() {
          // Cookie channel
          document.cookie = 'pulse-session-id=$sessionId; path=/; max-age=86400; SameSite=Lax';

          // CustomEvent channel
          window.dispatchEvent(new CustomEvent('flutter-session-init', {
            detail: { pulseSessionId: '$sessionId' }
          }));
        })();
      ''');
    } catch (e) {
      debugPrint('Error injecting session ID: $e');
    }
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
    } catch (e, stackTrace) {
      await ErrorReporter.captureException(e,
          stackTrace: stackTrace,
          reason: 'PulseWebView._injectSupabaseSession');
    }
  }

  /// Handle messages from WebView using JSON parsing
  void _handleMessage(String message) {
    try {
      Sentry.addBreadcrumb(Breadcrumb(
        message: 'FlutterBridge message received',
        category: 'webview.bridge',
        data: {'raw': message.length > 200 ? message.substring(0, 200) : message},
      ));

      if (message.startsWith('{')) {
        final decoded = jsonDecode(message) as Map<String, dynamic>;
        final type = decoded['type'] as String?;

        switch (type) {
          case 'ready':
            _handleReadySignal();
          case 'LOCALE_CHANGED':
            _handleLocaleChanged(decoded);
          case 'GOOGLE_SIGN_IN_REQUESTED':
            _handleGoogleSignInRequested();
          case 'AUTH_COMPLETED':
            _handleAuthCompleted(decoded);
          default:
            debugPrint('Unknown FlutterBridge message type: $type');
        }
      } else if (message == 'ready') {
        // Simple string message fallback
        _handleReadySignal();
      }
    } catch (e, stackTrace) {
      ErrorReporter.captureException(e,
          stackTrace: stackTrace, reason: 'PulseWebView._handleMessage');
    }
  }

  /// Handle the ready signal from WebView
  void _handleReadySignal() {
    widget.onReady?.call();
  }

  /// Handle LOCALE_CHANGED message from WebView
  void _handleLocaleChanged(Map<String, dynamic> decoded) {
    try {
      final localeCode = decoded['locale'] as String?;
      if (localeCode != null) {
        final newLocale = Locale(localeCode);

        // Update Riverpod locale provider
        ref.read(localeProvider.notifier).state = newLocale;

        // Persist to SharedPreferences and Supabase
        final localeService = ref.read(localeServiceProvider);
        localeService.setStoredLocale(newLocale);
        localeService.syncToProfile(newLocale);

        debugPrint('Locale changed from WebView: $localeCode');
      }
    } catch (e, stackTrace) {
      ErrorReporter.captureException(e,
          stackTrace: stackTrace,
          reason: 'PulseWebView._handleLocaleChanged');
    }
  }

  /// Handle GOOGLE_SIGN_IN_REQUESTED — delegate OAuth to native
  Future<void> _handleGoogleSignInRequested() async {
    if (ObservabilityConfig.hasPosthog) {
      Posthog().capture(eventName: 'google_sign_in_started');
    }

    try {
      debugPrint('Google sign-in requested from WebView');
      final authService = ref.read(authServiceProvider);
      final success = await authService.signInWithGoogle();

      if (!success) {
        // Dispatch error to web
        await _controller.runJavaScript('''
          window.dispatchEvent(new CustomEvent('flutter-google-auth-error', {
            detail: { error: 'Google sign-in was cancelled or failed' }
          }));
        ''');
      }
      // If success, the auth state listener will handle navigation
    } catch (e, stackTrace) {
      await ErrorReporter.captureException(e,
          stackTrace: stackTrace,
          reason: 'PulseWebView._handleGoogleSignInRequested');
      try {
        await _controller.runJavaScript('''
          window.dispatchEvent(new CustomEvent('flutter-google-auth-error', {
            detail: { error: 'Google sign-in failed' }
          }));
        ''');
      } catch (_) {}
    }
  }

  /// Handle AUTH_COMPLETED — persist session for cold-start recovery.
  Future<void> _handleAuthCompleted(Map<String, dynamic> decoded) async {
    if (ObservabilityConfig.hasPosthog) {
      Posthog().capture(eventName: 'auth_completed');
    }

    try {
      final payload = decoded['payload'] as Map<String, dynamic>?;
      if (payload == null) return;

      final accessToken = payload['accessToken'] as String?;
      final refreshToken = payload['refreshToken'] as String?;

      if (accessToken == null || refreshToken == null) return;

      debugPrint('Persisting auth session for cold-start recovery');
      await _persistSessionManually(accessToken, refreshToken, payload);
    } catch (e, stackTrace) {
      await ErrorReporter.captureException(e,
          stackTrace: stackTrace,
          reason: 'PulseWebView._handleAuthCompleted');
    }
  }

  /// Persist session data directly to SharedPreferences as a fallback.
  Future<void> _persistSessionManually(
    String accessToken,
    String refreshToken,
    Map<String, dynamic> payload,
  ) async {
    try {
      // Decode JWT to extract user info (no verification, base64 only)
      final jwtPayload = _decodeJwtPayload(accessToken);
      if (jwtPayload['sub'] == null) {
        debugPrint('Cannot persist session: JWT missing sub claim');
        return;
      }

      // Construct session JSON matching Session.toJson() format
      final sessionData = {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'expires_at': jwtPayload['exp'],
        'expires_in': payload['expiresIn'] ?? 3600,
        'token_type': 'bearer',
        'user': {
          'id': jwtPayload['sub'],
          'email': jwtPayload['email'],
          'aud': jwtPayload['aud'] ?? 'authenticated',
          'role': jwtPayload['role'],
          'app_metadata': jwtPayload['app_metadata'] ?? {},
          'user_metadata': jwtPayload['user_metadata'] ?? {},
          'created_at': '',
        },
      };

      // Write using the same key supabase_flutter uses
      final projectRef = _getProjectRef(SupabaseConfig.supabaseUrl);
      final persistKey = 'sb-$projectRef-auth-token';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(persistKey, jsonEncode(sessionData));

      debugPrint('Session persisted manually for cold-start recovery');
    } catch (e, stackTrace) {
      await ErrorReporter.captureException(e,
          stackTrace: stackTrace,
          reason: 'PulseWebView._persistSessionManually');
    }
  }

  /// Decode a JWT payload without signature verification.
  Map<String, dynamic> _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return {};
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('JWT decode error: $e');
      return {};
    }
  }

  /// Send current locale to WebView
  Future<void> _sendLocaleToWebView() async {
    try {
      final locale = ref.read(localeProvider).languageCode;
      final js = '''
        window.dispatchEvent(new CustomEvent('flutter-locale-changed', {
          detail: { locale: '$locale' }
        }));
      ''';
      await _controller.runJavaScript(js);
      debugPrint('Locale sent to WebView: $locale');
    } catch (e) {
      debugPrint('Error sending locale to WebView: $e');
    }
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
      return _buildErrorView(context);
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

  Widget _buildErrorView(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
              Text(
                l10n.failedLoadDashboard,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? l10n.unknownErrorOccurred,
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
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
