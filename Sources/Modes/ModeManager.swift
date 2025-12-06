import Foundation
import Combine

/// Manages available modes and current mode selection
class ModeManager: ObservableObject {
    static let shared = ModeManager()
    
    /// All available modes
    let modes: [any TranscriptionMode] = [
        RawMode()
        // More modes will be added in Phase 3: Fix, Bullet, Email, etc.
    ]
    
    /// Currently selected mode
    @Published var currentMode: any TranscriptionMode
    
    /// Current mode index for display
    @Published var currentModeIndex: Int = 0
    
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
        // Load saved mode or default to Raw
        let savedModeId = UserDefaults.standard.string(forKey: "currentModeId") ?? "raw"
        currentMode = modes.first { $0.id == savedModeId } ?? modes[0]
        currentModeIndex = modes.firstIndex { $0.id == savedModeId } ?? 0
        
        // Load translation toggle state
        translateEnabled = UserDefaults.standard.bool(forKey: "translateEnabled")
    }
    
    /// Select a mode by shortcut number
    func selectMode(byShortcut number: Int) {
        guard let mode = modes.first(where: { $0.shortcutNumber == number }) else {
            print("⚠️ No mode with shortcut \(number)")
            return
        }
        selectMode(mode)
    }
    
    /// Select a specific mode
    func selectMode(_ mode: any TranscriptionMode) {
        currentMode = mode
        currentModeIndex = modes.firstIndex { $0.id == mode.id } ?? 0
        UserDefaults.standard.set(mode.id, forKey: "currentModeId")
        print("🔄 Mode changed to: \(mode.name)")
    }
    
    /// Process text through current mode, optionally with translation
    func processText(_ text: String, context: String? = nil) async throws -> String {
        // If mode is Raw and translate is OFF, return as-is
        if currentMode.id == "raw" && !translateEnabled {
            return text
        }
        
        // Build combined prompt
        var systemInstruction = ""
        
        // Add mode-specific instructions (unless Raw)
        if currentMode.id != "raw" {
            systemInstruction = currentMode.systemPrompt
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
            prompt: text,
            systemInstruction: systemInstruction
        )
        
        if translateEnabled {
            print("🌐 Translated to \(targetLanguage)")
        }
        
        return result
    }
    
    /// Get mode by ID
    func mode(withId id: String) -> (any TranscriptionMode)? {
        return modes.first { $0.id == id }
    }
}
