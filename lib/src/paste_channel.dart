import 'dart:async';

import 'package:flutter/services.dart';

import 'paste_payload.dart';

/// Handles communication with the native platform for paste events.
///
/// This class manages both the [MethodChannel] for method calls and
/// the [EventChannel] for receiving paste events from native code.
class PasteChannel {
  PasteChannel._();

  static final PasteChannel _instance = PasteChannel._();

  /// The singleton instance of [PasteChannel].
  static PasteChannel get instance => _instance;

  /// The method channel for calling native methods.
  static const MethodChannel _methodChannel = MethodChannel(
    'dev.gausoft/flutter_paste_input/methods',
  );

  /// The event channel for receiving paste events.
  static const EventChannel _eventChannel = EventChannel(
    'dev.gausoft/flutter_paste_input/events',
  );

  StreamSubscription<dynamic>? _subscription;
  final _pasteController = StreamController<PastePayload>.broadcast();

  /// Stream of paste events from the native platform.
  ///
  /// Subscribe to this stream to receive [PastePayload] objects whenever
  /// the user pastes content into a wrapped text field.
  Stream<PastePayload> get onPaste => _pasteController.stream;

  bool _isInitialized = false;

  /// Initializes the paste event listener.
  ///
  /// This should be called once before using the plugin.
  /// It's automatically called by [PasteWrapper] when first mounted.
  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    _subscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          final payload = PastePayload.fromMap(Map<String, dynamic>.from(event));
          _pasteController.add(payload);
        }
      },
      onError: (dynamic error) {
        // Log error but don't crash
        // ignore: avoid_print
        print('PasteChannel error: $error');
      },
    );
  }

  /// Disposes of the paste event listener.
  ///
  /// Call this when the plugin is no longer needed.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _isInitialized = false;
  }

  /// Returns the current platform version.
  ///
  /// This is mainly for debugging purposes.
  Future<String?> getPlatformVersion() async {
    final version = await _methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  /// Clears temporary image files created by paste operations.
  ///
  /// Call this periodically to free up disk space. The plugin stores
  /// pasted images in the app's cache directory, and they are not
  /// automatically deleted.
  Future<void> clearTempFiles() async {
    await _methodChannel.invokeMethod<void>('clearTempFiles');
  }

  /// Notifies the native side that a view is ready to receive paste events.
  ///
  /// This is called internally by [PasteWrapper].
  Future<void> registerView(int viewId) async {
    await _methodChannel.invokeMethod<void>('registerView', {'viewId': viewId});
  }

  /// Notifies the native side that a view is no longer listening for paste events.
  ///
  /// This is called internally by [PasteWrapper].
  Future<void> unregisterView(int viewId) async {
    await _methodChannel.invokeMethod<void>('unregisterView', {'viewId': viewId});
  }

  /// Triggers a clipboard check on the native side.
  ///
  /// This is used on platforms where the native side cannot automatically
  /// detect paste events (e.g., Android). The native side will read the
  /// clipboard and send an event if content is found.
  ///
  /// This is called internally by [PasteWrapper] when it intercepts
  /// a paste action from the Flutter framework.
  Future<void> checkClipboard() async {
    await _methodChannel.invokeMethod<void>('checkClipboard');
  }
}
