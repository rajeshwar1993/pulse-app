import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/colors.dart';
import '../../core/services/auth_service.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/auth_button.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _showEmailForm = false;
  bool _isSignUpMode = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithGoogle();
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _errorMessage = l10n.failedSignInGoogle(e.toString());
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitEmailForm() async {
    final l10n = AppLocalizations.of(context);

    // Email validation
    if (_emailController.text.trim().isEmpty) {
      setState(() => _errorMessage = l10n.pleaseEnterYourEmail);
      return;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      setState(() => _errorMessage = l10n.pleaseEnterValidEmail);
      return;
    }

    // Password validation
    if (_passwordController.text.isEmpty) {
      setState(() => _errorMessage = l10n.pleaseEnterYourPassword);
      return;
    }

    if (_passwordController.text.length < 6) {
      setState(() => _errorMessage = l10n.passwordTooShort);
      return;
    }

    // Confirm password validation (sign up only)
    if (_isSignUpMode &&
        _passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = l10n.passwordsDoNotMatch);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);

      if (_isSignUpMode) {
        final response = await authService.signUp(
          _emailController.text.trim(),
          _passwordController.text,
        );

        // When email confirmations are disabled, signUp for an existing email
        // returns a user with empty identities instead of throwing.
        // Check for explicitly empty list (not null) to avoid false positives.
        final identities = response.user?.identities;
        if (response.user != null &&
            identities != null &&
            identities.isEmpty) {
          if (mounted) {
            setState(() {
              _errorMessage = l10n.userAlreadyExists;
              _isLoading = false;
            });
          }
          return;
        }

        // signUp may not establish a session (e.g. when email confirmations
        // are enabled on the remote instance). Sign in explicitly to ensure
        // the user is authenticated before navigating.
        if (response.session == null) {
          await authService.signInWithPassword(
            _emailController.text.trim(),
            _passwordController.text,
          );
        }

        // New user — go straight to profile setup (skip splash delay)
        if (mounted) {
          context.go('/profile-setup');
        }
      } else {
        await authService.signInWithPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );

        // Existing user — go through splash for profile check + pulse
        if (mounted) {
          context.go('/');
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _mapAuthError(e, l10n);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _isSignUpMode
              ? l10n.failedSignUp(e.toString())
              : l10n.failedSignIn(e.toString());
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _mapAuthError(AuthException e, AppLocalizations l10n) {
    final message = e.message.toLowerCase();
    if (message.contains('invalid') || message.contains('credentials')) {
      return l10n.invalidCredentials;
    }
    if (message.contains('already registered') ||
        message.contains('already exists')) {
      return l10n.userAlreadyExists;
    }
    if (message.contains('weak password') || message.contains('too short')) {
      return l10n.passwordTooShort;
    }
    return _isSignUpMode
        ? l10n.failedSignUp(e.message)
        : l10n.failedSignIn(e.message);
  }

  void _toggleMode() {
    setState(() {
      _isSignUpMode = !_isSignUpMode;
      _passwordController.clear();
      _confirmPasswordController.clear();
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
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
                const SizedBox(height: 24),

                // Title
                Text(
                  l10n.appTitle,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: AppColors.teal,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),

                // Tagline
                Text(
                  l10n.tagline,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.slate500,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Error Message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Google Sign In Button
                AuthButton(
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  icon: Icons.g_mobiledata,
                  label: l10n.signInWithGoogle,
                  backgroundColor: Colors.white,
                  textColor: AppColors.slate900,
                ),
                const SizedBox(height: 16),

                // Email Sign In/Up Button or Form
                if (!_showEmailForm)
                  AuthButton(
                    onPressed: _isLoading
                        ? null
                        : () => setState(() => _showEmailForm = true),
                    icon: Icons.email_outlined,
                    label: l10n.signInWithEmail,
                    backgroundColor: AppColors.teal,
                    textColor: Colors.white,
                  ),

                // Email + Password Form
                if (_showEmailForm) ...[
                  // Email field
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      hintText: l10n.enterYourEmail,
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 12),

                  // Password field
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      hintText: l10n.enterYourPassword,
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(
                              () => _obscurePassword = !_obscurePassword);
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    obscureText: _obscurePassword,
                    textInputAction: _isSignUpMode
                        ? TextInputAction.next
                        : TextInputAction.done,
                    onSubmitted:
                        _isSignUpMode ? null : (_) => _submitEmailForm(),
                    enabled: !_isLoading,
                  ),

                  // Confirm Password field (sign up only)
                  if (_isSignUpMode) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPasswordController,
                      decoration: InputDecoration(
                        hintText: l10n.confirmYourPassword,
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() => _obscureConfirmPassword =
                                !_obscureConfirmPassword);
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      obscureText: _obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submitEmailForm(),
                      enabled: !_isLoading,
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Cancel + Submit buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  setState(() {
                                    _showEmailForm = false;
                                    _isSignUpMode = false;
                                    _emailController.clear();
                                    _passwordController.clear();
                                    _confirmPasswordController.clear();
                                    _errorMessage = null;
                                  });
                                },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(l10n.cancel),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: AuthButton(
                          onPressed: _isLoading ? null : _submitEmailForm,
                          icon: _isSignUpMode
                              ? Icons.person_add
                              : Icons.login,
                          label:
                              _isSignUpMode ? l10n.signUp : l10n.signIn,
                          backgroundColor: AppColors.teal,
                          textColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Toggle sign in / sign up
                  TextButton(
                    onPressed: _isLoading ? null : _toggleMode,
                    child: Text(
                      _isSignUpMode
                          ? l10n.alreadyHaveAccount
                          : l10n.dontHaveAccount,
                      style: TextStyle(
                        color: AppColors.teal,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],

                // Loading Indicator
                if (_isLoading) ...[
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.teal),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
