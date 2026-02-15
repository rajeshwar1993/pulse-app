# Pulse App (Flutter)

The Pulse mobile application - a native Flutter shell that wraps a Next.js web dashboard in a WebView. This app provides the native mobile experience while delegating UI rendering to the web app.

## Architecture

**Flutter Shell + Next.js WebView Architecture**

```
┌─────────────────────────────────────────┐
│         FLUTTER NATIVE SHELL            │
│                                         │
│  ┌──────────┐  ┌──────────────────┐   │
│  │ Splash   │→ │ WebView Container │   │
│  │ Screen   │  │ (Next.js Dashboard)│   │
│  └──────────┘  └──────────────────┘   │
│       ↓                  ↑              │
│  PulseService      window.isReady      │
│  (Supabase)        (JS Bridge)         │
└─────────────────────────────────────────┘
```

**Key Principles:**
- Flutter handles: Authentication, Splash Screen, Heartbeat Animation, Backend Communication
- Next.js handles: All UI/UX after authentication (Dashboard, Wisdom, Connections)
- Communication: JavaScript channel (`FlutterBridge`) for bidirectional messaging

---

## Core Features

### 1. **Splash Screen with Heartbeat Animation**
- Animated heartbeat effect (1.5s duration, scale + opacity)
- Parallel execution:
  - Heartbeat animation
  - Auto-pulse via PulseService
  - WebView pre-warming (hidden)
- Cross-fade transition to WebView when both tasks complete

### 2. **PulseService - Daily Check-in Logic**
Location: `lib/core/services/pulse_service.dart`

Handles automatic daily check-ins with 4:00 AM reset logic.

#### API Methods:

```dart
// Calculate start of current Pulse Day (4 AM local time)
DateTime getStartOfPulseDay()

// Check if user has pulsed today
Future<bool> hasPulsedToday()

// Send a pulse (insert into daily_pulses table)
Future<bool> sendPulse()

// Check if pulsed today, if not, send pulse
Future<bool> checkAndPulse()
```

#### Pulse Day Logic:
- **Pulse Day** starts at 4:00 AM local time
- Before 4 AM: Pulse Day started yesterday at 4 AM
- After 4 AM: Pulse Day started today at 4 AM
- Example:
  - Current time: 2:00 AM → Pulse Day: Yesterday 4:00 AM - Today 3:59 AM
  - Current time: 8:00 AM → Pulse Day: Today 4:00 AM - Tomorrow 3:59 AM

#### Usage:

```dart
final pulseService = ref.read(pulseServiceProvider);

// Auto-pulse on app launch
final pulsed = await pulseService.checkAndPulse();
if (pulsed) {
  print('Pulse sent successfully');
} else {
  print('Already pulsed today');
}
```

### 3. **WebView Integration**
Location: `lib/features/webview/pulse_webview.dart`

Wraps `webview_flutter` to load the Next.js Dashboard.

#### Features:
- **JavaScript Channel**: `FlutterBridge` for Flutter ↔ WebView communication
- **Loading State**: Shows loading indicator until WebView is ready
- **Error Handling**: Displays error view with retry button on failure
- **Ready Signal**: Listens for `window.isReady` from WebView

#### Flutter ↔ WebView Communication:

**WebView → Flutter** (JavaScript to Flutter):
```javascript
// In Next.js Dashboard
window.FlutterBridge.postMessage(JSON.stringify({
  type: 'ready',
  timestamp: Date.now(),
}));
```

**Flutter receives**:
```dart
..addJavaScriptChannel(
  'FlutterBridge',
  onMessageReceived: (JavaScriptMessage message) {
    // message.message = JSON string from WebView
    _handleMessage(message.message);
  },
)
```

#### Usage:

```dart
PulseWebView(
  dashboardUrl: 'http://localhost:3000/dashboard',
  onReady: () {
    print('WebView is ready');
  },
)
```

---

## Project Structure

```
lib/
├── core/
│   ├── config/
│   │   └── supabase_config.dart      # Supabase client setup
│   ├── services/
│   │   └── pulse_service.dart         # Daily pulse business logic
│   └── theme/
│       └── colors.dart                # App color palette
├── features/
│   ├── splash/
│   │   └── splash_screen.dart         # Splash + Heartbeat + Handoff
│   └── webview/
│       └── pulse_webview.dart         # WebView wrapper
└── main.dart                          # App entry point

test/
├── core/services/
│   └── pulse_service_test.dart        # PulseService unit tests
└── features/
    ├── splash/
    │   └── splash_screen_test.dart    # SplashScreen widget tests
    └── webview/
        └── pulse_webview_test.dart    # PulseWebView widget tests
```

---

## Getting Started

### Prerequisites
- Flutter SDK (3.0+)
- Dart SDK
- iOS Simulator / Android Emulator
- Supabase project configured

### Installation

1. **Install dependencies:**
   ```bash
   flutter pub get
   ```

2. **Configure Supabase:**
   - Update `lib/core/config/supabase_config.dart` with your Supabase URL and Anon Key

3. **Run the app:**
   ```bash
   flutter run
   ```

### Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/core/services/pulse_service_test.dart

# Run with coverage
flutter test --coverage
```

---

## Dependencies

### Core Dependencies:
- `flutter_riverpod` - State management
- `go_router` - Navigation
- `supabase_flutter` - Backend & Auth
- `webview_flutter` - WebView integration

### Dev Dependencies:
- `flutter_test` - Testing framework
- `mockito` - Mocking for tests
- `build_runner` - Code generation

---

## Configuration

### Environment Setup

The app expects the Next.js Dashboard to be running at `http://localhost:3000/dashboard` in development mode.

To change the dashboard URL:

```dart
PulseWebView(
  dashboardUrl: 'https://your-production-url.com/dashboard',
)
```

### Supabase Configuration

Update `lib/core/config/supabase_config.dart`:

```dart
class SupabaseConfig {
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  // ...
}
```

---

## Testing Strategy

### Unit Tests (PulseService)
- ✅ Pulse Day calculation (4 AM boundary logic)
- ✅ hasPulsedToday() accuracy
- ✅ sendPulse() database insertion
- ✅ checkAndPulse() prevents duplicates

### Widget Tests (SplashScreen, PulseWebView)
- ✅ Heartbeat animation rendering
- ✅ WebView pre-warming
- ✅ Cross-fade transition
- ✅ Error handling

---

## Troubleshooting

### WebView not loading
- Ensure Next.js dev server is running (`npm run dev` in pulse-web)
- Check network permissions in AndroidManifest.xml / Info.plist
- Verify dashboard URL is correct

### Pulse not sending
- Check Supabase connection
- Verify `daily_pulses` table exists
- Check RLS policies allow INSERT for authenticated users

### Build issues
- Run `flutter clean && flutter pub get`
- Check Flutter version: `flutter --version`
- Update dependencies: `flutter pub upgrade`

---

## Learn More

- [Flutter Documentation](https://docs.flutter.dev/)
- [Riverpod Documentation](https://riverpod.dev/)
- [Supabase Flutter Guide](https://supabase.com/docs/guides/getting-started/quickstarts/flutter)
- [WebView Flutter Package](https://pub.dev/packages/webview_flutter)
