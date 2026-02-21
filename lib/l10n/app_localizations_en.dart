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
  String get enterYourEmail => 'Enter your email';

  @override
  String get cancel => 'Cancel';

  @override
  String get sendMagicLink => 'Send Magic Link';

  @override
  String get checkEmailForMagicLink => 'Check your email for the magic link!';

  @override
  String get pleaseEnterYourEmail => 'Please enter your email';

  @override
  String get pleaseEnterValidEmail => 'Please enter a valid email';

  @override
  String failedSignInGoogle(String error) {
    return 'Failed to sign in with Google: $error';
  }

  @override
  String failedSendMagicLink(String error) {
    return 'Failed to send magic link: $error';
  }

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
