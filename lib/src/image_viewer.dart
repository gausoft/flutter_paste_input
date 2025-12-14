import 'dart:io';

import 'package:flutter/material.dart';

/// A fullscreen image viewer widget with zoom and pan support.
///
/// This widget displays an image in fullscreen with a semi-transparent
/// background, a close button, and interactive zoom/pan capabilities.
///
/// ## Usage
///
/// Use [showImageViewer] to display the viewer:
///
/// ```dart
/// showImageViewer(
///   context: context,
///   imageFile: File('/path/to/image.png'),
/// );
/// ```
///
/// Or with a hero animation:
///
/// ```dart
/// // In your thumbnail widget:
/// Hero(
///   tag: 'my-image',
///   child: Image.file(imageFile),
/// )
///
/// // To open fullscreen:
/// showImageViewer(
///   context: context,
///   imageFile: imageFile,
///   heroTag: 'my-image',
/// );
/// ```
class ImageViewer extends StatelessWidget {
  /// Creates an [ImageViewer] widget.
  const ImageViewer({
    super.key,
    required this.imageFile,
    this.heroTag,
    this.backgroundColor = Colors.black87,
    this.closeButtonColor = Colors.black54,
    this.closeIconColor = Colors.white,
    this.minScale = 0.5,
    this.maxScale = 4.0,
    this.onClose,
  });

  /// The image file to display.
  final File imageFile;

  /// Optional hero tag for hero animation.
  ///
  /// If provided, the image will animate from its source location
  /// using Flutter's Hero widget.
  final String? heroTag;

  /// Background color of the viewer overlay.
  ///
  /// Defaults to [Colors.black87].
  final Color backgroundColor;

  /// Background color of the close button.
  ///
  /// Defaults to [Colors.black54].
  final Color closeButtonColor;

  /// Color of the close icon.
  ///
  /// Defaults to [Colors.white].
  final Color closeIconColor;

  /// Minimum scale factor for zoom.
  ///
  /// Defaults to 0.5.
  final double minScale;

  /// Maximum scale factor for zoom.
  ///
  /// Defaults to 4.0.
  final double maxScale;

  /// Callback when the viewer is closed.
  ///
  /// If not provided, [Navigator.pop] will be called.
  final VoidCallback? onClose;

  void _handleClose(BuildContext context) {
    if (onClose != null) {
      onClose!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageWidget = Image.file(
      imageFile,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Icon(
            Icons.broken_image,
            color: closeIconColor.withValues(alpha: 0.5),
            size: 64,
          ),
        );
      },
    );

    final interactiveImage = InteractiveViewer(
      minScale: minScale,
      maxScale: maxScale,
      child: heroTag != null
          ? Hero(tag: heroTag!, child: imageWidget)
          : imageWidget,
    );

    return GestureDetector(
      onTap: () => _handleClose(context),
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Stack(
          children: [
            // Centered image with zoom
            Center(child: interactiveImage),

            // Close button
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: GestureDetector(
                onTap: () => _handleClose(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: closeButtonColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    color: closeIconColor,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows a fullscreen image viewer.
///
/// This function pushes an [ImageViewer] onto the navigation stack
/// with a fade transition and transparent background.
///
/// ## Example
///
/// ```dart
/// showImageViewer(
///   context: context,
///   imageFile: File('/path/to/image.png'),
///   heroTag: 'unique-tag', // Optional, for hero animation
/// );
/// ```
///
/// Returns a [Future] that completes when the viewer is closed.
Future<void> showImageViewer({
  required BuildContext context,
  required File imageFile,
  String? heroTag,
  Color backgroundColor = Colors.black87,
  Color closeButtonColor = Colors.black54,
  Color closeIconColor = Colors.white,
  double minScale = 0.5,
  double maxScale = 4.0,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      pageBuilder: (context, animation, secondaryAnimation) {
        return ImageViewer(
          imageFile: imageFile,
          heroTag: heroTag,
          backgroundColor: backgroundColor,
          closeButtonColor: closeButtonColor,
          closeIconColor: closeIconColor,
          minScale: minScale,
          maxScale: maxScale,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}
