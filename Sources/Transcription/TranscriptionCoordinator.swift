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
    
    private init() {
        setupAudioRecorder()
        setupScribeService()
    }
    
    // MARK: - Public Interface
    
    /// Toggle recording on/off
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    /// Start recording and transcription
    func startRecording() {
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
        
        // Connect to Scribe
        scribeService.connect(apiKey: apiKey, languageCode: languageCode)
        
        // Play start sound
        SoundPlayer.shared.playStartSound()
        
        print("🎙️ Starting transcription...")
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
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.lastTranscript = text
                self.isRecording = false
                
                // Copy to clipboard
                if !text.isEmpty {
                    ClipboardManager.shared.copyToClipboard(text)
                    SoundPlayer.shared.playCompletionSound()
                    print("✅ Transcription complete!")
                }
                
                // Disconnect
                self.scribeService.disconnect()
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
