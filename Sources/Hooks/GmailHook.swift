import Foundation

/// Gmail Hook - Smart compose/reply with Gemini-detected focus and click-to-unfocus
/// Logic:
/// - If ?compose= in URL AND context.composeBodyFocused is true → paste directly
/// - Otherwise: click to unfocus → use R/C shortcuts based on target
class GmailHook: Hook {
    let id = "gmail-reply"
    let name = "Gmail Auto-Paste"
    
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "gmailHookEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "gmailHookEnabled") }
    }
    
    func canExecute(context: HookContext) -> Bool {
        guard isEnabled else { 
            print("🔗 Gmail hook: disabled")
            return false 
        }
        
        guard context.modeId == "email" else { 
            print("🔗 Gmail hook: not in email mode (mode: \(context.modeId))")
            return false 
        }
        
        guard let url = context.browserURL else { 
            print("🔗 Gmail hook: no browser URL detected")
            return false 
        }
        
        let isGmail = url.contains("mail.google.com")
        print("🔗 Gmail hook: URL=\(url), isGmail=\(isGmail)")
        return isGmail
    }
    
    func execute(text: String, context: HookContext) async throws {
        print("🔗 Gmail hook: executing...")
        
        let hasSubject = context.emailSubject != nil
        let isThreadURL = isViewingEmailThread(url: context.browserURL)
        let hasComposeInURL = context.browserURL?.contains("?compose=") ?? false
        
        print("🔗 Gmail hook: hasSubject=\(hasSubject), isThreadURL=\(isThreadURL), hasComposeInURL=\(hasComposeInURL), composeBodyFocused=\(context.composeBodyFocused)")
        
        // DECISION: Direct paste vs click-to-unfocus + shortcuts
        if hasComposeInURL && context.composeBodyFocused {
            // User is already typing in compose body → just paste
            print("🔗 Gmail hook: DIRECT PASTE - compose body is focused")
            KeyboardSimulator.paste()
        } else {
            // Click to unfocus any field, then use shortcuts
            try await clickToUnfocus()
            
            if hasSubject {
                // New email with subject
                try await handleCompose(subject: context.emailSubject!, body: context.emailBody)
            } else if isThreadURL {
                // Reply
                try await handleReply(body: context.emailBody)
            } else {
                // Compose without subject
                try await handleComposeNoSubject(body: context.emailBody)
            }
        }
        
        print("🔗 Gmail hook: completed")
    }
    
    // MARK: - Click to Unfocus
    
    /// Click on an empty area to unfocus any text field
    /// We click the bottom-left of the browser window where Gmail usually has empty space
    private func clickToUnfocus() async throws {
        guard let bounds = BrowserDetector.shared.getFrontmostWindowBounds() else {
            print("🔗 Gmail hook: could not get window bounds, skipping click")
            return
        }
        
        // Click bottom-left corner of the window
        // This area is usually empty in Gmail (below sidebar)
        let clickX = bounds.origin.x + 10
        let clickY = bounds.origin.y + bounds.size.height - 15
        
        print("🔗 Gmail hook: Window bounds: \(bounds), clicking at (\(clickX), \(clickY))")
        MouseSimulator.clickAt(x: clickX, y: clickY)
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms for focus to clear
    }
    
    // MARK: - Action Handlers
    
    /// Handle new compose with subject
    private func handleCompose(subject: String, body: String) async throws {
        print("🔗 Gmail hook: COMPOSE - opening new email with subject")
        
        KeyboardSimulator.pressKey(.c)
        try await Task.sleep(nanoseconds: 800_000_000)
        
        // Tab to Subject, paste subject
        KeyboardSimulator.pressKey(.tab)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        ClipboardManager.shared.copyToClipboard(subject)
        try await Task.sleep(nanoseconds: 50_000_000)
        KeyboardSimulator.paste()
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Tab to Body, paste body
        KeyboardSimulator.pressKey(.tab)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        ClipboardManager.shared.copyToClipboard(body)
        try await Task.sleep(nanoseconds: 50_000_000)
        KeyboardSimulator.paste()
        print("🔗 Gmail hook: subject and body inserted")
    }
    
    /// Handle reply (no subject needed)
    private func handleReply(body: String) async throws {
        print("🔗 Gmail hook: REPLY - opening reply composer")
        
        KeyboardSimulator.pressKey(.r)
        try await Task.sleep(nanoseconds: 700_000_000)
        
        KeyboardSimulator.paste()
        print("🔗 Gmail hook: body inserted into reply")
    }
    
    /// Handle compose without subject
    private func handleComposeNoSubject(body: String) async throws {
        print("🔗 Gmail hook: COMPOSE (no subject) - opening new email")
        
        KeyboardSimulator.pressKey(.c)
        try await Task.sleep(nanoseconds: 800_000_000)
        
        // Tab twice to reach Body
        KeyboardSimulator.pressKey(.tab)
        try await Task.sleep(nanoseconds: 100_000_000)
        KeyboardSimulator.pressKey(.tab)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        KeyboardSimulator.paste()
        print("🔗 Gmail hook: body inserted into compose")
    }
    
    // MARK: - URL Detection
    
    private func isViewingEmailThread(url: String?) -> Bool {
        guard let url = url else { return false }
        guard let hashIndex = url.firstIndex(of: "#") else { return false }
        let fragment = String(url[url.index(after: hashIndex)...])
        let fragmentWithoutQuery = fragment.split(separator: "?").first.map(String.init) ?? fragment
        let components = fragmentWithoutQuery.split(separator: "/")
        return components.count >= 2 && components[1].count > 5
    }
}
