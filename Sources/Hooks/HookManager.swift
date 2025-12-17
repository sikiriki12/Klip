import Foundation
import AppKit

/// Manages all hooks and executes them after text processing
class HookManager: ObservableObject {
    static let shared = HookManager()
    
    /// All registered hooks
    private var hooks: [any Hook] = []
    
    private init() {
        // Register all available hooks
        registerHook(GmailHook())
    }
    
    /// Register a new hook
    func registerHook(_ hook: any Hook) {
        hooks.append(hook)
    }
    
    /// Execute all applicable hooks for the given text and mode
    /// - Parameters:
    ///   - text: The processed text (body for emails, full text for others)
    ///   - modeId: The current mode ID
    ///   - emailSubject: Optional subject line for email mode (nil = reply)
    ///   - composeBodyFocused: Whether Gemini detected compose body is focused
    func executeHooks(text: String, modeId: String, emailSubject: String? = nil, composeBodyFocused: Bool = false) async {
        // Build context
        let context = HookContext(
            modeId: modeId,
            frontmostAppBundleId: BrowserDetector.shared.getFrontmostAppBundleId(),
            browserURL: BrowserDetector.shared.getBrowserURL(),
            emailSubject: emailSubject,
            emailBody: text,
            composeBodyFocused: composeBodyFocused
        )
        
        // Execute each applicable hook
        for hook in hooks {
            guard hook.canExecute(context: context) else { continue }
            
            print("🔗 Executing hook: \(hook.name)")
            do {
                try await hook.execute(text: text, context: context)
                print("✅ Hook \(hook.name) completed")
            } catch {
                print("❌ Hook \(hook.name) failed: \(error)")
            }
        }
    }
    
    /// Get a hook by ID for settings UI
    func getHook(id: String) -> (any Hook)? {
        hooks.first { $0.id == id }
    }
}
