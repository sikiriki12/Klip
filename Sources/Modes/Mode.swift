import Foundation

/// Protocol defining a text processing mode
protocol TranscriptionMode {
    /// Unique identifier for this mode
    var id: String { get }
    
    /// Display name shown in UI
    var name: String { get }
    
    /// Short description of what this mode does
    var description: String { get }
    
    /// Keyboard shortcut number (1-9)
    var shortcutNumber: Int { get }
    
    /// System prompt for Gemini (used when this mode is active)
    var systemPrompt: String { get }
    
    /// Whether this mode uses clipboard context (when available)
    var usesClipboardContext: Bool { get }
    
    /// Whether this mode uses screenshot context (when available)
    var usesScreenshotContext: Bool { get }
}

// Default implementation - most modes don't use context
extension TranscriptionMode {
    var usesClipboardContext: Bool { false }
    var usesScreenshotContext: Bool { false }
}
