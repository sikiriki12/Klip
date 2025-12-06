import Foundation

/// Raw mode - returns transcription as-is without processing
struct RawMode: TranscriptionMode {
    let id = "raw"
    let name = "Raw"
    let description = "No processing - raw transcription"
    let shortcutNumber = 1
    
    /// Raw mode has no system prompt (unless translate is enabled, handled by ModeManager)
    let systemPrompt = ""
}
