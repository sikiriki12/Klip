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
}

/// Built-in modes available in Klip
enum ModeType: String, CaseIterable {
    case raw = "raw"
    case fix = "fix"
    case bullet = "bullet"
    case email = "email"
    case summarize = "summarize"
    case tweet = "tweet"
    case commit = "commit"
    case reply = "reply"
    case task = "task"
    case code = "code"
    case formal = "formal"
}
