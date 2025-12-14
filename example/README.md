# flutter_paste_input Example

A demo app showcasing the `flutter_paste_input` plugin with a chat-style interface.

## Features Demonstrated

- **Text paste detection** - Paste text from clipboard into the TextField
- **Image paste detection** - Paste images (PNG, JPEG, GIF) directly into the chat input
- **Image preview thumbnails** - Pasted images appear as removable thumbnails
- **Full-screen image viewer** - Tap images to view them in full screen with zoom
- **Multi-image support** - Paste multiple images at once

## Running the Example

```bash
cd example
flutter run
```

## How to Test

1. **Text paste**: Copy some text, focus the TextField, and paste (Cmd+V / Ctrl+V)
2. **Image paste**: Copy an image from any app or browser, then paste into the TextField
3. **Remove images**: Tap the X button on image thumbnails to remove them
4. **View full-screen**: Tap an image thumbnail to open the full-screen viewer

## Screenshot

<!-- TODO: Add screenshot here -->

## Code Highlights

The key integration point is wrapping your `TextField` with `PasteWrapper`:

```dart
PasteWrapper(
  onPaste: (payload) {
    switch (payload) {
      case TextPaste():
        // Text is automatically inserted into TextField
        break;
      case ImagePaste(:final uris):
        // Handle pasted images
        _pastedImages.addAll(uris);
        break;
      case UnsupportedPaste():
        break;
    }
  },
  child: TextField(
    controller: _controller,
    decoration: InputDecoration(hintText: 'Type a message'),
  ),
)
```

See [main.dart](lib/main.dart) for the complete implementation.
samples, guidance on mobile development, and a full API reference.
