// Copyright 2024 Gausoft. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/generated/messages.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/src/main/kotlin/dev/gausoft/flutter_paste_input/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'dev.gausoft.flutter_paste_input'),
    swiftOut: 'ios/Classes/Messages.g.swift',
    swiftOptions: SwiftOptions(),
    cppHeaderOut: 'windows/messages.g.h',
    cppSourceOut: 'windows/messages.g.cpp',
    cppOptions: CppOptions(namespace: 'flutter_paste_input'),
    gobjectHeaderOut: 'linux/messages.g.h',
    gobjectSourceOut: 'linux/messages.g.cc',
    gobjectOptions: GObjectOptions(),
  ),
)

/// Represents a single item from the clipboard.
///
/// Each item contains raw binary data and its MIME type,
/// allowing Flutter to determine how to handle the content.
class ClipboardItem {
  ClipboardItem({
    required this.data,
    required this.mimeType,
  });

  /// Raw binary data of the clipboard item.
  ///
  /// For images, this contains the image bytes (PNG, JPEG, GIF, etc.).
  /// For text, this contains the UTF-8 encoded string bytes.
  Uint8List data;

  /// MIME type of the clipboard item.
  ///
  /// Common values:
  /// - "text/plain" for plain text
  /// - "image/png" for PNG images
  /// - "image/jpeg" for JPEG images
  /// - "image/gif" for GIF images
  /// - "image/webp" for WebP images
  String mimeType;
}

/// Represents the complete clipboard content.
///
/// The clipboard may contain multiple items of different types.
/// For example, copying an image might also include a text representation.
class ClipboardContent {
  ClipboardContent({required this.items});

  /// List of clipboard items.
  ///
  /// May be empty if the clipboard is empty or contains unsupported content.
  List<ClipboardItem> items;
}

/// Host API for clipboard operations (Dart -> Native).
///
/// This API is implemented by each platform's native code and called from Dart.
@HostApi()
abstract class PasteInputHostApi {
  /// Retrieves the current clipboard content.
  ///
  /// Returns a [ClipboardContent] containing all available clipboard items.
  /// The items are returned with their raw data and MIME types, allowing
  /// the Dart side to determine how to process them.
  ///
  /// Returns an empty [ClipboardContent] if the clipboard is empty or
  /// contains only unsupported content types.
  ClipboardContent getClipboardContent();

  /// Clears temporary files created during paste operations.
  ///
  /// Call this periodically to free up disk space. Paste operations may
  /// create temporary files when handling image content.
  void clearTempFiles();

  /// Returns the platform version string.
  ///
  /// Useful for debugging and platform-specific behavior.
  /// Example: "Android 14", "iOS 17.0", "macOS 14.0"
  String getPlatformVersion();
}

/// Flutter API for paste event notifications (Native -> Dart).
///
/// This API is implemented in Dart and called from native code when
/// paste events are detected (e.g., through keyboard shortcuts or
/// context menu actions).
@FlutterApi()
abstract class PasteInputFlutterApi {
  /// Called when a paste event is detected on the native side.
  ///
  /// The [content] parameter contains the clipboard content at the time
  /// of the paste event. This allows Flutter to handle the pasted content
  /// immediately without additional clipboard reads.
  void onPasteDetected(ClipboardContent content);
}
