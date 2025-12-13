import Cocoa
import FlutterMacOS

/// Flutter plugin for intercepting paste events in text fields on macOS.
public class FlutterPasteInputPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    private var eventSink: FlutterEventSink?
    private static var swizzled = false
    private static weak var sharedInstance: FlutterPasteInputPlugin?

    public static func register(with registrar: FlutterPluginRegistrar) {
        // Method channel for calling native methods
        let methodChannel = FlutterMethodChannel(
            name: "dev.gausoft/flutter_paste_input/methods",
            binaryMessenger: registrar.messenger
        )

        // Event channel for sending paste events to Flutter
        let eventChannel = FlutterEventChannel(
            name: "dev.gausoft/flutter_paste_input/events",
            binaryMessenger: registrar.messenger
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
            result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
        case "clearTempFiles":
            clearTempFiles()
            result(nil)
        case "registerView":
            result(nil)
        case "unregisterView":
            result(nil)
        case "checkClipboard":
            processPasteboard()
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
        let pasteboard = NSPasteboard.general

        // Check for images first
        if hasImages(pasteboard: pasteboard) {
            processImages(from: pasteboard)
            return
        }

        // Check for text
        if let text = pasteboard.string(forType: .string) {
            sendTextEvent(text)
            return
        }

        // Unsupported content
        sendUnsupportedEvent()
    }

    private func hasImages(pasteboard: NSPasteboard) -> Bool {
        let imageTypes: [NSPasteboard.PasteboardType] = [
            .png,
            .tiff,
            NSPasteboard.PasteboardType("public.jpeg"),
            NSPasteboard.PasteboardType("com.compuserve.gif")
        ]

        for type in imageTypes {
            if pasteboard.data(forType: type) != nil {
                return true
            }
        }

        return false
    }

    private func processImages(from pasteboard: NSPasteboard) {
        var uris: [String] = []
        var mimeTypes: [String] = []

        // Check for GIF first
        let gifType = NSPasteboard.PasteboardType("com.compuserve.gif")
        if let gifData = pasteboard.data(forType: gifType), isValidGif(data: gifData) {
            if let uri = saveTempFile(data: gifData, extension: "gif") {
                uris.append(uri)
                mimeTypes.append("image/gif")
            }
        }

        // Check for PNG
        if let pngData = pasteboard.data(forType: .png) {
            if let uri = saveTempFile(data: pngData, extension: "png") {
                uris.append(uri)
                mimeTypes.append("image/png")
            }
        } else if let tiffData = pasteboard.data(forType: .tiff) {
            // Convert TIFF to PNG
            if let imageRep = NSBitmapImageRep(data: tiffData),
               let pngData = imageRep.representation(using: .png, properties: [:]) {
                if let uri = saveTempFile(data: pngData, extension: "png") {
                    uris.append(uri)
                    mimeTypes.append("image/png")
                }
            }
        }

        // Check for JPEG
        let jpegType = NSPasteboard.PasteboardType("public.jpeg")
        if let jpegData = pasteboard.data(forType: jpegType) {
            if let uri = saveTempFile(data: jpegData, extension: "jpg") {
                uris.append(uri)
                mimeTypes.append("image/jpeg")
            }
        }

        if !uris.isEmpty {
            sendImageEvent(uris: uris, mimeTypes: mimeTypes)
        } else {
            sendUnsupportedEvent()
        }
    }

    private func isValidGif(data: Data) -> Bool {
        guard data.count >= 6 else { return false }
        let header = data.prefix(6)
        let gif87a: [UInt8] = [0x47, 0x49, 0x46, 0x38, 0x37, 0x61]
        let gif89a: [UInt8] = [0x47, 0x49, 0x46, 0x38, 0x39, 0x61]
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
        // Swizzle NSTextView - it has paste: as an instance method
        swizzlePaste(for: NSTextView.self)

        // Swizzle NSTextField
        swizzlePaste(for: NSTextField.self)
    }

    private static func swizzlePaste(for targetClass: AnyClass) {
        // Get selector for paste: using NSSelectorFromString to avoid compile-time checks
        let originalSelector = NSSelectorFromString("paste:")
        let swizzledSelector = #selector(NSTextView.flutterPasteInput_paste(_:))

        guard let originalMethod = class_getInstanceMethod(targetClass, originalSelector),
              let swizzledMethod = class_getInstanceMethod(NSTextView.self, swizzledSelector) else {
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
            if let newMethod = class_getInstanceMethod(targetClass, swizzledSelector) {
                method_exchangeImplementations(originalMethod, newMethod)
            }
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
}

// MARK: - NSTextView Extension for Swizzling

extension NSTextView {
    @objc func flutterPasteInput_paste(_ sender: Any?) {
        // Notify Flutter about the paste event
        FlutterPasteInputPlugin.handlePasteEvent()

        // Call the original implementation (which is now swapped)
        self.flutterPasteInput_paste(sender)
    }
}
