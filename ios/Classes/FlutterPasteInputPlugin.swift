import Flutter
import UIKit
import MobileCoreServices
import UniformTypeIdentifiers

/// Flutter plugin for intercepting paste events in text fields.
public class FlutterPasteInputPlugin: NSObject, FlutterPlugin, PasteInputHostApi {

    private static var swizzled = false
    private static weak var sharedInstance: FlutterPasteInputPlugin?
    private var flutterApi: PasteInputFlutterApi?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = FlutterPasteInputPlugin()
        sharedInstance = instance

        // Set up Pigeon APIs
        PasteInputHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
        instance.flutterApi = PasteInputFlutterApi(binaryMessenger: registrar.messenger())

        // Perform swizzling once
        if !swizzled {
            swizzlePasteMethods()
            swizzled = true
        }
    }

    // MARK: - PasteInputHostApi Implementation

    func getClipboardContent() throws -> ClipboardContent {
        let pasteboard = UIPasteboard.general
        var items: [ClipboardItem] = []

        // Process images first
        if pasteboard.hasImages {
            let imageItems = extractImageItems(from: pasteboard)
            items.append(contentsOf: imageItems)
        }

        // Process text
        if pasteboard.hasStrings, let text = pasteboard.string {
            if let textData = text.data(using: .utf8) {
                items.append(ClipboardItem(
                    data: FlutterStandardTypedData(bytes: textData),
                    mimeType: "text/plain"
                ))
            }
        }

        return ClipboardContent(items: items)
    }

    func clearTempFiles() throws {
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

    func getPlatformVersion() throws -> String {
        return "iOS " + UIDevice.current.systemVersion
    }

    // MARK: - Image Extraction

    private func extractImageItems(from pasteboard: UIPasteboard) -> [ClipboardItem] {
        var items: [ClipboardItem] = []
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
                items.append(ClipboardItem(
                    data: FlutterStandardTypedData(bytes: data),
                    mimeType: mime
                ))
            }
        }

        return items
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

    private func isValidGif(data: Data) -> Bool {
        guard data.count >= 6 else { return false }
        let header = data.prefix(6)
        let gif87a: [UInt8] = [0x47, 0x49, 0x46, 0x38, 0x37, 0x61]
        let gif89a: [UInt8] = [0x47, 0x49, 0x46, 0x38, 0x39, 0x61]
        return header.elementsEqual(gif87a) || header.elementsEqual(gif89a)
    }

    // MARK: - Paste Event Handling

    static func handlePasteEvent() {
        guard let instance = sharedInstance else { return }
        instance.notifyPasteDetected()
    }

    private func notifyPasteDetected() {
        do {
            let content = try getClipboardContent()
            flutterApi?.onPasteDetected(content: content) { result in
                if case .failure(let error) = result {
                    print("FlutterPasteInput: Failed to notify paste: \(error)")
                }
            }
        } catch {
            print("FlutterPasteInput: Error getting clipboard content: \(error)")
        }
    }

    // MARK: - Method Swizzling

    private static func swizzlePasteMethods() {
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
            swizzlePaste(for: flutterClass)
            swizzleCanPerformAction(for: flutterClass)
            swizzlePasteConfiguration(for: flutterClass)
        }
    }

    private static func swizzlePaste(for targetClass: AnyClass) {
        let originalSelector = #selector(UIResponder.paste(_:))
        let swizzledSelector = #selector(UIResponder.flutterPasteInput_paste(_:))

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
        // Notify Flutter about the paste event
        FlutterPasteInputPlugin.handlePasteEvent()

        // Call the original implementation (which is now swapped)
        self.flutterPasteInput_paste(sender)
    }

    @objc func flutterPasteInput_canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(UIResponder.paste(_:)) {
            let hasText = UIPasteboard.general.hasStrings
            let hasImages = UIPasteboard.general.hasImages

            // Always enable paste if there's text or images
            if hasText || hasImages {
                return true
            }
        }
        return self.flutterPasteInput_canPerformAction(action, withSender: sender)
    }

    @objc var flutterPasteInput_pasteConfiguration: UIPasteConfiguration? {
        get {
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
