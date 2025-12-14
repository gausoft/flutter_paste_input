import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_paste_input/flutter_paste_input.dart';
import 'package:flutter_paste_input/widgets.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paste Input Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: const ChatInputDemo(),
    );
  }
}

class ChatInputDemo extends StatefulWidget {
  const ChatInputDemo({super.key});

  @override
  State<ChatInputDemo> createState() => _ChatInputDemoState();
}

class _ChatInputDemoState extends State<ChatInputDemo> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _pastedImagePaths = [];

  void _handlePaste(PastePayload payload) {
    setState(() {
      switch (payload) {
        case TextPaste():
          // Text is automatically inserted into the TextField
          break;
        case ImagePaste(:final uris):
          _pastedImagePaths.addAll(uris);
        case RawImagePaste(:final items):
          // Handle raw image data - save to temp files for display
          _saveRawImages(items);
        case UnsupportedPaste():
          break;
      }
    });
  }

  Future<void> _saveRawImages(List<RawClipboardItem> items) async {
    for (final item in items) {
      final extension = item.mimeType.split('/').last;
      final fileName = 'paste_${DateTime.now().millisecondsSinceEpoch}.$extension';
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

    // Simuler l'envoi
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hasImages
              ? 'Sent: "$text" with ${_pastedImagePaths.length} image(s)'
              : 'Sent: "$text"',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Reset
    _controller.clear();
    setState(() {
      _pastedImagePaths.clear();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    PasteChannel.instance.clearTempFiles();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: Column(
          children: [
            // Espace vide
            const Expanded(child: SizedBox()),

            // Zone de saisie style message
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Champ de saisie avec images
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFEFEFEF),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Images collées
                    if (_pastedImagePaths.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(
                            _pastedImagePaths.length,
                            (index) => _buildImagePreview(index),
                          ),
                        ),
                      ),

                    // TextField
                    PasteWrapper(
                      onPaste: _handlePaste,
                      child: TextField(
                        controller: _controller,
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
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 10),

            // Bouton envoyer
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF3A3A3C)
                      : const Color(0xFF3C3C3C),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(int index) {
    final imagePath = _pastedImagePaths[index];

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () => _openImageFullscreen(imagePath),
          child: Hero(
            tag: 'image_$imagePath',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(imagePath),
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  final colorScheme = Theme.of(context).colorScheme;
                  return Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.broken_image,
                      color: colorScheme.onErrorContainer,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        // Bouton X pour supprimer
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: () => _removeImage(index),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                size: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openImageFullscreen(String imagePath) {
    showImageViewer(
      context: context,
      imageFile: File(imagePath),
      heroTag: 'image_$imagePath',
    );
  }
}
