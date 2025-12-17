import SwiftUI

struct SettingsView: View {
    @State private var elevenLabsKey = ""
    @State private var geminiKey = ""
    @State private var selectedLanguage = "Auto-detect"
    @State private var targetLanguage = "English"
    @State private var waitForSilence = true
    @State private var showSaveConfirmation = false
    @State private var expandedModeId: String? = nil
    @State private var expandedToneId: String? = nil
    @State private var newToneName = ""
    @State private var newTonePrompt = ""
    @State private var newCustomModeName = ""

    @State private var newCustomModePrompt = ""
    @State private var newCustomModeClipboard = false
    @State private var newCustomModeScreenshot = false
    @State private var gmailHookEnabled = UserDefaults.standard.bool(forKey: "gmailHookEnabled")
    @ObservedObject private var modeManager = ModeManager.shared
    @ObservedObject private var toneManager = ToneManager.shared
    
    let languages = ["Auto-detect", "Croatian", "English", "German", "Spanish", "French", "Italian", "Portuguese", "Dutch", "Polish", "Russian", "Japanese", "Chinese", "Korean"]
    
    var body: some View {
        Form {
            // App header
            HStack {
                Image(systemName: "waveform")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
                VStack(alignment: .leading) {
                    Text("Klip")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("v0.4")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 8)
            
            Section("API Keys") {
                SecureField("ElevenLabs API Key", text: $elevenLabsKey)
                    .textFieldStyle(.roundedBorder)
                
                SecureField("Gemini API Key", text: $geminiKey)
                    .textFieldStyle(.roundedBorder)
                
                HStack {
                    Spacer()
                    
                    Button("Save Keys") {
                        saveAPIKeys()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                if showSaveConfirmation {
                    Text("✅ Keys saved successfully!")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                Toggle("🔐 Store in Keychain", isOn: Binding(
                    get: { KeychainManager.shared.useKeychain },
                    set: { newValue in
                        KeychainManager.shared.useKeychain = newValue
                        // Reload keys from new storage location
                        loadSettings()
                    }
                ))
                
                if KeychainManager.shared.useKeychain {
                    Text("Secure storage. May require password during development.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("⚠️ Keys stored in plain text. Use only for development.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Section("Your Identity") {
                Toggle("Include in context-aware modes", isOn: Binding(
                    get: { UserProfile.shared.isEnabled },
                    set: { UserProfile.shared.isEnabled = $0 }
                ))
                
                TextField("Name", text: Binding(
                    get: { UserProfile.shared.name },
                    set: { UserProfile.shared.name = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .disabled(!UserProfile.shared.isEnabled)
                
                TextField("Email (optional)", text: Binding(
                    get: { UserProfile.shared.email },
                    set: { UserProfile.shared.email = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .disabled(!UserProfile.shared.isEnabled)
                
                TextField("Company (optional)", text: Binding(
                    get: { UserProfile.shared.company },
                    set: { UserProfile.shared.company = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .disabled(!UserProfile.shared.isEnabled)
                
                Text("Auto-detected. Used for Email, Message, and custom modes with context.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Modes") {
                Text("Drag to reorder. First 9 get ⌘1-9 shortcuts.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                List {
                    ForEach(Array(modeManager.modes.enumerated()), id: \.element.id) { index, mode in
                        HStack {
                            // Drag handle
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.secondary)
                            
                            // Mode name
                            Text(mode.name)
                                .fontWeight(.medium)
                            
                            // Context indicators
                            if mode.usesClipboardContext {
                                Text("📋")
                                    .font(.caption)
                            }
                            if mode.usesScreenshotContext {
                                Text("📷")
                                    .font(.caption)
                            }
                            
                            // Gmail hook indicator (only for Email mode when hook is enabled)
                            if mode.id == "email" && gmailHookEnabled {
                                Image(systemName: "envelope.fill")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            
                            // Shortcut badge (first 9 only)
                            if index < 9 {
                                Text("⌘\(index + 1)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(3)
                            }
                            
                            Spacer()
                            
                            // Info button to show prompt
                            Button(action: {
                                if expandedModeId == mode.id {
                                    expandedModeId = nil
                                } else {
                                    expandedModeId = mode.id
                                }
                            }) {
                                Image(systemName: expandedModeId == mode.id ? "info.circle.fill" : "info.circle")
                                    .foregroundColor(expandedModeId == mode.id ? .blue : .secondary)
                                    .font(.system(size: 14))
                            }
                            .buttonStyle(.plain)
                            
                            // Tone picker (disabled for Raw mode to maintain alignment)
                            Picker("", selection: Binding(
                                get: { toneManager.getTone(for: mode.id, defaultToneId: mode.defaultToneId).id },
                                set: { toneManager.setTone(for: mode.id, toneId: $0) }
                            )) {
                                ForEach(toneManager.allTones) { tone in
                                    Text(tone.name).tag(tone.id)
                                }
                            }
                            .frame(width: 100)
                            .labelsHidden()
                            .disabled(mode.id == "raw")
                            .opacity(mode.id == "raw" ? 0.3 : 1.0)
                        }
                    }
                    .onMove { source, destination in
                        modeManager.moveMode(from: source, to: destination)
                    }
                }
                .frame(height: 250)
                
                // Show selected mode prompt below the list
                if let modeId = expandedModeId,
                   let mode = modeManager.modes.first(where: { $0.id == modeId }) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(mode.name) Prompt")
                                .font(.caption)
                                .fontWeight(.medium)
                            Spacer()
                            Button("Close") {
                                expandedModeId = nil
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        
                        ScrollView {
                            Text(mode.systemPrompt.isEmpty ? "(No prompt - raw passthrough)" : mode.systemPrompt)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .frame(height: 120)
                        .padding(8)
                        .background(Color.gray.opacity(0.08))
                        .cornerRadius(6)
                    }
                }
                
                Text("📋 = clipboard, 📷 = screenshot")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Context") {
                // Clipboard context
                Toggle("Enable clipboard context", isOn: Binding(
                    get: { ClipboardMonitor.shared.isEnabled },
                    set: { ClipboardMonitor.shared.isEnabled = $0 }
                ))
                
                Text("Modes marked 📋 use recently copied text (<1 min)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Divider()
                
                // Screenshot context
                Toggle("Enable screenshot context", isOn: Binding(
                    get: { ScreenshotService.shared.isEnabled },
                    set: { ScreenshotService.shared.isEnabled = $0 }
                ))
                
                if ScreenshotService.shared.isEnabled {
                    Picker("Capture", selection: Binding(
                        get: { ScreenshotService.shared.captureMode },
                        set: { ScreenshotService.shared.captureMode = $0 }
                    )) {
                        ForEach(ScreenshotService.CaptureMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Text("Modes marked 📷 capture screen when recording starts")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if ScreenshotService.shared.isEnabled {
                    Button(action: {
                        // Open Screen Recording preferences
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack {
                            Text("⚠️ Requires Screen Recording permission")
                            Image(systemName: "arrow.up.forward.square")
                                .font(.caption2)
                        }
                        .font(.caption)
                        .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Section("Hooks") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Gmail Auto-Paste (Email mode)", isOn: $gmailHookEnabled)
                        .onChange(of: gmailHookEnabled) { newValue in
                            UserDefaults.standard.set(newValue, forKey: "gmailHookEnabled")
                        }
                    
                    Text("When using Email mode on Gmail, auto-opens reply and pastes text")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Requires Gmail keyboard shortcuts")
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                    
                    Text("Go to Gmail Settings → General → Keyboard shortcuts → On")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        if let url = URL(string: "https://mail.google.com/mail/u/0/#settings/general") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack {
                            Text("Open Gmail Settings")
                            Image(systemName: "arrow.up.forward.square")
                                .font(.caption2)
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                }
            }
            
            Section("Custom Tones") {
                // List existing custom tones
                ForEach(toneManager.customTones) { tone in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(tone.name)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            // Edit button
                            Button(action: {
                                if expandedToneId == tone.id {
                                    expandedToneId = nil
                                } else {
                                    expandedToneId = tone.id
                                }
                            }) {
                                Text(expandedToneId == tone.id ? "Done" : "Edit")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                toneManager.deleteCustomTone(id: tone.id)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Expanded edit view
                        if expandedToneId == tone.id {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Prompt modifier:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(tone.promptModifier)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(6)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 2)
                }
                
                // Add new tone
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Tone name (e.g., Friendly)", text: $newToneName)
                        .textFieldStyle(.roundedBorder)
                    TextField("Prompt modifier (e.g., Use warm, friendly language)", text: $newTonePrompt)
                        .textFieldStyle(.roundedBorder)
                    Button(action: {
                        if !newToneName.isEmpty && !newTonePrompt.isEmpty {
                            toneManager.addCustomTone(name: newToneName, promptModifier: newTonePrompt)
                            newToneName = ""
                            newTonePrompt = ""
                        }
                    }) {
                        Label("Add Tone", systemImage: "plus.circle")
                    }
                    .disabled(newToneName.isEmpty || newTonePrompt.isEmpty)
                }
                
                Text("Custom tones appear in mode tone picker")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Custom Modes") {
                // List existing custom modes
                ForEach(modeManager.customModes, id: \.id) { mode in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(mode.name)
                                .fontWeight(.medium)
                            
                            // Context indicators
                            if mode.usesClipboardContext {
                                Text("📋")
                                    .font(.caption)
                                    .opacity(0.8)
                            }
                            if mode.usesScreenshotContext {
                                Text("📷")
                                    .font(.caption)
                                    .opacity(0.8)
                            }
                            
                            Spacer()
                            
                            // Edit button
                            Button(action: {
                                if expandedModeId == mode.id {
                                    expandedModeId = nil
                                } else {
                                    expandedModeId = mode.id
                                }
                            }) {
                                Text(expandedModeId == mode.id ? "Done" : "Edit")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                modeManager.deleteCustomMode(id: mode.id)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Expanded edit view
                        if expandedModeId == mode.id {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("System prompt:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(mode.systemPrompt)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(6)
                                
                                HStack(spacing: 16) {
                                    Button(action: {
                                        var updated = mode
                                        updated.usesClipboardContext.toggle()
                                        modeManager.updateCustomMode(updated)
                                    }) {
                                        HStack {
                                            Image(systemName: mode.usesClipboardContext ? "checkmark.square.fill" : "square")
                                            Text("Clipboard")
                                        }
                                        .font(.caption)
                                        .foregroundColor(mode.usesClipboardContext ? .blue : .secondary)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button(action: {
                                        var updated = mode
                                        updated.usesScreenshotContext.toggle()
                                        modeManager.updateCustomMode(updated)
                                    }) {
                                        HStack {
                                            Image(systemName: mode.usesScreenshotContext ? "checkmark.square.fill" : "square")
                                            Text("Screenshot")
                                        }
                                        .font(.caption)
                                        .foregroundColor(mode.usesScreenshotContext ? .blue : .secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 2)
                }
                
                // Add new custom mode (always visible)
                Divider()
                
                Text("Add New Mode")
                    .font(.headline)
                    .padding(.top, 8)
                
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Mode name", text: $newCustomModeName)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("System prompt:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $newCustomModePrompt)
                        .font(.body)
                        .frame(minHeight: 100, maxHeight: 150)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    
                    HStack {
                        Toggle("📋 Clipboard", isOn: $newCustomModeClipboard)
                        Toggle("📷 Screenshot", isOn: $newCustomModeScreenshot)
                        
                        Spacer()
                        
                        Button(action: {
                            if !newCustomModeName.isEmpty && !newCustomModePrompt.isEmpty {
                                modeManager.addCustomMode(
                                    name: newCustomModeName,
                                    description: newCustomModeName,
                                    systemPrompt: newCustomModePrompt,
                                    usesClipboard: newCustomModeClipboard,
                                    usesScreenshot: newCustomModeScreenshot
                                )
                                newCustomModeName = ""

                                newCustomModePrompt = ""
                                newCustomModeClipboard = false
                                newCustomModeScreenshot = false
                            }
                        }) {
                            Label("Create Mode", systemImage: "plus.circle")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newCustomModeName.isEmpty || newCustomModePrompt.isEmpty)
                    }
                }
                
                Text("Custom modes appear in the modes list above")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Transcription") {
                Picker("Input Language", selection: $selectedLanguage) {
                    ForEach(languages, id: \.self) { lang in
                        Text(lang).tag(lang)
                    }
                }
                .onChange(of: selectedLanguage) { newValue in
                    saveLanguageSettings()
                }
                
                Picker("Translate To", selection: $targetLanguage) {
                    ForEach(languages.filter { $0 != "Auto-detect" }, id: \.self) { lang in
                        Text(lang).tag(lang)
                    }
                }
                .onChange(of: targetLanguage) { newValue in
                    saveLanguageSettings()
                }
            }
            
            Section("Recording") {
                Toggle("Wait for silence to stop", isOn: $waitForSilence)
                    .onChange(of: waitForSilence) { newValue in
                        UserDefaults.standard.set(newValue, forKey: "waitForSilence")
                    }
                
                if waitForSilence {
                    HStack {
                        Text("Silence duration:")
                        Spacer()
                        Picker("", selection: Binding(
                            get: { 
                                let val = UserDefaults.standard.double(forKey: "silenceDuration")
                                return val >= 1.0 ? val : 1.0
                            },
                            set: { UserDefaults.standard.set($0, forKey: "silenceDuration") }
                        )) {
                            Text("1s").tag(1.0)
                            Text("1.5s").tag(1.5)
                            Text("2s").tag(2.0)
                            Text("2.5s").tag(2.5)
                            Text("3s").tag(3.0)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 220)
                    }
                } else {
                    Text("Press ⌥K again to stop manually")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Shortcuts") {
                HStack {
                    Text("Start/Stop Recording")
                    Spacer()
                    Text("⌥K")
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Record (Invert Silence)")
                        Text("Uses opposite of your silence setting")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("⇧⌥K")
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
                
                HStack {
                    Text("Switch Mode")
                    Spacer()
                    Text("⌘1-9")
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 850)
        .onAppear {
            loadSettings()
        }
    }
    
    private func loadSettings() {
        if KeychainManager.shared.getElevenLabsKey() != nil {
            elevenLabsKey = "••••••••••••••••"
        }
        if KeychainManager.shared.getGeminiKey() != nil {
            geminiKey = "••••••••••••••••"
        }
        
        selectedLanguage = UserDefaults.standard.string(forKey: "inputLanguage") ?? "Auto-detect"
        // Apply saved language to coordinator on startup
        if selectedLanguage == "Auto-detect" {
            TranscriptionCoordinator.shared.languageCode = nil
        } else {
            TranscriptionCoordinator.shared.languageCode = languageToCode(selectedLanguage)
        }
        
        targetLanguage = UserDefaults.standard.string(forKey: "targetLanguage") ?? "English"
        waitForSilence = UserDefaults.standard.bool(forKey: "waitForSilence")
    }
    
    private func saveAPIKeys() {
        do {
            if !elevenLabsKey.contains("•") && !elevenLabsKey.isEmpty {
                try KeychainManager.shared.saveElevenLabsKey(elevenLabsKey)
            }
            if !geminiKey.contains("•") && !geminiKey.isEmpty {
                try KeychainManager.shared.saveGeminiKey(geminiKey)
            }
            
            showSaveConfirmation = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showSaveConfirmation = false
            }
        } catch {
            print("❌ Failed to save keys: \(error)")
        }
    }
    
    private func saveLanguageSettings() {
        UserDefaults.standard.set(selectedLanguage, forKey: "inputLanguage")
        UserDefaults.standard.set(targetLanguage, forKey: "targetLanguage")
        
        if selectedLanguage == "Auto-detect" {
            TranscriptionCoordinator.shared.languageCode = nil
        } else {
            TranscriptionCoordinator.shared.languageCode = languageToCode(selectedLanguage)
        }
    }
    
    private func languageToCode(_ language: String) -> String {
        let codes: [String: String] = [
            "Croatian": "hr", "English": "en", "German": "de", "Spanish": "es",
            "French": "fr", "Italian": "it", "Portuguese": "pt", "Dutch": "nl",
            "Polish": "pl", "Russian": "ru", "Japanese": "ja", "Chinese": "zh", "Korean": "ko"
        ]
        return codes[language] ?? "en"
    }
    
    /// Generate tooltip text for a mode
    private func modeTooltip(for mode: any TranscriptionMode) -> String {
        // For custom modes, show the system prompt (truncated if long)
        if modeManager.customModes.contains(where: { $0.id == mode.id }) {
            let prompt = mode.systemPrompt
            if prompt.count > 200 {
                return String(prompt.prefix(200)) + "..."
            }
            return prompt.isEmpty ? mode.description : prompt
        }
        
        // For built-in modes, show description
        return mode.description
    }
}

#Preview {
    SettingsView()
}
