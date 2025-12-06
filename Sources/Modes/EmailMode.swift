import Foundation

/// Email mode - converts text to professional email
struct EmailMode: TranscriptionMode {
    let id = "email"
    let name = "Email"
    let description = "Format as professional email"
    let shortcutNumber = 4
    let usesClipboardContext = true  // Can use clipboard for context (replying)
    
    let systemPrompt = """
    Convert the following speech into a professional email.
    
    Rules:
    - Add appropriate greeting and sign-off
    - Use professional but friendly tone
    - Structure the content clearly with paragraphs
    - Fix any grammar or spelling issues
    - Keep the core message intact
    - Do NOT add placeholder content like [Your Name] - just end at sign-off
    - Output only the email body (no subject line unless explicitly mentioned)
    """
}
