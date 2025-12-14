import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_paste_input/widgets.dart';

import '../models/models.dart';

/// A chat bubble displaying a message with optional images.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  /// The message to display.
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? colorScheme.surfaceContainerHighest
              : colorScheme.surfaceContainerHigh,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.hasImages) _ImageGrid(imagePaths: message.imagePaths),
            if (message.hasText)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  14,
                  message.hasImages ? 8 : 12,
                  14,
                  12,
                ),
                child: Text(
                  message.text!,
                  style: TextStyle(
                    fontSize: 15,
                    color: colorScheme.onSurface,
                    height: 1.3,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ImageGrid extends StatelessWidget {
  const _ImageGrid({required this.imagePaths});

  final List<String> imagePaths;

  @override
  Widget build(BuildContext context) {
    if (imagePaths.length == 1) {
      return _SingleImage(path: imagePaths.first);
    }

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: imagePaths
            .map((path) => _GridImage(path: path, count: imagePaths.length))
            .toList(),
      ),
    );
  }
}

class _SingleImage extends StatelessWidget {
  const _SingleImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openViewer(context),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(4),
        ),
        child: Image.file(
          File(path),
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const _ImageError(),
        ),
      ),
    );
  }

  void _openViewer(BuildContext context) {
    showImageViewer(context: context, imageFile: File(path));
  }
}

class _GridImage extends StatelessWidget {
  const _GridImage({required this.path, required this.count});

  final String path;
  final int count;

  double get _size {
    if (count == 2) return 120;
    if (count <= 4) return 90;
    return 70;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openViewer(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(path),
          width: _size,
          height: _size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              SizedBox(width: _size, height: _size, child: const _ImageError()),
        ),
      ),
    );
  }

  void _openViewer(BuildContext context) {
    showImageViewer(context: context, imageFile: File(path));
  }
}

class _ImageError extends StatelessWidget {
  const _ImageError();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.errorContainer,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: colorScheme.onErrorContainer,
          size: 24,
        ),
      ),
    );
  }
}
