import Foundation
import Security

protocol DeviceStoring: Sendable {
    func loadDevice() throws -> TVDevice?
    func saveDevice(_ device: TVDevice) throws
    func clearDevice() throws
}

struct DeviceStore: DeviceStoring {
    private let service = "com.worksbienstudios.clearmote.smartcast.device"
    private let account = "selected-device"
    private let legacyDefaultsKey = "saved.smartcast.device.v1"

    func loadDevice() throws -> TVDevice? {
        var result: CFTypeRef?
        let status = SecItemCopyMatching(readQuery as CFDictionary, &result)
        if status == errSecItemNotFound {
            return try migrateLegacyDeviceIfPresent()
        }
        guard status == errSecSuccess,
              let data = result as? Data,
              let device = try? JSONDecoder().decode(TVDevice.self, from: data),
              device.isValidForPersistence else {
            if status == errSecSuccess { try? clearDevice() }
            throw SmartCastError.securityStorageUnavailable
        }
        return device
    }

    func saveDevice(_ device: TVDevice) throws {
        guard device.isValidForPersistence else { throw SmartCastError.unsupportedAddress }
        let data = try JSONEncoder().encode(device)
        let update: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
        if updateStatus != errSecSuccess {
            guard updateStatus == errSecItemNotFound else {
                throw SmartCastError.securityStorageUnavailable
            }
            var add = baseQuery
            update.forEach { add[$0.key] = $0.value }
            guard SecItemAdd(add as CFDictionary, nil) == errSecSuccess else {
                throw SmartCastError.securityStorageUnavailable
            }
        }
        UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
    }

    func clearDevice() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SmartCastError.securityStorageUnavailable
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private var readQuery: [String: Any] {
        baseQuery.merging([
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]) { current, _ in current }
    }

    private func migrateLegacyDeviceIfPresent() throws -> TVDevice? {
        guard let data = UserDefaults.standard.data(forKey: legacyDefaultsKey) else { return nil }
        guard let device = try? JSONDecoder().decode(TVDevice.self, from: data),
              device.isValidForPersistence else {
            UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
            return nil
        }
        try saveDevice(device)
        return device
    }
}

extension TVDevice {
    var isValidForPersistence: Bool {
        guard !name.isEmpty, name.count <= 128 else { return false }
        if isDemo {
            return id == TVDevice.demo.id && host == TVDevice.demo.host && port == TVDevice.demo.port
        }
        guard LocalNetworkAddress.isPrivateHost(host),
              LocalNetworkAddress.isSupportedSmartCastPort(port) else { return false }
        return id == "smartcast-\(host):\(port)"
    }
}
