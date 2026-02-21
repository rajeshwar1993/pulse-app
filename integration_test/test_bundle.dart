// This is the entry point for Patrol integration tests.
// Import all test files here.

import 'tests/splash_test.dart' as splash_test;
import 'tests/auth_test.dart' as auth_test;

void main() {
  splash_test.main();
  auth_test.main();
}
