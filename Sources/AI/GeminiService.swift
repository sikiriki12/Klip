import Foundation

/// Service for interacting with Google Gemini API
class GeminiService {
    static let shared = GeminiService()
    
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
    
    private init() {}
    
    /// Generate text using Gemini
    /// - Parameters:
    ///   - prompt: The user prompt
    ///   - systemInstruction: System instruction for the model
    ///   - imageData: Optional JPEG image data to include
    /// - Returns: Generated text response
    func generate(prompt: String, systemInstruction: String, imageData: Data? = nil) async throws -> String {
        guard let apiKey = KeychainManager.shared.getGeminiKey(), !apiKey.isEmpty else {
            throw GeminiError.noAPIKey
        }
        
        let url = URL(string: "\(baseURL)?key=\(apiKey)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build parts array
        var parts: [[String: Any]] = []
        
        // Add image if provided
        if let imageData = imageData {
            let base64Image = imageData.base64EncodedString()
            parts.append([
                "inlineData": [
                    "mimeType": "image/jpeg",
                    "data": base64Image
                ]
            ])
            print("📷 Including image in request (\(imageData.count / 1024)KB)")
        }
        
        // Add text prompt
        parts.append(["text": prompt])
        
        // Build request body
        let requestBody: [String: Any] = [
            "contents": [
                ["parts": parts]
            ],
            "systemInstruction": [
                "parts": [
                    ["text": systemInstruction]
                ]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "topP": 0.95,
                "maxOutputTokens": 2048
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check response status
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            // Try to parse error message
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw GeminiError.apiError(message)
            }
            throw GeminiError.apiError("HTTP \(httpResponse.statusCode)")
        }
        
        // Parse response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw GeminiError.parseError
        }
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Errors
enum GeminiError: Error, LocalizedError {
    case noAPIKey
    case invalidResponse
    case apiError(String)
    case parseError
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "Gemini API key not set. Go to Settings to add it."
        case .invalidResponse:
            return "Invalid response from Gemini API"
        case .apiError(let message):
            return "Gemini API error: \(message)"
        case .parseError:
            return "Failed to parse Gemini response"
        }
    }
}
