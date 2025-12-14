import 'package:flutter/material.dart';
import 'package:flutter_paste_input/flutter_paste_input.dart';

import 'image_preview.dart';
import 'send_button.dart';

/// A message input field with image preview and send button.
class MessageInput extends StatelessWidget {
  const MessageInput({
    super.key,
    required this.controller,
    required this.imagePaths,
    required this.onPaste,
    required this.onRemoveImage,
    required this.onSend,
  });

  /// The text editing controller.
  final TextEditingController controller;

  /// List of pasted image paths.
  final List<String> imagePaths;

  /// Callback when content is pasted.
  final void Function(PastePayload payload) onPaste;

  /// Callback when an image is removed.
  final void Function(int index) onRemoveImage;

  /// Callback when the send button is tapped.
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _InputContainer(
                controller: controller,
                imagePaths: imagePaths,
                onPaste: onPaste,
                onRemoveImage: onRemoveImage,
              ),
            ),
            const SizedBox(width: 10),
            SendButton(onTap: onSend),
          ],
        ),
      ),
    );
  }
}

class _InputContainer extends StatelessWidget {
  const _InputContainer({
    required this.controller,
    required this.imagePaths,
    required this.onPaste,
    required this.onRemoveImage,
  });

  final TextEditingController controller;
  final List<String> imagePaths;
  final void Function(PastePayload payload) onPaste;
  final void Function(int index) onRemoveImage;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imagePaths.isNotEmpty)
            _ImageList(imagePaths: imagePaths, onRemoveImage: onRemoveImage),
          _TextField(controller: controller, onPaste: onPaste),
        ],
      ),
    );
  }
}

class _ImageList extends StatelessWidget {
  const _ImageList({required this.imagePaths, required this.onRemoveImage});

  final List<String> imagePaths;
  final void Function(int index) onRemoveImage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(
          imagePaths.length,
          (index) => ImagePreview(
            imagePath: imagePaths[index],
            onRemove: () => onRemoveImage(index),
          ),
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({required this.controller, required this.onPaste});

  final TextEditingController controller;
  final void Function(PastePayload payload) onPaste;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PasteWrapper(
      onPaste: onPaste,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: 'Type a message',
          hintStyle: TextStyle(
            color: isDark ? Colors.grey[500] : Colors.grey[600],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        maxLines: 5,
        minLines: 1,
        textCapitalization: TextCapitalization.sentences,
      ),
    );
  }
}
