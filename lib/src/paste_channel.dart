import 'dart:async';
import 'dart:convert';

import 'generated/messages.g.dart';
import 'paste_payload.dart';

/// Implementation of [PasteInputFlutterApi] to receive paste events from native.
class _PasteInputFlutterApiImpl implements PasteInputFlutterApi {
  _PasteInputFlutterApiImpl(this._onPaste);

  final void Function(ClipboardContent content) _onPaste;

  @override
  void onPasteDetected(ClipboardContent content) {
    _onPaste(content);
  }
}

/// Handles communication with the native platform for paste events.
///
/// This class uses Pigeon-generated type-safe APIs for communication
/// with native code across all platforms.
class PasteChannel {
  PasteChannel._() {
    _hostApi = PasteInputHostApi();
  }

  static final PasteChannel _instance = PasteChannel._();

  /// The singleton instance of [PasteChannel].
  static PasteChannel get instance => _instance;

  late final PasteInputHostApi _hostApi;
  final _pasteController = StreamController<PastePayload>.broadcast();

  bool _isInitialized = false;

  /// Stream of paste events from the native platform.
  ///
  /// Subscribe to this stream to receive [PastePayload] objects whenever
  /// the user pastes content into a wrapped text field.
  Stream<PastePayload> get onPaste => _pasteController.stream;

  /// Initializes the paste event listener.
  ///
  /// This should be called once before using the plugin.
  /// It's automatically called by [PasteWrapper] when first mounted.
  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    // Set up the Flutter API to receive callbacks from native
    PasteInputFlutterApi.setUp(
      _PasteInputFlutterApiImpl(_handlePasteFromNative),
    );
  }

  /// Disposes of the paste event listener.
  ///
  /// Call this when the plugin is no longer needed.
  void dispose() {
    _isInitialized = false;
    PasteInputFlutterApi.setUp(null);
  }

  /// Handles paste events received from native code via Pigeon.
  void _handlePasteFromNative(ClipboardContent content) {
    final payload = _convertToPayload(content);
    _pasteController.add(payload);
  }

  /// Converts [ClipboardContent] from Pigeon to [PastePayload].
  PastePayload _convertToPayload(ClipboardContent content) {
    if (content.items.isEmpty) {
      return const UnsupportedPaste();
    }

    // Check for images first (priority to images)
    final imageItems = content.items.where((item) => _isImage(item.mimeType)).toList();
    if (imageItems.isNotEmpty) {
      return RawImagePaste(
        items: imageItems.map((item) => RawClipboardItem(
          data: item.data,
          mimeType: item.mimeType,
        )).toList(),
      );
    }

    // Check for text
    final textItems = content.items.where((item) => _isText(item.mimeType)).toList();
    if (textItems.isNotEmpty) {
      // Decode the first text item as UTF-8
      final textData = textItems.first.data;
      final text = utf8.decode(textData);
      return TextPaste(text: text);
    }

    return const UnsupportedPaste();
  }

  bool _isImage(String mimeType) => mimeType.startsWith('image/');
  bool _isText(String mimeType) => mimeType.startsWith('text/');

  /// Returns the current platform version.
  ///
  /// This is mainly for debugging purposes.
  Future<String?> getPlatformVersion() async {
    try {
      return await _hostApi.getPlatformVersion();
    } catch (e) {
      return null;
    }
  }

  /// Clears temporary image files created by paste operations.
  ///
  /// Call this periodically to free up disk space. The plugin stores
  /// pasted images in the app's cache directory, and they are not
  /// automatically deleted.
  Future<void> clearTempFiles() async {
    await _hostApi.clearTempFiles();
  }

  /// Gets the current clipboard content.
  ///
  /// Returns a [ClipboardContent] containing all available items.
  /// Use this to manually check clipboard content.
  Future<ClipboardContent> getClipboardContent() async {
    return await _hostApi.getClipboardContent();
  }

  /// Gets the clipboard content and converts it to a [PastePayload].
  ///
  /// This is useful for handling paste events manually, for example
  /// when intercepting paste actions from the Flutter framework.
  Future<PastePayload> getPastePayload() async {
    final content = await getClipboardContent();
    return _convertToPayload(content);
  }
}

