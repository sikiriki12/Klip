import Foundation
import Security

/// Securely stores API keys - supports both Keychain (secure) and UserDefaults (dev mode)
class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.klip.app"
    
    /// Whether to use Keychain (true) or UserDefaults (false)
    var useKeychain: Bool {
        get {
            // Default to true (Keychain) if not set
            if UserDefaults.standard.object(forKey: "useKeychainStorage") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "useKeychainStorage")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "useKeychainStorage")
        }
    }
    
    private init() {}
    
    // MARK: - API Key Storage
    
    /// Save ElevenLabs API key
    func saveElevenLabsKey(_ key: String) throws {
        if useKeychain {
            try saveToKeychain(key: key, account: "elevenlabs_api_key")
        } else {
            saveToUserDefaults(key: key, account: "elevenlabs_api_key")
        }
    }
    
    /// Get ElevenLabs API key
    func getElevenLabsKey() -> String? {
        if useKeychain {
            return getFromKeychain(account: "elevenlabs_api_key")
        } else {
            return getFromUserDefaults(account: "elevenlabs_api_key")
        }
    }
    
    /// Save Gemini API key
    func saveGeminiKey(_ key: String) throws {
        if useKeychain {
            try saveToKeychain(key: key, account: "gemini_api_key")
        } else {
            saveToUserDefaults(key: key, account: "gemini_api_key")
        }
    }
    
    /// Get Gemini API key
    func getGeminiKey() -> String? {
        if useKeychain {
            return getFromKeychain(account: "gemini_api_key")
        } else {
            return getFromUserDefaults(account: "gemini_api_key")
        }
    }
    
    // MARK: - UserDefaults Storage (Dev Mode)
    
    private func saveToUserDefaults(key: String, account: String) {
        UserDefaults.standard.set(key, forKey: "apikey_\(account)")
        print("✅ Saved \(account) to UserDefaults (dev mode)")
    }
    
    private func getFromUserDefaults(account: String) -> String? {
        return UserDefaults.standard.string(forKey: "apikey_\(account)")
    }
    
    // MARK: - Keychain Storage (Secure)
    
    private func saveToKeychain(key: String, account: String) throws {
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
    
    private func getFromKeychain(account: String) -> String? {
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
        // Delete from Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
        
        // Delete from UserDefaults
        UserDefaults.standard.removeObject(forKey: "apikey_elevenlabs_api_key")
        UserDefaults.standard.removeObject(forKey: "apikey_gemini_api_key")
        
        print("🗑️ Deleted all stored keys")
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
