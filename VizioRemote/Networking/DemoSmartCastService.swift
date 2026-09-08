import Foundation

actor DemoSmartCastService: SmartCastServicing {
    private(set) var commandLog: [String] = []

    func startPairing(with device: TVDevice) async throws -> PairingChallenge {
        try await pause()
        return PairingChallenge(requestToken: 246810, challengeType: 1, deviceID: "clearmote-demo")
    }

    func completePairing(
        with device: TVDevice,
        challenge: PairingChallenge,
        pin: String
    ) async throws -> String {
        try await pause()
        guard pin == "1234" else {
            throw SmartCastError.pairingDenied(String(localized: "Demo TV PIN is 1234."))
        }
        return "DEMO-AUTH-TOKEN"
    }

    func cancelPairing(with device: TVDevice, challenge: PairingChallenge) async {
        // The in-process demo has no external pairing state to cancel.
    }

    func discardPairingSecurityIdentity(for device: TVDevice) async {
        // The in-process demo has no certificate candidate.
    }

    func resetSecurityIdentity(for device: TVDevice) async throws {
        // The in-process demo has no certificate identity.
    }

    func resetAllSecurityData() async throws {
        // The in-process demo has no persisted security data.
    }

    func verify(device: TVDevice, authToken: String) async throws {
        try await pause(milliseconds: 120)
        guard authToken == "DEMO-AUTH-TOKEN" else {
            throw SmartCastError.authenticationRequired
        }
    }

    func send(_ command: RemoteCommand, to device: TVDevice, authToken: String) async throws {
        try await verify(device: device, authToken: authToken)
        commandLog.append(command.name)
    }

    func sendText(_ text: String, to device: TVDevice, authToken: String) async throws {
        try await verify(device: device, authToken: authToken)
        guard !text.isEmpty else { return }
        commandLog.append("Text: \(text)")
    }

    private func pause(milliseconds: UInt64 = 250) async throws {
        try await Task.sleep(nanoseconds: milliseconds * 1_000_000)
    }
}
