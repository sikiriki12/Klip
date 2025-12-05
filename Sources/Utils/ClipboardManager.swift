import AppKit

/// Manages clipboard operations
class ClipboardManager {
    static let shared = ClipboardManager()
    
    private init() {}
    
    /// Copy text to the system clipboard
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        print("📋 Copied to clipboard: \(text.prefix(50))...")
    }
    
    /// Get the current clipboard text
    func getClipboardText() -> String? {
        return NSPasteboard.general.string(forType: .string)
    }
    
    /// Get clipboard text if it was set recently (within timeWindow seconds)
    /// Note: macOS doesn't provide clipboard timestamps, so this is a placeholder
    /// for future implementation with clipboard monitoring
    func getRecentClipboardText(withinSeconds timeWindow: TimeInterval = 60) -> String? {
        // For now, just return current clipboard
        // TODO: Implement clipboard monitoring to track timestamps
        return getClipboardText()
    }
}
