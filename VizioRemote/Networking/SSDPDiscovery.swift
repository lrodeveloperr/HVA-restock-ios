import Darwin
import Foundation

protocol TVDiscovering: Sendable {
    func discover(timeout: TimeInterval) async throws -> [TVDevice]
}

/// Discovers SmartCast televisions with one bound UDP socket. SSDP replies are
/// unicast to the source port of M-SEARCH, so sending and receiving on separate
/// sockets (or a connected multicast endpoint) is not reliable.
final class SSDPDiscovery: TVDiscovering, @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.worksbienstudios.clearmote.ssdp", qos: .userInitiated)

    func discover(timeout: TimeInterval = 3.0) async throws -> [TVDevice] {
        let boundedTimeout = min(max(timeout, 1), 10)
        let socketState = DiscoverySocketState()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                queue.async {
                    do {
                        continuation.resume(returning: try self.performDiscovery(timeout: boundedTimeout, state: socketState))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } onCancel: {
            socketState.cancel()
        }
    }

    private func performDiscovery(timeout: TimeInterval, state: DiscoverySocketState) throws -> [TVDevice] {
        let descriptor = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard descriptor >= 0 else { throw socketError() }
        guard state.install(descriptor) else {
            Darwin.close(descriptor)
            throw SmartCastError.cancelled
        }
        defer { state.close(descriptor) }

        var reuseAddress: Int32 = 1
        guard setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR, &reuseAddress, socklen_t(MemoryLayout.size(ofValue: reuseAddress))) == 0 else {
            throw socketError()
        }

        var multicastTTL: UInt8 = 2
        guard setsockopt(descriptor, IPPROTO_IP, IP_MULTICAST_TTL, &multicastTTL, socklen_t(MemoryLayout.size(ofValue: multicastTTL))) == 0 else {
            throw socketError()
        }

        var receiveTimeout = timeval(tv_sec: 0, tv_usec: 250_000)
        guard setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &receiveTimeout, socklen_t(MemoryLayout.size(ofValue: receiveTimeout))) == 0 else {
            throw socketError()
        }

        var localAddress = sockaddr_in()
        localAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        localAddress.sin_family = sa_family_t(AF_INET)
        localAddress.sin_port = 0
        localAddress.sin_addr = in_addr(s_addr: INADDR_ANY)
        let bindResult = withUnsafePointer(to: &localAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else { throw socketError() }

        var multicastAddress = sockaddr_in()
        multicastAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        multicastAddress.sin_family = sa_family_t(AF_INET)
        multicastAddress.sin_port = in_port_t(1900).bigEndian
        guard inet_pton(AF_INET, "239.255.255.250", &multicastAddress.sin_addr) == 1 else {
            throw SmartCastError.network(String(localized: "Could not prepare TV discovery."))
        }

        let searchRequest = [
            "M-SEARCH * HTTP/1.1",
            "HOST: 239.255.255.250:1900",
            "MAN: \"ssdp:discover\"",
            "MX: 2",
            "ST: urn:schemas-kinoma-com:device:shell:1",
            "",
            ""
        ].joined(separator: "\r\n").data(using: .utf8)!

        var devices: [String: TVDevice] = [:]
        let deadline = Date().addingTimeInterval(timeout)
        var nextSend = Date.distantPast
        var sendsRemaining = 3

        while Date() < deadline {
            if state.isCancelled { throw SmartCastError.cancelled }

            if sendsRemaining > 0, Date() >= nextSend {
                let sent = searchRequest.withUnsafeBytes { bytes in
                    withUnsafePointer(to: &multicastAddress) { pointer in
                        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                            sendto(descriptor, bytes.baseAddress, bytes.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                        }
                    }
                }
                guard sent == searchRequest.count else { throw socketError() }
                sendsRemaining -= 1
                nextSend = Date().addingTimeInterval(0.6)
            }

            var buffer = [UInt8](repeating: 0, count: 16_384)
            var sender = sockaddr_storage()
            var senderLength = socklen_t(MemoryLayout<sockaddr_storage>.size)
            let received = buffer.withUnsafeMutableBytes { bytes in
                withUnsafeMutablePointer(to: &sender) { pointer in
                    pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        recvfrom(descriptor, bytes.baseAddress, bytes.count, 0, $0, &senderLength)
                    }
                }
            }

            if received > 0 {
                guard let sourceHost = ipv4Host(from: sender) else { continue }
                let data = Data(buffer.prefix(received))
                if let device = SSDPResponseParser.parse(data, sourceHost: sourceHost), devices.count < 16 {
                    devices["\(device.host):\(device.port)"] = device
                }
            } else if received < 0 {
                if state.isCancelled { throw SmartCastError.cancelled }
                if errno != EAGAIN, errno != EWOULDBLOCK, errno != EINTR {
                    throw socketError()
                }
            }
        }

        return devices.values.sorted { $0.host.localizedStandardCompare($1.host) == .orderedAscending }
    }

    private func ipv4Host(from storage: sockaddr_storage) -> String? {
        guard storage.ss_family == sa_family_t(AF_INET) else { return nil }
        var storage = storage
        return withUnsafePointer(to: &storage) { pointer -> String? in
            pointer.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { address in
                var internetAddress = address.pointee.sin_addr
                var characters = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                guard inet_ntop(AF_INET, &internetAddress, &characters, socklen_t(INET_ADDRSTRLEN)) != nil else { return nil }
                return String(cString: characters)
            }
        }
    }

    private func socketError() -> SmartCastError {
        SmartCastError.network(String(cString: strerror(errno)))
    }
}

private final class DiscoverySocketState: @unchecked Sendable {
    private let lock = NSLock()
    private var descriptor: Int32 = -1
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func install(_ descriptor: Int32) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !cancelled else { return false }
        self.descriptor = descriptor
        return true
    }

    func close(_ descriptor: Int32) {
        lock.lock()
        guard self.descriptor == descriptor else {
            lock.unlock()
            return
        }
        self.descriptor = -1
        lock.unlock()
        Darwin.close(descriptor)
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let descriptor = self.descriptor
        self.descriptor = -1
        lock.unlock()
        if descriptor >= 0 {
            shutdown(descriptor, SHUT_RDWR)
            Darwin.close(descriptor)
        }
    }
}
