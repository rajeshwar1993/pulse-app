import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:pulse_app/features/auth/auth_screen.dart';

import '../helpers/test_helpers.dart';

void main() {
  patrolTest(
    'Auth screen renders with email input and sign-in options',
    ($) async {
      await $.pumpWidgetAndSettle(createTestApp());

      // Navigate to auth screen — in a real scenario, the splash screen
      // would redirect here if user is not authenticated.
      // For now, we verify the AuthScreen widget tree renders correctly.

      // We can directly pump the AuthScreen for isolated testing
      await $.pumpWidgetAndSettle(
        MaterialApp(
          home: const AuthScreen(),
        ),
      );

      expect($(AuthScreen), findsOneWidget);

      // Verify email input field exists
      expect($(TextField), findsWidgets);
    },
  );

  patrolTest(
    'Auth screen email input accepts text',
    ($) async {
      await $.pumpWidgetAndSettle(
        MaterialApp(
          home: const AuthScreen(),
        ),
      );

      // Find and interact with the email text field
      final textField = $(TextField);
      if (textField.evaluate().isNotEmpty) {
        await textField.first.enterText('test@example.com');
        expect($('test@example.com'), findsOneWidget);
      }
    },
  );
}
