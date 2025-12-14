import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_paste_input/flutter_paste_input.dart';

import '../models/models.dart';
import '../widgets/widgets.dart';

/// A demo screen showing a chat-style input with paste support.
class ChatInputDemo extends StatefulWidget {
  const ChatInputDemo({super.key});

  @override
  State<ChatInputDemo> createState() => _ChatInputDemoState();
}

class _ChatInputDemoState extends State<ChatInputDemo> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<String> _pastedImagePaths = [];
  final List<ChatMessage> _messages = [];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    PasteChannel.instance.clearTempFiles();
    super.dispose();
  }

  void _handlePaste(PastePayload payload) {
    setState(() {
      switch (payload) {
        case TextPaste():
          // Text is automatically inserted into the TextField
          break;
        case ImagePaste(:final uris):
          _pastedImagePaths.addAll(uris);
        case RawImagePaste(:final items):
          _saveRawImages(items);
        case UnsupportedPaste():
          break;
      }
    });
  }

  Future<void> _saveRawImages(List<RawClipboardItem> items) async {
    for (final item in items) {
      final extension = item.mimeType.split('/').last;
      final fileName =
          'paste_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(item.data);
      if (mounted) {
        setState(() {
          _pastedImagePaths.add(file.path);
        });
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _pastedImagePaths.removeAt(index);
    });
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    final hasImages = _pastedImagePaths.isNotEmpty;

    if (text.isEmpty && !hasImages) return;

    // Create a new message
    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text.isNotEmpty ? text : null,
      imagePaths: List.from(_pastedImagePaths),
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(message);
      _pastedImagePaths.clear();
    });

    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: _MessageList(
                messages: _messages,
                scrollController: _scrollController,
              ),
            ),
            MessageInput(
              controller: _controller,
              imagePaths: _pastedImagePaths,
              onPaste: _handlePaste,
              onRemoveImage: _removeImage,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.messages, required this.scrollController});

  final List<ChatMessage> messages;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const _EmptyState();
    }

    return ListView.builder(
      controller: scrollController,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        // Reverse index to show newest at bottom
        final reversedIndex = messages.length - 1 - index;
        return MessageBubble(message: messages[reversedIndex]);
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Try pasting text or images into the input field below',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
