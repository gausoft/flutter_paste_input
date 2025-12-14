#include "flutter_paste_input_plugin.h"

#include <windows.h>
#include <gdiplus.h>
#include <shlobj.h>
#include <VersionHelpers.h>

#include <codecvt>
#include <locale>
#include <sstream>

#pragma comment(lib, "gdiplus.lib")

namespace flutter_paste_input {

namespace {

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

// static
void FlutterPasteInputPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {

  // Initialize GDI+
  Gdiplus::GdiplusStartupInput gdiplusStartupInput;
  Gdiplus::GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, nullptr);

  auto plugin = std::make_unique<FlutterPasteInputPlugin>(registrar->messenger());

  // Set up Pigeon API
  PasteInputHostApi::SetUp(registrar->messenger(), plugin.get());

  registrar->AddPlugin(std::move(plugin));
}

FlutterPasteInputPlugin::FlutterPasteInputPlugin(flutter::BinaryMessenger* messenger) {
  flutter_api_ = std::make_unique<PasteInputFlutterApi>(messenger);
}

FlutterPasteInputPlugin::~FlutterPasteInputPlugin() {
  if (gdiplusToken != 0) {
    Gdiplus::GdiplusShutdown(gdiplusToken);
    gdiplusToken = 0;
  }
}

ErrorOr<ClipboardContent> FlutterPasteInputPlugin::GetClipboardContent() {
  flutter::EncodableList items;

  if (!OpenClipboard(nullptr)) {
    return ClipboardContent(items);
  }

  // Check for bitmap first
  if (IsClipboardFormatAvailable(CF_BITMAP) || IsClipboardFormatAvailable(CF_DIB)) {
    std::vector<uint8_t> imageData = GetBitmapData();
    if (!imageData.empty()) {
      ClipboardItem item(imageData, "image/png");
      items.push_back(flutter::CustomEncodableValue(item));
    }
  }

  // Check for text
  std::string text = GetTextData();
  if (!text.empty()) {
    std::vector<uint8_t> textBytes(text.begin(), text.end());
    ClipboardItem item(textBytes, "text/plain");
    items.push_back(flutter::CustomEncodableValue(item));
  }

  CloseClipboard();
  return ClipboardContent(items);
}

std::optional<FlutterError> FlutterPasteInputPlugin::ClearTempFiles() {
  std::wstring temp_path = GetTempPath();
  if (temp_path.empty()) return std::nullopt;

  std::wstring search_path = temp_path + L"paste_*";

  WIN32_FIND_DATAW find_data;
  HANDLE hFind = FindFirstFileW(search_path.c_str(), &find_data);

  if (hFind != INVALID_HANDLE_VALUE) {
    do {
      std::wstring file_path = temp_path + find_data.cFileName;
      DeleteFileW(file_path.c_str());
    } while (FindNextFileW(hFind, &find_data));
    FindClose(hFind);
  }

  return std::nullopt;
}

ErrorOr<std::string> FlutterPasteInputPlugin::GetPlatformVersion() {
  std::ostringstream version_stream;
  version_stream << "Windows ";
  if (IsWindows10OrGreater()) {
    version_stream << "10+";
  } else if (IsWindows8OrGreater()) {
    version_stream << "8";
  } else if (IsWindows7OrGreater()) {
    version_stream << "7";
  }
  return version_stream.str();
}

void FlutterPasteInputPlugin::NotifyPasteDetected() {
  auto result = GetClipboardContent();
  if (!result.has_error()) {
    flutter_api_->OnPasteDetected(
      result.value(),
      []() {},
      [](const FlutterError& error) {}
    );
  }
}

std::vector<uint8_t> FlutterPasteInputPlugin::GetBitmapData() {
  std::vector<uint8_t> result;

  HBITMAP hBitmap = (HBITMAP)GetClipboardData(CF_BITMAP);
  if (hBitmap == nullptr) return result;

  // Use GDI+ to convert to PNG
  Gdiplus::Bitmap* bitmap = Gdiplus::Bitmap::FromHBITMAP(hBitmap, nullptr);
  if (bitmap == nullptr) return result;

  CLSID pngClsid;
  if (GetEncoderClsid(L"image/png", &pngClsid) < 0) {
    delete bitmap;
    return result;
  }

  // Create a stream to save PNG data
  IStream* stream = nullptr;
  if (CreateStreamOnHGlobal(nullptr, TRUE, &stream) != S_OK) {
    delete bitmap;
    return result;
  }

  if (bitmap->Save(stream, &pngClsid, nullptr) == Gdiplus::Ok) {
    // Get stream size
    STATSTG stats;
    stream->Stat(&stats, STATFLAG_NONAME);
    ULONG size = static_cast<ULONG>(stats.cbSize.QuadPart);

    // Read data from stream
    result.resize(size);
    LARGE_INTEGER li = {0};
    stream->Seek(li, STREAM_SEEK_SET, nullptr);
    ULONG bytesRead;
    stream->Read(result.data(), size, &bytesRead);
  }

  stream->Release();
  delete bitmap;

  return result;
}

std::string FlutterPasteInputPlugin::GetTextData() {
  std::string result;

  if (IsClipboardFormatAvailable(CF_UNICODETEXT)) {
    HANDLE hData = GetClipboardData(CF_UNICODETEXT);
    if (hData != nullptr) {
      wchar_t* pszText = static_cast<wchar_t*>(GlobalLock(hData));
      if (pszText != nullptr) {
        result = WideToUtf8(pszText);
        GlobalUnlock(hData);
      }
    }
  } else if (IsClipboardFormatAvailable(CF_TEXT)) {
    HANDLE hData = GetClipboardData(CF_TEXT);
    if (hData != nullptr) {
      char* pszText = static_cast<char*>(GlobalLock(hData));
      if (pszText != nullptr) {
        result = std::string(pszText);
        GlobalUnlock(hData);
      }
    }
  }

  return result;
}

std::wstring FlutterPasteInputPlugin::GetTempPath() {
  wchar_t temp_path[MAX_PATH];
  DWORD result = ::GetTempPathW(MAX_PATH, temp_path);
  if (result == 0 || result > MAX_PATH) return L"";
  return std::wstring(temp_path);
}

}  // namespace flutter_paste_input
