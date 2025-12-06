import AppKit

/// Manages clipboard operations
class ClipboardManager {
    static let shared = ClipboardManager()
    
    private init() {}
    
    /// Copy text to the system clipboard
    func copyToClipboard(_ text: String) {
        // Mark that we're about to copy (so ClipboardMonitor ignores it)
        ClipboardMonitor.shared.markAppCopy()
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        print("📋 Copied to clipboard: \(text.prefix(50))...")
    }
    
    /// Get the current clipboard text
    func getClipboardText() -> String? {
        return NSPasteboard.general.string(forType: .string)
    }
}
