#include "include/flutter_paste_input/flutter_paste_input_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_paste_input_plugin.h"

void FlutterPasteInputPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_paste_input::FlutterPasteInputPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
