import 'package:flutter/material.dart';

import 'image_preview.dart';

/// A horizontal scrollable list of pasted images with smooth animations.
///
/// Displays images in a horizontal [AnimatedList] with smooth insert and
/// remove animations. When an image is removed, it fades out while the
/// following images slide left to take its place.
///
/// Example:
/// ```dart
/// PastedImageList(
///   imagePaths: ['/path/to/image1.png', '/path/to/image2.png'],
///   onRemoveImage: (index) => print('Remove image at $index'),
/// )
/// ```
class PastedImageList extends StatefulWidget {
  /// Creates a pasted image list widget.
  const PastedImageList({
    super.key,
    required this.imagePaths,
    required this.onRemoveImage,
    this.itemSize = 80,
    this.spacing = 8,
    this.height = 80,
    this.padding = EdgeInsets.zero,
  });

  /// List of image file paths to display.
  final List<String> imagePaths;

  /// Callback when an image is removed. Provides the index of the removed image.
  final void Function(int index) onRemoveImage;

  /// The size (width and height) of each image preview.
  final double itemSize;

  /// The spacing between images.
  final double spacing;

  /// The height of the list container.
  final double height;

  /// Padding around the list.
  final EdgeInsets padding;

  @override
  State<PastedImageList> createState() => _PastedImageListState();
}

class _PastedImageListState extends State<PastedImageList> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  late List<String> _internalList;
  bool _isAnimatingRemoval = false;

  @override
  void initState() {
    super.initState();
    _internalList = List.from(widget.imagePaths);
  }

  @override
  void didUpdateWidget(PastedImageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync internal list with external list when new items are added
    if (widget.imagePaths.length > _internalList.length &&
        !_isAnimatingRemoval) {
      // New items added - insert them with animation
      for (int i = _internalList.length; i < widget.imagePaths.length; i++) {
        _internalList.add(widget.imagePaths[i]);
        _listKey.currentState?.insertItem(
          i,
          duration: const Duration(milliseconds: 150),
        );
      }
    } else if (!_isAnimatingRemoval) {
      // Direct sync for other cases
      _internalList = List.from(widget.imagePaths);
    }
  }

  void _removeItem(int index) {
    if (_isAnimatingRemoval) return;

    final isLastItem = _internalList.length == 1;
    final removedPath = _internalList[index];

    setState(() {
      _isAnimatingRemoval = true;
    });

    _listKey.currentState?.removeItem(
      index,
      (context, animation) =>
          _buildRemovedItem(removedPath, animation, index, isLastItem),
      duration: const Duration(milliseconds: 200),
    );

    // Update internal list immediately
    _internalList.removeAt(index);

    // Notify parent after animation completes
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _isAnimatingRemoval = false;
        });
        widget.onRemoveImage(index);
      }
    });
  }

  Widget _buildRemovedItem(
    String imagePath,
    Animation<double> animation,
    int index,
    bool isLastItem,
  ) {
    if (isLastItem) {
      // Last item: slide down and disappear
      return ClipRect(
        child: SlideTransition(
          position: Tween<Offset>(begin: Offset.zero, end: const Offset(0, 1))
              .animate(
                CurvedAnimation(
                  parent: ReverseAnimation(animation),
                  curve: Curves.easeOut,
                ),
              ),
          child: ImagePreview(
            imagePath: imagePath,
            size: widget.itemSize,
            onRemove: () {},
          ),
        ),
      );
    } else {
      // Non-last items: item stays in place and fades out,
      // while following elements slide left to replace it
      return SizeTransition(
        sizeFactor: CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubic,
        ),
        axis: Axis.horizontal,
        axisAlignment: -1.0, // Item stays left, space shrinks from right
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ),
          child: Padding(
            padding: EdgeInsets.only(right: widget.spacing),
            child: ImagePreview(
              imagePath: imagePath,
              size: widget.itemSize,
              onRemove: () {},
            ),
          ),
        ),
      );
    }
  }

  Widget _buildItem(
    BuildContext context,
    int index,
    Animation<double> animation,
  ) {
    return ClipRect(
      child: SizeTransition(
        sizeFactor: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ),
        axis: Axis.horizontal,
        axisAlignment: -1.0,
        child: Padding(
          padding: EdgeInsets.only(
            right: index < _internalList.length - 1 ? widget.spacing : 0,
          ),
          child: ImagePreview(
            imagePath: _internalList[index],
            size: widget.itemSize,
            onRemove: () => _removeItem(index),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: SizedBox(
        height: widget.height,
        child: AnimatedList(
          key: _listKey,
          scrollDirection: Axis.horizontal,
          initialItemCount: _internalList.length,
          itemBuilder: _buildItem,
        ),
      ),
    );
  }
}
