import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_paste_input/widgets.dart';

/// A thumbnail preview of an image with a remove button.
class ImagePreview extends StatelessWidget {
  const ImagePreview({
    super.key,
    required this.imagePath,
    required this.onRemove,
    this.size = 80,
  });

  /// The path to the image file.
  final String imagePath;

  /// Callback when the remove button is tapped.
  final VoidCallback onRemove;

  /// The size of the preview (width and height).
  final double size;

  void _openFullscreen(BuildContext context) {
    showImageViewer(context: context, imageFile: File(imagePath));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () => _openFullscreen(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(imagePath),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _ErrorPlaceholder(size: size);
              },
            ),
          ),
        ),
        Positioned(top: -6, right: -6, child: _RemoveButton(onTap: onRemove)),
      ],
    );
  }
}

class _ErrorPlaceholder extends StatelessWidget {
  const _ErrorPlaceholder({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.broken_image, color: colorScheme.onErrorContainer),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.close, size: 14, color: colorScheme.onSurface),
      ),
    );
  }
}
