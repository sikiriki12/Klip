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
    
    // Configuration
    private let modelId = "scribe_v2_realtime"
    private let sampleRate = 16000
    
    // MARK: - Initialization
    override init() {
        super.init()
    }
    
    // MARK: - Connection Management
    
    /// Connect to Scribe v2 WebSocket API
    func connect(apiKey: String, languageCode: String? = nil) {
        self.apiKey = apiKey
        self.languageCode = languageCode
        
        // Build WebSocket URL with query parameters
        var urlComponents = URLComponents(string: "wss://api.elevenlabs.io/v1/speech-to-text/realtime")!
        var queryItems = [
            URLQueryItem(name: "model_id", value: modelId),
            URLQueryItem(name: "audio_format", value: "pcm_16000"),
            URLQueryItem(name: "commit_strategy", value: "manual"),  // We'll commit on stop
            URLQueryItem(name: "include_timestamps", value: "false")
        ]
        
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
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        urlSession = nil
        isConnected = false
        print("🔌 Disconnected from Scribe v2")
    }
    
    // MARK: - Audio Streaming
    
    /// Send audio chunk to Scribe
    func sendAudio(_ audioData: Data) {
        guard isConnected else {
            print("⚠️ Cannot send audio - not connected")
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
            switch result {
            case .success(let message):
                self?.handleMessage(message)
                // Continue receiving
                self?.receiveMessage()
                
            case .failure(let error):
                print("❌ WebSocket receive error: \(error.localizedDescription)")
                self?.onError?(error)
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
