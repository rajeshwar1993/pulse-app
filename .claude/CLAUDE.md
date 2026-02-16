# pulse-app Technical Reference

Flutter mobile application (native shell + WebView for dashboard screens).

## Project Type & Technology Stack

**Framework**: Flutter 3.10.8+
**Language**: Dart SDK ^3.10.8
**State Management**: flutter_riverpod ^2.5.1
**Routing**: go_router ^14.0.0
**Backend**: supabase_flutter ^2.5.0
**WebView**: webview_flutter ^4.7.0
**Deep Linking**: app_links ^3.4.5
**Environment**: flutter_dotenv ^5.1.0
**UI**: google_fonts ^6.2.1
**Testing**: mockito ^5.4.4, build_runner ^2.4.9

## Project Structure

```
lib/
├── core/
│   ├── config/         # Supabase initialization
│   ├── constants/      # Avatar gallery, app constants
│   ├── models/         # Data models (Profile, Connection, InviteCode)
│   ├── services/       # Business logic services
│   └── theme/          # App theme, colors
├── features/
│   ├── auth/           # Authentication screens & widgets
│   ├── profile/        # Profile setup screen
│   ├── splash/         # Splash screen & launch orchestration
│   └── webview/        # WebView wrapper for dashboard
└── main.dart           # App entry point, GoRouter config
```

## Critical Files

**Entry Point**
- `/Users/rajeshwarrudra/Documents/DevWork/Pulse-workspace/pulse-app/lib/main.dart` - App initialization, GoRouter config, ProviderScope

**Core Services**
- `/Users/rajeshwarrudra/Documents/DevWork/Pulse-workspace/pulse-app/lib/core/services/pulse_service.dart` - Daily pulse check-in logic (Pulse Day = 4 AM reset)
- `/Users/rajeshwarrudra/Documents/DevWork/Pulse-workspace/pulse-app/lib/core/services/auth_service.dart` - Supabase authentication wrapper
- `/Users/rajeshwarrudra/Documents/DevWork/Pulse-workspace/pulse-app/lib/core/services/profile_service.dart` - Profile CRUD operations
- `/Users/rajeshwarrudra/Documents/DevWork/Pulse-workspace/pulse-app/lib/core/services/connection_service.dart` - Connection management
- `/Users/rajeshwarrudra/Documents/DevWork/Pulse-workspace/pulse-app/lib/core/services/deep_link_service.dart` - Handle pulse:// deep links

**Core Config & Models**
- `/Users/rajeshwarrudra/Documents/DevWork/Pulse-workspace/pulse-app/lib/core/config/supabase_config.dart` - Supabase.initialize()
- `/Users/rajeshwarrudra/Documents/DevWork/Pulse-workspace/pulse-app/lib/core/models/profile.dart` - Profile data model
- `/Users/rajeshwarrudra/Documents/DevWork/Pulse-workspace/pulse-app/lib/core/models/connection.dart` - Connection data model

**Feature Screens**
- `/Users/rajeshwarrudra/Documents/DevWork/Pulse-workspace/pulse-app/lib/features/splash/splash_screen.dart` - Launch orchestration (auth check, pulse send, routing)
- `/Users/rajeshwarrudra/Documents/DevWork/Pulse-workspace/pulse-app/lib/features/auth/auth_screen.dart` - Email OTP authentication
- `/Users/rajeshwarrudra/Documents/DevWork/Pulse-workspace/pulse-app/lib/features/profile/profile_setup_screen.dart` - First-time profile creation
- `/Users/rajeshwarrudra/Documents/DevWork/Pulse-workspace/pulse-app/lib/features/webview/pulse_webview.dart` - WebView wrapper (loads pulse-web dashboard)

**Theme**
- `/Users/rajeshwarrudra/Documents/DevWork/Pulse-workspace/pulse-app/lib/core/theme/app_theme.dart` - MaterialApp theme definition
- `/Users/rajeshwarrudra/Documents/DevWork/Pulse-workspace/pulse-app/lib/core/theme/colors.dart` - Color constants (Pulse Purple, Off White, etc.)

## Development Setup

**Prerequisites**
- Flutter SDK 3.10.8+
- Dart SDK 3.10.8+
- Xcode (iOS) or Android Studio (Android)

**Installation**
```bash
cd /Users/rajeshwarrudra/Documents/DevWork/Pulse-workspace/pulse-app
flutter pub get
```

**Environment Configuration**
Create `.env` in project root:
```
SUPABASE_URL=<your_supabase_url>
SUPABASE_ANON_KEY=<your_supabase_anon_key>
```

**Run on Device**
```bash
flutter run
# Or specific device
flutter run -d <device_id>
```

## Coding Patterns & Conventions

**Service Layer Pattern**
- All services in `lib/core/services/`
- Services use Riverpod providers
- Services accept `SupabaseClient` in constructor
- Example: `PulseService(SupabaseClient _supabase)`

**Riverpod Providers**
```dart
// Provider definition (bottom of service file)
final pulseServiceProvider = Provider<PulseService>((ref) {
  final supabase = Supabase.instance.client;
  return PulseService(supabase);
});

// Usage in widgets
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(pulseServiceProvider);
    // Use service...
  }
}
```

**Widget Patterns**
- Use `StatelessWidget` for static UI
- Use `ConsumerWidget` (Riverpod) when accessing providers
- Use `ConsumerStatefulWidget` when needing both state and providers
- Prefer composition over inheritance

**Async Patterns**
- Services return `Future<bool>` for success/failure operations
- Services return `Future<Model?>` for data fetching (null = not found)
- Use `async/await` consistently
- Graceful error handling (print errors, return safe defaults)

**Navigation**
- Use GoRouter (`context.go('/path')`, `context.push('/path')`)
- Routes defined in `main.dart` (_router)
- Deep links handled by DeepLinkService (pulse:// scheme)

**Data Models**
- Models in `lib/core/models/`
- Use `fromJson` factory constructors
- Use `toJson` methods for serialization
- Immutable classes with `const` constructors where possible

## State Management

**Approach**: Riverpod (Provider pattern)

**Provider Types Used**
- `Provider` - For services (PulseService, AuthService, ProfileService)
- `StateProvider` - For simple reactive state
- `FutureProvider` - For async data loading
- `StreamProvider` - For realtime Supabase subscriptions (future use)

**Global State**
- Services are singleton providers (scoped to ProviderScope in main.dart)
- Access via `ref.read()` (one-time read) or `ref.watch()` (reactive)

**Local State**
- Use `StatefulWidget` or `ConsumerStatefulWidget`
- Prefer lifting state up to parent when needed by multiple children

## Testing Approach

**Test Framework**: flutter_test (built-in)
**Mocking**: mockito ^5.4.4
**Code Generation**: build_runner ^2.4.9

**Test Structure**
```
test/
├── core/
│   └── services/    # Service unit tests
├── features/
│   └── widgets/     # Widget tests
└── ...
```

**Running Tests**
```bash
# All tests
flutter test

# Specific test file
flutter test test/core/services/pulse_service_test.dart

# With coverage
flutter test --coverage
```

**Mock Generation**
```bash
# Generate mocks (when adding @GenerateMocks annotations)
flutter pub run build_runner build
```

**Widget Testing Pattern**
```dart
testWidgets('description', (WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(home: MyWidget()),
    ),
  );

  expect(find.text('Expected Text'), findsOneWidget);
});
```

**Service Testing Pattern**
```dart
// Mock Supabase client with mockito
@GenerateMocks([SupabaseClient, GoTrueClient, PostgrestQueryBuilder])
void main() {
  late MockSupabaseClient mockSupabase;
  late PulseService service;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    service = PulseService(mockSupabase);
  });

  test('hasPulsedToday returns true when pulse exists', () async {
    // Setup mocks, test service methods
  });
}
```

## Build & Development Commands

**Development**
```bash
# Run app in debug mode
flutter run

# Hot reload (press 'r' in running app)
# Hot restart (press 'R' in running app)

# Run on specific device
flutter devices              # List available devices
flutter run -d <device_id>   # Run on specific device

# Clean build
flutter clean && flutter pub get && flutter run
```

**Testing**
```bash
flutter test                 # Run all tests
flutter test --coverage      # Run with coverage report
flutter analyze              # Static analysis (linting)
```

**Code Generation**
```bash
# Generate mocks for tests
flutter pub run build_runner build

# Watch mode (auto-regenerate on changes)
flutter pub run build_runner watch
```

**Build Release**
```bash
# iOS
flutter build ios --release

# Android
flutter build apk --release
flutter build appbundle --release
```

**Dependencies**
```bash
flutter pub get              # Install dependencies
flutter pub upgrade          # Upgrade dependencies
flutter pub outdated         # Check for outdated packages
```

## Integration Points

**pulse-app → pulse-supabase**
- Supabase client initialized in `SupabaseConfig.initialize()`
- Environment variables from `.env` file
- Direct database access via `supabase_flutter` package
- Tables: `profiles`, `daily_pulses`, `connections`, `invite_codes`

**pulse-app → pulse-web (WebView Bridge)**
- WebView loads `http://localhost:3000/dashboard` (dev) or production URL
- JavaScript channel: `FlutterBridge`
- Message protocol: JSON strings with `{ type: string, payload: any }` structure
- Flutter → Web: `webViewController.runJavaScript('FlutterBridge.postMessage(...)')`
- Web → Flutter: `window.FlutterBridge.postMessage(...)` handled by JavaScriptChannel

**Deep Links**
- Scheme: `pulse://`
- Example: `pulse://invite?code=ABC123`
- Handled by DeepLinkService via app_links package
- Routes to appropriate screens in GoRouter

## Common Code Patterns

**Service Method Example**
```dart
Future<bool> sendPulse() async {
  try {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    await _supabase.from('daily_pulses').insert({
      'user_id': user.id,
      'status': 'active',
    });

    return true;
  } catch (e) {
    print('Error sending pulse: $e');
    return false;
  }
}
```

**Consumer Widget Pattern**
```dart
class MyScreen extends ConsumerWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(myServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Title')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await service.doSomething();
          },
          child: const Text('Action'),
        ),
      ),
    );
  }
}
```

**Navigation Pattern**
```dart
// Push to new route
context.push('/profile-setup');

// Replace current route
context.go('/dashboard');

// Go back
context.pop();

// With parameters
context.push('/details', extra: {'id': '123'});
```

**Supabase Query Pattern**
```dart
// Fetch single record
final response = await _supabase
    .from('profiles')
    .select()
    .eq('id', userId)
    .single();

// Fetch with filter
final response = await _supabase
    .from('daily_pulses')
    .select('id')
    .eq('user_id', userId)
    .gte('created_at', startDate.toIso8601String())
    .count(CountOption.exact);

// Insert record
await _supabase.from('profiles').insert({
  'id': userId,
  'display_name': displayName,
});

// Update record
await _supabase
    .from('profiles')
    .update({'display_name': newName})
    .eq('id', userId);
```
