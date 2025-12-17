import Foundation
import Combine

/// Coordinates the transcription flow: recording → Scribe → result
class TranscriptionCoordinator: ObservableObject {
    static let shared = TranscriptionCoordinator()
    
    // MARK: - Published State
    @Published var isRecording = false
    @Published var partialTranscript = ""
    @Published var lastTranscript = ""
    @Published var errorMessage: String?
    
    // MARK: - Components
    private let audioRecorder = AudioRecorder()
    private let scribeService = ScribeService()
    
    // MARK: - Settings
    var languageCode: String? = nil  // nil = auto-detect
    var waitForSilence: Bool {
        get { UserDefaults.standard.bool(forKey: "waitForSilence") }
        set { UserDefaults.standard.set(newValue, forKey: "waitForSilence") }
    }
    
    // VAD is enabled when waitForSilence is true (can be inverted per-recording)
    private var useVAD: Bool { waitForSilence }
    
    // Track whether current recording uses VAD (for proper stop handling)
    private var currentRecordingUsesVAD = false
    
    private init() {
        setupAudioRecorder()
        setupScribeService()
    }
    
    // MARK: - Public Interface
    
    /// Toggle recording on/off
    /// - Parameter invertSilence: If true, invert the wait-for-silence setting for this recording
    func toggleRecording(invertSilence: Bool = false) {
        if isRecording {
            stopRecording()
        } else {
            startRecording(invertSilence: invertSilence)
        }
    }
    
    /// Start recording and transcription
    /// - Parameter invertSilence: If true, invert the wait-for-silence setting
    func startRecording(invertSilence: Bool = false) {
        guard !isRecording else { return }
        
        // Get API key
        guard let apiKey = KeychainManager.shared.getElevenLabsKey(), !apiKey.isEmpty else {
            errorMessage = "ElevenLabs API key not set. Go to Settings to add it."
            SoundPlayer.shared.playErrorSound()
            print("❌ No ElevenLabs API key")
            return
        }
        
        // Reset state
        partialTranscript = ""
        lastTranscript = ""
        errorMessage = nil
        
        // Determine if we should use VAD (invert if requested)
        currentRecordingUsesVAD = invertSilence ? !useVAD : useVAD
        
        // Configure VAD
        var vadConfig = ScribeService.VADConfig()
        vadConfig.enabled = currentRecordingUsesVAD
        
        // Read silence duration from settings (minimum: 1 second)
        let silenceDuration = UserDefaults.standard.double(forKey: "silenceDuration")
        vadConfig.silenceThresholdSecs = max(silenceDuration, 1.0)  // At least 1 second
        vadConfig.vadThreshold = 0.35  // More forgiving of background noise
        
        // Connect to Scribe with VAD config
        scribeService.connect(apiKey: apiKey, languageCode: languageCode, vadConfig: vadConfig)
        
        // Play different start sound based on mode
        if currentRecordingUsesVAD {
            SoundPlayer.shared.playStartSound()  // Normal beep for auto-stop
        } else {
            SoundPlayer.shared.playManualModeSound()  // Different sound for manual stop
        }
        
        let modeDesc = currentRecordingUsesVAD ? "auto-stop on silence" : "manual stop only"
        print("🎙️ Starting transcription (\(modeDesc))...")
    }
    
    /// Stop recording and get final transcript
    func stopRecording() {
        guard isRecording else { return }
        
        // Stop audio recording (this will send remaining buffer)
        audioRecorder.stopRecording()
        
        // Commit the transcript to get final result
        scribeService.commit()
        
        print("🛑 Stopping transcription...")
    }
    
    // MARK: - Setup
    
    private func setupAudioRecorder() {
        audioRecorder.delegate = self
    }
    
    private func setupScribeService() {
        scribeService.onSessionStarted = { [weak self] in
            DispatchQueue.main.async {
                // Session is ready, start recording audio
                do {
                    try self?.audioRecorder.startRecording()
                    self?.isRecording = true
                } catch {
                    self?.errorMessage = error.localizedDescription
                    self?.scribeService.disconnect()
                    SoundPlayer.shared.playErrorSound()
                }
            }
        }
        
        scribeService.onPartialTranscript = { [weak self] text in
            DispatchQueue.main.async {
                self?.partialTranscript = text
            }
        }
        
        scribeService.onCommittedTranscript = { [weak self] text in
            guard let self = self else { return }
            
            // Stop audio recorder first (important for VAD mode)
            self.audioRecorder.stopRecording()
            
            // Process through current mode (handles translation toggle internally)
            Task {
                do {
                    let processedText: String
                    
                    if text.isEmpty {
                        processedText = text
                    } else {
                        // ModeManager handles mode + translation in one call
                        processedText = try await ModeManager.shared.processText(text)
                    }
                    
                    await MainActor.run {
                        self.isRecording = false
                        self.errorMessage = nil
                        
                        // Parse email fields if present (for Email mode)
                        var emailSubject: String? = nil
                        var emailBody = processedText
                        var composeBodyFocused = false
                        
                        if ModeManager.shared.currentMode.id == "email" {
                            var lines = processedText.components(separatedBy: "\n")
                            
                            // Check for COMPOSE_BODY_FOCUSED line
                            if let firstLine = lines.first, firstLine.hasPrefix("COMPOSE_BODY_FOCUSED:") {
                                let value = String(firstLine.dropFirst("COMPOSE_BODY_FOCUSED:".count)).trimmingCharacters(in: .whitespaces).uppercased()
                                composeBodyFocused = value == "YES"
                                lines = Array(lines.dropFirst())
                                print("📧 Compose body focused: \(composeBodyFocused)")
                            }
                            
                            // Skip blank lines
                            lines = lines.drop(while: { $0.trimmingCharacters(in: .whitespaces).isEmpty }).map { $0 }
                            
                            // Check for SUBJECT line
                            if let firstLine = lines.first, firstLine.hasPrefix("SUBJECT:") {
                                emailSubject = String(firstLine.dropFirst("SUBJECT:".count)).trimmingCharacters(in: .whitespaces)
                                lines = Array(lines.dropFirst())
                                print("📧 Parsed subject: \(emailSubject ?? "none")")
                            }
                            
                            // Rest is body (skip leading blank lines)
                            emailBody = lines.drop(while: { $0.trimmingCharacters(in: .whitespaces).isEmpty })
                                .joined(separator: "\n")
                        }
                        
                        self.lastTranscript = emailBody
                        
                        // Copy body to clipboard (not subject)
                        if !emailBody.isEmpty {
                            ClipboardManager.shared.copyToClipboard(emailBody)
                            SoundPlayer.shared.playCompletionSound()
                            print("✅ Done!")
                            
                            // Execute any applicable hooks (e.g., Gmail auto-paste)
                            Task {
                                await HookManager.shared.executeHooks(
                                    text: emailBody,
                                    modeId: ModeManager.shared.currentMode.id,
                                    emailSubject: emailSubject,
                                    composeBodyFocused: composeBodyFocused
                                )
                            }
                        }
                        
                        // Disconnect
                        self.scribeService.disconnect()
                    }
                } catch {
                    await MainActor.run {
                        self.lastTranscript = text  // Fall back to raw text
                        self.errorMessage = error.localizedDescription
                        self.isRecording = false
                        ClipboardManager.shared.copyToClipboard(text)
                        SoundPlayer.shared.playErrorSound()
                        self.scribeService.disconnect()
                    }
                }
            }
        }
        
        scribeService.onError = { [weak self] error in
            DispatchQueue.main.async {
                self?.errorMessage = error.localizedDescription
                self?.isRecording = false
                self?.audioRecorder.stopRecording()
                SoundPlayer.shared.playErrorSound()
            }
        }
        
        scribeService.onConnectionClosed = { [weak self] in
            DispatchQueue.main.async {
                if self?.isRecording == true {
                    self?.isRecording = false
                    self?.audioRecorder.stopRecording()
                }
            }
        }
    }
}

// MARK: - AudioRecorderDelegate
extension TranscriptionCoordinator: AudioRecorderDelegate {
    func audioRecorder(_ recorder: AudioRecorder, didCaptureAudioData data: Data) {
        // Stream audio to Scribe
        scribeService.sendAudio(data)
    }
    
    func audioRecorderDidStartRecording(_ recorder: AudioRecorder) {
        print("🎙️ Audio capture started")
    }
    
    func audioRecorderDidStopRecording(_ recorder: AudioRecorder) {
        print("🎙️ Audio capture stopped")
    }
    
    func audioRecorder(_ recorder: AudioRecorder, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = error.localizedDescription
            self.isRecording = false
            self.scribeService.disconnect()
            SoundPlayer.shared.playErrorSound()
        }
    }
}
