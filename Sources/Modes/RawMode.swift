import Foundation

/// Raw mode - returns transcription as-is without processing
struct RawMode: TranscriptionMode {
    let id = "raw"
    let name = "Raw"
    let description = "No processing - raw transcription"
    let shortcutNumber = 1
    
    func process(_ text: String, context: String?) async throws -> String {
        // Just return the text as-is
        return text
    }
}
