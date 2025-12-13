# flutter_paste_input

A Flutter plugin for intercepting paste events in TextFields, supporting both text and image content across all platforms.

## Features

- Intercept paste events before content reaches the TextField
- Support for text and image paste content
- Works with PNG, JPEG, GIF, and other image formats
- Cross-platform support: iOS, Android, macOS, Linux, and Windows
- Type-safe API using Dart 3 sealed classes
- Easy integration with existing TextFields

## Platform Support

| Platform | Support | Notes |
|----------|---------|-------|
| iOS      | ✅       | Uses method swizzling on UITextField/UITextView |
| Android  | ✅       | Uses clipboard monitoring with Actions interception |
| macOS    | ✅       | Uses method swizzling on NSTextField/NSTextView |
| Linux    | ✅       | Uses GTK clipboard API |
| Windows  | ✅       | Uses Win32 clipboard API with GDI+ |

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_paste_input: ^0.1.0
```

## Usage

### Basic Usage

Wrap your TextField with `PasteWrapper`:

```dart
import 'package:flutter_paste_input/flutter_paste_input.dart';

PasteWrapper(
  onPaste: (payload) {
    switch (payload) {
      case TextPaste(:final text):
        print('Pasted text: $text');
      case ImagePaste(:final uris, :final mimeTypes):
        print('Pasted ${uris.length} image(s)');
        // uris contains temporary file paths
        for (int i = 0; i < uris.length; i++) {
          print('Image ${i + 1}: ${uris[i]} (${mimeTypes[i]})');
        }
      case UnsupportedPaste():
        print('Unsupported paste content');
    }
  },
  child: TextField(
    decoration: InputDecoration(hintText: 'Type or paste here...'),
  ),
)
```

### Filter Paste Types

Accept only specific content types:

```dart
PasteWrapper(
  acceptedTypes: {PasteType.image}, // Only accept images
  onPaste: (payload) {
    // Only ImagePaste will be received
  },
  child: TextField(),
)
```

### Enable/Disable Dynamically

```dart
PasteWrapper(
  enabled: _isPasteEnabled,
  onPaste: _handlePaste,
  child: TextField(),
)
```

### Handle Images

When images are pasted, they are saved as temporary files:

```dart
case ImagePaste(:final uris, :final mimeTypes):
  for (int i = 0; i < uris.length; i++) {
    final file = File(uris[i]);
    final mimeType = mimeTypes[i];

    // Copy to permanent location if needed
    await file.copy('/path/to/permanent/location.png');

    // Or display directly
    Image.file(file);
  }
```

### Clear Temporary Files

Temporary files can be cleaned up manually:

```dart
await PasteChannel.instance.clearTempFiles();
```

## API Reference

### PasteWrapper

The main widget for intercepting paste events.

| Property | Type | Description |
|----------|------|-------------|
| `child` | `Widget` | The widget to wrap (typically TextField) |
| `onPaste` | `void Function(PastePayload)` | Callback when paste is detected |
| `acceptedTypes` | `Set<PasteType>?` | Filter for accepted content types |
| `enabled` | `bool` | Enable/disable paste detection |

### PastePayload

Sealed class representing paste content:

- `TextPaste` - Plain text with `text` property
- `ImagePaste` - Images with `uris` and `mimeTypes` lists
- `UnsupportedPaste` - Unsupported content type

### ImagePaste

| Property | Type | Description |
|----------|------|-------------|
| `uris` | `List<String>` | File paths to temporary images |
| `mimeTypes` | `List<String>` | MIME types (e.g., 'image/png') |
| `hasGif` | `bool` | True if paste contains animated GIFs |
| `count` | `int` | Number of images |

### PasteType

Enum for filtering:
- `PasteType.text`
- `PasteType.image`

## How It Works

### iOS & macOS
Uses Objective-C runtime method swizzling to intercept the `paste:` method on text input controls. When paste is detected, the clipboard content is processed and sent to Flutter via EventChannel.

### Android
Uses Flutter's Actions system to intercept `PasteTextIntent`. When detected, the native plugin reads the clipboard content including images and sends events to Flutter.

### Linux
Uses GTK's `GtkClipboard` API to read clipboard content, supporting both images and text.

### Windows
Uses Win32 Clipboard API with GDI+ for image processing. Supports bitmap data, text, and file drops.

## Limitations

- Images are saved as temporary files; copy them to a permanent location if persistence is needed
- Rich text (formatted HTML, etc.) is not currently supported
- On some platforms, the original paste action continues after interception (text will still be pasted)

## License

MIT License - see LICENSE file for details.
