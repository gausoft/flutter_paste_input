import Flutter
import UIKit
import MobileCoreServices
import UniformTypeIdentifiers

/// Flutter plugin for intercepting paste events in text fields.
public class FlutterPasteInputPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    private var eventSink: FlutterEventSink?
    private static var swizzled = false
    private static weak var sharedInstance: FlutterPasteInputPlugin?

    public static func register(with registrar: FlutterPluginRegistrar) {
        print("FlutterPasteInput: Registering plugin")
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
        case "getClipboardImage":
            getClipboardImage(result: result)
        case "getClipboardContent":
            getClipboardContent(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Get clipboard content and return it to Flutter.
    /// Returns a dictionary with:
    /// - "hasText": Bool
    /// - "hasImages": Bool
    /// - "text": String? (if text is available)
    /// - "images": [[String: Any]]? (if images are available)
    private func getClipboardContent(result: @escaping FlutterResult) {
        let pasteboard = UIPasteboard.general
        
        var response: [String: Any] = [:]
        
        // Check for text
        let hasText = pasteboard.hasStrings
        response["hasText"] = hasText
        if hasText, let text = pasteboard.string {
            response["text"] = text
        }
        
        // Check for images
        let hasImages = pasteboard.hasImages
        response["hasImages"] = hasImages
        
        if hasImages {
            let images = getImagesData(from: pasteboard)
            if !images.isEmpty {
                response["images"] = images
            }
        }
        
        result(response)
    }
    
    /// Extract image data as byte arrays from pasteboard
    private func getImagesData(from pasteboard: UIPasteboard) -> [[String: Any]] {
        var images: [[String: Any]] = []
        let itemCount = pasteboard.numberOfItems
        
        for i in 0..<itemCount {
            let indexSet = IndexSet(integer: i)
            
            var imageData: Data?
            var mimeType: String?
            
            // Check for GIF first
            if let gifData = getGifData(from: pasteboard, at: indexSet) {
                imageData = gifData
                mimeType = "image/gif"
            }
            // Check for PNG
            else if let pngDataArray = pasteboard.data(forPasteboardType: kUTTypePNG as String, inItemSet: indexSet),
                    let pngData = pngDataArray.first {
                imageData = pngData
                mimeType = "image/png"
            }
            // Check for JPEG
            else if let jpegDataArray = pasteboard.data(forPasteboardType: kUTTypeJPEG as String, inItemSet: indexSet),
                    let jpegData = jpegDataArray.first {
                imageData = jpegData
                mimeType = "image/jpeg"
            }
            // Fallback: convert image to PNG
            else if let pasteboardImages = pasteboard.images, i < pasteboardImages.count {
                let image = pasteboardImages[i]
                imageData = image.pngData()
                mimeType = "image/png"
            }
            
            if let data = imageData, let mime = mimeType {
                images.append([
                    "data": FlutterStandardTypedData(bytes: data),
                    "mimeType": mime
                ])
            }
        }
        
        return images
    }

    private func getClipboardImage(result: @escaping FlutterResult) {
        let pasteboard = UIPasteboard.general
        
        if !pasteboard.hasImages {
            result(nil)
            return
        }
        
        let images = getImagesData(from: pasteboard)
        
        if !images.isEmpty {
            result(["images": images])
        } else {
            result(nil)
        }
    }

    private func getGifData(from pasteboard: UIPasteboard, at indexSet: IndexSet) -> Data? {
        let gifTypes = [
            kUTTypeGIF as String,
            "com.compuserve.gif",
            "public.gif"
        ]
        
        for gifType in gifTypes {
            if let dataArray = pasteboard.data(forPasteboardType: gifType, inItemSet: indexSet),
               let data = dataArray.first,
               isValidGif(data: data) {
                return data
            }
        }
        
        return nil
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
        print("FlutterPasteInput: Swizzling methods")
        // Swizzle UITextField
        swizzlePaste(for: UITextField.self)
        swizzleCanPerformAction(for: UITextField.self)
        swizzlePasteConfiguration(for: UITextField.self)

        // Swizzle UITextView
        swizzlePaste(for: UITextView.self)
        swizzleCanPerformAction(for: UITextView.self)
        swizzlePasteConfiguration(for: UITextView.self)

        // Swizzle FlutterTextInputView (used by Flutter for text input)
        if let flutterClass = NSClassFromString("FlutterTextInputView") {
            print("FlutterPasteInput: Found FlutterTextInputView, swizzling")
            swizzlePaste(for: flutterClass)
            swizzleCanPerformAction(for: flutterClass)
            swizzlePasteConfiguration(for: flutterClass)
        } else {
            print("FlutterPasteInput: FlutterTextInputView not found")
        }
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

    private static func swizzleCanPerformAction(for targetClass: AnyClass) {
        let originalSelector = #selector(UIResponder.canPerformAction(_:withSender:))
        let swizzledSelector = #selector(UIResponder.flutterPasteInput_canPerformAction(_:withSender:))

        guard let originalMethod = class_getInstanceMethod(targetClass, originalSelector),
              let swizzledMethod = class_getInstanceMethod(UIResponder.self, swizzledSelector) else {
            return
        }

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

    private static func swizzlePasteConfiguration(for targetClass: AnyClass) {
        let originalSelector = #selector(getter: UIResponder.pasteConfiguration)
        let swizzledSelector = #selector(getter: UIResponder.flutterPasteInput_pasteConfiguration)

        guard let originalMethod = class_getInstanceMethod(targetClass, originalSelector),
              let swizzledMethod = class_getInstanceMethod(UIResponder.self, swizzledSelector) else {
            return
        }

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

// MARK: - UIResponder Extension for Swizzling

extension UIResponder {
    @objc func flutterPasteInput_paste(_ sender: Any?) {
        print("FlutterPasteInput: paste called on \(type(of: self))")
        // Notify Flutter about the paste event
        FlutterPasteInputPlugin.handlePasteEvent()

        // Call the original implementation (which is now swapped)
        self.flutterPasteInput_paste(sender)
    }

    @objc func flutterPasteInput_canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(UIResponder.paste(_:)) {
            let hasText = UIPasteboard.general.hasStrings
            let hasImages = UIPasteboard.general.hasImages
            
            print("FlutterPasteInput: canPerformAction paste - hasText: \(hasText), hasImages: \(hasImages)")
            
            // Always enable paste if there's text or images
            if hasText || hasImages {
                print("FlutterPasteInput: Enabling paste")
                return true
            }
        }
        return self.flutterPasteInput_canPerformAction(action, withSender: sender)
    }

    @objc var flutterPasteInput_pasteConfiguration: UIPasteConfiguration? {
        get {
            print("FlutterPasteInput: pasteConfiguration getter called on \(type(of: self))")
            // Create a paste configuration that accepts images
            if #available(iOS 11.0, *) {
                let config = UIPasteConfiguration(acceptableTypeIdentifiers: [
                    kUTTypeImage as String,
                    kUTTypePNG as String,
                    kUTTypeJPEG as String,
                    kUTTypeGIF as String,
                    kUTTypeText as String,
                    kUTTypePlainText as String
                ])
                return config
            }
            return self.flutterPasteInput_pasteConfiguration
        }
        set {
            // Do nothing for setter
        }
    }
}
