import Foundation

struct TVDevice: Codable, Hashable, Identifiable, Sendable {
    let id: String
    var name: String
    let host: String
    let port: Int
    var isDemo: Bool

    init(
        id: String = UUID().uuidString,
        name: String,
        host: String,
        port: Int = 7345,
        isDemo: Bool = false
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.isDemo = isDemo
    }

    static let demo = TVDevice(
        id: "demo-smartcast-tv",
        name: String(localized: "Demo Living Room TV"),
        host: "demo.local",
        port: 7345,
        isDemo: true
    )
}

struct PairingChallenge: Sendable, Equatable {
    let requestToken: Int
    let challengeType: Int
    let deviceID: String
}

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case searching
    case pairing
    case connected
    case sending
    case failed(String)

    var label: String {
        switch self {
        case .disconnected: return String(localized: "Not connected")
        case .connecting: return String(localized: "Checking connection…")
        case .searching: return String(localized: "Searching…")
        case .pairing: return String(localized: "Pairing…")
        case .connected: return String(localized: "Connected")
        case .sending: return String(localized: "Sending…")
        case .failed: return String(localized: "Needs attention")
        }
    }
}

enum SmartCastError: LocalizedError, Equatable {
    case invalidAddress
    case unsupportedAddress
    case noDeviceFound
    case localNetworkUnavailable
    case malformedResponse
    case pairingDenied(String)
    case authenticationRequired
    case securityIdentityChanged
    case securityIdentityUnavailable
    case securityStorageUnavailable
    case tvRejected(String)
    case network(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidAddress:
            return String(localized: "Enter a valid local IP address, such as 192.168.1.25.")
        case .unsupportedAddress:
            return String(localized: "TV Remote accepts only canonical private IPv4 addresses on supported TV ports.")
        case .noDeviceFound:
            return String(localized: "No Vizio SmartCast TV was found. Confirm that the TV is on and both devices use the same Wi-Fi.")
        case .localNetworkUnavailable:
            return String(localized: "Local-network discovery is unavailable. Check Local Network permission, Wi-Fi, VPN and router isolation, then try again.")
        case .malformedResponse:
            return String(localized: "The television returned an unexpected response.")
        case .pairingDenied(let detail):
            return detail.isEmpty ? String(localized: "The PIN was not accepted.") : detail
        case .authenticationRequired:
            return String(localized: "This television needs to be paired again.")
        case .securityIdentityChanged:
            return String(localized: "The TV security identity changed. If you replaced or updated the TV, reset its saved security identity before pairing again.")
        case .securityIdentityUnavailable:
            return String(localized: "A secure TV connection could not be established. Reset the saved TV identity, then pair again on a network you trust.")
        case .securityStorageUnavailable:
            return String(localized: "The TV security identity could not be read or saved securely. Unlock this device and try again.")
        case .tvRejected(let detail):
            return detail.isEmpty ? String(localized: "The television did not accept that command.") : detail
        case .network(let detail):
            return detail
        case .cancelled:
            return String(localized: "The operation was cancelled.")
        }
    }
}
