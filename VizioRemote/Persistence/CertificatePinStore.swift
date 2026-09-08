import Foundation
import Security

enum CertificatePinStatus {
    case missing
    case matches
    case mismatch
}

struct CertificatePinStoreError: Error {
    let status: OSStatus
}

protocol CertificatePinStoring: Sendable {
    func status(for certificate: Data, host: String, port: Int) throws -> CertificatePinStatus
    func store(_ certificate: Data, host: String, port: Int) throws
    func delete(host: String, port: Int) throws
    func deleteAll() throws
}

struct KeychainCertificatePinStore: CertificatePinStoring {
    private let service = "com.worksbienstudios.clearmote.smartcast.certificate"

    func status(for certificate: Data, host: String, port: Int) throws -> CertificatePinStatus {
        let query = baseQuery(account: "\(host):\(port)")
        var result: CFTypeRef?
        let readStatus = SecItemCopyMatching(readQuery(query) as CFDictionary, &result)
        if readStatus == errSecItemNotFound { return .missing }
        guard readStatus == errSecSuccess, let stored = result as? Data else {
            throw CertificatePinStoreError(status: readStatus)
        }
        return stored == certificate ? .matches : .mismatch
    }

    func store(_ certificate: Data, host: String, port: Int) throws {
        let query = baseQuery(account: "\(host):\(port)")
        let addQuery = query.merging([
            kSecValueData as String: certificate,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]) { current, _ in current }
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else { throw CertificatePinStoreError(status: status) }
    }

    func delete(host: String, port: Int) throws {
        let status = SecItemDelete(baseQuery(account: "\(host):\(port)") as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CertificatePinStoreError(status: status)
        }
    }

    func deleteAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CertificatePinStoreError(status: status)
        }
    }

    private func readQuery(_ query: [String: Any]) -> [String: Any] {
        query.merging([
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]) { current, _ in current }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
