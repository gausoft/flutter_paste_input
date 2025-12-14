package dev.gausoft.flutter_paste_input

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import java.io.ByteArrayOutputStream
import java.io.File

/**
 * Flutter plugin for intercepting paste events and extracting clipboard content.
 *
 * This plugin provides access to rich clipboard content including text and images,
 * using Pigeon for type-safe communication with Flutter.
 */
class FlutterPasteInputPlugin : FlutterPlugin, PasteInputHostApi {

    private lateinit var context: Context
    private var clipboardManager: ClipboardManager? = null
    private var flutterApi: PasteInputFlutterApi? = null

    companion object {
        private const val TAG = "FlutterPasteInput"
        private const val TEMP_FILE_PREFIX = "paste_"
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        clipboardManager = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager

        // Set up Pigeon APIs
        PasteInputHostApi.setUp(flutterPluginBinding.binaryMessenger, this)
        flutterApi = PasteInputFlutterApi(flutterPluginBinding.binaryMessenger)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        PasteInputHostApi.setUp(binding.binaryMessenger, null)
        flutterApi = null
    }

    // MARK: - PasteInputHostApi Implementation

    override fun getClipboardContent(): ClipboardContent {
        val items = mutableListOf<ClipboardItem>()
        val clipData = clipboardManager?.primaryClip

        if (clipData == null || clipData.itemCount == 0) {
            return ClipboardContent(items = items)
        }

        // Process images first
        if (hasImages(clipData)) {
            val imageItems = extractImageItems(clipData)
            items.addAll(imageItems)
        }

        // Then process text
        val text = getTextFromClipboard(clipData)
        if (text != null) {
            val textBytes = text.toByteArray(Charsets.UTF_8)
            items.add(ClipboardItem(data = textBytes, mimeType = "text/plain"))
        }

        return ClipboardContent(items = items)
    }

    override fun clearTempFiles() {
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

    override fun getPlatformVersion(): String {
        return "Android ${Build.VERSION.RELEASE}"
    }

    // MARK: - Helper Methods

    private fun hasImages(clipData: ClipData): Boolean {
        val description = clipData.description
        if (description.hasMimeType(ClipDescription.MIMETYPE_TEXT_URILIST)) {
            for (i in 0 until clipData.itemCount) {
                val uri = clipData.getItemAt(i).uri
                if (uri != null && isImageUri(uri)) {
                    return true
                }
            }
        }

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

    private fun extractImageItems(clipData: ClipData): List<ClipboardItem> {
        val items = mutableListOf<ClipboardItem>()

        for (i in 0 until clipData.itemCount) {
            val item = clipData.getItemAt(i)
            val uri = item.uri

            if (uri != null) {
                val mimeType = context.contentResolver.getType(uri)
                if (mimeType != null && mimeType.startsWith("image/")) {
                    val imageData = getImageBytes(uri, mimeType)
                    if (imageData != null) {
                        items.add(ClipboardItem(data = imageData, mimeType = mimeType))
                    }
                }
            }
        }

        return items
    }

    private fun getImageBytes(uri: Uri, mimeType: String): ByteArray? {
        return try {
            context.contentResolver.openInputStream(uri)?.use { stream ->
                if (mimeType == "image/gif") {
                    // For GIFs, read raw bytes to preserve animation
                    stream.readBytes()
                } else {
                    // For other images, decode and re-encode
                    val bitmap = BitmapFactory.decodeStream(stream)
                    if (bitmap != null) {
                        val outputStream = ByteArrayOutputStream()
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
                        bitmap.compress(format, 100, outputStream)
                        bitmap.recycle()
                        outputStream.toByteArray()
                    } else {
                        // Fallback: read raw bytes
                        context.contentResolver.openInputStream(uri)?.readBytes()
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read image bytes: ${e.message}")
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

    /**
     * Notifies Flutter about a paste event.
     * Call this from swizzled paste handlers or clipboard listeners.
     */
    fun notifyPasteDetected() {
        val content = getClipboardContent()
        flutterApi?.onPasteDetected(content) { result ->
            result.onFailure { error ->
                Log.e(TAG, "Failed to notify paste: ${error.message}")
            }
        }
    }
}
