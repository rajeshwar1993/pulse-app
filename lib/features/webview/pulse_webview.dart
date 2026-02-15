import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
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

  @override
  void initState() {
    super.initState();
    _initializeWebView();
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
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
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

  /// Handle messages from WebView
  void _handleMessage(String message) {
    debugPrint('Received message from WebView: $message');

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
    debugPrint('WebView is ready');
    widget.onReady?.call();
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
