import Foundation

/// Paste Hook - Automatically pastes clipboard content after processing
/// Works on all modes except when Gmail hook handles the request
class PasteHook: Hook {
    let id = "paste"
    let name = "Auto-Paste"
    
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "pasteHookEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "pasteHookEnabled") }
    }
    
    func canExecute(context: HookContext) -> Bool {
        // Must be enabled
        guard isEnabled else {
            print("🔗 Paste hook: disabled")
            return false
        }
        
        // Skip if Gmail hook will handle this
        if let gmailHook = HookManager.shared.getHook(id: "gmail-reply") {
            if gmailHook.isEnabled && gmailHook.canExecute(context: context) {
                print("🔗 Paste hook: skipping (Gmail hook will handle)")
                return false
            }
        }
        return true  // Paste handles everything else
    }
    
    func execute(text: String, context: HookContext) async throws {
        print("🔗 Paste hook: executing...")
        KeyboardSimulator.paste()
        print("🔗 Paste hook: completed")
    }
}
