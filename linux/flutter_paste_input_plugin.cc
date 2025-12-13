#include "include/flutter_paste_input/flutter_paste_input_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <gdk-pixbuf/gdk-pixbuf.h>
#include <sys/utsname.h>

#include <cstring>
#include <cstdlib>
#include <ctime>
#include <vector>
#include <string>

#include "flutter_paste_input_plugin_private.h"

#define FLUTTER_PASTE_INPUT_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), flutter_paste_input_plugin_get_type(), \
                              FlutterPasteInputPlugin))

#define METHOD_CHANNEL_NAME "dev.gausoft/flutter_paste_input/methods"
#define EVENT_CHANNEL_NAME "dev.gausoft/flutter_paste_input/events"
#define TEMP_FILE_PREFIX "paste_"

struct _FlutterPasteInputPlugin {
  GObject parent_instance;
  FlMethodChannel* method_channel;
  FlEventChannel* event_channel;
  FlEventSink* event_sink;
};

G_DEFINE_TYPE(FlutterPasteInputPlugin, flutter_paste_input_plugin, g_object_get_type())

// Forward declarations
static void process_clipboard(FlutterPasteInputPlugin* self);
static void send_text_event(FlutterPasteInputPlugin* self, const gchar* text);
static void send_image_event(FlutterPasteInputPlugin* self,
                              const std::vector<std::string>& uris,
                              const std::vector<std::string>& mime_types);
static void send_unsupported_event(FlutterPasteInputPlugin* self);
static gchar* save_temp_file(GdkPixbuf* pixbuf, const gchar* format, const gchar* extension);
static void clear_temp_files();

// Get platform version
FlMethodResponse* get_platform_version() {
  struct utsname uname_data = {};
  uname(&uname_data);
  g_autofree gchar *version = g_strdup_printf("Linux %s", uname_data.version);
  g_autoptr(FlValue) result = fl_value_new_string(version);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

// Handle method calls from Flutter
static void flutter_paste_input_plugin_handle_method_call(
    FlutterPasteInputPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "getPlatformVersion") == 0) {
    response = get_platform_version();
  } else if (strcmp(method, "clearTempFiles") == 0) {
    clear_temp_files();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "registerView") == 0) {
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "unregisterView") == 0) {
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (strcmp(method, "checkClipboard") == 0) {
    process_clipboard(self);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

// Process clipboard content
static void process_clipboard(FlutterPasteInputPlugin* self) {
  GtkClipboard* clipboard = gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);

  // Check for image first
  if (gtk_clipboard_wait_is_image_available(clipboard)) {
    GdkPixbuf* pixbuf = gtk_clipboard_wait_for_image(clipboard);
    if (pixbuf != nullptr) {
      std::vector<std::string> uris;
      std::vector<std::string> mime_types;

      // Save as PNG
      gchar* path = save_temp_file(pixbuf, "png", "png");
      if (path != nullptr) {
        uris.push_back(path);
        mime_types.push_back("image/png");
        g_free(path);
      }

      g_object_unref(pixbuf);

      if (!uris.empty()) {
        send_image_event(self, uris, mime_types);
        return;
      }
    }
  }

  // Check for text
  if (gtk_clipboard_wait_is_text_available(clipboard)) {
    gchar* text = gtk_clipboard_wait_for_text(clipboard);
    if (text != nullptr) {
      send_text_event(self, text);
      g_free(text);
      return;
    }
  }

  // Check for URIs (might be image files)
  if (gtk_clipboard_wait_is_uris_available(clipboard)) {
    gchar** uris = gtk_clipboard_wait_for_uris(clipboard);
    if (uris != nullptr) {
      std::vector<std::string> image_uris;
      std::vector<std::string> mime_types;

      for (gchar** uri = uris; *uri != nullptr; uri++) {
        // Check if it's an image file
        gchar* filename = g_filename_from_uri(*uri, nullptr, nullptr);
        if (filename != nullptr) {
          GdkPixbuf* pixbuf = gdk_pixbuf_new_from_file(filename, nullptr);
          if (pixbuf != nullptr) {
            gchar* path = save_temp_file(pixbuf, "png", "png");
            if (path != nullptr) {
              image_uris.push_back(path);
              mime_types.push_back("image/png");
              g_free(path);
            }
            g_object_unref(pixbuf);
          }
          g_free(filename);
        }
      }

      g_strfreev(uris);

      if (!image_uris.empty()) {
        send_image_event(self, image_uris, mime_types);
        return;
      }
    }
  }

  send_unsupported_event(self);
}

// Save pixbuf to temporary file
static gchar* save_temp_file(GdkPixbuf* pixbuf, const gchar* format, const gchar* extension) {
  const gchar* temp_dir = g_get_tmp_dir();
  guint64 timestamp = g_get_real_time() / 1000;
  gint random = g_random_int_range(0, 99999);

  g_autofree gchar* filename = g_strdup_printf("%s/%s%lu_%d.%s",
                                                temp_dir,
                                                TEMP_FILE_PREFIX,
                                                timestamp,
                                                random,
                                                extension);

  GError* error = nullptr;
  if (gdk_pixbuf_save(pixbuf, filename, format, &error, nullptr)) {
    return g_strdup(filename);
  }

  if (error != nullptr) {
    g_warning("FlutterPasteInput: Failed to save temp file: %s", error->message);
    g_error_free(error);
  }

  return nullptr;
}

// Send text event to Flutter
static void send_text_event(FlutterPasteInputPlugin* self, const gchar* text) {
  if (self->event_sink == nullptr) return;

  g_autoptr(FlValue) event = fl_value_new_map();
  fl_value_set_string_take(event, "type", fl_value_new_string("text"));
  fl_value_set_string_take(event, "value", fl_value_new_string(text));

  fl_event_sink_success(self->event_sink, event, nullptr);
}

// Send image event to Flutter
static void send_image_event(FlutterPasteInputPlugin* self,
                              const std::vector<std::string>& uris,
                              const std::vector<std::string>& mime_types) {
  if (self->event_sink == nullptr) return;

  g_autoptr(FlValue) uris_list = fl_value_new_list();
  for (const auto& uri : uris) {
    fl_value_append_take(uris_list, fl_value_new_string(uri.c_str()));
  }

  g_autoptr(FlValue) types_list = fl_value_new_list();
  for (const auto& type : mime_types) {
    fl_value_append_take(types_list, fl_value_new_string(type.c_str()));
  }

  g_autoptr(FlValue) event = fl_value_new_map();
  fl_value_set_string_take(event, "type", fl_value_new_string("images"));
  fl_value_set_string(event, "uris", uris_list);
  fl_value_set_string(event, "mimeTypes", types_list);

  fl_event_sink_success(self->event_sink, event, nullptr);
}

// Send unsupported event to Flutter
static void send_unsupported_event(FlutterPasteInputPlugin* self) {
  if (self->event_sink == nullptr) return;

  g_autoptr(FlValue) event = fl_value_new_map();
  fl_value_set_string_take(event, "type", fl_value_new_string("unsupported"));

  fl_event_sink_success(self->event_sink, event, nullptr);
}

// Clear temporary files
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

// Event channel listen callback
static FlMethodErrorResponse* on_listen(FlEventChannel* channel,
                                         FlValue* args,
                                         gpointer user_data) {
  FlutterPasteInputPlugin* self = FLUTTER_PASTE_INPUT_PLUGIN(user_data);
  self->event_sink = fl_event_channel_get_event_sink(channel);
  return nullptr;
}

// Event channel cancel callback
static FlMethodErrorResponse* on_cancel(FlEventChannel* channel,
                                         FlValue* args,
                                         gpointer user_data) {
  FlutterPasteInputPlugin* self = FLUTTER_PASTE_INPUT_PLUGIN(user_data);
  self->event_sink = nullptr;
  return nullptr;
}

static void flutter_paste_input_plugin_dispose(GObject* object) {
  FlutterPasteInputPlugin* self = FLUTTER_PASTE_INPUT_PLUGIN(object);

  g_clear_object(&self->method_channel);
  g_clear_object(&self->event_channel);

  G_OBJECT_CLASS(flutter_paste_input_plugin_parent_class)->dispose(object);
}

static void flutter_paste_input_plugin_class_init(FlutterPasteInputPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = flutter_paste_input_plugin_dispose;
}

static void flutter_paste_input_plugin_init(FlutterPasteInputPlugin* self) {
  self->event_sink = nullptr;
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  FlutterPasteInputPlugin* plugin = FLUTTER_PASTE_INPUT_PLUGIN(user_data);
  flutter_paste_input_plugin_handle_method_call(plugin, method_call);
}

void flutter_paste_input_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  FlutterPasteInputPlugin* plugin = FLUTTER_PASTE_INPUT_PLUGIN(
      g_object_new(flutter_paste_input_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();

  // Method channel
  plugin->method_channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar),
      METHOD_CHANNEL_NAME,
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(plugin->method_channel,
                                            method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  // Event channel
  plugin->event_channel = fl_event_channel_new(
      fl_plugin_registrar_get_messenger(registrar),
      EVENT_CHANNEL_NAME,
      FL_METHOD_CODEC(codec));
  fl_event_channel_set_stream_handlers(plugin->event_channel,
                                        on_listen,
                                        on_cancel,
                                        g_object_ref(plugin),
                                        g_object_unref);

  g_object_unref(plugin);
}
