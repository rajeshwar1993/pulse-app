# CLAUDE.md — pulse-app

## Overview

Flutter mobile shell for Pulse — a daily check-in app. Acts as a thin native wrapper: splash screen, authentication, and a WebView container that renders the Next.js app (pulse-web).

## Architecture: Hybrid App

Flutter acts as a thin native shell; all UI screens (auth, profile setup, dashboard) are rendered by the Next.js app (pulse-web) inside a WebView.

**Communication:** Flutter ↔ WebView via `FlutterBridge` JavaScript channel. Messages use `{ type: string, payload: any }` JSON format. The `window.isReady` signal tells Flutter the dashboard has loaded so it can cross-fade from splash.

**Pulse Day:** Resets at 4 AM local time. Auto-pulse fires during splash screen on app launch.

**Data flow:** Both pulse-app and pulse-web connect to the same Supabase project. Auth sessions are shared via cookies injected by Flutter into the WebView.

## Build & Development

```bash
flutter pub get
flutter run                                              # Debug mode
flutter run -d <device_id>                               # Specific device
flutter test                                             # All tests
flutter test test/core/services/pulse_service_test.dart   # Single test
flutter test --coverage                                  # Coverage
flutter analyze                                          # Static analysis
flutter pub run build_runner build                        # Generate mocks
```

## Key Conventions

- Services in `lib/core/services/` use Riverpod providers, accept `SupabaseClient` in constructor
- `ConsumerWidget` / `ConsumerStatefulWidget` for widgets needing providers
- Navigation: GoRouter (`context.go()`, `context.push()`)
- Services return `Future<bool>` for success/failure, `Future<Model?>` for data (null = not found)
- Locale bootstrapping: SharedPreferences (instant) → Supabase profile → fallback `'en'`

## Environment Variables

`.env`:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
