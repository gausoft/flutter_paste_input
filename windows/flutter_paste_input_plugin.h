#ifndef FLUTTER_PLUGIN_FLUTTER_PASTE_INPUT_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_PASTE_INPUT_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace flutter_paste_input {

class FlutterPasteInputPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FlutterPasteInputPlugin();

  virtual ~FlutterPasteInputPlugin();

  // Disallow copy and assign.
  FlutterPasteInputPlugin(const FlutterPasteInputPlugin&) = delete;
  FlutterPasteInputPlugin& operator=(const FlutterPasteInputPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace flutter_paste_input

#endif  // FLUTTER_PLUGIN_FLUTTER_PASTE_INPUT_PLUGIN_H_
