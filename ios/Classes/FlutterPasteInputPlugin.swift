import Flutter
import UIKit
import MobileCoreServices

/// Flutter plugin for intercepting paste events in text fields.
public class FlutterPasteInputPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    private var eventSink: FlutterEventSink?
    private static var swizzled = false
    private static weak var sharedInstance: FlutterPasteInputPlugin?

    public static func register(with registrar: FlutterPluginRegistrar) {
        // Method channel for calling native methods
        let methodChannel = FlutterMethodChannel(
            name: "dev.gausoft/flutter_paste_input/methods",
            binaryMessenger: registrar.messenger()
        )

        // Event channel for sending paste events to Flutter
        let eventChannel = FlutterEventChannel(
            name: "dev.gausoft/flutter_paste_input/events",
            binaryMessenger: registrar.messenger()
        )

        let instance = FlutterPasteInputPlugin()
        sharedInstance = instance

        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)

        // Perform swizzling once
        if !swizzled {
            swizzlePasteMethods()
            swizzled = true
        }
    }

    // MARK: - FlutterStreamHandler

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    // MARK: - Method Channel Handler

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        case "clearTempFiles":
            clearTempFiles()
            result(nil)
        case "registerView":
            // View registration is handled automatically via swizzling
            result(nil)
        case "unregisterView":
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Paste Event Handling

    /// Called when a paste event is detected
    static func handlePasteEvent() {
        guard let instance = sharedInstance else { return }
        instance.processPasteboard()
    }

    private func processPasteboard() {
        let pasteboard = UIPasteboard.general

        // Check for images first
        if pasteboard.hasImages {
            processImages(from: pasteboard)
            return
        }

        // Check for text
        if pasteboard.hasStrings, let text = pasteboard.string {
            sendTextEvent(text)
            return
        }

        // Unsupported content
        sendUnsupportedEvent()
    }

    private func processImages(from pasteboard: UIPasteboard) {
        var uris: [String] = []
        var mimeTypes: [String] = []

        // Get all items from pasteboard
        let itemCount = pasteboard.numberOfItems

        for i in 0..<itemCount {
            let indexSet = IndexSet(integer: i)

            // Check for GIF first (need raw data to preserve animation)
            if let gifData = getGifData(from: pasteboard, at: indexSet) {
                if let uri = saveTempFile(data: gifData, extension: "gif") {
                    uris.append(uri)
                    mimeTypes.append("image/gif")
                }
                continue
            }

            // Check for PNG using legacy API
            let pngType = kUTTypePNG as String
            if let dataArray = pasteboard.data(forPasteboardType: pngType, inItemSet: indexSet),
               let pngData = dataArray.first {
                if let uri = saveTempFile(data: pngData, extension: "png") {
                    uris.append(uri)
                    mimeTypes.append("image/png")
                }
                continue
            }

            // Check for JPEG using legacy API
            let jpegType = kUTTypeJPEG as String
            if let dataArray = pasteboard.data(forPasteboardType: jpegType, inItemSet: indexSet),
               let jpegData = dataArray.first {
                if let uri = saveTempFile(data: jpegData, extension: "jpg") {
                    uris.append(uri)
                    mimeTypes.append("image/jpeg")
                }
                continue
            }

            // Fallback: try to get image and convert to PNG
            if let images = pasteboard.images, i < images.count {
                let image = images[i]
                if let pngData = image.pngData() {
                    if let uri = saveTempFile(data: pngData, extension: "png") {
                        uris.append(uri)
                        mimeTypes.append("image/png")
                    }
                }
            }
        }

        if !uris.isEmpty {
            sendImageEvent(uris: uris, mimeTypes: mimeTypes)
        } else {
            sendUnsupportedEvent()
        }
    }

    private func getGifData(from pasteboard: UIPasteboard, at indexSet: IndexSet) -> Data? {
        // Check multiple GIF type identifiers using legacy API
        let gifTypes = [
            kUTTypeGIF as String,
            "com.compuserve.gif",
            "public.gif"
        ]

        for gifType in gifTypes {
            if let dataArray = pasteboard.data(forPasteboardType: gifType, inItemSet: indexSet),
               let data = dataArray.first {
                // Verify GIF signature
                if isValidGif(data: data) {
                    return data
                }
            }
        }

        return nil
    }

    private func isValidGif(data: Data) -> Bool {
        guard data.count >= 6 else { return false }
        let header = data.prefix(6)
        let gif87a: [UInt8] = [0x47, 0x49, 0x46, 0x38, 0x37, 0x61] // GIF87a
        let gif89a: [UInt8] = [0x47, 0x49, 0x46, 0x38, 0x39, 0x61] // GIF89a
        return header.elementsEqual(gif87a) || header.elementsEqual(gif89a)
    }

    private func saveTempFile(data: Data, extension ext: String) -> String? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "paste_\(Int(Date().timeIntervalSince1970 * 1000))_\(UUID().uuidString.prefix(8)).\(ext)"
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL)
            return fileURL.path
        } catch {
            print("FlutterPasteInput: Failed to save temp file: \(error)")
            return nil
        }
    }

    // MARK: - Event Sending

    private func sendTextEvent(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?([
                "type": "text",
                "value": text
            ])
        }
    }

    private func sendImageEvent(uris: [String], mimeTypes: [String]) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?([
                "type": "images",
                "uris": uris,
                "mimeTypes": mimeTypes
            ])
        }
    }

    private func sendUnsupportedEvent() {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?([
                "type": "unsupported"
            ])
        }
    }

    // MARK: - Cleanup

    private func clearTempFiles() {
        let tempDir = FileManager.default.temporaryDirectory
        do {
            let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            for file in files where file.lastPathComponent.hasPrefix("paste_") {
                try? FileManager.default.removeItem(at: file)
            }
        } catch {
            print("FlutterPasteInput: Failed to clear temp files: \(error)")
        }
    }

    // MARK: - Method Swizzling

    private static func swizzlePasteMethods() {
        // Swizzle UITextField
        swizzlePaste(for: UITextField.self)

        // Swizzle UITextView
        swizzlePaste(for: UITextView.self)
    }

    private static func swizzlePaste(for targetClass: AnyClass) {
        let originalSelector = #selector(UIResponder.paste(_:))
        let swizzledSelector = #selector(UIResponder.flutterPasteInput_paste(_:))

        guard let originalMethod = class_getInstanceMethod(targetClass, originalSelector),
              let swizzledMethod = class_getInstanceMethod(UIResponder.self, swizzledSelector) else {
            return
        }

        // Add the swizzled method to the target class
        let didAddMethod = class_addMethod(
            targetClass,
            swizzledSelector,
            method_getImplementation(swizzledMethod),
            method_getTypeEncoding(swizzledMethod)
        )

        if didAddMethod {
            // Get the newly added method and swap implementations
            if let newMethod = class_getInstanceMethod(targetClass, swizzledSelector) {
                method_exchangeImplementations(originalMethod, newMethod)
            }
        } else {
            // Method already exists, just swap
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
}

// MARK: - UIResponder Extension for Swizzling

extension UIResponder {
    @objc func flutterPasteInput_paste(_ sender: Any?) {
        // Notify Flutter about the paste event
        FlutterPasteInputPlugin.handlePasteEvent()

        // Call the original implementation (which is now swapped)
        self.flutterPasteInput_paste(sender)
    }
}
