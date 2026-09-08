import Foundation
import Security

enum SmartCastAuthToken {
    static func isValid(_ token: String) -> Bool {
        !token.isEmpty
            && token.utf8.count <= 1_024
            && token.utf8.allSatisfy({ (33...126).contains($0) })
    }
}

protocol TokenStoring: Sendable {
    func token(for deviceID: String) throws -> String?
    func save(_ token: String, for deviceID: String) throws
    func deleteToken(for deviceID: String) throws
    func deleteAll() throws
}

struct KeychainTokenStore: TokenStoring {
    private let service = "com.worksbienstudios.clearmote.smartcast"

    func token(for deviceID: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: deviceID,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8),
              SmartCastAuthToken.isValid(token) else {
            throw SmartCastError.securityStorageUnavailable
        }
        return token
    }

    func save(_ token: String, for deviceID: String) throws {
        guard SmartCastAuthToken.isValid(token),
              let data = token.data(using: .utf8) else {
            throw SmartCastError.securityStorageUnavailable
        }

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: deviceID
        ]
        let update: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw SmartCastError.network(String(localized: "The secure pairing key could not be saved."))
        }

        var addQuery = baseQuery
        update.forEach { addQuery[$0.key] = $0.value }
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SmartCastError.network(String(localized: "The secure pairing key could not be saved."))
        }
    }

    func deleteToken(for deviceID: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: deviceID
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SmartCastError.securityStorageUnavailable
        }
    }

    func deleteAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SmartCastError.securityStorageUnavailable
        }
    }
}
