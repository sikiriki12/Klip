import AVFoundation
import Foundation

/// Callback protocol for audio recording events
protocol AudioRecorderDelegate: AnyObject {
    func audioRecorder(_ recorder: AudioRecorder, didCaptureAudioData data: Data)
    func audioRecorderDidStartRecording(_ recorder: AudioRecorder)
    func audioRecorderDidStopRecording(_ recorder: AudioRecorder)
    func audioRecorder(_ recorder: AudioRecorder, didFailWithError error: Error)
}

/// Records audio from the microphone in PCM format suitable for Scribe v2
class AudioRecorder: NSObject {
    weak var delegate: AudioRecorderDelegate?
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var isRecording = false
    
    // Scribe v2 requires: 16kHz, 16-bit, mono PCM
    private let targetSampleRate: Double = 16000
    private let targetChannels: AVAudioChannelCount = 1
    
    // Buffer for accumulating audio data
    private var audioBuffer = Data()
    private let chunkSize = 3200 // 100ms of audio at 16kHz (16000 * 0.1 * 2 bytes)
    
    var recording: Bool {
        return isRecording
    }
    
    override init() {
        super.init()
    }
    
    /// Start recording audio from the microphone
    func startRecording() throws {
        guard !isRecording else { return }
        
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw AudioRecorderError.engineCreationFailed
        }
        
        inputNode = audioEngine.inputNode
        guard let inputNode = inputNode else {
            throw AudioRecorderError.inputNodeUnavailable
        }
        
        // Get the native format
        let nativeFormat = inputNode.outputFormat(forBus: 0)
        print("📊 Native format: \(nativeFormat.sampleRate)Hz, \(nativeFormat.channelCount) channels")
        
        // Create target format (16kHz, mono, PCM Int16)
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: targetSampleRate,
            channels: targetChannels,
            interleaved: true
        ) else {
            throw AudioRecorderError.formatCreationFailed
        }
        
        // Create a converter
        guard let converter = AVAudioConverter(from: nativeFormat, to: targetFormat) else {
            throw AudioRecorderError.converterCreationFailed
        }
        
        // Install tap on input node
        let bufferSize: AVAudioFrameCount = 1024
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: nativeFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, converter: converter, targetFormat: targetFormat)
        }
        
        // Start the audio engine
        audioEngine.prepare()
        try audioEngine.start()
        
        isRecording = true
        audioBuffer = Data()
        
        print("🎙️ Recording started")
        delegate?.audioRecorderDidStartRecording(self)
    }
    
    /// Stop recording audio
    func stopRecording() {
        guard isRecording else { return }
        
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        isRecording = false
        
        // Send any remaining buffered audio
        if !audioBuffer.isEmpty {
            delegate?.audioRecorder(self, didCaptureAudioData: audioBuffer)
            audioBuffer = Data()
        }
        
        print("🛑 Recording stopped")
        delegate?.audioRecorderDidStopRecording(self)
    }
    
    /// Process incoming audio buffer
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter, targetFormat: AVAudioFormat) {
        // Calculate output frame count based on sample rate conversion
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outputFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCount) else {
            return
        }
        
        var error: NSError?
        var inputConsumed = false
        
        let status = converter.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
            if inputConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputConsumed = true
            outStatus.pointee = .haveData
            return buffer
        }
        
        guard status != .error, error == nil else {
            print("❌ Conversion error: \(error?.localizedDescription ?? "unknown")")
            return
        }
        
        // Extract PCM data from the buffer
        guard let int16Data = outputBuffer.int16ChannelData else { return }
        let frameCount = Int(outputBuffer.frameLength)
        let data = Data(bytes: int16Data[0], count: frameCount * 2)  // 2 bytes per Int16 sample
        
        // Accumulate data
        audioBuffer.append(data)
        
        // Send chunks when we have enough data
        while audioBuffer.count >= chunkSize {
            let chunk = audioBuffer.prefix(chunkSize)
            delegate?.audioRecorder(self, didCaptureAudioData: Data(chunk))
            audioBuffer = Data(audioBuffer.dropFirst(chunkSize))
        }
    }
}

enum AudioRecorderError: Error, LocalizedError {
    case engineCreationFailed
    case inputNodeUnavailable
    case formatCreationFailed
    case converterCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .engineCreationFailed:
            return "Failed to create audio engine"
        case .inputNodeUnavailable:
            return "Microphone input not available"
        case .formatCreationFailed:
            return "Failed to create audio format"
        case .converterCreationFailed:
            return "Failed to create audio converter"
        }
    }
}
