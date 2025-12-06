import Foundation
import Combine

/// Manages available modes and current mode selection
class ModeManager: ObservableObject {
    static let shared = ModeManager()
    
    /// All available modes (master list)
    let allModes: [any TranscriptionMode] = [
        RawMode(),
        FixMode(),
        BulletMode(),
        EmailMode(),
        SummarizeMode()
    ]
    
    /// IDs of modes visible in quick bar (ordered), max 5
    @Published var visibleModeIds: [String] {
        didSet {
            UserDefaults.standard.set(visibleModeIds, forKey: "visibleModeIds")
            objectWillChange.send()
        }
    }
    
    /// Modes visible in quick bar (computed from visibleModeIds)
    var modes: [any TranscriptionMode] {
        visibleModeIds.compactMap { id in allModes.first { $0.id == id } }
    }
    
    /// Currently selected mode
    @Published var currentMode: any TranscriptionMode
    
    /// Current mode index for display (within visible modes)
    var currentModeIndex: Int {
        get { modes.firstIndex { $0.id == currentMode.id } ?? 0 }
        set { 
            if newValue < modes.count {
                selectMode(modes[newValue])
            }
        }
    }
    
    /// Translation toggle - when ON, output is translated to target language
    @Published var translateEnabled: Bool {
        didSet {
            UserDefaults.standard.set(translateEnabled, forKey: "translateEnabled")
        }
    }
    
    /// Target language for translation
    var targetLanguage: String {
        UserDefaults.standard.string(forKey: "targetLanguage") ?? "English"
    }
    
    private init() {
        // Load visible mode IDs or use defaults
        if let savedIds = UserDefaults.standard.array(forKey: "visibleModeIds") as? [String] {
            visibleModeIds = savedIds
        } else {
            visibleModeIds = ["raw", "fix", "bullet", "email", "summarize"]
        }
        
        // Load saved mode or default to first visible
        let savedModeId = UserDefaults.standard.string(forKey: "currentModeId") ?? "raw"
        currentMode = allModes.first { $0.id == savedModeId } ?? allModes[0]
        
        // Load translation toggle state
        translateEnabled = UserDefaults.standard.bool(forKey: "translateEnabled")
    }
    
    /// Select a mode by shortcut number (1-5)
    func selectMode(byShortcut number: Int) {
        let index = number - 1
        guard index >= 0 && index < modes.count else {
            print("⚠️ No mode at position \(number)")
            return
        }
        selectMode(modes[index])
    }
    
    /// Select a specific mode
    func selectMode(_ mode: any TranscriptionMode) {
        currentMode = mode
        UserDefaults.standard.set(mode.id, forKey: "currentModeId")
        print("🔄 Mode changed to: \(mode.name)")
        objectWillChange.send()
    }
    
    /// Move a mode in the visible list
    func moveMode(from source: Int, to destination: Int) {
        guard source < visibleModeIds.count && destination <= visibleModeIds.count else { return }
        let id = visibleModeIds.remove(at: source)
        visibleModeIds.insert(id, at: destination > source ? destination - 1 : destination)
    }
    
    /// Toggle mode visibility
    func toggleModeVisibility(_ modeId: String) {
        if visibleModeIds.contains(modeId) {
            // Can't remove if it's the last one
            guard visibleModeIds.count > 1 else { return }
            visibleModeIds.removeAll { $0 == modeId }
        } else if visibleModeIds.count < 5 {
            visibleModeIds.append(modeId)
        }
    }
    
    /// Check if mode is visible
    func isModeVisible(_ modeId: String) -> Bool {
        visibleModeIds.contains(modeId)
    }
    
    /// Process text through current mode, optionally with translation and context
    func processText(_ text: String, context: String? = nil) async throws -> String {
        // If mode is Raw and translate is OFF, return as-is
        if currentMode.id == "raw" && !translateEnabled {
            print("📝 Raw mode - no processing")
            return text
        }
        
        // Build the user prompt with optional context
        var userPrompt = text
        
        // Add clipboard context if mode uses it and it's available
        if currentMode.usesClipboardContext, let clipboardContent = ClipboardMonitor.shared.getFreshContent() {
            print("📋 Including clipboard context (\(clipboardContent.count) chars)")
            userPrompt = """
            [Clipboard context - recently copied text that may be relevant]:
            \(clipboardContent.prefix(2000))
            
            [User's speech to process]:
            \(text)
            """
        }
        
        // Build system instruction
        var systemInstruction = ""
        
        // Add mode-specific instructions (unless Raw)
        if currentMode.id != "raw" {
            systemInstruction = currentMode.systemPrompt
            
            // Add context assessment instruction if mode uses context
            if currentMode.usesClipboardContext {
                systemInstruction += """
                
                
                Note: If clipboard context is provided, first assess if it's relevant to the user's speech.
                If relevant (e.g., it's an email they're replying to), use it to inform your response.
                If not relevant, ignore the clipboard context and focus only on the speech.
                """
            }
            
            print("🔄 Processing with mode: \(currentMode.name)")
        }
        
        // Append translation instruction if enabled
        if translateEnabled {
            if !systemInstruction.isEmpty {
                systemInstruction += "\n\n"
            }
            systemInstruction += """
            Finally, translate the result to \(targetLanguage).
            Provide ONLY the final \(translateEnabled && currentMode.id == "raw" ? "translation" : "processed and translated text"), no explanations.
            """
        }
        
        // For Raw mode with translation
        if currentMode.id == "raw" && translateEnabled {
            systemInstruction = """
            You are a professional translator. Translate the following text to \(targetLanguage).
            
            Rules:
            - Provide ONLY the translation, no explanations or notes
            - Preserve the tone and style of the original
            - Keep proper nouns unchanged unless they have a standard translation
            """
        }
        
        let result = try await GeminiService.shared.generate(
            prompt: userPrompt,
            systemInstruction: systemInstruction
        )
        
        if translateEnabled {
            print("🌐 Translated to \(targetLanguage)")
        }
        
        return result
    }
    
    /// Get mode by ID
    func mode(withId id: String) -> (any TranscriptionMode)? {
        return allModes.first { $0.id == id }
    }
}
