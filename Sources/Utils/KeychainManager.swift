import Foundation
import Security

/// Securely stores API keys in macOS Keychain
class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.klip.app"
    
    private init() {}
    
    // MARK: - API Key Storage
    
    /// Save ElevenLabs API key
    func saveElevenLabsKey(_ key: String) throws {
        try save(key: key, account: "elevenlabs_api_key")
    }
    
    /// Get ElevenLabs API key
    func getElevenLabsKey() -> String? {
        return get(account: "elevenlabs_api_key")
    }
    
    /// Save Gemini API key
    func saveGeminiKey(_ key: String) throws {
        try save(key: key, account: "gemini_api_key")
    }
    
    /// Get Gemini API key
    func getGeminiKey() -> String? {
        return get(account: "gemini_api_key")
    }
    
    // MARK: - Generic Keychain Operations
    
    private func save(key: String, account: String) throws {
        guard let data = key.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        
        // Delete existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Add new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        
        if status != errSecSuccess {
            throw KeychainError.saveFailed(status)
        }
        
        print("✅ Saved \(account) to Keychain")
    }
    
    private func get(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    /// Delete all stored keys
    func deleteAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
        print("🗑️ Deleted all Keychain items")
    }
}

enum KeychainError: Error, LocalizedError {
    case encodingFailed
    case saveFailed(OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode key"
        case .saveFailed(let status):
            return "Failed to save to Keychain: \(status)"
        }
    }
}
