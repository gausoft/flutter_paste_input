import Cocoa
import FlutterMacOS

/// Flutter plugin for intercepting paste events in text fields on macOS.
public class FlutterPasteInputPlugin: NSObject, FlutterPlugin, PasteInputHostApi {

    private static var swizzled = false
    private static weak var sharedInstance: FlutterPasteInputPlugin?
    private var flutterApi: PasteInputFlutterApi?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = FlutterPasteInputPlugin()
        sharedInstance = instance

        // Set up Pigeon APIs
        PasteInputHostApiSetup.setUp(binaryMessenger: registrar.messenger, api: instance)
        instance.flutterApi = PasteInputFlutterApi(binaryMessenger: registrar.messenger)

        // Perform swizzling once
        if !swizzled {
            swizzlePasteMethods()
            swizzled = true
        }
    }

    // MARK: - PasteInputHostApi Implementation

    func getClipboardContent() throws -> ClipboardContent {
        let pasteboard = NSPasteboard.general
        var items: [ClipboardItem] = []

        // Process images first
        if hasImages(pasteboard: pasteboard) {
            let imageItems = extractImageItems(from: pasteboard)
            items.append(contentsOf: imageItems)
        }

        // Process text
        if let text = pasteboard.string(forType: .string) {
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
        return "macOS " + ProcessInfo.processInfo.operatingSystemVersionString
    }

    // MARK: - Image Detection and Extraction

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

    private func extractImageItems(from pasteboard: NSPasteboard) -> [ClipboardItem] {
        var items: [ClipboardItem] = []

        // Check for GIF first
        let gifType = NSPasteboard.PasteboardType("com.compuserve.gif")
        if let gifData = pasteboard.data(forType: gifType), isValidGif(data: gifData) {
            items.append(ClipboardItem(
                data: FlutterStandardTypedData(bytes: gifData),
                mimeType: "image/gif"
            ))
        }

        // Check for PNG
        if let pngData = pasteboard.data(forType: .png) {
            items.append(ClipboardItem(
                data: FlutterStandardTypedData(bytes: pngData),
                mimeType: "image/png"
            ))
        } else if let tiffData = pasteboard.data(forType: .tiff) {
            // Convert TIFF to PNG
            if let imageRep = NSBitmapImageRep(data: tiffData),
               let pngData = imageRep.representation(using: .png, properties: [:]) {
                items.append(ClipboardItem(
                    data: FlutterStandardTypedData(bytes: pngData),
                    mimeType: "image/png"
                ))
            }
        }

        // Check for JPEG
        let jpegType = NSPasteboard.PasteboardType("public.jpeg")
        if let jpegData = pasteboard.data(forType: jpegType) {
            items.append(ClipboardItem(
                data: FlutterStandardTypedData(bytes: jpegData),
                mimeType: "image/jpeg"
            ))
        }

        return items
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
        // Swizzle NSTextView
        swizzlePaste(for: NSTextView.self)

        // Swizzle NSTextField
        swizzlePaste(for: NSTextField.self)
    }

    private static func swizzlePaste(for targetClass: AnyClass) {
        let originalSelector = NSSelectorFromString("paste:")
        let swizzledSelector = #selector(NSTextView.flutterPasteInput_paste(_:))

        guard let originalMethod = class_getInstanceMethod(targetClass, originalSelector),
              let swizzledMethod = class_getInstanceMethod(NSTextView.self, swizzledSelector) else {
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

// MARK: - NSTextView Extension for Swizzling

extension NSTextView {
    @objc func flutterPasteInput_paste(_ sender: Any?) {
        // Notify Flutter about the paste event
        FlutterPasteInputPlugin.handlePasteEvent()

        // Call the original implementation (which is now swapped)
        self.flutterPasteInput_paste(sender)
    }
}
