import Foundation

/// WebSocket-based client for ElevenLabs Scribe v2 real-time transcription
class ScribeService: NSObject {
    
    // MARK: - Callbacks
    var onPartialTranscript: ((String) -> Void)?
    var onCommittedTranscript: ((String) -> Void)?
    var onError: ((Error) -> Void)?
    var onSessionStarted: (() -> Void)?
    var onConnectionClosed: (() -> Void)?
    
    // MARK: - Properties
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var apiKey: String?
    private var languageCode: String?
    private var isConnected = false
    private var isDisconnecting = false  // Track intentional disconnect
    
    // Configuration
    private let modelId = "scribe_v2_realtime"
    private let sampleRate = 16000
    
    // MARK: - Initialization
    override init() {
        super.init()
    }
    
    // MARK: - Connection Management
    
    /// VAD Configuration
    struct VADConfig {
        var enabled: Bool = false
        var silenceThresholdSecs: Double = 2.0     // Wait 2 seconds of silence before commit
        var vadThreshold: Double = 0.35             // Lower = more sensitive (0.1-0.9)
        var minSpeechDurationMs: Int = 100
        var minSilenceDurationMs: Int = 100
    }
    
    /// Connect to Scribe v2 WebSocket API
    func connect(apiKey: String, languageCode: String? = nil, vadConfig: VADConfig = VADConfig()) {
        self.apiKey = apiKey
        self.languageCode = languageCode
        self.isDisconnecting = false
        
        // Build WebSocket URL with query parameters
        var urlComponents = URLComponents(string: "wss://api.elevenlabs.io/v1/speech-to-text/realtime")!
        var queryItems = [
            URLQueryItem(name: "model_id", value: modelId),
            URLQueryItem(name: "audio_format", value: "pcm_16000"),
            URLQueryItem(name: "include_timestamps", value: "false")
        ]
        
        // Set commit strategy based on VAD config
        if vadConfig.enabled {
            queryItems.append(URLQueryItem(name: "commit_strategy", value: "vad"))
            queryItems.append(URLQueryItem(name: "vad_silence_threshold_secs", value: String(vadConfig.silenceThresholdSecs)))
            queryItems.append(URLQueryItem(name: "vad_threshold", value: String(vadConfig.vadThreshold)))
            queryItems.append(URLQueryItem(name: "min_speech_duration_ms", value: String(vadConfig.minSpeechDurationMs)))
            queryItems.append(URLQueryItem(name: "min_silence_duration_ms", value: String(vadConfig.minSilenceDurationMs)))
            print("🎙️ Using VAD mode (silence: \(vadConfig.silenceThresholdSecs)s, threshold: \(vadConfig.vadThreshold))")
        } else {
            queryItems.append(URLQueryItem(name: "commit_strategy", value: "manual"))
            print("🎙️ Using manual commit mode")
        }
        
        if let languageCode = languageCode, !languageCode.isEmpty {
            queryItems.append(URLQueryItem(name: "language_code", value: languageCode))
        }
        
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            onError?(ScribeError.invalidURL)
            return
        }
        
        // Create request with API key header
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        
        // Create session and WebSocket task
        let configuration = URLSessionConfiguration.default
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
        webSocket = urlSession?.webSocketTask(with: request)
        
        // Start receiving messages
        receiveMessage()
        
        // Connect
        webSocket?.resume()
        print("🔌 Connecting to Scribe v2...")
    }
    
    /// Disconnect from WebSocket
    func disconnect() {
        isDisconnecting = true  // Mark as intentional disconnect
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        urlSession = nil
        isConnected = false
        print("🔌 Disconnected from Scribe v2")
    }
    
    // MARK: - Audio Streaming
    
    /// Send audio chunk to Scribe
    func sendAudio(_ audioData: Data) {
        // Silently ignore if disconnected or disconnecting
        guard isConnected && !isDisconnecting else {
            return
        }
        
        // Encode audio as base64
        let base64Audio = audioData.base64EncodedString()
        
        // Create message payload
        let message: [String: Any] = [
            "message_type": "input_audio_chunk",
            "audio_base_64": base64Audio,
            "commit": false,
            "sample_rate": sampleRate
        ]
        
        sendJSON(message)
    }
    
    /// Commit the current transcript segment
    func commit() {
        guard isConnected else { return }
        
        let message: [String: Any] = [
            "message_type": "input_audio_chunk",
            "audio_base_64": "",
            "commit": true,
            "sample_rate": sampleRate
        ]
        
        sendJSON(message)
        print("📝 Committed transcript segment")
    }
    
    // MARK: - Private Methods
    
    private func sendJSON(_ dictionary: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary),
              let string = String(data: data, encoding: .utf8) else {
            return
        }
        
        let message = URLSessionWebSocketTask.Message.string(string)
        webSocket?.send(message) { error in
            if let error = error {
                print("❌ WebSocket send error: \(error.localizedDescription)")
            }
        }
    }
    
    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                self.handleMessage(message)
                // Continue receiving
                self.receiveMessage()
                
            case .failure(let error):
                // Only report error if not intentionally disconnecting
                if !self.isDisconnecting {
                    print("❌ WebSocket receive error: \(error.localizedDescription)")
                    self.onError?(error)
                }
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            parseMessage(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                parseMessage(text)
            }
        @unknown default:
            break
        }
    }
    
    private func parseMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messageType = json["message_type"] as? String else {
            return
        }
        
        switch messageType {
        case "session_started":
            print("✅ Scribe session started")
            isConnected = true
            onSessionStarted?()
            
        case "partial_transcript":
            if let transcript = json["text"] as? String {
                print("📝 Partial: \(transcript)")
                onPartialTranscript?(transcript)
            }
            
        case "committed_transcript":
            if let transcript = json["text"] as? String {
                print("✅ Committed: \(transcript)")
                onCommittedTranscript?(transcript)
            }
            
        case "committed_transcript_with_timestamps":
            if let transcript = json["text"] as? String {
                print("✅ Committed (with timestamps): \(transcript)")
                onCommittedTranscript?(transcript)
            }
            
        case "input_error", "auth_error", "transcriber_error", "error":
            let errorMessage = json["message"] as? String ?? "Unknown error"
            print("❌ Scribe error: \(errorMessage)")
            onError?(ScribeError.serverError(errorMessage))
            
        default:
            print("📨 Unknown message type: \(messageType)")
        }
    }
}

// MARK: - URLSessionWebSocketDelegate
extension ScribeService: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("🔌 WebSocket connected")
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("🔌 WebSocket closed with code: \(closeCode.rawValue)")
        isConnected = false
        onConnectionClosed?()
    }
}

// MARK: - Errors
enum ScribeError: Error, LocalizedError {
    case invalidURL
    case connectionFailed
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid WebSocket URL"
        case .connectionFailed:
            return "Failed to connect to Scribe"
        case .serverError(let message):
            return "Scribe error: \(message)"
        }
    }
}
