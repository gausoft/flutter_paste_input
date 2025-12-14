/// Represents a chat message with optional text and images.
class ChatMessage {
  ChatMessage({
    required this.id,
    this.text,
    this.imagePaths = const [],
    required this.timestamp,
  });

  /// Unique identifier for the message.
  final String id;

  /// The text content of the message.
  final String? text;

  /// List of image file paths attached to the message.
  final List<String> imagePaths;

  /// When the message was sent.
  final DateTime timestamp;

  /// Whether the message has any content.
  bool get hasContent =>
      (text != null && text!.isNotEmpty) || imagePaths.isNotEmpty;

  /// Whether the message has images.
  bool get hasImages => imagePaths.isNotEmpty;

  /// Whether the message has text.
  bool get hasText => text != null && text!.isNotEmpty;
}
