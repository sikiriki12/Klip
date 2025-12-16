import Foundation
import Combine

/// Manages available modes and current mode selection
class ModeManager: ObservableObject {
    static let shared = ModeManager()
    
    /// Built-in modes (constant)
    private let builtInModes: [any TranscriptionMode] = [
        RawMode(),
        FixMode(),
        PolishMode(),
        EmailMode(),
        IMMode(),
        SummarizeMode(),
        TweetMode()
    ]
    
    /// Custom modes (user-defined)
    @Published var customModes: [CustomMode] = []
    
    /// All available modes (built-in + custom)
    var allModes: [any TranscriptionMode] {
        builtInModes + customModes
    }
    
    /// Mode IDs in user-preferred order (first 9 get ⌘1-9 shortcuts)
    @Published var orderedModeIds: [String] {
        didSet {
            UserDefaults.standard.set(orderedModeIds, forKey: "orderedModeIds")
            objectWillChange.send()
        }
    }
    
    /// Modes in user-preferred order (computed from orderedModeIds)
    var modes: [any TranscriptionMode] {
        orderedModeIds.compactMap { id in allModes.first { $0.id == id } }
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
    
    private let customModesKey = "customModes"
    
    private init() {
        // Load custom modes
        var loadedCustomModes: [CustomMode] = []
        var needsSaveCustomModes = false
        
        if let data = UserDefaults.standard.data(forKey: customModesKey),
           let modes = try? JSONDecoder().decode([CustomMode].self, from: data) {
            loadedCustomModes = modes
        } else {
            // First run - add Commit mode as example
            loadedCustomModes = [CustomMode.commitMode]
            needsSaveCustomModes = true
        }
        customModes = loadedCustomModes
        
        // Load ordered mode IDs or migrate from old format or use defaults
        if let savedIds = UserDefaults.standard.array(forKey: "orderedModeIds") as? [String] {
            orderedModeIds = savedIds
        } else if let oldVisibleIds = UserDefaults.standard.array(forKey: "visibleModeIds") as? [String] {
            // Migrate from old visible-only format: start with old visible, add remaining
            let allIds = (builtInModes.map { $0.id }) + loadedCustomModes.map { $0.id }
            var ordered = oldVisibleIds.filter { allIds.contains($0) }
            for id in allIds where !ordered.contains(id) {
                ordered.append(id)
            }
            orderedModeIds = ordered
        } else {
            // Default order: all built-in modes then custom
            orderedModeIds = (builtInModes.map { $0.id }) + loadedCustomModes.map { $0.id }
        }
        
        // Load saved mode or default to first
        let savedModeId = UserDefaults.standard.string(forKey: "currentModeId") ?? "raw"
        currentMode = builtInModes.first { $0.id == savedModeId } ?? builtInModes[0]
        
        // Load translation toggle state
        translateEnabled = UserDefaults.standard.bool(forKey: "translateEnabled")
        
        // Save custom modes if needed (after all properties initialized)
        if needsSaveCustomModes {
            saveCustomModes()
        }
    }
    
    // MARK: - Custom Mode CRUD
    
    private func saveCustomModes() {
        if let data = try? JSONEncoder().encode(customModes) {
            UserDefaults.standard.set(data, forKey: customModesKey)
        }
    }
    
    func addCustomMode(name: String, description: String, systemPrompt: String, usesClipboard: Bool, usesScreenshot: Bool) {
        let mode = CustomMode(
            name: name,
            description: description,
            systemPrompt: systemPrompt,
            usesClipboardContext: usesClipboard,
            usesScreenshotContext: usesScreenshot
        )
        customModes.append(mode)
        orderedModeIds.append(mode.id)  // Add to ordered list
        saveCustomModes()
        objectWillChange.send()
    }
    
    func deleteCustomMode(id: String) {
        customModes.removeAll { $0.id == id }
        orderedModeIds.removeAll { $0 == id }
        saveCustomModes()
        objectWillChange.send()
    }
    
    func updateCustomMode(_ mode: CustomMode) {
        if let index = customModes.firstIndex(where: { $0.id == mode.id }) {
            customModes[index] = mode
            saveCustomModes()
            objectWillChange.send()
        }
    }
    
    // MARK: - Mode Selection
    
    /// Select a mode by shortcut number (1-9)
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
    
    /// Move a mode in the ordered list
    func moveMode(from source: IndexSet, to destination: Int) {
        orderedModeIds.move(fromOffsets: source, toOffset: destination)
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
        var hasClipboardContext = false
        var hasScreenshotContext = false
        
        // Add clipboard context if mode uses it and it's available
        if currentMode.usesClipboardContext, let clipboardContent = ClipboardMonitor.shared.getFreshContent() {
            print("📋 Including clipboard context (\(clipboardContent.count) chars)")
            hasClipboardContext = true
            userPrompt = """
            [Clipboard context - recently copied text that may be relevant]:
            \(clipboardContent.prefix(2000))
            
            [User's speech to process]:
            \(text)
            """
        }
        
        // Capture screenshot if mode uses it and it's enabled
        var screenshotData: Data? = nil
        if currentMode.usesScreenshotContext && ScreenshotService.shared.isEnabled {
            // Check if we need async capture (select area mode)
            if ScreenshotService.shared.requiresAsyncCapture {
                screenshotData = await ScreenshotService.shared.captureSelectArea()
            } else {
                screenshotData = ScreenshotService.shared.capture()
            }
            
            if screenshotData != nil {
                hasScreenshotContext = true
                
                // DEBUG MODE: Do separate OCR call to log what model reads
                if ScreenshotService.shared.debugMode {
                    print("🔍 DEBUG: Running separate OCR to see what model reads from screenshot...")
                    do {
                        let ocrResult = try await GeminiService.shared.generate(
                            prompt: """
                            Analyze this screenshot:
                            1. DESCRIBE what you see (what app, what type of content)
                            2. READ all visible text (transcribe it)
                            3. EXPLAIN what this content is about (your understanding)
                            """,
                            systemInstruction: "You are analyzing a screenshot to understand its context. Be thorough but concise.",
                            imageData: screenshotData
                        )
                        print("═══════════════════════════════════════════════════════════")
                        print("🔍 MODEL READS FROM SCREENSHOT:")
                        print("───────────────────────────────────────────────────────────")
                        print(ocrResult)
                        print("═══════════════════════════════════════════════════════════")
                    } catch {
                        print("❌ DEBUG OCR failed: \(error)")
                    }
                }
                
                // Add explicit instruction that screenshot is CONTEXT with OCR
                if !hasClipboardContext {
                    userPrompt = """
                    [Screenshot context - image of user's active window]:
                    (See attached image)
                    
                    FIRST: Read and extract ALL text visible in the screenshot. This text is the CONTEXT.
                    
                    [User's speech to process - THIS is what you should respond to]:
                    \(text)
                    """
                } else {
                    // Both contexts - append screenshot note
                    userPrompt = """
                    [Screenshot context - image of user's active window]:
                    (See attached image)
                    
                    FIRST: Read and extract ALL text visible in the screenshot. This text is the CONTEXT.
                    
                    \(userPrompt)
                    """
                }
            }
        }
        
        // Build system instruction
        var systemInstruction = ""
        
        // Add mode-specific instructions (unless Raw)
        if currentMode.id != "raw" {
            systemInstruction = currentMode.systemPrompt
            
            // IMPORTANT: If translate is OFF, preserve the input language
            if !translateEnabled {
                systemInstruction += """
                
                
                LANGUAGE: Respond in the SAME language as the user's speech. Do NOT translate to English or any other language.
                """
            }
            
            // Add context assessment instructions
            var contextNotes: [String] = []
            
            if currentMode.usesClipboardContext {
                contextNotes.append("clipboard text (if provided)")
            }
            
            if currentMode.usesScreenshotContext && screenshotData != nil {
                contextNotes.append("screenshot of the active window")
            }
            
            if !contextNotes.isEmpty {
                systemInstruction += """
                
                
                CONTEXT: You may receive \(contextNotes.joined(separator: " and/or ")).
                This shows what the user is looking at or referencing.
                Use it to understand their request, but do NOT process/translate the context itself.
                If the context is not relevant, ignore it.
                """
            }
            
            // Apply tone modifier
            let tone = ToneManager.shared.getTone(for: currentMode.id, defaultToneId: currentMode.defaultToneId)
            if !tone.promptModifier.isEmpty {
                systemInstruction += "\n\nTONE: \(tone.promptModifier)"
                print("🎭 Tone: \(tone.name)")
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
        
        let startTime = Date()
        print("⏱️ Starting Gemini processing...")
        
        let result = try await GeminiService.shared.generate(
            prompt: userPrompt,
            systemInstruction: systemInstruction,
            imageData: screenshotData
        )
        
        let elapsed = Date().timeIntervalSince(startTime)
        print("⏱️ Gemini completed in \(String(format: "%.2f", elapsed))s")
        
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
