import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_paste_input/flutter_paste_input.dart';
import 'package:flutter_paste_input/flutter_paste_input_platform_interface.dart';
import 'package:flutter_paste_input/flutter_paste_input_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterPasteInputPlatform
    with MockPlatformInterfaceMixin
    implements FlutterPasteInputPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterPasteInputPlatform initialPlatform = FlutterPasteInputPlatform.instance;

  test('$MethodChannelFlutterPasteInput is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterPasteInput>());
  });

  test('getPlatformVersion', () async {
    FlutterPasteInput flutterPasteInputPlugin = FlutterPasteInput();
    MockFlutterPasteInputPlatform fakePlatform = MockFlutterPasteInputPlatform();
    FlutterPasteInputPlatform.instance = fakePlatform;

    expect(await flutterPasteInputPlugin.getPlatformVersion(), '42');
  });
}
