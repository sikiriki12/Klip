import SwiftUI

struct SettingsView: View {
    @State private var selectedLanguage = "Croatian"
    @State private var targetLanguage = "English"
    @State private var waitForSilence = true
    
    let languages = ["Auto-detect", "Croatian", "English", "German", "Spanish", "French", "Italian"]
    
    var body: some View {
        Form {
            Section("Transcription") {
                Picker("Input Language", selection: $selectedLanguage) {
                    ForEach(languages, id: \.self) { lang in
                        Text(lang).tag(lang)
                    }
                }
                
                Picker("Translate To", selection: $targetLanguage) {
                    ForEach(languages.filter { $0 != "Auto-detect" }, id: \.self) { lang in
                        Text(lang).tag(lang)
                    }
                }
            }
            
            Section("Recording") {
                Toggle("Wait for silence to stop", isOn: $waitForSilence)
                Text("Or press ⌥K again to stop manually")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("API Keys") {
                SecureField("ElevenLabs API Key", text: .constant(""))
                SecureField("Gemini API Key", text: .constant(""))
                Text("Keys are stored securely in Keychain")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 300)
    }
}

#Preview {
    SettingsView()
}
