import Foundation

/// Represents a tone that influences output style
struct Tone: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let promptModifier: String
    let isBuiltIn: Bool
    
    static let builtInTones: [Tone] = [
        Tone(id: "informal", name: "Informal", promptModifier: "Use casual, conversational, friendly language.", isBuiltIn: true),
        Tone(id: "normal", name: "Normal", promptModifier: "", isBuiltIn: true),  // No modifier
        Tone(id: "professional", name: "Professional", promptModifier: "Use professional, formal business language.", isBuiltIn: true),
        Tone(id: "legal", name: "Legal", promptModifier: "Use precise legal language, formal, unambiguous, like a lawyer would speak.", isBuiltIn: true)
    ]
    
    /// Default custom tone example
    static let genZTone = Tone(
        id: "genz",
        name: "Gen Z",
        promptModifier: "Use Gen Z slang, internet speak, and casual vibes. Be relatable and use modern expressions.",
        isBuiltIn: false
    )
}
