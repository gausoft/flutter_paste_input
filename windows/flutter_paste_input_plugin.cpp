#include "flutter_paste_input_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>
#include <gdiplus.h>
#include <shlobj.h>

#include <VersionHelpers.h>

#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <chrono>
#include <codecvt>
#include <locale>
#include <memory>
#include <random>
#include <sstream>

#pragma comment(lib, "gdiplus.lib")

namespace flutter_paste_input {

namespace {

const char kMethodChannelName[] = "dev.gausoft/flutter_paste_input/methods";
const char kEventChannelName[] = "dev.gausoft/flutter_paste_input/events";
const wchar_t kTempFilePrefix[] = L"paste_";

// GDI+ initialization token
ULONG_PTR gdiplusToken = 0;

// Convert wide string to UTF-8
std::string WideToUtf8(const std::wstring& wide) {
  if (wide.empty()) return std::string();
  int size = WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), -1, nullptr, 0, nullptr, nullptr);
  std::string result(size - 1, 0);
  WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), -1, &result[0], size, nullptr, nullptr);
  return result;
}

// Get CLSID for image encoder
int GetEncoderClsid(const WCHAR* format, CLSID* pClsid) {
  UINT num = 0;
  UINT size = 0;
  Gdiplus::GetImageEncodersSize(&num, &size);
  if (size == 0) return -1;

  Gdiplus::ImageCodecInfo* pImageCodecInfo = (Gdiplus::ImageCodecInfo*)(malloc(size));
  if (pImageCodecInfo == nullptr) return -1;

  Gdiplus::GetImageEncoders(num, size, pImageCodecInfo);

  for (UINT j = 0; j < num; ++j) {
    if (wcscmp(pImageCodecInfo[j].MimeType, format) == 0) {
      *pClsid = pImageCodecInfo[j].Clsid;
      free(pImageCodecInfo);
      return j;
    }
  }

  free(pImageCodecInfo);
  return -1;
}

}  // namespace

// Static plugin instance for event sink access
static FlutterPasteInputPlugin* g_plugin_instance = nullptr;

// static
void FlutterPasteInputPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {

  // Initialize GDI+
  Gdiplus::GdiplusStartupInput gdiplusStartupInput;
  Gdiplus::GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, nullptr);

  auto method_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), kMethodChannelName,
          &flutter::StandardMethodCodec::GetInstance());

  auto event_channel =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(), kEventChannelName,
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<FlutterPasteInputPlugin>();
  g_plugin_instance = plugin.get();

  method_channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  auto stream_handler = std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
      [plugin_pointer = plugin.get()](
          const flutter::EncodableValue* arguments,
          std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
          -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        plugin_pointer->SetEventSink(std::move(events));
        return nullptr;
      },
      [plugin_pointer = plugin.get()](const flutter::EncodableValue* arguments)
          -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        plugin_pointer->ClearEventSink();
        return nullptr;
      });

  event_channel->SetStreamHandler(std::move(stream_handler));

  registrar->AddPlugin(std::move(plugin));
}

FlutterPasteInputPlugin::FlutterPasteInputPlugin() {}

FlutterPasteInputPlugin::~FlutterPasteInputPlugin() {
  if (gdiplusToken != 0) {
    Gdiplus::GdiplusShutdown(gdiplusToken);
    gdiplusToken = 0;
  }
  g_plugin_instance = nullptr;
}

void FlutterPasteInputPlugin::SetEventSink(
    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink) {
  event_sink_ = std::move(sink);
}

void FlutterPasteInputPlugin::ClearEventSink() {
  event_sink_.reset();
}

void FlutterPasteInputPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  if (method_call.method_name() == "getPlatformVersion") {
    std::ostringstream version_stream;
    version_stream << "Windows ";
    if (IsWindows10OrGreater()) {
      version_stream << "10+";
    } else if (IsWindows8OrGreater()) {
      version_stream << "8";
    } else if (IsWindows7OrGreater()) {
      version_stream << "7";
    }
    result->Success(flutter::EncodableValue(version_stream.str()));
  } else if (method_call.method_name() == "clearTempFiles") {
    ClearTempFiles();
    result->Success();
  } else if (method_call.method_name() == "registerView") {
    result->Success();
  } else if (method_call.method_name() == "unregisterView") {
    result->Success();
  } else if (method_call.method_name() == "checkClipboard") {
    ProcessClipboard();
    result->Success();
  } else {
    result->NotImplemented();
  }
}

void FlutterPasteInputPlugin::ProcessClipboard() {
  if (!OpenClipboard(nullptr)) {
    SendUnsupportedEvent();
    return;
  }

  // Check for bitmap first
  if (IsClipboardFormatAvailable(CF_BITMAP) || IsClipboardFormatAvailable(CF_DIB)) {
    HBITMAP hBitmap = (HBITMAP)GetClipboardData(CF_BITMAP);
    if (hBitmap != nullptr) {
      std::string path = SaveBitmapToFile(hBitmap);
      if (!path.empty()) {
        std::vector<std::string> uris = {path};
        std::vector<std::string> mime_types = {"image/png"};
        CloseClipboard();
        SendImageEvent(uris, mime_types);
        return;
      }
    }
  }

  // Check for text
  if (IsClipboardFormatAvailable(CF_UNICODETEXT)) {
    HANDLE hData = GetClipboardData(CF_UNICODETEXT);
    if (hData != nullptr) {
      wchar_t* pszText = static_cast<wchar_t*>(GlobalLock(hData));
      if (pszText != nullptr) {
        std::string text = WideToUtf8(pszText);
        GlobalUnlock(hData);
        CloseClipboard();
        SendTextEvent(text);
        return;
      }
    }
  }

  // Check for ANSI text
  if (IsClipboardFormatAvailable(CF_TEXT)) {
    HANDLE hData = GetClipboardData(CF_TEXT);
    if (hData != nullptr) {
      char* pszText = static_cast<char*>(GlobalLock(hData));
      if (pszText != nullptr) {
        std::string text(pszText);
        GlobalUnlock(hData);
        CloseClipboard();
        SendTextEvent(text);
        return;
      }
    }
  }

  // Check for file drop (might contain images)
  if (IsClipboardFormatAvailable(CF_HDROP)) {
    HDROP hDrop = (HDROP)GetClipboardData(CF_HDROP);
    if (hDrop != nullptr) {
      UINT count = DragQueryFileW(hDrop, 0xFFFFFFFF, nullptr, 0);
      std::vector<std::string> uris;
      std::vector<std::string> mime_types;

      for (UINT i = 0; i < count; i++) {
        UINT size = DragQueryFileW(hDrop, i, nullptr, 0) + 1;
        std::wstring filename(size, L'\0');
        DragQueryFileW(hDrop, i, &filename[0], size);

        // Check if it's an image file
        std::wstring ext = filename.substr(filename.find_last_of(L'.'));
        for (auto& c : ext) c = towlower(c);

        std::string mime_type;
        if (ext == L".png") mime_type = "image/png";
        else if (ext == L".jpg" || ext == L".jpeg") mime_type = "image/jpeg";
        else if (ext == L".gif") mime_type = "image/gif";
        else if (ext == L".bmp") mime_type = "image/bmp";

        if (!mime_type.empty()) {
          uris.push_back(WideToUtf8(filename));
          mime_types.push_back(mime_type);
        }
      }

      if (!uris.empty()) {
        CloseClipboard();
        SendImageEvent(uris, mime_types);
        return;
      }
    }
  }

  CloseClipboard();
  SendUnsupportedEvent();
}

std::string FlutterPasteInputPlugin::SaveBitmapToFile(HBITMAP hBitmap) {
  if (hBitmap == nullptr) return "";

  std::wstring temp_path = GetTempPath();
  if (temp_path.empty()) return "";

  // Generate unique filename
  auto now = std::chrono::system_clock::now().time_since_epoch();
  auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(now).count();

  std::random_device rd;
  std::mt19937 gen(rd());
  std::uniform_int_distribution<> dis(0, 99999);

  std::wostringstream filename;
  filename << temp_path << L"\\" << kTempFilePrefix << ms << L"_" << dis(gen) << L".png";
  std::wstring filepath = filename.str();

  // Use GDI+ to save as PNG
  Gdiplus::Bitmap* bitmap = Gdiplus::Bitmap::FromHBITMAP(hBitmap, nullptr);
  if (bitmap == nullptr) return "";

  CLSID pngClsid;
  if (GetEncoderClsid(L"image/png", &pngClsid) < 0) {
    delete bitmap;
    return "";
  }

  Gdiplus::Status status = bitmap->Save(filepath.c_str(), &pngClsid, nullptr);
  delete bitmap;

  if (status != Gdiplus::Ok) return "";

  return WideToUtf8(filepath);
}

void FlutterPasteInputPlugin::SendTextEvent(const std::string& text) {
  if (!event_sink_) return;

  flutter::EncodableMap event;
  event[flutter::EncodableValue("type")] = flutter::EncodableValue("text");
  event[flutter::EncodableValue("value")] = flutter::EncodableValue(text);
  event_sink_->Success(flutter::EncodableValue(event));
}

void FlutterPasteInputPlugin::SendImageEvent(
    const std::vector<std::string>& uris,
    const std::vector<std::string>& mime_types) {
  if (!event_sink_) return;

  flutter::EncodableList uris_list;
  for (const auto& uri : uris) {
    uris_list.push_back(flutter::EncodableValue(uri));
  }

  flutter::EncodableList types_list;
  for (const auto& type : mime_types) {
    types_list.push_back(flutter::EncodableValue(type));
  }

  flutter::EncodableMap event;
  event[flutter::EncodableValue("type")] = flutter::EncodableValue("images");
  event[flutter::EncodableValue("uris")] = flutter::EncodableValue(uris_list);
  event[flutter::EncodableValue("mimeTypes")] = flutter::EncodableValue(types_list);
  event_sink_->Success(flutter::EncodableValue(event));
}

void FlutterPasteInputPlugin::SendUnsupportedEvent() {
  if (!event_sink_) return;

  flutter::EncodableMap event;
  event[flutter::EncodableValue("type")] = flutter::EncodableValue("unsupported");
  event_sink_->Success(flutter::EncodableValue(event));
}

std::wstring FlutterPasteInputPlugin::GetTempPath() {
  wchar_t temp_path[MAX_PATH];
  DWORD result = ::GetTempPathW(MAX_PATH, temp_path);
  if (result == 0 || result > MAX_PATH) return L"";
  return std::wstring(temp_path);
}

void FlutterPasteInputPlugin::ClearTempFiles() {
  std::wstring temp_path = GetTempPath();
  if (temp_path.empty()) return;

  std::wstring search_path = temp_path + kTempFilePrefix + L"*";

  WIN32_FIND_DATAW find_data;
  HANDLE hFind = FindFirstFileW(search_path.c_str(), &find_data);

  if (hFind != INVALID_HANDLE_VALUE) {
    do {
      std::wstring file_path = temp_path + find_data.cFileName;
      DeleteFileW(file_path.c_str());
    } while (FindNextFileW(hFind, &find_data));
    FindClose(hFind);
  }
}

}  // namespace flutter_paste_input
