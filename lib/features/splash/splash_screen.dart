import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/colors.dart';
import '../../core/config/supabase_config.dart';
import '../../core/services/pulse_service.dart';
import '../webview/pulse_webview.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  StreamSubscription<AuthState>? _authSubscription;
  late AnimationController _heartbeatController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  bool _pulseCompleted = false;
  bool _webViewReady = false;
  bool _shouldShowWebView = false;
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _setupAuthListener();
    _checkAuthAndPulse();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _heartbeatController.dispose();
    _timeout?.cancel();
    super.dispose();
  }

  void _initializeAnimation() {
    // Create animation controller for heartbeat effect (1.5 seconds duration)
    _heartbeatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Scale animation: pulse from 1.0 to 1.2 and back
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_heartbeatController);

    // Opacity animation: subtle pulse effect
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.7)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.7, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_heartbeatController);

    // Start the heartbeat animation (repeat)
    _heartbeatController.repeat();
  }

  void _setupAuthListener() {
    // Listen for auth state changes (e.g., when deep link authenticates user)
    _authSubscription = SupabaseConfig.client.auth.onAuthStateChange.listen(
      (data) {
        final event = data.event;
        if (event == AuthChangeEvent.signedIn) {
          // User just signed in via deep link, restart pulse flow
          _checkAuthAndPulse();
        }
      },
    );
  }

  Future<void> _checkAuthAndPulse() async {
    // Check if user is authenticated
    final user = SupabaseConfig.client.auth.currentUser;

    if (user == null) {
      // Not authenticated, go to auth screen after animation
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      context.go('/auth');
      return;
    }

    // Check if profile exists
    final response = await SupabaseConfig.client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (!mounted) return;

    if (response == null) {
      // No profile, go to profile setup
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      context.go('/profile-setup');
      return;
    }

    // User is authenticated and has profile
    // Execute parallel tasks: Pulse + WebView pre-warming
    _executeParallelTasks();
  }

  Future<void> _executeParallelTasks() async {
    // Set timeout for WebView ready signal (5 seconds)
    _timeout = Timer(const Duration(seconds: 5), () {
      if (!_webViewReady) {
        debugPrint('WebView ready timeout - proceeding anyway');
        setState(() {
          _webViewReady = true;
        });
        _checkHandoff();
      }
    });

    // Execute pulse in background
    _executePulse();

    // Note: WebView is already pre-warming in the widget tree (see build method)
  }

  Future<void> _executePulse() async {
    try {
      final pulseService = ref.read(pulseServiceProvider);
      final pulsed = await pulseService.checkAndPulse();

      if (pulsed) {
        debugPrint('Pulse sent successfully');
      } else {
        debugPrint('User already pulsed today or pulse failed');
      }
    } catch (e) {
      debugPrint('Error sending pulse: $e');
    } finally {
      setState(() {
        _pulseCompleted = true;
      });
      _checkHandoff();
    }
  }

  void _onWebViewReady() {
    debugPrint('WebView ready signal received');
    _timeout?.cancel();
    setState(() {
      _webViewReady = true;
    });
    _checkHandoff();
  }

  void _checkHandoff() {
    // Both pulse and WebView must be ready before handoff
    if (_pulseCompleted && _webViewReady && !_shouldShowWebView) {
      debugPrint('Both tasks complete - initiating handoff');

      // Stop the heartbeat animation
      _heartbeatController.stop();

      // Wait for current animation cycle to complete, then cross-fade
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _shouldShowWebView = true;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: Stack(
        children: [
          // WebView (pre-warming in background, hidden until ready)
          if (!_shouldShowWebView)
            const Offstage(
              child: PulseWebView(),
            )
          else
            PulseWebView(
              onReady: _onWebViewReady,
            ),

          // Splash screen with heartbeat animation
          AnimatedOpacity(
            opacity: _shouldShowWebView ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              color: AppColors.offWhite,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Heartbeat animation
                    AnimatedBuilder(
                      animation: _heartbeatController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Opacity(
                            opacity: _opacityAnimation.value,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: const BoxDecoration(
                          color: AppColors.teal,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Pulse',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            color: AppColors.teal,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.teal),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
