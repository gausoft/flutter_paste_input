/// A Flutter plugin for intercepting paste events in text fields.
///
/// This plugin enables your app to detect when users paste content
/// (text or images) into a TextField, TextFormField, or similar widgets.
///
/// ## Getting Started
///
/// Wrap your text input with [PasteWrapper]:
///
/// ```dart
/// import 'package:flutter_paste_input/flutter_paste_input.dart';
///
/// PasteWrapper(
///   onPaste: (payload) {
///     switch (payload) {
///       case TextPaste(:final text):
///         print('Pasted text: $text');
///       case ImagePaste(:final uris):
///         print('Pasted ${uris.length} images');
///         // Handle images - uris are temporary file paths
///       case UnsupportedPaste():
///         print('Unsupported content');
///     }
///   },
///   child: TextField(
///     decoration: InputDecoration(hintText: 'Type or paste here...'),
///   ),
/// )
/// ```
///
/// ## Platform Support
///
/// | Platform | Support |
/// |----------|---------|
/// | iOS      | ✅      |
/// | Android  | ✅      |
/// | macOS    | ✅      |
/// | Linux    | ✅      |
/// | Windows  | ✅      |
///
/// ## Image Handling
///
/// When images are pasted, they are saved as temporary files in the app's
/// cache directory. The [ImagePaste.uris] field contains the file paths.
/// If you need to persist these images, copy them to a permanent location.
///
/// To clean up temporary files, call:
/// ```dart
/// await PasteChannel.instance.clearTempFiles();
/// ```
library;

export 'src/paste_payload.dart' show PastePayload, TextPaste, ImagePaste, UnsupportedPaste, PasteType;
export 'src/paste_wrapper.dart' show PasteWrapper;
export 'src/paste_channel.dart' show PasteChannel;
