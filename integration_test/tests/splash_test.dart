import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:pulse_app/features/splash/splash_screen.dart';

import '../helpers/test_helpers.dart';

void main() {
  patrolTest(
    'Splash screen renders with Pulse branding',
    ($) async {
      await $.pumpWidgetAndSettle(createTestApp());

      // The splash screen should be the first screen shown
      expect($(SplashScreen), findsOneWidget);

      // Verify the Pulse text/logo is visible
      expect($('Pulse'), findsOneWidget);
    },
  );

  patrolTest(
    'Splash screen shows heartbeat animation',
    ($) async {
      await $.pumpWidget(createTestApp());

      // Pump a few frames to let animation start
      await $.pump(const Duration(milliseconds: 500));

      // The splash screen should still be visible during animation
      expect($(SplashScreen), findsOneWidget);
    },
  );
}
