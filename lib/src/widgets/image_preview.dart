import 'dart:io';

import 'package:flutter/material.dart';

import '../image_viewer.dart';

/// A thumbnail preview of an image with a remove button.
///
/// Displays an image file as a thumbnail with a circular remove button
/// in the top-right corner. Tapping the image opens it in fullscreen.
///
/// Example:
/// ```dart
/// ImagePreview(
///   imagePath: '/path/to/image.png',
///   onRemove: () => print('Remove tapped'),
/// )
/// ```
class ImagePreview extends StatelessWidget {
  /// Creates an image preview widget.
  const ImagePreview({
    super.key,
    required this.imagePath,
    required this.onRemove,
    this.size = 80,
    this.borderRadius = 8,
  });

  /// The path to the image file.
  final String imagePath;

  /// Callback when the remove button is tapped.
  final VoidCallback onRemove;

  /// The size of the preview (width and height).
  final double size;

  /// The border radius of the image corners.
  final double borderRadius;

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
            borderRadius: BorderRadius.circular(borderRadius),
            child: Image.file(
              File(imagePath),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _ErrorPlaceholder(size: size, borderRadius: borderRadius);
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
  const _ErrorPlaceholder({required this.size, required this.borderRadius});

  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(borderRadius),
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
