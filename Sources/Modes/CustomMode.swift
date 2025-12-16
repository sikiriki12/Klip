import Foundation

/// User-defined custom mode
struct CustomMode: TranscriptionMode, Codable, Identifiable {
    let id: String
    var name: String
    var description: String
    var shortcutNumber: Int
    var systemPrompt: String
    var defaultToneId: String
    var usesClipboardContext: Bool
    var usesScreenshotContext: Bool
    
    /// Create a new custom mode
    init(name: String, description: String, systemPrompt: String, usesClipboardContext: Bool = false, usesScreenshotContext: Bool = false) {
        self.id = "custom_" + name.lowercased().replacingOccurrences(of: " ", with: "_")
        self.name = name
        self.description = description
        self.shortcutNumber = 0  // Custom modes don't have default shortcuts
        self.systemPrompt = systemPrompt
        self.defaultToneId = "normal"
        self.usesClipboardContext = usesClipboardContext
        self.usesScreenshotContext = usesScreenshotContext
    }
    
    /// Example: Commit mode
    static let commitMode = CustomMode(
        name: "Commit",
        description: "Git commit message",
        systemPrompt: """
        Convert the user's description into a proper git commit message.
        
        Rules:
        - Start with a type: feat, fix, docs, style, refactor, test, chore
        - First line: type: short description (max 50 chars)
        - Leave blank line if adding body
        - Body: explain what and why (not how)
        - Use imperative mood ("Add feature" not "Added feature")
        
        Output format:
        git add . && git commit -m "type: description"
        
        For complex commits with body:
        git add . && git commit -m "type: description" -m "body text"
        """,
        usesClipboardContext: false,
        usesScreenshotContext: false
    )
}
