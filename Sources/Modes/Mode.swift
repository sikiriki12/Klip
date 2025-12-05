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
    
    /// Process the transcribed text through this mode
    /// - Parameters:
    ///   - text: The raw transcription from Scribe
    ///   - context: Optional context (e.g., clipboard content)
    /// - Returns: The processed text
    func process(_ text: String, context: String?) async throws -> String
}

/// Built-in modes available in Klip
enum ModeType: String, CaseIterable {
    case raw = "raw"
    case translate = "translate"
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
