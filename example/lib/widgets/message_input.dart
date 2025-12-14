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

class _ImageList extends StatefulWidget {
  const _ImageList({required this.imagePaths, required this.onRemoveImage});

  final List<String> imagePaths;
  final void Function(int index) onRemoveImage;

  @override
  State<_ImageList> createState() => _ImageListState();
}

class _ImageListState extends State<_ImageList> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  late List<String> _internalList;
  bool _isAnimatingRemoval = false;

  @override
  void initState() {
    super.initState();
    _internalList = List.from(widget.imagePaths);
  }

  @override
  void didUpdateWidget(_ImageList oldWidget) {
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
          child: Padding(
            padding: const EdgeInsets.only(right: 0),
            child: ImagePreview(imagePath: imagePath, onRemove: () {}),
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
            padding: const EdgeInsets.only(right: 8),
            child: ImagePreview(imagePath: imagePath, onRemove: () {}),
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
            right: index < _internalList.length - 1 ? 8 : 0,
          ),
          child: ImagePreview(
            imagePath: _internalList[index],
            onRemove: () => _removeItem(index),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: SizedBox(
        height: 80,
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
