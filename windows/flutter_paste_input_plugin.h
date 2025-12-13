#ifndef FLUTTER_PLUGIN_FLUTTER_PASTE_INPUT_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_PASTE_INPUT_PLUGIN_H_

#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>
#include <string>
#include <vector>

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

  // Set the event sink for sending paste events
  void SetEventSink(std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink);

  // Clear the event sink
  void ClearEventSink();

 private:
  // Process clipboard content and send event
  void ProcessClipboard();

  // Send text event to Flutter
  void SendTextEvent(const std::string& text);

  // Send image event to Flutter
  void SendImageEvent(const std::vector<std::string>& uris,
                      const std::vector<std::string>& mime_types);

  // Send unsupported event to Flutter
  void SendUnsupportedEvent();

  // Save bitmap to temporary file
  std::string SaveBitmapToFile(HBITMAP hBitmap);

  // Clear temporary files
  void ClearTempFiles();

  // Get temporary directory path
  std::wstring GetTempPath();

  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
};

}  // namespace flutter_paste_input

#endif  // FLUTTER_PLUGIN_FLUTTER_PASTE_INPUT_PLUGIN_H_
