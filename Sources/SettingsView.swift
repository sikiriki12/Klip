import SwiftUI

struct SettingsView: View {
    @State private var elevenLabsKey = ""
    @State private var geminiKey = ""
    @State private var selectedLanguage = "Auto-detect"
    @State private var targetLanguage = "English"
    @State private var waitForSilence = true
    @State private var showSaveConfirmation = false
    
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
                                return val >= 1.0 ? val : 1.0  // Default to 1s if not set or too low
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
                    
                    Text("Wait this long after you stop speaking before auto-commit")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
        .frame(width: 450, height: 400)
        .onAppear {
            loadSettings()
        }
    }
    
    private func loadSettings() {
        // Load API keys from Keychain (show masked placeholder)
        if KeychainManager.shared.getElevenLabsKey() != nil {
            elevenLabsKey = "••••••••••••••••"
        }
        if KeychainManager.shared.getGeminiKey() != nil {
            geminiKey = "••••••••••••••••"
        }
        
        // Load language settings
        selectedLanguage = UserDefaults.standard.string(forKey: "inputLanguage") ?? "Auto-detect"
        targetLanguage = UserDefaults.standard.string(forKey: "targetLanguage") ?? "English"
        waitForSilence = UserDefaults.standard.bool(forKey: "waitForSilence")
    }
    
    private func saveAPIKeys() {
        do {
            // Only save if not the masked placeholder
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
        
        // Update coordinator
        if selectedLanguage == "Auto-detect" {
            TranscriptionCoordinator.shared.languageCode = nil
        } else {
            TranscriptionCoordinator.shared.languageCode = languageToCode(selectedLanguage)
        }
    }
    
    private func languageToCode(_ language: String) -> String {
        let codes: [String: String] = [
            "Croatian": "hr",
            "English": "en",
            "German": "de",
            "Spanish": "es",
            "French": "fr",
            "Italian": "it",
            "Portuguese": "pt",
            "Dutch": "nl",
            "Polish": "pl",
            "Russian": "ru",
            "Japanese": "ja",
            "Chinese": "zh",
            "Korean": "ko"
        ]
        return codes[language] ?? "en"
    }
}

#Preview {
    SettingsView()
}
