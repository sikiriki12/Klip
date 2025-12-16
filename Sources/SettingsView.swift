import SwiftUI

struct SettingsView: View {
    @State private var elevenLabsKey = ""
    @State private var geminiKey = ""
    @State private var selectedLanguage = "Auto-detect"
    @State private var targetLanguage = "English"
    @State private var waitForSilence = true
    @State private var showSaveConfirmation = false
    @State private var expandedModeId: String? = nil
    @State private var newToneName = ""
    @State private var newTonePrompt = ""
    @State private var newCustomModeName = ""

    @State private var newCustomModePrompt = ""
    @State private var newCustomModeClipboard = false
    @State private var newCustomModeScreenshot = false
    @ObservedObject private var modeManager = ModeManager.shared
    @ObservedObject private var toneManager = ToneManager.shared
    
    let languages = ["Auto-detect", "Croatian", "English", "German", "Spanish", "French", "Italian", "Portuguese", "Dutch", "Polish", "Russian", "Japanese", "Chinese", "Korean"]
    
    var body: some View {
        Form {
            Section("API Keys") {
                SecureField("ElevenLabs API Key", text: $elevenLabsKey)
                    .textFieldStyle(.roundedBorder)
                
                SecureField("Gemini API Key", text: $geminiKey)
                    .textFieldStyle(.roundedBorder)
                
                HStack {
                    Text("Keys are stored securely in Keychain")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
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
            }
            
            Section("Modes") {
                Text("Quick bar modes (⌘1-5):")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(modeManager.allModes, id: \.id) { mode in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            // Visibility checkbox
                            Button(action: {
                                modeManager.toggleModeVisibility(mode.id)
                            }) {
                                Image(systemName: modeManager.isModeVisible(mode.id) ? "checkmark.square.fill" : "square")
                                    .foregroundColor(modeManager.isModeVisible(mode.id) ? .blue : .secondary)
                            }
                            .buttonStyle(.plain)
                            
                            // Mode name and position
                            Text(mode.name)
                                .fontWeight(.medium)
                            
                            // Context indicators
                            if mode.usesClipboardContext {
                                Text("📋")
                                    .font(.caption)
                                    .help("Uses clipboard context")
                            }
                            if mode.usesScreenshotContext {
                                Text("📷")
                                    .font(.caption)
                                    .help("Uses screenshot context")
                            }
                            
                            if let position = modeManager.visibleModeIds.firstIndex(of: mode.id) {
                                Text("⌘\(position + 1)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(3)
                            }
                            
                            Spacer()
                            
                            // Tone picker (hidden for Raw mode)
                            if mode.id != "raw" {
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
                            }
                            
                            // Expand to show prompt
                            Button(action: {
                                if expandedModeId == mode.id {
                                    expandedModeId = nil
                                } else {
                                    expandedModeId = mode.id
                                }
                            }) {
                                Image(systemName: expandedModeId == mode.id ? "chevron.up" : "chevron.down")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Show prompt when expanded
                        if expandedModeId == mode.id {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mode.systemPrompt.isEmpty ? "(No prompt - passthrough)" : mode.systemPrompt)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if mode.usesClipboardContext {
                                    Text("📋 Uses clipboard context when enabled")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                                if mode.usesScreenshotContext {
                                    Text("📷 Uses screenshot context when enabled")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                    .padding(.vertical, 2)
                }
                
                Text("Max 5 modes. 📋 = clipboard, 📷 = screenshot")
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
            
            Section("Custom Tones") {
                // List existing custom tones
                ForEach(toneManager.customTones) { tone in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(tone.name)
                                .fontWeight(.medium)
                            Text(tone.promptModifier)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button(action: {
                            toneManager.deleteCustomTone(id: tone.id)
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
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
                            VStack(alignment: .leading) {
                                Text(mode.name)
                                    .fontWeight(.medium)
                                Text(mode.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            
                            // Context toggles
                            HStack(spacing: 8) {
                                Button(action: {
                                    var updated = mode
                                    updated.usesClipboardContext.toggle()
                                    modeManager.updateCustomMode(updated)
                                }) {
                                    Text("📋")
                                        .opacity(mode.usesClipboardContext ? 1.0 : 0.3)
                                }
                                .buttonStyle(.plain)
                                .help("Clipboard context")
                                
                                Button(action: {
                                    var updated = mode
                                    updated.usesScreenshotContext.toggle()
                                    modeManager.updateCustomMode(updated)
                                }) {
                                    Text("📷")
                                        .opacity(mode.usesScreenshotContext ? 1.0 : 0.3)
                                }
                                .buttonStyle(.plain)
                                .help("Screenshot context")
                            }
                            
                            Button(action: {
                                modeManager.deleteCustomMode(id: mode.id)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
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
                    Text("Switch Mode")
                    Spacer()
                    Text("⌘1-5")
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
}

#Preview {
    SettingsView()
}
