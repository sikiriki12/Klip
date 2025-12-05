import Foundation
import Combine

/// Manages available modes and current mode selection
class ModeManager: ObservableObject {
    static let shared = ModeManager()
    
    /// All available modes
    let modes: [any TranscriptionMode] = [
        RawMode(),
        TranslateMode()
    ]
    
    /// Currently selected mode
    @Published var currentMode: any TranscriptionMode
    
    /// Current mode index for display
    @Published var currentModeIndex: Int = 0
    
    private init() {
        // Load saved mode or default to Raw
        let savedModeId = UserDefaults.standard.string(forKey: "currentModeId") ?? "raw"
        currentMode = modes.first { $0.id == savedModeId } ?? modes[0]
        currentModeIndex = modes.firstIndex { $0.id == savedModeId } ?? 0
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
    
    /// Process text through current mode
    func processText(_ text: String, context: String? = nil) async throws -> String {
        return try await currentMode.process(text, context: context)
    }
    
    /// Get mode by ID
    func mode(withId id: String) -> (any TranscriptionMode)? {
        return modes.first { $0.id == id }
    }
}
