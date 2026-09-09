import Darwin
import Foundation
import Network

protocol TVDiscovering: Sendable {
    func discover(timeout: TimeInterval) async throws -> [TVDevice]
}

/// Finds Cast-capable Vizio televisions through their declared Bonjour service,
/// then confirms the local SmartCast control port before showing a result.
/// Browsing one declared service type avoids arbitrary multicast access.
final class BonjourDiscovery: NSObject, TVDiscovering, @unchecked Sendable {
    private var browser: NetServiceBrowser?
    private var services: [ObjectIdentifier: NetService] = [:]
    private var probes: [String: SmartCastPortProbe] = [:]
    private var devices: [String: TVDevice] = [:]
    private var continuation: CheckedContinuation<[TVDevice], Error>?
    private var requestID: UUID?
    private var timeoutWorkItem: DispatchWorkItem?
    private var settleWorkItem: DispatchWorkItem?

    func discover(timeout: TimeInterval = 4.0) async throws -> [TVDevice] {
        let boundedTimeout = min(max(timeout, 2), 8)
        let id = UUID()

        return try await withTaskCancellationHandler {
            if Task.isCancelled { throw SmartCastError.cancelled }
            return try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.main.async {
                    self.start(id: id, timeout: boundedTimeout, continuation: continuation)
                }
            }
        } onCancel: {
            DispatchQueue.main.async {
                self.cancel(id: id)
            }
        }
    }

    private func start(
        id: UUID,
        timeout: TimeInterval,
        continuation: CheckedContinuation<[TVDevice], Error>
    ) {
        finish(with: .failure(SmartCastError.cancelled))

        requestID = id
        self.continuation = continuation
        services = [:]
        probes = [:]
        devices = [:]

        let browser = NetServiceBrowser()
        browser.delegate = self
        self.browser = browser
        browser.searchForServices(ofType: "_googlecast._tcp.", inDomain: "local.")

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.requestID == id else { return }
            self.finish(with: .success(self.sortedDevices))
        }
        timeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: workItem)
    }

    private func cancel(id: UUID) {
        guard requestID == id else { return }
        finish(with: .failure(SmartCastError.cancelled))
    }

    private func finish(with result: Result<[TVDevice], Error>) {
        guard let continuation else { return }
        self.continuation = nil
        requestID = nil
        timeoutWorkItem?.cancel()
        settleWorkItem?.cancel()
        timeoutWorkItem = nil
        settleWorkItem = nil

        browser?.delegate = nil
        browser?.stop()
        browser = nil

        services.values.forEach { $0.delegate = nil }
        services = [:]
        probes.values.forEach { $0.cancel() }
        probes = [:]

        continuation.resume(with: result)
    }

    private var sortedDevices: [TVDevice] {
        devices.values.sorted {
            if $0.name == $1.name {
                return $0.host.localizedStandardCompare($1.host) == .orderedAscending
            }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private func resolvedIPv4Addresses(for service: NetService) -> [String] {
        var addresses = Set<String>()
        for data in service.addresses ?? [] {
            guard data.count >= MemoryLayout<sockaddr_in>.size else { continue }
            let address = data.withUnsafeBytes { bytes -> String? in
                guard let baseAddress = bytes.baseAddress else { return nil }
                let socketAddress = baseAddress.assumingMemoryBound(to: sockaddr.self)
                guard socketAddress.pointee.sa_family == sa_family_t(AF_INET) else { return nil }
                var internetAddress = baseAddress.assumingMemoryBound(to: sockaddr_in.self).pointee.sin_addr
                var characters = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                guard inet_ntop(AF_INET, &internetAddress, &characters, socklen_t(INET_ADDRSTRLEN)) != nil else {
                    return nil
                }
                return LocalNetworkAddress.normalizedIPv4(String(cString: characters))
            }
            if let address { addresses.insert(address) }
        }
        return addresses.sorted()
    }

    private func displayName(for service: NetService) -> String {
        let txt = service.txtRecordData().map(NetService.dictionary(fromTXTRecord:)) ?? [:]
        let friendlyName = txt["fn"].flatMap { String(data: $0, encoding: .utf8) }
        let candidate = friendlyName ?? service.name
        let cleaned = candidate
            .components(separatedBy: .controlCharacters)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return String(localized: "Vizio SmartCast TV") }
        return String(cleaned.prefix(80))
    }

    private func probe(host: String, name: String) {
        guard probes[host] == nil, devices.values.allSatisfy({ $0.host != host }) else { return }
        let probe = SmartCastPortProbe(host: host) { [weak self] port in
            guard let discovery = self else { return }
            DispatchQueue.main.async { [discovery] in
                guard discovery.continuation != nil else { return }
                discovery.probes[host] = nil
                guard let port else { return }
                let key = "\(host):\(port)"
                discovery.devices[key] = TVDevice(
                    id: "smartcast-\(key)",
                    name: name,
                    host: host,
                    port: port
                )
                discovery.scheduleSettledResult()
            }
        }
        probes[host] = probe
        probe.start()
    }

    private func scheduleSettledResult() {
        settleWorkItem?.cancel()
        let currentID = requestID
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.requestID == currentID, !self.devices.isEmpty else { return }
            self.finish(with: .success(self.sortedDevices))
        }
        settleWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: workItem)
    }
}

extension BonjourDiscovery: NetServiceBrowserDelegate, NetServiceDelegate {
    func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didFind service: NetService,
        moreComing: Bool
    ) {
        guard continuation != nil, services.count < 16 else { return }
        services[ObjectIdentifier(service)] = service
        service.delegate = self
        service.resolve(withTimeout: 2)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        finish(with: .failure(SmartCastError.localNetworkUnavailable))
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        guard continuation != nil else { return }
        let name = displayName(for: sender)
        for host in resolvedIPv4Addresses(for: sender) {
            probe(host: host, name: name)
        }
    }
}

/// A Cast advertisement is only accepted after the same host exposes one of
/// Vizio's local SmartCast HTTPS ports. This prevents unrelated Cast devices
/// from appearing as televisions the app can control.
private final class SmartCastPortProbe: @unchecked Sendable {
    private let host: String
    private let queue: DispatchQueue
    private let completion: @Sendable (Int?) -> Void
    private var connections: [NWConnection] = []
    private var failedPorts = Set<Int>()
    private var isFinished = false

    init(host: String, completion: @escaping @Sendable (Int?) -> Void) {
        self.host = host
        self.completion = completion
        self.queue = DispatchQueue(label: "com.worksbienstudios.clearmote.smartcast-probe.\(UUID().uuidString)")
    }

    func start() {
        queue.async { [weak self] in
            guard let self, !self.isFinished else { return }
            for port in [7345, 9000] {
                guard let networkPort = NWEndpoint.Port(rawValue: UInt16(port)) else { continue }
                let connection = NWConnection(host: NWEndpoint.Host(self.host), port: networkPort, using: .tcp)
                connection.stateUpdateHandler = { [weak self, weak connection] state in
                    guard let self, let connection, !self.isFinished else { return }
                    switch state {
                    case .ready:
                        self.finish(port: port)
                    case .failed(_), .cancelled:
                        self.failedPorts.insert(port)
                        if self.failedPorts.count == 2 { self.finish(port: nil) }
                    default:
                        break
                    }
                    _ = connection
                }
                self.connections.append(connection)
                connection.start(queue: self.queue)
            }
            self.queue.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.finish(port: nil)
            }
        }
    }

    func cancel() {
        queue.async { [weak self] in self?.finish(port: nil, notify: false) }
    }

    private func finish(port: Int?, notify: Bool = true) {
        guard !isFinished else { return }
        isFinished = true
        connections.forEach {
            $0.stateUpdateHandler = nil
            $0.cancel()
        }
        connections = []
        if notify { completion(port) }
    }
}
