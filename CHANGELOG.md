# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-12-14

### Added

- Initial release
- `PasteWrapper` widget for intercepting paste events in TextFields
- Support for text paste detection with `TextPaste` payload
- Support for image paste detection with `ImagePaste` payload
- `PastePayload` sealed class hierarchy for type-safe handling
- `acceptedTypes` parameter for filtering paste content types
- `enabled` parameter for dynamic enable/disable
- `PasteChannel` for direct access to platform communication
- `clearTempFiles()` method for cleaning up temporary image files

### Platform Support

- **iOS**: Method swizzling on UITextField/UITextView with UIPasteboard
- **Android**: Clipboard monitoring with ClipboardManager
- **macOS**: Method swizzling on NSTextField/NSTextView with NSPasteboard
- **Linux**: GTK clipboard API integration
- **Windows**: Win32 Clipboard API with GDI+ for image processing

### Image Formats

- PNG support on all platforms
- JPEG support on all platforms
- GIF support with animation preservation on iOS/Android
- TIFF to PNG conversion on macOS
- BMP support on Windows
