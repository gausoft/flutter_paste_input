package dev.gausoft.flutter_paste_input

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.ContentResolver
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream

/**
 * Flutter plugin for intercepting paste events and extracting clipboard content.
 *
 * This plugin provides access to rich clipboard content including text and images,
 * and sends paste events to Flutter via EventChannel.
 */
class FlutterPasteInputPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var context: Context
    private var eventSink: EventChannel.EventSink? = null
    private var clipboardManager: ClipboardManager? = null
    private var clipboardListener: ClipboardManager.OnPrimaryClipChangedListener? = null

    companion object {
        private const val TAG = "FlutterPasteInput"
        private const val METHOD_CHANNEL = "dev.gausoft/flutter_paste_input/methods"
        private const val EVENT_CHANNEL = "dev.gausoft/flutter_paste_input/events"
        private const val TEMP_FILE_PREFIX = "paste_"
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext

        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, METHOD_CHANNEL)
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(this)

        clipboardManager = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${Build.VERSION.RELEASE}")
            }
            "clearTempFiles" -> {
                clearTempFiles()
                result.success(null)
            }
            "registerView" -> {
                // Start listening for clipboard changes when a view is registered
                startClipboardMonitoring()
                result.success(null)
            }
            "unregisterView" -> {
                result.success(null)
            }
            "checkClipboard" -> {
                // Manual clipboard check triggered from Flutter
                processClipboard()
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    // MARK: - EventChannel.StreamHandler

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    // MARK: - Clipboard Monitoring

    private fun startClipboardMonitoring() {
        if (clipboardListener != null) return

        clipboardListener = ClipboardManager.OnPrimaryClipChangedListener {
            // Note: We don't automatically process on clipboard change
            // because it would fire for any clipboard change in the system.
            // Instead, we wait for Flutter to trigger via checkClipboard method
            // when the user actually performs a paste action.
        }

        clipboardManager?.addPrimaryClipChangedListener(clipboardListener!!)
    }

    private fun stopClipboardMonitoring() {
        clipboardListener?.let {
            clipboardManager?.removePrimaryClipChangedListener(it)
        }
        clipboardListener = null
    }

    /**
     * Process the current clipboard content and send an event to Flutter.
     */
    private fun processClipboard() {
        val clipData = clipboardManager?.primaryClip ?: run {
            sendUnsupportedEvent()
            return
        }

        if (clipData.itemCount == 0) {
            sendUnsupportedEvent()
            return
        }

        // Check for images first
        if (hasImages(clipData)) {
            processImages(clipData)
            return
        }

        // Check for text
        val text = getTextFromClipboard(clipData)
        if (text != null) {
            sendTextEvent(text)
            return
        }

        sendUnsupportedEvent()
    }

    private fun hasImages(clipData: ClipData): Boolean {
        val description = clipData.description
        if (description.hasMimeType(ClipDescription.MIMETYPE_TEXT_URILIST)) {
            // Check if the URI points to an image
            for (i in 0 until clipData.itemCount) {
                val uri = clipData.getItemAt(i).uri
                if (uri != null && isImageUri(uri)) {
                    return true
                }
            }
        }

        // Check for image MIME types
        for (i in 0 until description.mimeTypeCount) {
            val mimeType = description.getMimeType(i)
            if (mimeType.startsWith("image/")) {
                return true
            }
        }

        return false
    }

    private fun isImageUri(uri: Uri): Boolean {
        val mimeType = context.contentResolver.getType(uri) ?: return false
        return mimeType.startsWith("image/")
    }

    private fun processImages(clipData: ClipData) {
        val uris = mutableListOf<String>()
        val mimeTypes = mutableListOf<String>()

        for (i in 0 until clipData.itemCount) {
            val item = clipData.getItemAt(i)
            val uri = item.uri

            if (uri != null) {
                val mimeType = context.contentResolver.getType(uri)
                if (mimeType != null && mimeType.startsWith("image/")) {
                    val savedPath = saveImageFromUri(uri, mimeType)
                    if (savedPath != null) {
                        uris.add(savedPath)
                        mimeTypes.add(mimeType)
                    }
                }
            }
        }

        if (uris.isNotEmpty()) {
            sendImageEvent(uris, mimeTypes)
        } else {
            sendUnsupportedEvent()
        }
    }

    private fun saveImageFromUri(uri: Uri, mimeType: String): String? {
        return try {
            val inputStream: InputStream? = context.contentResolver.openInputStream(uri)
            inputStream?.use { stream ->
                val extension = when (mimeType) {
                    "image/png" -> "png"
                    "image/jpeg" -> "jpg"
                    "image/gif" -> "gif"
                    "image/webp" -> "webp"
                    else -> "png"
                }

                val timestamp = System.currentTimeMillis()
                val randomSuffix = (Math.random() * 100000).toInt()
                val fileName = "${TEMP_FILE_PREFIX}${timestamp}_${randomSuffix}.$extension"
                val file = File(context.cacheDir, fileName)

                if (mimeType == "image/gif") {
                    // For GIFs, copy the raw data to preserve animation
                    FileOutputStream(file).use { output ->
                        stream.copyTo(output)
                    }
                } else {
                    // For other images, decode and re-encode
                    val bitmap = BitmapFactory.decodeStream(stream)
                    if (bitmap != null) {
                        FileOutputStream(file).use { output ->
                            val format = when (mimeType) {
                                "image/jpeg" -> Bitmap.CompressFormat.JPEG
                                "image/webp" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                                    Bitmap.CompressFormat.WEBP_LOSSLESS
                                } else {
                                    @Suppress("DEPRECATION")
                                    Bitmap.CompressFormat.WEBP
                                }
                                else -> Bitmap.CompressFormat.PNG
                            }
                            bitmap.compress(format, 100, output)
                        }
                        bitmap.recycle()
                    } else {
                        // If bitmap decoding fails, copy raw data
                        context.contentResolver.openInputStream(uri)?.use { retryStream ->
                            FileOutputStream(file).use { output ->
                                retryStream.copyTo(output)
                            }
                        }
                    }
                }

                file.absolutePath
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save image from URI: ${e.message}")
            null
        }
    }

    private fun getTextFromClipboard(clipData: ClipData): String? {
        val item = clipData.getItemAt(0)

        // Try to get as text directly
        val text = item.text?.toString()
        if (text != null) {
            return text
        }

        // Try to coerce to text
        return try {
            item.coerceToText(context)?.toString()
        } catch (e: Exception) {
            null
        }
    }

    // MARK: - Event Sending

    private fun sendTextEvent(text: String) {
        val event = mapOf(
            "type" to "text",
            "value" to text
        )
        eventSink?.success(event)
    }

    private fun sendImageEvent(uris: List<String>, mimeTypes: List<String>) {
        val event = mapOf(
            "type" to "images",
            "uris" to uris,
            "mimeTypes" to mimeTypes
        )
        eventSink?.success(event)
    }

    private fun sendUnsupportedEvent() {
        val event = mapOf("type" to "unsupported")
        eventSink?.success(event)
    }

    // MARK: - Cleanup

    private fun clearTempFiles() {
        try {
            val cacheDir = context.cacheDir
            cacheDir.listFiles()?.filter {
                it.name.startsWith(TEMP_FILE_PREFIX)
            }?.forEach { file ->
                file.delete()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to clear temp files: ${e.message}")
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopClipboardMonitoring()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }
}
