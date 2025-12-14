import 'package:flutter_paste_input/flutter_paste_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PastePayload', () {
    test('TextPaste fromMap creates correct instance', () {
      final map = {'type': 'text', 'value': 'Hello World'};
      final payload = PastePayload.fromMap(map);

      expect(payload, isA<TextPaste>());
      expect((payload as TextPaste).text, equals('Hello World'));
    });

    test('ImagePaste fromMap creates correct instance', () {
      final map = {
        'type': 'images',
        'uris': ['/path/to/image1.png', '/path/to/image2.jpg'],
        'mimeTypes': ['image/png', 'image/jpeg'],
      };
      final payload = PastePayload.fromMap(map);

      expect(payload, isA<ImagePaste>());
      final imagePaste = payload as ImagePaste;
      expect(imagePaste.uris.length, equals(2));
      expect(imagePaste.mimeTypes, contains('image/png'));
      expect(imagePaste.count, equals(2));
    });

    test('ImagePaste hasGif returns true for GIF', () {
      final imagePaste = ImagePaste(
        uris: ['/path/to/anim.gif'],
        mimeTypes: ['image/gif'],
      );

      expect(imagePaste.hasGif, isTrue);
    });

    test('ImagePaste hasGif returns false for non-GIF', () {
      final imagePaste = ImagePaste(
        uris: ['/path/to/image.png'],
        mimeTypes: ['image/png'],
      );

      expect(imagePaste.hasGif, isFalse);
    });

    test('UnsupportedPaste fromMap for unknown type', () {
      final map = {'type': 'unknown'};
      final payload = PastePayload.fromMap(map);

      expect(payload, isA<UnsupportedPaste>());
    });

    test('TextPaste equality', () {
      const paste1 = TextPaste(text: 'Hello');
      const paste2 = TextPaste(text: 'Hello');
      const paste3 = TextPaste(text: 'World');

      expect(paste1, equals(paste2));
      expect(paste1, isNot(equals(paste3)));
    });

    test('ImagePaste equality', () {
      const paste1 = ImagePaste(
        uris: ['/path/1.png'],
        mimeTypes: ['image/png'],
      );
      const paste2 = ImagePaste(
        uris: ['/path/1.png'],
        mimeTypes: ['image/png'],
      );
      const paste3 = ImagePaste(
        uris: ['/path/2.png'],
        mimeTypes: ['image/png'],
      );

      expect(paste1, equals(paste2));
      expect(paste1, isNot(equals(paste3)));
    });
  });

  group('PasteType', () {
    test('PasteType values exist', () {
      expect(PasteType.values, contains(PasteType.text));
      expect(PasteType.values, contains(PasteType.image));
    });
  });
}
