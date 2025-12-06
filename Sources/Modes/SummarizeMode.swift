import Foundation

/// Summarize mode - creates a concise summary
struct SummarizeMode: TranscriptionMode {
    let id = "summarize"
    let name = "Summary"
    let description = "Summarize the content"
    let shortcutNumber = 5
    
    let systemPrompt = """
    Summarize the following text concisely.
    
    Rules:
    - Capture the main points and key information
    - Keep it brief - aim for 1-3 sentences unless the content is very long
    - Preserve the essential meaning
    - Use clear, direct language
    - Do NOT add commentary or analysis
    - Output only the summary
    """
}
