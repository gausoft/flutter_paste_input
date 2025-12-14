/// Optional UI widgets for flutter_paste_input.
///
/// This library provides ready-to-use widgets for common use cases
/// like displaying pasted images in fullscreen.
///
/// ## Usage
///
/// ```dart
/// import 'package:flutter_paste_input/flutter_paste_input.dart';
/// import 'package:flutter_paste_input/widgets.dart';
///
/// // Show image in fullscreen
/// showImageViewer(
///   context: context,
///   imageFile: File('/path/to/image.png'),
/// );
/// ```
library;

export 'src/image_viewer.dart' show ImageViewer, showImageViewer;
