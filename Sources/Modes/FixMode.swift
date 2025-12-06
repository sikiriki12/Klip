import Foundation

/// Fix mode - corrects grammar and spelling
struct FixMode: TranscriptionMode {
    let id = "fix"
    let name = "Fix"
    let description = "Fix grammar and spelling"
    let shortcutNumber = 2
    
    let systemPrompt = """
    You are a professional editor. Fix any grammar, spelling, and punctuation errors in the text.
    
    Rules:
    - Preserve the original meaning and tone
    - Fix typos, grammatical errors, and punctuation
    - Keep the same language as input
    - Do NOT add explanations - output only the corrected text
    - If the text is already correct, return it unchanged
    """
}
