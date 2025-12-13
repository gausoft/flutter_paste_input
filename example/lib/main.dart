import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_paste_input/flutter_paste_input.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Paste Input Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const PasteInputDemo(),
    );
  }
}

class PasteInputDemo extends StatefulWidget {
  const PasteInputDemo({super.key});

  @override
  State<PasteInputDemo> createState() => _PasteInputDemoState();
}

class _PasteInputDemoState extends State<PasteInputDemo> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _pastedImagePaths = [];
  String _lastPasteInfo = 'No paste detected yet';

  void _handlePaste(PastePayload payload) {
    setState(() {
      switch (payload) {
        case TextPaste(:final text):
          _lastPasteInfo = 'Pasted text: "${text.length > 50 ? '${text.substring(0, 50)}...' : text}"';
        case ImagePaste(:final uris, :final mimeTypes):
          _lastPasteInfo = 'Pasted ${uris.length} image(s): ${mimeTypes.join(', ')}';
          _pastedImagePaths.addAll(uris);
        case UnsupportedPaste():
          _lastPasteInfo = 'Unsupported paste content';
      }
    });
  }

  void _clearImages() {
    setState(() {
      _pastedImagePaths.clear();
    });
    PasteChannel.instance.clearTempFiles();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paste Input Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_pastedImagePaths.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _clearImages,
              tooltip: 'Clear images',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _lastPasteInfo,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Pasted images preview
            if (_pastedImagePaths.isNotEmpty) ...[
              Text(
                'Pasted Images:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _pastedImagePaths.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_pastedImagePaths[index]),
                          height: 100,
                          width: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 100,
                              width: 100,
                              color: Colors.grey[300],
                              child: const Icon(Icons.error),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Text input with paste wrapper
            const Text('Paste text or images here:'),
            const SizedBox(height: 8),
            PasteWrapper(
              onPaste: _handlePaste,
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Type or paste content here...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ),

            const Spacer(),

            // Instructions
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How to test:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('1. Copy an image or text to your clipboard'),
                    Text('2. Tap on the text field above'),
                    Text('3. Use the paste action (long press → Paste)'),
                    Text('4. Watch the status update above!'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
