#include "include/flutter_paste_input/flutter_paste_input_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <gdk-pixbuf/gdk-pixbuf.h>
#include <sys/utsname.h>

#include <cstring>
#include <cstdlib>
#include <vector>
#include <string>

#include "flutter_paste_input_plugin_private.h"
#include "messages.g.h"

#define FLUTTER_PASTE_INPUT_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), flutter_paste_input_plugin_get_type(), \
                              FlutterPasteInputPlugin))

#define TEMP_FILE_PREFIX "paste_"

struct _FlutterPasteInputPlugin {
  GObject parent_instance;
  FlutterPasteInputPasteInputFlutterApi* flutter_api;
};

G_DEFINE_TYPE(FlutterPasteInputPlugin, flutter_paste_input_plugin, g_object_get_type())

// Forward declarations
static std::vector<uint8_t> get_image_data(GtkClipboard* clipboard);
static std::string get_text_data(GtkClipboard* clipboard);
static void clear_temp_files();

// Global plugin instance for VTable callbacks
static FlutterPasteInputPlugin* g_plugin_instance = nullptr;

// Pigeon VTable Implementation

static FlutterPasteInputPasteInputHostApiGetClipboardContentResponse*
handle_get_clipboard_content(gpointer user_data) {
  GtkClipboard* clipboard = gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);
  g_autoptr(FlValue) items = fl_value_new_list();

  // Check for image first
  if (gtk_clipboard_wait_is_image_available(clipboard)) {
    std::vector<uint8_t> image_data = get_image_data(clipboard);
    if (!image_data.empty()) {
      FlutterPasteInputClipboardItem* item =
          flutter_paste_input_clipboard_item_new(
              image_data.data(),
              image_data.size(),
              "image/png");
      fl_value_append(items, fl_value_new_custom_object(G_OBJECT(item)));
      g_object_unref(item);
    }
  }

  // Check for text
  if (gtk_clipboard_wait_is_text_available(clipboard)) {
    std::string text = get_text_data(clipboard);
    if (!text.empty()) {
      FlutterPasteInputClipboardItem* item =
          flutter_paste_input_clipboard_item_new(
              reinterpret_cast<const uint8_t*>(text.data()),
              text.size(),
              "text/plain");
      fl_value_append(items, fl_value_new_custom_object(G_OBJECT(item)));
      g_object_unref(item);
    }
  }

  FlutterPasteInputClipboardContent* content =
      flutter_paste_input_clipboard_content_new(items);

  FlutterPasteInputPasteInputHostApiGetClipboardContentResponse* response =
      flutter_paste_input_paste_input_host_api_get_clipboard_content_response_new(content);

  g_object_unref(content);
  return response;
}

static FlutterPasteInputPasteInputHostApiClearTempFilesResponse*
handle_clear_temp_files(gpointer user_data) {
  clear_temp_files();
  return flutter_paste_input_paste_input_host_api_clear_temp_files_response_new();
}

static FlutterPasteInputPasteInputHostApiGetPlatformVersionResponse*
handle_get_platform_version(gpointer user_data) {
  struct utsname uname_data = {};
  uname(&uname_data);
  g_autofree gchar* version = g_strdup_printf("Linux %s", uname_data.release);
  return flutter_paste_input_paste_input_host_api_get_platform_version_response_new(version);
}

// VTable for Pigeon Host API
static FlutterPasteInputPasteInputHostApiVTable host_api_vtable = {
    .get_clipboard_content = handle_get_clipboard_content,
    .clear_temp_files = handle_clear_temp_files,
    .get_platform_version = handle_get_platform_version,
};

// Helper Functions

static std::vector<uint8_t> get_image_data(GtkClipboard* clipboard) {
  std::vector<uint8_t> result;

  GdkPixbuf* pixbuf = gtk_clipboard_wait_for_image(clipboard);
  if (pixbuf == nullptr) {
    return result;
  }

  gchar* buffer = nullptr;
  gsize buffer_size = 0;
  GError* error = nullptr;

  if (gdk_pixbuf_save_to_buffer(pixbuf, &buffer, &buffer_size, "png", &error, nullptr)) {
    result.assign(reinterpret_cast<uint8_t*>(buffer),
                  reinterpret_cast<uint8_t*>(buffer) + buffer_size);
    g_free(buffer);
  } else if (error != nullptr) {
    g_warning("FlutterPasteInput: Failed to save image: %s", error->message);
    g_error_free(error);
  }

  g_object_unref(pixbuf);
  return result;
}

static std::string get_text_data(GtkClipboard* clipboard) {
  gchar* text = gtk_clipboard_wait_for_text(clipboard);
  if (text == nullptr) {
    return std::string();
  }
  std::string result(text);
  g_free(text);
  return result;
}

static void clear_temp_files() {
  const gchar* temp_dir = g_get_tmp_dir();
  GDir* dir = g_dir_open(temp_dir, 0, nullptr);

  if (dir != nullptr) {
    const gchar* name;
    while ((name = g_dir_read_name(dir)) != nullptr) {
      if (g_str_has_prefix(name, TEMP_FILE_PREFIX)) {
        g_autofree gchar* path = g_build_filename(temp_dir, name, nullptr);
        g_unlink(path);
      }
    }
    g_dir_close(dir);
  }
}

// Notify Flutter about paste events
void flutter_paste_input_plugin_notify_paste(FlutterPasteInputPlugin* self) {
  if (self == nullptr || self->flutter_api == nullptr) {
    return;
  }

  GtkClipboard* clipboard = gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);
  g_autoptr(FlValue) items = fl_value_new_list();

  // Get image data
  if (gtk_clipboard_wait_is_image_available(clipboard)) {
    std::vector<uint8_t> image_data = get_image_data(clipboard);
    if (!image_data.empty()) {
      FlutterPasteInputClipboardItem* item =
          flutter_paste_input_clipboard_item_new(
              image_data.data(),
              image_data.size(),
              "image/png");
      fl_value_append(items, fl_value_new_custom_object(G_OBJECT(item)));
      g_object_unref(item);
    }
  }

  // Get text data
  if (gtk_clipboard_wait_is_text_available(clipboard)) {
    std::string text = get_text_data(clipboard);
    if (!text.empty()) {
      FlutterPasteInputClipboardItem* item =
          flutter_paste_input_clipboard_item_new(
              reinterpret_cast<const uint8_t*>(text.data()),
              text.size(),
              "text/plain");
      fl_value_append(items, fl_value_new_custom_object(G_OBJECT(item)));
      g_object_unref(item);
    }
  }

  FlutterPasteInputClipboardContent* content =
      flutter_paste_input_clipboard_content_new(items);

  flutter_paste_input_paste_input_flutter_api_on_paste_detected(
      self->flutter_api, content, nullptr, nullptr, nullptr);

  g_object_unref(content);
}

// Plugin lifecycle

static void flutter_paste_input_plugin_dispose(GObject* object) {
  FlutterPasteInputPlugin* self = FLUTTER_PASTE_INPUT_PLUGIN(object);

  g_clear_object(&self->flutter_api);

  if (g_plugin_instance == self) {
    g_plugin_instance = nullptr;
  }

  G_OBJECT_CLASS(flutter_paste_input_plugin_parent_class)->dispose(object);
}

static void flutter_paste_input_plugin_class_init(FlutterPasteInputPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = flutter_paste_input_plugin_dispose;
}

static void flutter_paste_input_plugin_init(FlutterPasteInputPlugin* self) {
  self->flutter_api = nullptr;
}

void flutter_paste_input_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  FlutterPasteInputPlugin* plugin = FLUTTER_PASTE_INPUT_PLUGIN(
      g_object_new(flutter_paste_input_plugin_get_type(), nullptr));

  g_plugin_instance = plugin;

  FlBinaryMessenger* messenger = fl_plugin_registrar_get_messenger(registrar);

  // Set up Pigeon Host API
  flutter_paste_input_paste_input_host_api_set_method_handlers(
      messenger,
      nullptr,  // no suffix
      &host_api_vtable,
      plugin,
      nullptr);  // no free func

  // Set up Pigeon Flutter API (for calling Dart)
  plugin->flutter_api = flutter_paste_input_paste_input_flutter_api_new(
      messenger,
      nullptr);  // no suffix

  g_object_unref(plugin);
}
