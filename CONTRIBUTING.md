# Contributing to flutter_paste_input

Thank you for your interest in contributing!

## Development Setup

1. Clone the repository
2. Run `flutter pub get`
3. Run tests: `flutter test`

## Architecture

This plugin uses [Pigeon](https://pub.dev/packages/pigeon) for type-safe communication between Flutter and native platforms.

### Pigeon API

The API is defined in `pigeons/messages.dart`. To regenerate native code after modifying the API:

```bash
dart run pigeon --input pigeons/messages.dart
```

This generates:
- `lib/src/generated/messages.g.dart` (Dart)
- `android/.../Messages.g.kt` (Kotlin)
- `ios/Classes/Messages.g.swift` (Swift)
- `macos/Classes/Messages.g.swift` (Swift)
- `windows/messages.g.cpp` + `.h` (C++)
- `linux/messages.g.cc` + `.h` (GObject C)

### Platform Implementations

#### iOS & macOS (Swift)

Uses Objective-C runtime method swizzling to intercept the `paste:` method on `UITextField`, `UITextView`, `NSTextField`, and `NSTextView`.

Files:
- `ios/Classes/FlutterPasteInputPlugin.swift`
- `macos/Classes/FlutterPasteInputPlugin.swift`

#### Android (Kotlin)

Uses Flutter's `ContentInsertionConfiguration` for rich content on iOS/Android, and the Actions system to intercept `PasteTextIntent` on desktop.

File: `android/.../FlutterPasteInputPlugin.kt`

#### Windows (C++)

Uses Win32 Clipboard API with GDI+ for image processing.

File: `windows/flutter_paste_input_plugin.cpp`

#### Linux (C)

Uses GTK's `GtkClipboard` API.

File: `linux/flutter_paste_input_plugin.cc`

## Code Style

- Run `dart format .` before committing
- Run `dart analyze` to check for issues
- All code and comments must be in English

## Testing

```bash
# Unit tests
flutter test

# Integration tests (requires device/simulator)
cd example
flutter test integration_test
```

## Pull Request Guidelines

1. Create a branch from `main`
2. Make your changes
3. Run `dart format .` and `dart analyze`
4. Run tests
5. Update CHANGELOG.md if needed
6. Submit PR with clear description
