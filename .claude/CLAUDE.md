# pulse-app — Flutter Mobile Shell

Flutter native shell for the Pulse app. Handles splash, authentication, profile setup, and hosts the Next.js dashboard inside a WebView.

## Tech Stack

| Concern | Package | Version |
|---------|---------|---------|
| Framework | Flutter | 3.10.8+ |
| State | flutter_riverpod | ^2.5.1 |
| Routing | go_router | ^14.0.0 |
| Backend | supabase_flutter | ^2.5.0 |
| WebView | webview_flutter | ^4.7.0 |
| Deep Links | app_links | ^3.4.5 |
| Env | flutter_dotenv | ^5.1.0 |
| Fonts | google_fonts | ^6.2.1 |
| Testing | mockito, build_runner | ^5.4.4 |

## Project Structure

```
lib/
├── core/
│   ├── config/            # SupabaseConfig (init, env, webViewUrl)
│   ├── constants/         # AvatarGallery (DiceBear PNG URLs)
│   ├── models/            # Profile, Connection, InviteCode
│   ├── services/          # AuthService, ProfileService, PulseService,
│   │                      #   ConnectionService, DeepLinkService, LocaleService
│   └── theme/
│       ├── colors.dart    # AppColors — all design token colors
│       └── app_theme.dart # AppTheme.lightTheme
├── features/
│   ├── auth/              # AuthScreen (email/password + Google sign-in)
│   ├── profile/           # ProfileSetupScreen (name + avatar)
│   ├── splash/            # SplashScreen (launch orchestration + WebView host)
│   └── webview/           # PulseWebView (WebView wrapper, FlutterBridge)
├── shared/
│   └── widgets/           # *** Reusable widget library (see below) ***
├── l10n/                  # Localization (ARB files, AppLocalizations)
└── main.dart              # App entry, GoRouter config, error handlers
```

## Design System

**Theme:** Mindful Glassmorphism
**Reference:** `the-office/projects/pulse/design/design-tokens.md`

### Colors (`lib/core/theme/colors.dart`)

All colors are defined as `AppColors` constants. **Never use raw hex values in widgets.**

| Token | Constant | Hex | Usage |
|-------|----------|-----|-------|
| teal-300 | `AppColors.teal` | #62B1AD | Primary brand, buttons, focus |
| rose-300 | `AppColors.rose` | #F28C8C | Accent color |
| offWhite | `AppColors.offWhite` | #F8FAFC | Screen backgrounds |
| slate-200 | `AppColors.slate200` | #E2E8F0 | Borders |
| slate-300 | `AppColors.slate300` | #CBD5E1 | Input borders |
| slate-500 | `AppColors.slate500` | #64748B | Body text |
| slate-900 | `AppColors.slate900` | #0F172A | Headings |
| error | `AppColors.error` | #EF4444 | Error states |
| success | `AppColors.success` | #10B981 | Success states |

Full spectrum available: `teal50`–`teal500`, `rose50`–`rose500`, `slate50`–`slate900`.

### Component Tokens

| Component | Background | Border | Radius | Padding |
|-----------|-----------|--------|--------|---------|
| Button (primary) | teal | — | 8px | 12px 24px |
| Button (secondary) | transparent | teal 1px | 8px | 12px 24px |
| Input | white | slate-300 1px | 8px | 12px 16px |
| Card | white | slate-200 1px | 12px | 24px |
| Glass Card | white@10% + blur(16) | white@20% | 16px | 24px |

## Shared Widget Library

**Import:** `import '../../shared/widgets/widgets.dart';`

All screens MUST use these shared widgets instead of inline Material widgets. This ensures design token consistency.

### PulseButton

```dart
// Primary — teal background, white text
PulseButton.primary(
  onPressed: () {},
  label: 'Continue',
  icon: Icons.arrow_forward,  // optional
  isLoading: false,           // shows spinner
  flex: 1,                    // for use in Row
)

// Secondary — white background, teal border
PulseButton.secondary(onPressed: () {}, label: 'Google Sign In')

// Outline — transparent, slate border
PulseButton.outline(onPressed: () {}, label: 'Cancel')
```

### PulseTextField

```dart
PulseTextField(
  controller: _controller,
  hintText: 'Enter your name',
  prefixIcon: Icons.person,     // optional
  maxLength: 50,                // optional
  suffixText: '12/50',          // optional
  counterText: '',              // hide default counter
  onChanged: (v) {},            // optional
  enabled: true,
)
```

### PulsePasswordField

```dart
PulsePasswordField(
  controller: _passwordController,
  hintText: 'Enter your password',
  textInputAction: TextInputAction.done,
  onSubmitted: (_) => _submit(),
  enabled: true,
)
```

Built-in visibility toggle icon. Wraps PulseTextField internally.

### PulseErrorBanner

```dart
if (errorMessage != null) ...[
  PulseErrorBanner(message: errorMessage!),
  const SizedBox(height: 24),
]
```

Red-tinted banner with error icon. Use for form/screen-level errors.

### PulseAvatar

```dart
// Gallery selection (64px, selection border)
PulseAvatar.selectable(
  imageUrl: url,
  selected: url == _selectedUrl,
  onTap: () => setState(() => _selectedUrl = url),
)

// Large preview (120px)
PulseAvatar.preview(imageUrl: _selectedUrl!)

// Basic usage
PulseAvatar(imageUrl: url, size: 48)
```

Built-in loading spinner and error icon for network images.

### PulseCard / PulseGlassCard

```dart
PulseCard(child: Text('Content'))
PulseGlassCard(child: Text('Glass effect'))
```

### Adding New Shared Widgets

1. Create `lib/shared/widgets/pulse_<name>.dart`
2. Follow design tokens from `the-office/projects/pulse/design/design-tokens.md`
3. Use `AppColors` constants — never hardcode hex values
4. Add export to `lib/shared/widgets/widgets.dart`
5. Prefix class name with `Pulse` (e.g., `PulseChip`, `PulseDialog`)

## Coding Conventions

### Service Layer

All services live in `lib/core/services/` and follow this pattern:

```dart
class MyService {
  final SupabaseClient _supabase;
  MyService(this._supabase);

  Future<bool> doAction() async {
    try {
      // ...
      return true;
    } catch (e) {
      debugPrint('MyService.doAction: $e');
      return false;
    }
  }
}

final myServiceProvider = Provider<MyService>((ref) {
  return MyService(Supabase.instance.client);
});
```

Rules:
- Constructor injection of `SupabaseClient` (testable)
- Riverpod `Provider` defined at bottom of file
- Use `debugPrint()`, never `print()` (stripped in release)
- Return `Future<bool>` for success/failure, `Future<Model?>` for data

### Widget Patterns

- `ConsumerWidget` when accessing providers
- `ConsumerStatefulWidget` when needing both state and providers
- Always use shared widgets from `widgets.dart` barrel
- Screen backgrounds: `AppColors.offWhite`

### Navigation

```dart
context.go('/');              // Replace route
context.go('/profile-setup'); // Replace route
context.push('/details');     // Push onto stack
```

Routes defined in `main.dart` via GoRouter.

### i18n

```dart
import '../../l10n/app_localizations.dart';

final l10n = AppLocalizations.of(context);
Text(l10n.signIn)
```

Do NOT use `package:flutter_gen/...` import path. Use relative `l10n/app_localizations.dart`.

### Models

- `fromJson` factory constructor, `toJson()` method
- `copyWith()` for immutable updates
- `==`, `hashCode`, `toString()` overrides
- Located in `lib/core/models/`

## Environment

`.env` file at project root:
```
SUPABASE_URL=<url>
SUPABASE_ANON_KEY=<key>
WEBVIEW_URL=http://localhost:3000/appview/dashboard   # optional, has default
```

`SupabaseConfig` guards `dotenv.isInitialized` so tests don't crash.

## Commands

```bash
flutter pub get                # Install deps
flutter run                    # Debug run
flutter test                   # All tests
flutter test --coverage        # Coverage report
flutter analyze                # Static analysis (must be 0 issues)
dart run build_runner build    # Generate mocks
```

## WebView Bridge

- WebView loads URL from `SupabaseConfig.webViewUrl`
- Session injection: cookies + localStorage via `jsonEncode()` (no raw string interpolation)
- Message protocol: `{ "type": "ready" | "navigation" | ..., "payload": ... }`
- Messages parsed with `jsonDecode()`, not string matching
- `FlutterBridge` JavaScript channel for Web → Flutter communication

## Testing

- Tests in `test/` mirroring `lib/` structure
- Mock Supabase with `@GenerateMocks` + mockito
- Widget tests wrap in `ProviderScope(child: MaterialApp(home: ...))`
- `SupabaseConfig` has `dotenv.isInitialized` guard for test safety

## Lint Rules

`analysis_options.yaml` enables:
- `avoid_print` (use `debugPrint`)
- `prefer_const_constructors`
- `prefer_const_declarations`
- `use_build_context_synchronously`
