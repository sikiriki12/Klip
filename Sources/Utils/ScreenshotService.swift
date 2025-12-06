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
    
    /// Last captured screenshot (as JPEG data for API)
    private(set) var lastCapture: Data?
    
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
    /// Returns JPEG data or nil if capture failed
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
        // Get window list
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            print("❌ Failed to get window list")
            return nil
        }
        
        // Get frontmost app
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            print("❌ No frontmost application")
            return nil
        }
        
        // Find the topmost window belonging to the frontmost app
        // Skip our own app and system UI elements
        let klipBundleId = Bundle.main.bundleIdentifier ?? "com.klip"
        
        for window in windowList {
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t,
                  let windowLayer = window[kCGWindowLayer as String] as? Int,
                  let windowID = window[kCGWindowNumber as String] as? CGWindowID,
                  let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                  windowLayer == 0  // Normal window layer
            else { continue }
            
            // Skip our own window
            if let bundleId = window[kCGWindowOwnerName as String] as? String,
               bundleId.contains("Klip") {
                continue
            }
            
            // Check if this window belongs to frontmost app
            if ownerPID == frontApp.processIdentifier {
                let rect = CGRect(
                    x: bounds["X"] ?? 0,
                    y: bounds["Y"] ?? 0,
                    width: bounds["Width"] ?? 0,
                    height: bounds["Height"] ?? 0
                )
                
                // Capture this window
                if let image = CGWindowListCreateImage(rect, .optionIncludingWindow, windowID, [.bestResolution, .boundsIgnoreFraming]) {
                    lastCapture = imageToJPEG(image)
                    print("📸 Captured active window: \(frontApp.localizedName ?? "Unknown") (\(Int(rect.width))x\(Int(rect.height)))")
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
        
        // Find screen containing cursor
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main else {
            print("❌ No screen found")
            return nil
        }
        
        // Convert to CG coordinates (flipped Y)
        let cgRect = CGRect(
            x: screen.frame.origin.x,
            y: screen.frame.origin.y,
            width: screen.frame.width,
            height: screen.frame.height
        )
        
        if let image = CGWindowListCreateImage(cgRect, .optionOnScreenOnly, kCGNullWindowID, .bestResolution) {
            lastCapture = imageToJPEG(image)
            print("📸 Captured screen (\(Int(screen.frame.width))x\(Int(screen.frame.height)))")
            return lastCapture
        }
        
        print("❌ Screen capture failed")
        return nil
    }
    
    /// Convert CGImage to JPEG data (compressed for API)
    private func imageToJPEG(_ cgImage: CGImage) -> Data? {
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        
        // Resize if too large (max 1024px on longest side for API efficiency)
        let maxSize: CGFloat = 1024
        var targetSize = nsImage.size
        
        if targetSize.width > maxSize || targetSize.height > maxSize {
            let scale = maxSize / max(targetSize.width, targetSize.height)
            targetSize = NSSize(width: targetSize.width * scale, height: targetSize.height * scale)
        }
        
        // Create resized image
        let resizedImage = NSImage(size: targetSize)
        resizedImage.lockFocus()
        nsImage.draw(in: NSRect(origin: .zero, size: targetSize),
                     from: NSRect(origin: .zero, size: nsImage.size),
                     operation: .copy,
                     fraction: 1.0)
        resizedImage.unlockFocus()
        
        // Convert to JPEG
        guard let tiffData = resizedImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else {
            return nil
        }
        
        print("📸 Image compressed to \(jpegData.count / 1024)KB")
        return jpegData
    }
    
    /// Clear the last capture
    func clearCapture() {
        lastCapture = nil
    }
}
