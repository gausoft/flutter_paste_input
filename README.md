# flutter_paste_input

[![pub package](https://img.shields.io/pub/v/flutter_paste_input.svg)](https://pub.dev/packages/flutter_paste_input)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.3.0+-02569B?logo=flutter)](https://flutter.dev)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20Android%20%7C%20macOS%20%7C%20Linux%20%7C%20Windows-green.svg)](#platform-support)

A Flutter plugin for intercepting paste events in TextFields, supporting both text and image content across all platforms.

## Demo

<table>
  <tr>
    <td align="center"><strong>iOS</strong></td>
    <td align="center"><strong>macOS</strong></td>
  </tr>
  <tr>
    <td><img src="https://raw.githubusercontent.com/gausoft/flutter_paste_input/main/screenshots/iphone-demo.gif" width="280" alt="iOS Demo"/></td>
    <td><img src="https://raw.githubusercontent.com/gausoft/flutter_paste_input/main/screenshots/macos-demo.gif" width="500" alt="macOS Demo"/></td>
  </tr>
</table>

## Features

- Detect when users paste content into a TextField
- Support for text and images (PNG, JPEG, GIF, WebP)
- Cross-platform: iOS, Android, macOS, Linux, and Windows
- Simple API with a single wrapper widget

## Platform Support

| Platform | Support |
|----------|---------|
| iOS      | ✅       |
| Android  | ✅       |
| macOS    | ✅       |
| Linux    | ✅       |
| Windows  | ✅       |

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_paste_input: ^1.0.0
```

## Quick Start

Wrap your TextField with `PasteWrapper`:

```dart
import 'package:flutter_paste_input/flutter_paste_input.dart';

PasteWrapper(
  onPaste: (payload) {
    switch (payload) {
      case TextPaste(:final text):
        print('Pasted text: $text');
      case RawImagePaste(:final items):
        for (final item in items) {
          print('Pasted image: ${item.mimeType}');
          // item.data contains the image bytes (Uint8List)
        }
      case ImagePaste(:final uris):
        print('Pasted images: $uris');
      case UnsupportedPaste():
        print('Unsupported content');
    }
  },
  child: TextField(
    decoration: InputDecoration(hintText: 'Type or paste here...'),
  ),
)
```

## Usage

### Handle Pasted Images

By default, images are returned as raw bytes:

```dart
case RawImagePaste(:final items):
  for (final item in items) {
    // Display directly
    Image.memory(item.data);

    // Or save to file
    final file = File('path/to/image.png');
    await file.writeAsBytes(item.data);
  }
```

### Save Images to Files Automatically

If you prefer file paths:

```dart
PasteWrapper(
  saveImagesToTempFiles: true,
  onPaste: (payload) {
    if (payload case ImagePaste(:final uris)) {
      for (final path in uris) {
        Image.file(File(path));
      }
    }
  },
  child: TextField(),
)
```

### Filter Paste Types

Accept only images or only text:

```dart
PasteWrapper(
  acceptedTypes: {PasteType.image}, // Only images
  onPaste: (payload) { ... },
  child: TextField(),
)
```

### Enable/Disable

```dart
PasteWrapper(
  enabled: _isPasteEnabled,
  onPaste: (payload) { ... },
  child: TextField(),
)
```

### Clean Up Temporary Files

```dart
await PasteChannel.instance.clearTempFiles();
```

## Complete Example

```dart
class ChatInput extends StatefulWidget {
  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();
  final List<Uint8List> _images = [];

  void _handlePaste(PastePayload payload) {
    if (payload case RawImagePaste(:final items)) {
      setState(() {
        _images.addAll(items.map((e) => e.data));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Image previews
        Wrap(
          children: _images.map((bytes) =>
            Image.memory(bytes, width: 80, height: 80, fit: BoxFit.cover),
          ).toList(),
        ),

        // Input
        PasteWrapper(
          onPaste: _handlePaste,
          child: TextField(controller: _controller),
        ),
      ],
    );
  }
}
```

## API Reference

### PasteWrapper

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `child` | `Widget` | required | The TextField to wrap |
| `onPaste` | `Function(PastePayload)` | required | Called when paste is detected |
| `acceptedTypes` | `Set<PasteType>?` | `null` | Filter: `{PasteType.text}`, `{PasteType.image}`, or both |
| `enabled` | `bool` | `true` | Enable/disable detection |
| `saveImagesToTempFiles` | `bool` | `false` | Return file paths instead of raw bytes |

### PastePayload Types

| Type | Description | Properties |
|------|-------------|------------|
| `TextPaste` | Plain text | `text: String` |
| `RawImagePaste` | Images as bytes | `items: List<RawClipboardItem>` |
| `ImagePaste` | Images as file paths | `uris: List<String>`, `mimeTypes: List<String>` |
| `UnsupportedPaste` | Unknown content | - |

### RawClipboardItem

| Property | Type | Description |
|----------|------|-------------|
| `data` | `Uint8List` | Image bytes |
| `mimeType` | `String` | e.g., `'image/png'` |
| `isGif` | `bool` | True if GIF |

## Roadmap

Upcoming features for future releases:

- [ ] **Web platform support** - Clipboard API integration for browsers
- [ ] **File paste support** - PDF, documents, and other file types
- [ ] **Drag and drop** - Unified behavior with paste
- [ ] **Preview before insert** - Optional confirmation dialog
- [ ] **Size limits** - `maxImageSize` and `maxFileSize` options
- [ ] **Paste callbacks** - `onPasteStart`, `onPasteAccept`, `onPasteReject`

Have a feature request? [Open an issue](https://github.com/gausoft/flutter_paste_input/issues)!

## Limitations

- Rich text (HTML, RTF) is not supported
- Web platform is not yet supported

## Acknowledgments

This package was inspired by [this post on X](https://x.com/i/status/1997738168247062774).

## License

MIT License - see [LICENSE](LICENSE) file.
