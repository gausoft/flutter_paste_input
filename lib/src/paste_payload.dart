/// Payload types for paste events.
///
/// This file defines the sealed class hierarchy for different types of
/// paste content that can be intercepted by the plugin.
library;

/// Represents the content pasted by the user.
///
/// Use pattern matching to handle different paste types:
/// ```dart
/// switch (payload) {
///   case TextPaste(:final text):
///     print('Pasted text: $text');
///   case ImagePaste(:final uris):
///     print('Pasted ${uris.length} images');
///   case UnsupportedPaste():
///     print('Unsupported content');
/// }
/// ```
sealed class PastePayload {
  const PastePayload();

  /// Creates a [PastePayload] from a map received from the native side.
  factory PastePayload.fromMap(Map<String, dynamic> map) {
    final type = map['type'] as String?;

    switch (type) {
      case 'text':
        return TextPaste(text: map['value'] as String? ?? '');
      case 'images':
        final uris = (map['uris'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final mimeTypes = (map['mimeTypes'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        return ImagePaste(uris: uris, mimeTypes: mimeTypes);
      default:
        return const UnsupportedPaste();
    }
  }
}

/// Represents pasted text content.
///
/// The [text] field contains the plain text that was pasted.
final class TextPaste extends PastePayload {
  /// Creates a [TextPaste] with the given text content.
  const TextPaste({required this.text});

  /// The pasted text content.
  final String text;

  @override
  String toString() => 'TextPaste(text: $text)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TextPaste && text == other.text;

  @override
  int get hashCode => text.hashCode;
}

/// Represents pasted image content.
///
/// The [uris] field contains file paths to temporary image files.
/// These files are stored in the app's cache directory and should be
/// copied elsewhere if you need to persist them.
///
/// The [mimeTypes] field contains the MIME types of each image
/// (e.g., 'image/png', 'image/jpeg', 'image/gif').
final class ImagePaste extends PastePayload {
  /// Creates an [ImagePaste] with the given URIs and MIME types.
  const ImagePaste({
    required this.uris,
    required this.mimeTypes,
  });

  /// File paths to the pasted images.
  ///
  /// These are temporary files in the app's cache directory.
  /// Copy them to a permanent location if needed.
  final List<String> uris;

  /// MIME types of the pasted images.
  ///
  /// Common values: 'image/png', 'image/jpeg', 'image/gif'
  final List<String> mimeTypes;

  /// Returns true if this paste contains animated GIFs.
  bool get hasGif => mimeTypes.any((type) => type == 'image/gif');

  /// The number of images in this paste.
  int get count => uris.length;

  @override
  String toString() => 'ImagePaste(uris: $uris, mimeTypes: $mimeTypes)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImagePaste &&
          _listEquals(uris, other.uris) &&
          _listEquals(mimeTypes, other.mimeTypes);

  @override
  int get hashCode => Object.hash(Object.hashAll(uris), Object.hashAll(mimeTypes));
}

/// Represents unsupported paste content.
///
/// This is returned when the clipboard contains content that cannot
/// be processed (e.g., files, rich text, etc.).
final class UnsupportedPaste extends PastePayload {
  /// Creates an [UnsupportedPaste] instance.
  const UnsupportedPaste();

  @override
  String toString() => 'UnsupportedPaste()';
}

/// Types of paste content that can be filtered.
enum PasteType {
  /// Plain text content.
  text,

  /// Image content (PNG, JPEG, GIF, etc.).
  image,
}

// Helper function to compare lists
bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
