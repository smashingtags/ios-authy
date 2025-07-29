import Foundation
import Security

protocol KeychainManagerProtocol {
    func store<T: Codable>(_ item: T, forKey key: String) throws
    func retrieve<T: Codable>(_ type: T.Type, forKey key: String) throws -> T?
    func delete(forKey key: String) throws
    func deleteAll() throws
}

class KeychainManager: KeychainManagerProtocol {
    private let service: String
    
    init(service: String = Bundle.main.bundleIdentifier ?? "IdentityProviderAuth") {
        self.service = service
    }
    
    func store<T: Codable>(_ item: T, forKey key: String) throws {
        let data = try JSONEncoder().encode(item)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw AuthenticationError.keychainError(status)
        }
    }
    
    func retrieve<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            throw AuthenticationError.keychainError(status)
        }
        
        guard let data = result as? Data else {
            throw AuthenticationError.keychainError(errSecInvalidData)
        }
        
        return try JSONDecoder().decode(type, from: data)
    }
    
    func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AuthenticationError.keychainError(status)
        }
    }
    
    func deleteAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AuthenticationError.keychainError(status)
        }
    }
}

// MARK: - Keychain Keys

extension KeychainManager {
    enum Keys {
        static let authTokens = "auth_tokens"
        static let user = "user"
        static let selectedProvider = "selected_provider"
    }
}