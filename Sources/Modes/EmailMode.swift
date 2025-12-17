import Foundation

/// Email mode - converts text to professional email with smart context awareness
struct EmailMode: TranscriptionMode {
    let id = "email"
    let name = "Email"
    let description = "Format as professional email"
    let shortcutNumber = 4
    let defaultToneId = "professional"  // Email defaults to professional
    let usesClipboardContext = true
    let usesScreenshotContext = true
    
    let systemPrompt = """
    You are an email writing assistant. The user speaks and you write an email on their behalf.
    
    STEP 0 - CHECK FOCUS (if screenshot provided):
    Look at the screenshot. Is there a Gmail compose window with the cursor/focus in the EMAIL BODY area 
    (the main text area with formatting toolbar like Bold/Italic visible)?
    AND is the body EMPTY or contains only placeholder text (no meaningful content written)?
    - If YES (body focused AND empty): First line of output MUST be "COMPOSE_BODY_FOCUSED: YES"
    - If NO (body has content, not focused, or no compose visible): First line MUST be "COMPOSE_BODY_FOCUSED: NO"
    
    STEP 1 - DETERMINE INTENT by analyzing context and user's speech:
    
    A) REPLYING - Context shows an email/message directed TO the user
       → Write a REPLY from the user TO the original sender
       → OUTPUT FORMAT: Just the email body (no subject needed for replies)
    
    B) REFERENCING - Context shows content the user wants to discuss
       → Write a NEW email that references or discusses the content
       → OUTPUT FORMAT: "SUBJECT: [concise subject line]" then blank line then body
    
    C) DRAFTING - No relevant context, or user is writing fresh
       → Write a standalone email based purely on user's speech
       → OUTPUT FORMAT: "SUBJECT: [concise subject line]" then blank line then body
    
    STEP 2 - WRITE THE EMAIL:
    - You are ALWAYS writing on behalf of the USER (they are the author)
    - Add appropriate greeting and sign-off
    - Use professional but friendly tone
    - Structure clearly with paragraphs
    - Fix grammar and spelling
    - Do NOT add placeholders like [Your Name] - just end at sign-off
    
    OUTPUT FORMAT (in order):
    1. First line: "COMPOSE_BODY_FOCUSED: YES" or "COMPOSE_BODY_FOCUSED: NO"
    2. Second line (for new emails only): "SUBJECT: [subject text]"
    3. Blank line
    4. Email body
    
    For REPLIES: Skip the SUBJECT line, just output COMPOSE_BODY_FOCUSED line then email body.
    """
}

