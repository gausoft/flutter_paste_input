import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

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
///       case RawImagePaste(:final items):
///         // Handle raw image data directly
///         for (final item in items) {
///           print('Image: ${item.mimeType}, ${item.data.length} bytes');
///         }
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
/// ## Image Handling
///
/// When images are pasted, you receive either:
/// - [RawImagePaste] with raw binary data (allowing you to process it yourself)
/// - [ImagePaste] with file URIs (for backward compatibility)
///
/// ## Platform Support
///
/// - **iOS/Android**: Uses Flutter's ContentInsertionConfiguration
/// - **macOS/Linux/Windows**: Uses clipboard monitoring via Pigeon
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
    this.saveImagesToTempFiles = false,
  });

  /// The child widget, typically a [TextField] or [TextFormField].
  final Widget child;

  /// Called when the user pastes content into the text field.
  ///
  /// The callback receives a [PastePayload] which can be:
  /// - [TextPaste] for plain text
  /// - [RawImagePaste] for images with raw data
  /// - [ImagePaste] for images with file URIs (when [saveImagesToTempFiles] is true)
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

  /// Whether to save images to temporary files instead of passing raw data.
  ///
  /// When true, [ImagePaste] with file URIs is returned instead of [RawImagePaste].
  /// This is useful for backward compatibility or when working with APIs that
  /// require file paths.
  final bool saveImagesToTempFiles;

  @override
  State<PasteWrapper> createState() => _PasteWrapperState();
}

class _PasteWrapperState extends State<PasteWrapper> {
  bool get _useContentInsertion => Platform.isIOS || Platform.isAndroid;

  // Store reference to the TextField controller for inserting text
  TextEditingController? _getController() {
    final child = widget.child;
    if (child is TextField) {
      return child.controller;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    // On iOS/Android, use ContentInsertionConfiguration
    if (_useContentInsertion) {
      return _buildWithContentInsertion();
    }

    // On desktop platforms, use clipboard monitoring
    return _buildWithClipboardMonitoring();
  }

  Widget _buildWithContentInsertion() {
    // Extract TextField from child
    final child = widget.child;

    if (child is TextField) {
      return TextField(
        controller: child.controller,
        focusNode: child.focusNode,
        decoration: child.decoration,
        keyboardType: child.keyboardType,
        textInputAction: child.textInputAction,
        textCapitalization: child.textCapitalization,
        style: child.style,
        strutStyle: child.strutStyle,
        textAlign: child.textAlign,
        textAlignVertical: child.textAlignVertical,
        textDirection: child.textDirection,
        readOnly: child.readOnly,
        showCursor: child.showCursor,
        autofocus: child.autofocus,
        obscuringCharacter: child.obscuringCharacter,
        obscureText: child.obscureText,
        autocorrect: child.autocorrect,
        smartDashesType: child.smartDashesType,
        smartQuotesType: child.smartQuotesType,
        enableSuggestions: child.enableSuggestions,
        maxLines: child.maxLines,
        minLines: child.minLines,
        expands: child.expands,
        maxLength: child.maxLength,
        onChanged: child.onChanged,
        onEditingComplete: child.onEditingComplete,
        onSubmitted: child.onSubmitted,
        onAppPrivateCommand: child.onAppPrivateCommand,
        inputFormatters: child.inputFormatters,
        enabled: child.enabled,
        cursorWidth: child.cursorWidth,
        cursorHeight: child.cursorHeight,
        cursorRadius: child.cursorRadius,
        cursorOpacityAnimates: child.cursorOpacityAnimates,
        cursorColor: child.cursorColor,
        selectionHeightStyle: child.selectionHeightStyle,
        selectionWidthStyle: child.selectionWidthStyle,
        keyboardAppearance: child.keyboardAppearance,
        scrollPadding: child.scrollPadding,
        dragStartBehavior: child.dragStartBehavior,
        enableInteractiveSelection: child.enableInteractiveSelection,
        selectionControls: child.selectionControls,
        onTap: child.onTap,
        onTapOutside: child.onTapOutside,
        mouseCursor: child.mouseCursor,
        buildCounter: child.buildCounter,
        scrollController: child.scrollController,
        scrollPhysics: child.scrollPhysics,
        autofillHints: child.autofillHints,
        clipBehavior: child.clipBehavior,
        restorationId: child.restorationId,
        stylusHandwritingEnabled: child.stylusHandwritingEnabled,
        enableIMEPersonalizedLearning: child.enableIMEPersonalizedLearning,
        contextMenuBuilder: _buildContextMenu,
        canRequestFocus: child.canRequestFocus,
        spellCheckConfiguration: child.spellCheckConfiguration,
        magnifierConfiguration: child.magnifierConfiguration,
        contentInsertionConfiguration: ContentInsertionConfiguration(
          onContentInserted: _onContentInserted,
          allowedMimeTypes: const [
            'image/png',
            'image/jpeg',
            'image/gif',
            'image/webp',
          ],
        ),
      );
    }

    // If not a TextField, wrap with Actions for clipboard monitoring
    return _buildWithClipboardMonitoring();
  }

  Widget _buildContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    final List<ContextMenuButtonItem> buttonItems = List.from(
      editableTextState.contextMenuButtonItems,
    );

    // Remove the default Paste button and replace with our custom one
    buttonItems.removeWhere((item) => item.type == ContextMenuButtonType.paste);

    // Add our custom "Paste" button that handles both text and images
    buttonItems.insert(
      0,
      ContextMenuButtonItem(
        label: 'Paste',
        onPressed: () async {
          ContextMenuController.removeAny();
          await _checkAndPasteFromClipboard(editableTextState);
        },
      ),
    );

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }

  Future<void> _checkAndPasteFromClipboard(
    EditableTextState editableTextState,
  ) async {
    try {
      // Use the Pigeon-based API
      final payload = await PasteChannel.instance.getPastePayload();

      if (payload is TextPaste) {
        _notifyTextPaste(payload.text);
        _insertTextIntoField(editableTextState, payload.text);
      } else if (payload is RawImagePaste) {
        await _handleRawImagePaste(payload);
      } else {
        // Fallback to Flutter's clipboard for text
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        if (data?.text != null && data!.text!.isNotEmpty) {
          _notifyTextPaste(data.text!);
          _insertTextIntoField(editableTextState, data.text!);
        }
      }
    } catch (e) {
      // Error reading clipboard content, try fallback
      try {
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        if (data?.text != null && data!.text!.isNotEmpty) {
          _notifyTextPaste(data.text!);
          _insertTextIntoField(editableTextState, data.text!);
        }
      } catch (_) {
        // Error reading clipboard text
      }
    }
  }

  Future<void> _handleRawImagePaste(RawImagePaste payload) async {
    if (widget.saveImagesToTempFiles) {
      // Convert raw data to files
      final tempDir = await getTemporaryDirectory();
      final List<String> uris = [];
      final List<String> mimeTypes = [];

      for (int i = 0; i < payload.items.length; i++) {
        final item = payload.items[i];
        final extension = _getExtensionFromMimeType(item.mimeType);
        final fileName = 'paste_${DateTime.now().millisecondsSinceEpoch}_$i.$extension';
        final file = File('${tempDir.path}/$fileName');

        await file.writeAsBytes(item.data);
        uris.add(file.path);
        mimeTypes.add(item.mimeType);
      }

      if (uris.isNotEmpty) {
        _notifyImagePaste(uris, mimeTypes);
      }
    } else {
      // Pass raw data directly
      _notifyRawImagePaste(payload);
    }
  }

  /// Insert text at the current cursor position in the TextField
  void _insertTextIntoField(EditableTextState editableTextState, String text) {
    final TextEditingValue currentValue = editableTextState.textEditingValue;
    final int start = currentValue.selection.start;
    final int end = currentValue.selection.end;

    // Handle case where there's no valid selection
    final int insertStart = start >= 0 ? start : currentValue.text.length;
    final int insertEnd = end >= 0 ? end : currentValue.text.length;

    final String newText = currentValue.text.replaceRange(
      insertStart,
      insertEnd,
      text,
    );
    final int newCursorPosition = insertStart + text.length;

    editableTextState.userUpdateTextEditingValue(
      TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursorPosition),
      ),
      SelectionChangedCause.keyboard,
    );
  }

  Widget _buildWithClipboardMonitoring() {
    return Actions(
      actions: <Type, Action<Intent>>{
        PasteTextIntent: _PasteInterceptAction(
          onPaste: _onClipboardPaste,
          onDefaultPaste: () {
            // Get the default paste action and invoke it
            final controller = _getController();
            if (controller != null) {
              Clipboard.getData(Clipboard.kTextPlain).then((data) {
                if (data?.text != null) {
                  final text = controller.text;
                  final selection = controller.selection;
                  final start = selection.start >= 0
                      ? selection.start
                      : text.length;
                  final end = selection.end >= 0 ? selection.end : text.length;
                  final newText = text.replaceRange(start, end, data!.text!);
                  final newCursorPosition = start + data.text!.length;
                  controller.value = TextEditingValue(
                    text: newText,
                    selection: TextSelection.collapsed(
                      offset: newCursorPosition,
                    ),
                  );
                }
              });
            }
          },
        ),
      },
      child: widget.child,
    );
  }

  Future<void> _onContentInserted(KeyboardInsertedContent content) async {
    if (!widget.enabled) return;

    // Check if it's an image
    if (content.mimeType.startsWith('image/')) {
      await _handleImageContent(content);
    } else if (content.mimeType == 'text/plain') {
      await _handleTextContent(content);
    } else {
      _notifyUnsupported();
    }
  }

  Future<void> _handleImageContent(KeyboardInsertedContent content) async {
    try {
      if (content.data != null) {
        if (widget.saveImagesToTempFiles) {
          final tempDir = await getTemporaryDirectory();
          final extension = _getExtensionFromMimeType(content.mimeType);
          final fileName = 'paste_${DateTime.now().millisecondsSinceEpoch}.$extension';
          final file = File('${tempDir.path}/$fileName');
          await file.writeAsBytes(content.data!);
          _notifyImagePaste([file.path], [content.mimeType]);
        } else {
          _notifyRawImagePaste(RawImagePaste(
            items: [RawClipboardItem(data: content.data!, mimeType: content.mimeType)],
          ));
        }
      } else {
        // Copy from URI if available
        final sourceFile = File(content.uri);
        if (await sourceFile.exists()) {
          final tempDir = await getTemporaryDirectory();
          final extension = _getExtensionFromMimeType(content.mimeType);
          final fileName = 'paste_${DateTime.now().millisecondsSinceEpoch}.$extension';
          final file = File('${tempDir.path}/$fileName');
          await sourceFile.copy(file.path);
          _notifyImagePaste([file.path], [content.mimeType]);
        }
      }
    } catch (e) {
      // Error handling image content
      _notifyUnsupported();
    }
  }

  Future<void> _handleTextContent(KeyboardInsertedContent content) async {
    if (content.data != null) {
      final text = String.fromCharCodes(content.data!);
      _notifyTextPaste(text);
    } else {
      _notifyUnsupported();
    }
  }

  Future<void> _onClipboardPaste() async {
    if (!widget.enabled) return;

    try {
      // Use Pigeon-based API
      final payload = await PasteChannel.instance.getPastePayload();
      if (payload is TextPaste) {
        _notifyTextPaste(payload.text);
      } else if (payload is RawImagePaste) {
        await _handleRawImagePaste(payload);
      } else {
        _notifyUnsupported();
      }
    } catch (e) {
      // Fallback to Flutter's clipboard
      try {
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        if (data?.text != null) {
          _notifyTextPaste(data!.text!);
        } else {
          _notifyUnsupported();
        }
      } catch (_) {
        _notifyUnsupported();
      }
    }
  }

  void _notifyTextPaste(String text) {
    if (widget.acceptedTypes != null &&
        !widget.acceptedTypes!.contains(PasteType.text)) {
      return;
    }
    widget.onPaste(TextPaste(text: text));
  }

  void _notifyImagePaste(List<String> uris, List<String> mimeTypes) {
    if (widget.acceptedTypes != null &&
        !widget.acceptedTypes!.contains(PasteType.image)) {
      return;
    }
    widget.onPaste(ImagePaste(uris: uris, mimeTypes: mimeTypes));
  }

  void _notifyRawImagePaste(RawImagePaste payload) {
    if (widget.acceptedTypes != null &&
        !widget.acceptedTypes!.contains(PasteType.image)) {
      return;
    }
    widget.onPaste(payload);
  }

  void _notifyUnsupported() {
    widget.onPaste(const UnsupportedPaste());
  }

  String _getExtensionFromMimeType(String mimeType) {
    switch (mimeType) {
      case 'image/png':
        return 'png';
      case 'image/jpeg':
      case 'image/jpg':
        return 'jpg';
      case 'image/gif':
        return 'gif';
      case 'image/webp':
        return 'webp';
      default:
        return 'png';
    }
  }
}

class _PasteInterceptAction extends Action<PasteTextIntent> {
  _PasteInterceptAction({required this.onPaste, required this.onDefaultPaste});

  final Future<void> Function() onPaste;
  final void Function() onDefaultPaste;

  @override
  Object? invoke(PasteTextIntent intent) {
    onPaste();
    // Also perform the actual paste into the text field
    onDefaultPaste();
    return null;
  }

  @override
  bool consumesKey(PasteTextIntent intent) => true;
}
