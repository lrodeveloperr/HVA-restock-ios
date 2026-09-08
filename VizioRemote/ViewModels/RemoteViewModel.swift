import Foundation
import Combine
import UIKit

@MainActor
final class RemoteViewModel: ObservableObject {
    @Published private(set) var device: TVDevice?
    @Published private(set) var discoveredDevices: [TVDevice] = []
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var pairingChallenge: PairingChallenge?
    @Published private(set) var isCompletingPairing = false
    @Published private(set) var isManagingLocalData = false
    @Published var alertMessage: String?
    @Published var showSettings = false
    @Published var showTextEntry = false
    @Published var showManualEntry = false

    private let discovery: TVDiscovering
    private let realService: SmartCastServicing
    private let demoService: SmartCastServicing
    private let deviceStore: DeviceStoring
    private let tokenStore: TokenStoring
    private var pendingDevice: TVDevice?
    private var hasRestored = false
    private var discoveryTask: Task<Void, Never>?
    private var pairingTask: Task<Void, Never>?
    private var pairingCancelTask: Task<Void, Never>?
    private var verificationTask: Task<Void, Never>?
    private var commandWorker: Task<Void, Never>?
    private var queuedActions: [QueuedRemoteAction] = []
    private var queueHeadIndex = 0
    private var isDrainingCommands = false
    private var commandGeneration = 0
    private var pairingOperationID: UUID?
    private var cachedToken: (deviceID: String, value: String)?
    private var remoteAccessEnabled = false
    private let maximumPendingCommands = 12

    var hasSavedTV: Bool { device != nil }
    var pairingIsDemo: Bool { pendingDevice?.isDemo == true }
    var canSendCommands: Bool {
        !isManagingLocalData && (connectionState == .connected || connectionState == .sending)
    }
    var canReconnect: Bool {
        remoteAccessEnabled && !isManagingLocalData && !isDrainingCommands && connectionState != .connecting
    }
    var isBusy: Bool {
        switch connectionState {
        case .connecting, .searching, .pairing, .sending: return true
        default: return false
        }
    }

    init(
        discovery: TVDiscovering = SSDPDiscovery(),
        realService: SmartCastServicing = SmartCastService(),
        demoService: SmartCastServicing = DemoSmartCastService(),
        deviceStore: DeviceStoring = DeviceStore(),
        tokenStore: TokenStoring = KeychainTokenStore()
    ) {
        self.discovery = discovery
        self.realService = realService
        self.demoService = demoService
        self.deviceStore = deviceStore
        self.tokenStore = tokenStore
    }

    func restoreLocalDeviceMetadata() {
        guard !isManagingLocalData, device == nil else { return }
        do {
            device = try deviceStore.loadDevice()
        } catch {
            // Protected Keychain data may be temporarily unavailable. Keep this
            // operation retryable after the device is unlocked.
            alertMessage = message(for: error)
        }
    }

    func restore() {
        guard !hasRestored, !isManagingLocalData else { return }
        do {
            if device == nil { device = try deviceStore.loadDevice() }
            guard let saved = device else {
                hasRestored = true
                return
            }
            guard let token = try tokenStore.token(for: saved.id) else {
                try deviceStore.clearDevice()
                device = nil
                hasRestored = true
                return
            }
            cachedToken = (saved.id, token)
            device = saved
            hasRestored = true
        } catch {
            // Protected Keychain data may be temporarily unavailable. Leave
            // restoration retryable when the scene becomes active again.
            alertMessage = message(for: error)
        }
    }

    func setRemoteAccessEnabled(_ enabled: Bool) {
        remoteAccessEnabled = enabled
        if !enabled { suspend() }
    }

    func discover() {
        guard remoteAccessEnabled, !isManagingLocalData else { return }
        discoveryTask?.cancel()
        pairingTask?.cancel()
        connectionState = .searching
        discoveredDevices = []
        discoveryTask = Task { [weak self] in
            guard let self else { return }
            do {
                let devices = try await discovery.discover(timeout: 3)
                guard !Task.isCancelled else { return }
                discoveredDevices = devices
                connectionState = .disconnected
                if devices.isEmpty { alertMessage = SmartCastError.noDeviceFound.localizedDescription }
            } catch {
                guard !Task.isCancelled else { return }
                connectionState = .failed(message(for: error))
                alertMessage = message(for: error)
            }
        }
    }

    func connectManually(ipAddress: String, legacyPort: Bool) {
        guard remoteAccessEnabled, !isManagingLocalData else { return }
        guard let host = LocalNetworkAddress.normalizedIPv4(ipAddress) else {
            alertMessage = SmartCastError.invalidAddress.localizedDescription
            return
        }
        let device = TVDevice(
            id: "smartcast-\(host):\(legacyPort ? 9000 : 7345)",
            name: String(localized: "Vizio SmartCast TV"),
            host: host,
            port: legacyPort ? 9000 : 7345
        )
        showManualEntry = false
        beginPairing(with: device)
    }

    func beginPairing(with selectedDevice: TVDevice) {
        guard remoteAccessEnabled, !isManagingLocalData else { return }
        discoveryTask?.cancel()
        pairingTask?.cancel()
        pairingCancelTask?.cancel()
        pairingCancelTask = nil
        verificationTask?.cancel()
        isCompletingPairing = false
        let operationID = UUID()
        pairingOperationID = operationID
        pendingDevice = selectedDevice
        pairingChallenge = nil
        connectionState = .pairing

        pairingTask = Task { [weak self] in
            guard let self else { return }
            do {
                let challenge = try await service(for: selectedDevice).startPairing(with: selectedDevice)
                guard !Task.isCancelled,
                      pairingOperationID == operationID,
                      pendingDevice == selectedDevice else { return }
                pairingChallenge = challenge
            } catch {
                guard !Task.isCancelled,
                      pairingOperationID == operationID,
                      pendingDevice == selectedDevice else { return }
                pairingOperationID = nil
                pendingDevice = nil
                connectionState = .failed(message(for: error))
                alertMessage = message(for: error)
            }
        }
    }

    func useDemoTV() {
        beginPairing(with: .demo)
    }

    func finishPairing(pin: String) {
        guard remoteAccessEnabled, !isManagingLocalData else { return }
        guard let pendingDevice,
              let pairingChallenge,
              let operationID = pairingOperationID else { return }
        guard pin.utf8.count == 4, pin.utf8.allSatisfy({ (48...57).contains($0) }) else {
            alertMessage = String(localized: "Enter the four-digit PIN shown on the TV.")
            return
        }

        connectionState = .pairing
        isCompletingPairing = true
        pairingCancelTask?.cancel()
        pairingCancelTask = nil
        pairingTask?.cancel()
        pairingTask = Task { [weak self] in
            guard let self else { return }
            do {
                let token = try await service(for: pendingDevice).completePairing(
                    with: pendingDevice,
                    challenge: pairingChallenge,
                    pin: pin
                )
                guard !Task.isCancelled,
                      pairingOperationID == operationID,
                      self.pendingDevice == pendingDevice else {
                    if !pendingDevice.isDemo {
                        try? await service(for: pendingDevice).resetSecurityIdentity(for: pendingDevice)
                    }
                    return
                }
                do {
                    try tokenStore.save(token, for: pendingDevice.id)
                    try deviceStore.saveDevice(pendingDevice)
                    cachedToken = (pendingDevice.id, token)
                } catch {
                    // Pairing already committed the certificate pin. Roll back
                    // both secure values so a partial local write cannot strand
                    // an unusable token or identity.
                    var cleanupFailed = false
                    do {
                        try tokenStore.deleteToken(for: pendingDevice.id)
                    } catch {
                        cleanupFailed = true
                    }
                    if !pendingDevice.isDemo {
                        do {
                            try await service(for: pendingDevice).resetSecurityIdentity(for: pendingDevice)
                        } catch {
                            cleanupFailed = true
                        }
                    }
                    guard pairingOperationID == operationID,
                          self.pendingDevice == pendingDevice else { return }
                    pairingOperationID = nil
                    self.pendingDevice = nil
                    self.pairingChallenge = nil
                    isCompletingPairing = false
                    connectionState = .disconnected
                    alertMessage = cleanupFailed
                        ? String(localized: "The TV accepted pairing, but secure storage and cleanup were incomplete. Unlock this device, remove all saved TV data, then pair again.")
                        : String(localized: "The TV accepted pairing, but its secure data could not be saved. Unlock this device and pair again.")
                    return
                }
                device = pendingDevice
                self.pendingDevice = nil
                self.pairingChallenge = nil
                isCompletingPairing = false
                connectionState = .connected
            } catch {
                guard !Task.isCancelled,
                      pairingOperationID == operationID,
                      self.pendingDevice == pendingDevice else { return }
                isCompletingPairing = false
                connectionState = .pairing
                alertMessage = message(for: error)
            }
        }
    }

    func cancelPairing() {
        let abandonedDevice = pendingDevice
        cancelPendingPairingOnTV()
        pairingTask?.cancel()
        pairingTask = nil
        pairingOperationID = nil
        isCompletingPairing = false
        pendingDevice = nil
        pairingChallenge = nil
        connectionState = .disconnected
        if let abandonedDevice, !abandonedDevice.isDemo {
            Task { await realService.discardPairingSecurityIdentity(for: abandonedDevice) }
        }
    }

    func send(_ command: RemoteCommand) {
        guard remoteAccessEnabled, !isManagingLocalData, canSendCommands else { return }
        guard queueHasCapacity else {
            reportFullCommandQueue()
            return
        }
        guard let device else { return }
        guard let token = readableToken(for: device) else {
            return
        }
        if enqueue(.command(command, device: device, token: token)) { haptic() }
    }

    func sendText(_ text: String) {
        guard remoteAccessEnabled, !isManagingLocalData, canSendCommands else { return }
        guard queueHasCapacity else {
            reportFullCommandQueue()
            return
        }
        guard let device, let token = readableToken(for: device) else { return }
        enqueue(.text(text, device: device, token: token))
    }

    func reconnect() {
        guard !isManagingLocalData, canReconnect else { return }
        startVerification(silently: false)
    }

    func resume() {
        guard remoteAccessEnabled, !isManagingLocalData else { return }
        if connectionState == .connecting || connectionState == .connected || connectionState == .sending { return }
        guard device != nil else {
            connectionState = .disconnected
            return
        }
        startVerification(silently: true)
    }

    func forgetTV() {
        guard !isManagingLocalData else { return }
        guard let forgottenDevice = device else { return }
        isManagingLocalData = true
        suspend()
        Task { [weak self] in
            guard let self else { return }
            defer { isManagingLocalData = false }
            var securityResetFailed = false
            if !forgottenDevice.isDemo {
                do {
                    try await service(for: forgottenDevice).resetSecurityIdentity(for: forgottenDevice)
                } catch {
                    securityResetFailed = true
                }
            }
            guard device == forgottenDevice else { return }
            let tokenResetFailed = resetConnection(showMessage: false)
            showSettings = false
            if securityResetFailed || tokenResetFailed {
                alertMessage = String(localized: "The TV was forgotten, but some secure pairing data could not be removed. Unlock this device and try the security reset again.")
            }
        }
    }

    func resetSecurityIdentity(ipAddress: String, legacyPort: Bool) {
        guard !isManagingLocalData else { return }
        guard let host = LocalNetworkAddress.normalizedIPv4(ipAddress) else {
            alertMessage = SmartCastError.invalidAddress.localizedDescription
            return
        }
        let target = TVDevice(name: "Security reset", host: host, port: legacyPort ? 9000 : 7345)
        isManagingLocalData = true
        suspend()
        Task { [weak self] in
            guard let self else { return }
            defer { isManagingLocalData = false }
            do {
                try await realService.resetSecurityIdentity(for: target)
                alertMessage = String(localized: "The saved TV security identity was reset. Pair again only if you trust this local network and recognize the TV.")
            } catch {
                alertMessage = message(for: error)
            }
        }
    }

    func removeAllSavedTVData() {
        guard !isManagingLocalData else { return }
        isManagingLocalData = true
        suspend()
        Task { [weak self] in
            guard let self else { return }
            defer { isManagingLocalData = false }
            var removalFailed = false
            do {
                try await realService.resetAllSecurityData()
            } catch {
                removalFailed = true
            }
            do {
                try tokenStore.deleteAll()
            } catch {
                removalFailed = true
            }
            do {
                try deviceStore.clearDevice()
            } catch {
                removalFailed = true
            }
            device = nil
            hasRestored = true
            connectionState = .disconnected
            alertMessage = removalFailed
                ? String(localized: "Some secure TV data could not be removed. Unlock this device and try again.")
                : String(localized: "All saved TV data was removed from this device.")
        }
    }

    func suspend() {
        cancelPendingPairingOnTV()
        discoveryTask?.cancel()
        pairingTask?.cancel()
        verificationTask?.cancel()
        resetCommandQueue()
        discoveryTask = nil
        pairingTask = nil
        verificationTask = nil
        pairingOperationID = nil
        isCompletingPairing = false
        showTextEntry = false
        showManualEntry = false
        showSettings = false
        cachedToken = nil
        pairingChallenge = nil
        pendingDevice = nil
        connectionState = .disconnected
    }

    private func startVerification(silently: Bool) {
        guard remoteAccessEnabled, !isManagingLocalData else { return }
        verificationTask?.cancel()
        guard let expectedDevice = device,
              let token = readableToken(for: expectedDevice, showError: !silently) else { return }
        connectionState = .connecting
        verificationTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await service(for: expectedDevice).verify(device: expectedDevice, authToken: token)
                guard !Task.isCancelled, device == expectedDevice else { return }
                connectionState = .connected
            } catch {
                guard !Task.isCancelled, device == expectedDevice else { return }
                if error as? SmartCastError == .authenticationRequired {
                    resetConnection(showMessage: !silently)
                } else {
                    connectionState = .failed(message(for: error))
                    if !silently { alertMessage = message(for: error) }
                }
            }
        }
    }

    private func handleCommandError(_ error: Error) {
        if error as? SmartCastError == .authenticationRequired {
            resetConnection(showMessage: true)
        } else {
            connectionState = .failed(message(for: error))
            alertMessage = message(for: error)
        }
    }

    @discardableResult
    private func resetConnection(showMessage: Bool) -> Bool {
        suspend()
        var secureDataRemovalFailed = false
        if let device {
            do {
                try tokenStore.deleteToken(for: device.id)
            } catch {
                secureDataRemovalFailed = true
            }
        }
        do {
            try deviceStore.clearDevice()
        } catch {
            secureDataRemovalFailed = true
        }
        device = nil
        pendingDevice = nil
        pairingChallenge = nil
        connectionState = .disconnected
        if showMessage {
            alertMessage = secureDataRemovalFailed
                ? SmartCastError.securityStorageUnavailable.localizedDescription
                : SmartCastError.authenticationRequired.localizedDescription
        }
        return secureDataRemovalFailed
    }

    private func service(for device: TVDevice) -> SmartCastServicing {
        device.isDemo ? demoService : realService
    }

    private func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    private func readableToken(for device: TVDevice, showError: Bool = true) -> String? {
        if cachedToken?.deviceID == device.id {
            return cachedToken?.value
        }
        do {
            guard let token = try tokenStore.token(for: device.id) else {
                resetConnection(showMessage: showError)
                return nil
            }
            cachedToken = (device.id, token)
            return token
        } catch {
            connectionState = .failed(message(for: error))
            if showError { alertMessage = message(for: error) }
            return nil
        }
    }

    private func haptic() {
        let enabled = (UserDefaults.standard.object(forKey: "haptics.enabled") as? Bool) ?? true
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    @discardableResult
    private func enqueue(_ action: QueuedRemoteAction) -> Bool {
        guard queueHasCapacity else {
            reportFullCommandQueue()
            return false
        }
        queuedActions.append(action)
        guard !isDrainingCommands else { return true }
        isDrainingCommands = true
        let generation = commandGeneration
        commandWorker = Task { [weak self] in
            await self?.drainCommandQueue(generation: generation)
        }
        return true
    }

    private var queueHasCapacity: Bool {
        queuedActions.count - queueHeadIndex < maximumPendingCommands
    }

    private func reportFullCommandQueue() {
        if alertMessage == nil {
            alertMessage = String(localized: "The TV is still processing earlier commands. Please wait a moment.")
        }
    }

    private func drainCommandQueue(generation: Int) async {
        defer {
            if generation == commandGeneration {
                queuedActions.removeAll(keepingCapacity: true)
                queueHeadIndex = 0
                isDrainingCommands = false
                commandWorker = nil
            }
        }

        while queueHeadIndex < queuedActions.count,
              generation == commandGeneration,
              !Task.isCancelled {
            let action = queuedActions[queueHeadIndex]
            queueHeadIndex += 1
            guard device == action.device else { continue }
            guard !action.isExpired else { continue }
            connectionState = .sending

            do {
                switch action.kind {
                case .command(let command):
                    let device = action.device
                    let token = action.token
                    try await service(for: device).send(command, to: device, authToken: token)
                case .text(let text):
                    let device = action.device
                    let token = action.token
                    try await service(for: device).sendText(text, to: device, authToken: token)
                    showTextEntry = false
                }
                if !Task.isCancelled { connectionState = .connected }
            } catch {
                guard !Task.isCancelled else { return }
                queueHeadIndex = queuedActions.count
                handleCommandError(error)
                return
            }
        }
    }

    private func resetCommandQueue() {
        commandGeneration += 1
        commandWorker?.cancel()
        commandWorker = nil
        queuedActions.removeAll(keepingCapacity: false)
        queueHeadIndex = 0
        isDrainingCommands = false
        if connectionState == .sending {
            connectionState = device == nil ? .disconnected : .connected
        }
    }

    private func cancelPendingPairingOnTV() {
        guard let deviceToCancel = pendingDevice, let challengeToCancel = pairingChallenge else { return }
        pairingCancelTask?.cancel()
        pairingCancelTask = Task { [weak self] in
            guard let self else { return }
            await service(for: deviceToCancel).cancelPairing(with: deviceToCancel, challenge: challengeToCancel)
        }
    }
}

private struct QueuedRemoteAction {
    enum Kind {
        case command(RemoteCommand)
        case text(String)
    }

    let kind: Kind
    let device: TVDevice
    let token: String
    let enqueuedAt: Date

    static func command(_ command: RemoteCommand, device: TVDevice, token: String) -> Self {
        Self(kind: .command(command), device: device, token: token, enqueuedAt: Date())
    }

    static func text(_ text: String, device: TVDevice, token: String) -> Self {
        Self(kind: .text(text), device: device, token: token, enqueuedAt: Date())
    }

    var isExpired: Bool {
        Date().timeIntervalSince(enqueuedAt) > 2
    }
}
