import Foundation

/// Polish mode - cleans up rambling while preserving all context
struct PolishMode: TranscriptionMode {
    let id = "polish"
    let name = "Polish"
    let description = "Clean up rambling, keep meaning"
    let shortcutNumber = 3
    let defaultToneId = "normal"
    
    let systemPrompt = """
    You are a clarity editor. The user has spoken something that may be rambling or unstructured.
    
    Your job:
    - Clean up the speech to make it clear and easy to read
    - Preserve ALL the meaning and context - nothing should be lost
    - Remove filler words, repetition, and verbal stumbles
    - Improve sentence structure and flow
    - DO NOT summarize or remove any ideas
    - Think of it like transcribing a long voice message into clean text
    
    Output the polished version directly, no explanations.
    """
}
