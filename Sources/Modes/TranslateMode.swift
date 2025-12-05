import Foundation

/// Translate mode - translates transcription to a target language
struct TranslateMode: TranscriptionMode {
    let id = "translate"
    let name = "Translate"
    let description = "Translate speech to another language"
    let shortcutNumber = 2
    
    /// Target language for translation (default: English)
    var targetLanguage: String {
        UserDefaults.standard.string(forKey: "targetLanguage") ?? "English"
    }
    
    func process(_ text: String, context: String?) async throws -> String {
        let systemInstruction = """
        You are a professional translator. Translate the following text to \(targetLanguage).
        
        Rules:
        - Provide ONLY the translation, no explanations or notes
        - Preserve the tone and style of the original
        - Keep proper nouns unchanged unless they have a standard translation
        - Maintain sentence structure where natural in the target language
        - If the text is already in \(targetLanguage), return it as-is with minor corrections if needed
        """
        
        let result = try await GeminiService.shared.generate(
            prompt: text,
            systemInstruction: systemInstruction
        )
        
        print("🌐 Translated to \(targetLanguage): \(result.prefix(50))...")
        return result
    }
}
