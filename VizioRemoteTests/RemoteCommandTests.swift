import XCTest
@testable import VizioRemote

final class RemoteCommandTests: XCTestCase {
    func testCriticalCommandMappings() {
        XCTAssertEqual(RemoteCommand.up.codeSet, 3)
        XCTAssertEqual(RemoteCommand.up.code, 8)
        XCTAssertEqual(RemoteCommand.select.codeSet, 3)
        XCTAssertEqual(RemoteCommand.select.code, 2)
        XCTAssertEqual(RemoteCommand.volumeUp.codeSet, 5)
        XCTAssertEqual(RemoteCommand.volumeUp.code, 1)
        XCTAssertEqual(RemoteCommand.home.codeSet, 4)
        XCTAssertEqual(RemoteCommand.home.code, 15)
        XCTAssertEqual(RemoteCommand.pause.code, 2)
        XCTAssertEqual(RemoteCommand.play.code, 3)
        XCTAssertEqual(RemoteCommand.power.codeSet, 11)
        XCTAssertEqual(RemoteCommand.power.code, 2)
    }

    func testPayloadUsesSmartCastShape() throws {
        let data = try JSONSerialization.data(withJSONObject: RemoteCommand.left.payload)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let keys = try XCTUnwrap(object["KEYLIST"] as? [[String: Any]])
        XCTAssertEqual(keys.count, 1)
        XCTAssertEqual(keys[0]["CODESET"] as? Int, 3)
        XCTAssertEqual(keys[0]["CODE"] as? Int, 1)
        XCTAssertEqual(keys[0]["ACTION"] as? String, "KEYPRESS")
    }
}

@MainActor
final class RemoteViewModelLifecycleTests: XCTestCase {
    func testLocalMetadataCanBeManagedWithoutRemoteAccess() {
        let saved = TVDevice(id: "smartcast-192.168.1.8:7345", name: "Saved TV", host: "192.168.1.8", port: 7345)
        let model = makeModel(device: saved)

        model.restoreLocalDeviceMetadata()

        XCTAssertEqual(model.device, saved)
        XCTAssertEqual(model.connectionState, .disconnected)
    }

    func testRevokingAccessClosesSheetsAndResetsInFlightState() async {
        let discovery = CountingDiscovery()
        let model = makeModel(discovery: discovery)
        model.setRemoteAccessEnabled(true)
        model.showSettings = true
        model.discover()
        XCTAssertEqual(model.connectionState, .searching)

        model.setRemoteAccessEnabled(false)

        XCTAssertEqual(model.connectionState, .disconnected)
        XCTAssertFalse(model.showSettings)
        await Task.yield()
    }

    func testDiscoveryIsAllowedBeforeEntitlementForPairFirstOnboarding() async {
        let discovery = CountingDiscovery()
        let model = makeModel(discovery: discovery)

        model.discover()
        for _ in 0..<100 {
            if await discovery.callCount == 1 { break }
            await Task.yield()
        }

        let callCount = await discovery.callCount
        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(model.connectionState, .searching)
        model.suspend()
    }

    func testRemovalBlocksNewNetworkAndPairingEntryPoints() {
        let discovery = CountingDiscovery()
        let saved = TVDevice(id: "smartcast-192.168.1.8:7345", name: "Saved TV", host: "192.168.1.8", port: 7345)
        let model = makeModel(discovery: discovery, device: saved)
        model.setRemoteAccessEnabled(true)

        model.removeAllSavedTVData()
        XCTAssertTrue(model.isManagingLocalData)

        model.discover()
        model.connectManually(ipAddress: "192.168.1.9", legacyPort: false)
        model.beginPairing(with: TVDevice(id: "smartcast-192.168.1.10:7345", name: "Other", host: "192.168.1.10"))

        XCTAssertEqual(model.connectionState, .disconnected)
        XCTAssertTrue(model.discoveredDevices.isEmpty)
        XCTAssertNil(model.pairingChallenge)
    }

    func testPersistedDeviceIDMustMatchCanonicalEndpoint() {
        let valid = TVDevice(id: "smartcast-192.168.1.8:7345", name: "TV", host: "192.168.1.8", port: 7345)
        let mismatched = TVDevice(id: "smartcast-192.168.1.9:7345", name: "TV", host: "192.168.1.8", port: 7345)
        let publicHost = TVDevice(id: "smartcast-8.8.8.8:7345", name: "TV", host: "8.8.8.8", port: 7345)

        XCTAssertTrue(valid.isValidForPersistence)
        XCTAssertFalse(mismatched.isValidForPersistence)
        XCTAssertFalse(publicHost.isValidForPersistence)
        XCTAssertTrue(TVDevice.demo.isValidForPersistence)
    }

    func testThousandCommandBurstIsBoundedToTwelveAcceptedActions() async {
        let service = CountingCommandService()
        let model = makeModel(realService: service, demoService: service)
        model.setRemoteAccessEnabled(true)
        model.beginPairing(with: .demo)

        for _ in 0..<100 where model.pairingChallenge == nil { await Task.yield() }
        XCTAssertNotNil(model.pairingChallenge)
        model.finishPairing(pin: "1234")
        for _ in 0..<100 where model.connectionState != .connected { await Task.yield() }
        XCTAssertEqual(model.connectionState, .connected)

        for _ in 0..<1_000 { model.send(.volumeUp) }
        XCTAssertEqual(
            model.alertMessage,
            String(localized: "The TV is still processing earlier commands. Please wait a moment.")
        )

        for _ in 0..<1_000 {
            if await service.sendCount == 12 { break }
            await Task.yield()
        }
        let acceptedCount = await service.sendCount
        XCTAssertEqual(acceptedCount, 12)
    }

    private func makeModel(
        discovery: TVDiscovering = CountingDiscovery(),
        device: TVDevice? = nil,
        realService: SmartCastServicing = NoopSmartCastService(),
        demoService: SmartCastServicing = NoopSmartCastService()
    ) -> RemoteViewModel {
        RemoteViewModel(
            discovery: discovery,
            realService: realService,
            demoService: demoService,
            deviceStore: MemoryDeviceStore(device: device),
            tokenStore: MemoryTokenStore()
        )
    }
}

private actor CountingCommandService: SmartCastServicing {
    private(set) var sendCount = 0

    func startPairing(with device: TVDevice) async throws -> PairingChallenge {
        PairingChallenge(requestToken: 1, challengeType: 1, deviceID: UUID().uuidString)
    }
    func completePairing(with device: TVDevice, challenge: PairingChallenge, pin: String) async throws -> String { "TOKEN" }
    func verify(device: TVDevice, authToken: String) async throws {}
    func send(_ command: RemoteCommand, to device: TVDevice, authToken: String) async throws { sendCount += 1 }
    func sendText(_ text: String, to device: TVDevice, authToken: String) async throws {}
    func cancelPairing(with device: TVDevice, challenge: PairingChallenge) async {}
    func discardPairingSecurityIdentity(for device: TVDevice) async {}
    func resetSecurityIdentity(for device: TVDevice) async throws {}
    func resetAllSecurityData() async throws {}
}

private actor CountingDiscovery: TVDiscovering {
    private(set) var callCount = 0

    func discover(timeout: TimeInterval) async throws -> [TVDevice] {
        callCount += 1
        try await Task.sleep(for: .seconds(1))
        return []
    }
}

private actor NoopSmartCastService: SmartCastServicing {
    func startPairing(with device: TVDevice) async throws -> PairingChallenge {
        PairingChallenge(requestToken: 1, challengeType: 1, deviceID: UUID().uuidString)
    }
    func completePairing(with device: TVDevice, challenge: PairingChallenge, pin: String) async throws -> String { "TOKEN" }
    func verify(device: TVDevice, authToken: String) async throws {}
    func send(_ command: RemoteCommand, to device: TVDevice, authToken: String) async throws {}
    func sendText(_ text: String, to device: TVDevice, authToken: String) async throws {}
    func cancelPairing(with device: TVDevice, challenge: PairingChallenge) async {}
    func discardPairingSecurityIdentity(for device: TVDevice) async {}
    func resetSecurityIdentity(for device: TVDevice) async throws {}
    func resetAllSecurityData() async throws {}
}

private final class MemoryDeviceStore: DeviceStoring, @unchecked Sendable {
    private var device: TVDevice?
    init(device: TVDevice?) { self.device = device }
    func loadDevice() throws -> TVDevice? { device }
    func saveDevice(_ device: TVDevice) throws { self.device = device }
    func clearDevice() throws { device = nil }
}

private struct MemoryTokenStore: TokenStoring {
    func token(for deviceID: String) throws -> String? { "TOKEN" }
    func save(_ token: String, for deviceID: String) throws {}
    func deleteToken(for deviceID: String) throws {}
    func deleteAll() throws {}
}
