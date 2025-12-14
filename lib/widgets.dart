/// Optional UI widgets for flutter_paste_input.
///
/// This library provides ready-to-use widgets for common use cases
/// like displaying pasted images with previews, lists, and fullscreen viewing.
///
/// ## Usage
///
/// ```dart
/// import 'package:flutter_paste_input/flutter_paste_input.dart';
/// import 'package:flutter_paste_input/widgets.dart';
///
/// // Display a list of pasted images with animations
/// PastedImageList(
///   imagePaths: imagePaths,
///   onRemoveImage: (index) => removeImage(index),
/// )
///
/// // Or use individual image previews
/// ImagePreview(
///   imagePath: '/path/to/image.png',
///   onRemove: () => removeImage(),
/// )
///
/// // Show image in fullscreen
/// showImageViewer(
///   context: context,
///   imageFile: File('/path/to/image.png'),
/// );
/// ```
library;

export 'src/image_viewer.dart' show ImageViewer, showImageViewer;
export 'src/widgets/image_preview.dart' show ImagePreview;
export 'src/widgets/pasted_image_list.dart' show PastedImageList;
