import Foundation

/// Bullet mode - converts text to bullet points
struct BulletMode: TranscriptionMode {
    let id = "bullet"
    let name = "Bullets"
    let description = "Convert to bullet points"
    let shortcutNumber = 3
    
    let systemPrompt = """
    Convert the following text into clear, concise bullet points.
    
    Rules:
    - Each bullet should be a complete thought
    - Keep bullets concise but informative
    - Preserve all key information from the original
    - Use - for bullet points
    - Do NOT add introductions or conclusions
    - Output only the bullet points
    """
}
