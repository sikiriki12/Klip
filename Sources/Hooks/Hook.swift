import Foundation

/// Context passed to hooks for decision making
struct HookContext {
    let modeId: String
    let frontmostAppBundleId: String?
    let browserURL: String?
    
    // Email-specific context
    let emailSubject: String?        // Subject line (nil for replies)
    let emailBody: String            // Email body text
    let composeBodyFocused: Bool     // Gemini detected compose body is focused
}

/// Protocol defining what a Hook can do
protocol Hook {
    /// Unique identifier for this hook
    var id: String { get }
    
    /// Display name for settings UI
    var name: String { get }
    
    /// Whether this hook is currently enabled
    var isEnabled: Bool { get set }
    
    /// Check if hook should run given current context
    func canExecute(context: HookContext) -> Bool
    
    /// Execute the hook action
    /// - Parameters:
    ///   - text: The processed text (also in clipboard)
    ///   - context: Current context (mode, app, URL)
    func execute(text: String, context: HookContext) async throws
}
