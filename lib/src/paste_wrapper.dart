import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'paste_channel.dart';
import 'paste_payload.dart';

/// A widget that wraps a [TextField] or [TextFormField] to intercept paste events.
///
/// This widget acts as an invisible wrapper that detects when the user pastes
/// content into the child text field. It supports pasting text and images.
///
/// ## Usage
///
/// ```dart
/// PasteWrapper(
///   onPaste: (payload) {
///     switch (payload) {
///       case TextPaste(:final text):
///         print('Pasted text: $text');
///       case ImagePaste(:final uris):
///         print('Pasted ${uris.length} images');
///         // uris contains file paths to temporary images
///       case UnsupportedPaste():
///         print('Unsupported paste content');
///     }
///   },
///   child: TextField(
///     controller: _controller,
///     decoration: InputDecoration(hintText: 'Type or paste here...'),
///   ),
/// )
/// ```
///
/// ## Image URIs
///
/// When images are pasted, the [ImagePaste.uris] field contains file paths
/// to temporary files in the app's cache directory. If you need to persist
/// these images, copy them to a permanent location.
///
/// ## Platform Support
///
/// - **iOS**: Uses method swizzling on UITextField/UITextView
/// - **Android**: Intercepts paste via clipboard monitoring
/// - **macOS**: Uses NSPasteboard with NSTextField swizzling
/// - **Linux**: Uses GTK clipboard API
/// - **Windows**: Uses Win32 clipboard API
class PasteWrapper extends StatefulWidget {
  /// Creates a [PasteWrapper] widget.
  ///
  /// The [child] must be a widget that contains a text input field
  /// (e.g., [TextField], [TextFormField], [CupertinoTextField]).
  ///
  /// The [onPaste] callback is called whenever the user pastes content.
  const PasteWrapper({
    super.key,
    required this.child,
    required this.onPaste,
    this.acceptedTypes,
    this.enabled = true,
  });

  /// The child widget, typically a [TextField] or [TextFormField].
  final Widget child;

  /// Called when the user pastes content into the text field.
  ///
  /// The callback receives a [PastePayload] which can be:
  /// - [TextPaste] for plain text
  /// - [ImagePaste] for images (with file URIs)
  /// - [UnsupportedPaste] for unsupported content types
  final void Function(PastePayload payload) onPaste;

  /// The types of paste content to accept.
  ///
  /// If null, all types are accepted.
  /// If specified, only matching paste types will trigger [onPaste].
  ///
  /// Example:
  /// ```dart
  /// PasteWrapper(
  ///   acceptedTypes: {PasteType.image}, // Only accept images
  ///   onPaste: (payload) { ... },
  ///   child: TextField(),
  /// )
  /// ```
  final Set<PasteType>? acceptedTypes;

  /// Whether paste detection is enabled.
  ///
  /// When false, the widget acts as a transparent wrapper and
  /// [onPaste] is never called.
  final bool enabled;

  @override
  State<PasteWrapper> createState() => _PasteWrapperState();
}

class _PasteWrapperState extends State<PasteWrapper> {
  StreamSubscription<PastePayload>? _subscription;
  static int _nextViewId = 0;
  late final int _viewId;

  /// Whether the native platform handles paste interception directly.
  /// iOS uses method swizzling to intercept paste at the UIKit level.
  bool get _nativeHandlesPaste => Platform.isIOS;

  @override
  void initState() {
    super.initState();
    _viewId = _nextViewId++;
    _initializePasteListener();
  }

  void _initializePasteListener() {
    if (!widget.enabled) return;

    // Initialize the channel if not already done
    PasteChannel.instance.initialize();

    // Register this view
    PasteChannel.instance.registerView(_viewId);

    // Subscribe to paste events
    _subscription = PasteChannel.instance.onPaste.listen(_handlePaste);
  }

  void _handlePaste(PastePayload payload) {
    if (!widget.enabled) return;

    // Filter by accepted types if specified
    if (widget.acceptedTypes != null) {
      final isAccepted = switch (payload) {
        TextPaste() => widget.acceptedTypes!.contains(PasteType.text),
        ImagePaste() => widget.acceptedTypes!.contains(PasteType.image),
        UnsupportedPaste() => false,
      };

      if (!isAccepted) return;
    }

    widget.onPaste(payload);
  }

  /// Called when a paste action is detected on non-iOS platforms.
  /// This triggers the native side to check the clipboard.
  void _onPasteAction() {
    if (!widget.enabled) return;
    PasteChannel.instance.checkClipboard();
  }

  @override
  void didUpdateWidget(PasteWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle enabled state changes
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _initializePasteListener();
      } else {
        _disposePasteListener();
      }
    }
  }

  void _disposePasteListener() {
    _subscription?.cancel();
    _subscription = null;
    PasteChannel.instance.unregisterView(_viewId);
  }

  @override
  void dispose() {
    _disposePasteListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // On iOS, the native side handles paste interception via swizzling.
    // On other platforms, we intercept paste actions here.
    if (_nativeHandlesPaste || !widget.enabled) {
      return widget.child;
    }

    // Wrap with Actions to intercept paste intent
    return Actions(
      actions: <Type, Action<Intent>>{
        PasteTextIntent: _PasteInterceptAction(_onPasteAction),
      },
      child: widget.child,
    );
  }
}

/// Custom action that intercepts paste and calls a callback.
class _PasteInterceptAction extends Action<PasteTextIntent> {
  _PasteInterceptAction(this.onPaste);

  final VoidCallback onPaste;

  @override
  Object? invoke(PasteTextIntent intent) {
    // Notify our handler about the paste
    onPaste();

    // Return null to let the default paste behavior continue
    // (text will be pasted normally, and we get notified via the event channel)
    return null;
  }

  @override
  bool consumesKey(PasteTextIntent intent) => false;
}
