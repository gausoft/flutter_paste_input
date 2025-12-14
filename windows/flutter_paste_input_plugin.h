#ifndef FLUTTER_PLUGIN_FLUTTER_PASTE_INPUT_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_PASTE_INPUT_PLUGIN_H_

#include <flutter/plugin_registrar_windows.h>

#include <memory>
#include <string>
#include <vector>

#include "messages.g.h"

namespace flutter_paste_input {

class FlutterPasteInputPlugin : public flutter::Plugin, public PasteInputHostApi {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FlutterPasteInputPlugin(flutter::BinaryMessenger* messenger);

  virtual ~FlutterPasteInputPlugin();

  // Disallow copy and assign.
  FlutterPasteInputPlugin(const FlutterPasteInputPlugin&) = delete;
  FlutterPasteInputPlugin& operator=(const FlutterPasteInputPlugin&) = delete;

  // PasteInputHostApi implementation
  ErrorOr<ClipboardContent> GetClipboardContent() override;
  std::optional<FlutterError> ClearTempFiles() override;
  ErrorOr<std::string> GetPlatformVersion() override;

  // Notify Flutter about a paste event
  void NotifyPasteDetected();

 private:
  // Extract image data from clipboard
  std::vector<uint8_t> GetBitmapData();

  // Extract text from clipboard
  std::string GetTextData();

  // Get temporary directory path
  std::wstring GetTempPath();

  std::unique_ptr<PasteInputFlutterApi> flutter_api_;
};

}  // namespace flutter_paste_input

#endif  // FLUTTER_PLUGIN_FLUTTER_PASTE_INPUT_PLUGIN_H_
