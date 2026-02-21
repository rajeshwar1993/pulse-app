// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Pulse';

  @override
  String get tagline => 'Effortless peace of mind';

  @override
  String get dashboardComingSoon => 'Dashboard - Coming Soon';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get signInWithEmail => 'Sign in with Email';

  @override
  String get signIn => 'Sign In';

  @override
  String get signUp => 'Sign Up';

  @override
  String get enterYourEmail => 'Enter your email';

  @override
  String get enterYourPassword => 'Enter your password';

  @override
  String get confirmYourPassword => 'Confirm your password';

  @override
  String get cancel => 'Cancel';

  @override
  String get pleaseEnterYourEmail => 'Please enter your email';

  @override
  String get pleaseEnterValidEmail => 'Please enter a valid email';

  @override
  String get pleaseEnterYourPassword => 'Please enter your password';

  @override
  String get passwordTooShort => 'Password must be at least 6 characters';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get invalidCredentials => 'Invalid email or password';

  @override
  String get userAlreadyExists =>
      'An account with this email already exists. Try signing in instead.';

  @override
  String failedSignInGoogle(String error) {
    return 'Failed to sign in with Google: $error';
  }

  @override
  String failedSignIn(String error) {
    return 'Failed to sign in: $error';
  }

  @override
  String failedSignUp(String error) {
    return 'Failed to sign up: $error';
  }

  @override
  String get dontHaveAccount => 'Don\'t have an account? Sign Up';

  @override
  String get alreadyHaveAccount => 'Already have an account? Sign In';

  @override
  String get setUpYourProfile => 'Set up your profile';

  @override
  String get displayName => 'Display Name';

  @override
  String get enterYourName => 'Enter your name';

  @override
  String get chooseYourAvatar => 'Choose your avatar';

  @override
  String get selectedAvatar => 'Selected Avatar';

  @override
  String get continueButton => 'Continue';

  @override
  String failedCreateProfile(String error) {
    return 'Failed to create profile: $error';
  }

  @override
  String get failedLoadDashboard => 'Failed to load Dashboard';

  @override
  String get unknownErrorOccurred => 'Unknown error occurred';

  @override
  String get retry => 'Retry';
}
