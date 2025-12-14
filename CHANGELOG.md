# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-12-14

### Added

- Initial release
- `PasteWrapper` widget for intercepting paste events in TextFields
- Text paste detection with `TextPaste`
- Image paste detection with `RawImagePaste` (raw bytes) or `ImagePaste` (file paths)
- `acceptedTypes` parameter to filter text or images
- `enabled` parameter for dynamic enable/disable
- `saveImagesToTempFiles` option to save images as temporary files
- `clearTempFiles()` method for cleanup

### Supported Platforms

- iOS
- Android
- macOS
- Linux
- Windows

### Supported Image Formats

- PNG
- JPEG
- GIF
- WebP
- BMP (Windows)
