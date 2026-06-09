import Foundation
import Security

enum APIKeyStoreError: LocalizedError {
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            return "Keychain returned status \(status)."
        }
    }
}

enum APIKeyStore {
    private static let service = "com.bookme.ConsoleMac.api"

    static var openAIAPIKeyExists: Bool {
        apiKeyExists(for: .openAI)
    }

    static func loadOpenAIAPIKey() throws -> String? {
        try loadAPIKey(for: .openAI)
    }

    static func saveOpenAIAPIKey(_ apiKey: String) throws {
        try saveAPIKey(apiKey, for: .openAI)
    }

    static func deleteOpenAIAPIKey() {
        deleteAPIKey(for: .openAI)
    }

    static func apiKeyExists(for provider: APIProvider) -> Bool {
        (try? loadAPIKey(for: provider))?.isEmpty == false
    }

    static func loadAPIKey(for provider: APIProvider) throws -> String? {
        var query = baseQuery(account: provider.keychainAccount)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw APIKeyStoreError.unexpectedStatus(status)
        }

        guard let data = item as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    static func saveAPIKey(_ apiKey: String, for provider: APIProvider) throws {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedKey.isEmpty == false else {
            deleteAPIKey(for: provider)
            return
        }

        let data = Data(trimmedKey.utf8)
        var query = baseQuery(account: provider.keychainAccount)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        guard updateStatus == errSecItemNotFound else {
            throw APIKeyStoreError.unexpectedStatus(updateStatus)
        }

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw APIKeyStoreError.unexpectedStatus(addStatus)
        }
    }

    static func deleteAPIKey(for provider: APIProvider) {
        let query = baseQuery(account: provider.keychainAccount)
        SecItemDelete(query as CFDictionary)
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
