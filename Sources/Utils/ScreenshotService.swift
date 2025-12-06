import Foundation
import AppKit
import CoreGraphics

/// Captures screenshots of active window or screen
class ScreenshotService: ObservableObject {
    static let shared = ScreenshotService()
    
    /// Whether screenshot context is enabled
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "screenshotContextEnabled")
        }
    }
    
    /// Capture mode
    enum CaptureMode: String, CaseIterable {
        case activeWindow = "Active Window"
        case screenWithCursor = "Screen with Cursor"
    }
    
    @Published var captureMode: CaptureMode {
        didSet {
            UserDefaults.standard.set(captureMode.rawValue, forKey: "screenshotCaptureMode")
        }
    }
    
    /// Last captured screenshot
    private(set) var lastCapture: Data?
    
    /// Last capture dimensions for logging
    private(set) var lastCaptureWidth: Int = 0
    private(set) var lastCaptureHeight: Int = 0
    
    /// Debug mode - when ON, does separate OCR call to log what model reads
    @Published var debugMode: Bool = false  // OFF by default
    
    /// Whether we have a recent capture
    var hasCapture: Bool { lastCapture != nil }
    
    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: "screenshotContextEnabled")
        
        if let modeStr = UserDefaults.standard.string(forKey: "screenshotCaptureMode"),
           let mode = CaptureMode(rawValue: modeStr) {
            captureMode = mode
        } else {
            captureMode = .activeWindow
        }
    }
    
    /// Capture screenshot based on current mode
    func capture() -> Data? {
        switch captureMode {
        case .activeWindow:
            return captureActiveWindow()
        case .screenWithCursor:
            return captureScreenWithCursor()
        }
    }
    
    /// Capture the frontmost window
    private func captureActiveWindow() -> Data? {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            print("❌ Failed to get window list")
            return nil
        }
        
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            print("❌ No frontmost application")
            return nil
        }
        
        for window in windowList {
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t,
                  let windowLayer = window[kCGWindowLayer as String] as? Int,
                  let windowID = window[kCGWindowNumber as String] as? CGWindowID,
                  let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                  windowLayer == 0
            else { continue }
            
            if let bundleId = window[kCGWindowOwnerName as String] as? String,
               bundleId.contains("Klip") {
                continue
            }
            
            if ownerPID == frontApp.processIdentifier {
                let rect = CGRect(
                    x: bounds["X"] ?? 0,
                    y: bounds["Y"] ?? 0,
                    width: bounds["Width"] ?? 0,
                    height: bounds["Height"] ?? 0
                )
                
                if let image = CGWindowListCreateImage(rect, .optionIncludingWindow, windowID, [.bestResolution, .boundsIgnoreFraming]) {
                    let originalWidth = image.width
                    let originalHeight = image.height
                    
                    lastCapture = imageToJPEG(image)
                    print("📸 Captured: \(frontApp.localizedName ?? "Unknown") | Original: \(originalWidth)x\(originalHeight) → Final: \(lastCaptureWidth)x\(lastCaptureHeight) | \(lastCapture?.count ?? 0 / 1024)KB")
                    return lastCapture
                }
            }
        }
        
        print("⚠️ No capturable window found, falling back to screen")
        return captureScreenWithCursor()
    }
    
    /// Capture the screen containing the cursor
    private func captureScreenWithCursor() -> Data? {
        let mouseLocation = NSEvent.mouseLocation
        
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main else {
            print("❌ No screen found")
            return nil
        }
        
        let cgRect = CGRect(
            x: screen.frame.origin.x,
            y: screen.frame.origin.y,
            width: screen.frame.width,
            height: screen.frame.height
        )
        
        if let image = CGWindowListCreateImage(cgRect, .optionOnScreenOnly, kCGNullWindowID, .bestResolution) {
            let originalWidth = image.width
            let originalHeight = image.height
            
            lastCapture = imageToJPEG(image)
            print("📸 Captured screen | Original: \(originalWidth)x\(originalHeight) → Final: \(lastCaptureWidth)x\(lastCaptureHeight) | \(lastCapture?.count ?? 0 / 1024)KB")
            return lastCapture
        }
        
        print("❌ Screen capture failed")
        return nil
    }
    
    /// Convert CGImage to JPEG data (1024px max, 70% quality)
    private func imageToJPEG(_ cgImage: CGImage) -> Data? {
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        
        let maxSize: CGFloat = 1024
        var targetSize = nsImage.size
        
        if targetSize.width > maxSize || targetSize.height > maxSize {
            let scale = maxSize / max(targetSize.width, targetSize.height)
            targetSize = NSSize(width: targetSize.width * scale, height: targetSize.height * scale)
        }
        
        lastCaptureWidth = Int(targetSize.width)
        lastCaptureHeight = Int(targetSize.height)
        
        let resizedImage = NSImage(size: targetSize)
        resizedImage.lockFocus()
        nsImage.draw(in: NSRect(origin: .zero, size: targetSize),
                     from: NSRect(origin: .zero, size: nsImage.size),
                     operation: .copy,
                     fraction: 1.0)
        resizedImage.unlockFocus()
        
        guard let tiffData = resizedImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else {
            return nil
        }
        
        return jpegData
    }
    
    func clearCapture() {
        lastCapture = nil
    }
}
