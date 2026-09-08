import Foundation

protocol SmartCastServicing: Sendable {
    func startPairing(with device: TVDevice) async throws -> PairingChallenge
    func completePairing(with device: TVDevice, challenge: PairingChallenge, pin: String) async throws -> String
    func verify(device: TVDevice, authToken: String) async throws
    func send(_ command: RemoteCommand, to device: TVDevice, authToken: String) async throws
    func sendText(_ text: String, to device: TVDevice, authToken: String) async throws
    func cancelPairing(with device: TVDevice, challenge: PairingChallenge) async
    func discardPairingSecurityIdentity(for device: TVDevice) async
    func resetSecurityIdentity(for device: TVDevice) async throws
    func resetAllSecurityData() async throws
}

protocol SmartCastTransporting: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
    func commitSecurityIdentity(host: String, port: Int) throws
    func resetSecurityIdentity(host: String, port: Int) throws
    func resetAllSecurityIdentities() throws
    func discardUncommittedSecurityIdentity(host: String, port: Int)
}

actor SmartCastService: SmartCastServicing {
    private let transport: SmartCastTransporting

    init(transport: SmartCastTransporting = SmartCastHTTPTransport()) {
        self.transport = transport
    }

    func startPairing(with device: TVDevice) async throws -> PairingChallenge {
        let deviceID = stableDeviceID()
        let response = try await request(
            device: device,
            method: "PUT",
            path: "/pairing/start",
            body: ["DEVICE_NAME": "TV Remote", "DEVICE_ID": deviceID],
            authToken: nil
        )
        try validateStatus(response)

        guard let item = response["ITEM"] as? [String: Any],
              let token = integer(item["PAIRING_REQ_TOKEN"]),
              let challenge = integer(item["CHALLENGE_TYPE"]),
              (0...Int(Int32.max)).contains(token),
              (0...Int(Int32.max)).contains(challenge) else {
            throw SmartCastError.malformedResponse
        }
        return PairingChallenge(requestToken: token, challengeType: challenge, deviceID: deviceID)
    }

    func completePairing(
        with device: TVDevice,
        challenge: PairingChallenge,
        pin: String
    ) async throws -> String {
        let response = try await request(
            device: device,
            method: "PUT",
            path: "/pairing/pair",
            body: [
                "DEVICE_ID": challenge.deviceID,
                "CHALLENGE_TYPE": challenge.challengeType,
                "RESPONSE_VALUE": pin,
                "PAIRING_REQ_TOKEN": challenge.requestToken
            ],
            authToken: nil
        )
        try validateStatus(response, pairing: true)

        guard let item = response["ITEM"] as? [String: Any],
              let authToken = item["AUTH_TOKEN"] as? String,
              SmartCastAuthToken.isValid(authToken) else {
            throw SmartCastError.malformedResponse
        }
        try Task.checkCancellation()
        try transport.commitSecurityIdentity(host: device.host, port: device.port)
        if Task.isCancelled {
            try? transport.resetSecurityIdentity(host: device.host, port: device.port)
            throw CancellationError()
        }
        return authToken
    }

    func cancelPairing(with device: TVDevice, challenge: PairingChallenge) async {
        _ = try? await request(
            device: device,
            method: "PUT",
            path: "/pairing/cancel",
            body: [
                "DEVICE_ID": challenge.deviceID,
                "CHALLENGE_TYPE": challenge.challengeType,
                "RESPONSE_VALUE": "1111",
                "PAIRING_REQ_TOKEN": challenge.requestToken
            ],
            authToken: nil
        )
        transport.discardUncommittedSecurityIdentity(host: device.host, port: device.port)
    }

    func discardPairingSecurityIdentity(for device: TVDevice) async {
        transport.discardUncommittedSecurityIdentity(host: device.host, port: device.port)
    }

    func resetSecurityIdentity(for device: TVDevice) async throws {
        try transport.resetSecurityIdentity(host: device.host, port: device.port)
    }

    func resetAllSecurityData() async throws {
        try transport.resetAllSecurityIdentities()
        UserDefaults.standard.removeObject(forKey: "smartcast.client.deviceID")
    }

    func verify(device: TVDevice, authToken: String) async throws {
        let response = try await request(
            device: device,
            method: "GET",
            path: "/state/device/power_mode",
            body: nil,
            authToken: authToken
        )
        try validateStatus(response)
    }

    func send(_ command: RemoteCommand, to device: TVDevice, authToken: String) async throws {
        let response = try await request(
            device: device,
            method: "PUT",
            path: "/key_command/",
            body: command.payload,
            authToken: authToken
        )
        try validateStatus(response)
    }

    func sendText(_ text: String, to device: TVDevice, authToken: String) async throws {
        let scalars = text.unicodeScalars
        guard !scalars.isEmpty, scalars.count <= 128,
              scalars.allSatisfy({ (32...126).contains(Int($0.value)) }) else {
            throw SmartCastError.tvRejected(String(localized: "TV text entry supports up to 128 basic Latin characters at a time."))
        }

        let keys = scalars.map { scalar in
            [
                "CODESET": 0,
                // SmartCast uses code 52 for space; other supported Basic Latin
                // characters use their protocol table value.
                "CODE": scalar.value == 32 ? 52 : Int(scalar.value),
                "ACTION": "KEYPRESS"
            ] as [String: Any]
        }
        let response = try await request(
            device: device,
            method: "PUT",
            path: "/key_command/",
            body: ["KEYLIST": keys],
            authToken: authToken
        )
        try validateStatus(response)
    }

    private func stableDeviceID() -> String {
        let key = "smartcast.client.deviceID"
        if let existing = UserDefaults.standard.string(forKey: key),
           let uuid = UUID(uuidString: existing) {
            return uuid.uuidString
        }
        let identifier = UUID().uuidString
        UserDefaults.standard.set(identifier, forKey: key)
        return identifier
    }

    private func request(
        device: TVDevice,
        method: String,
        path: String,
        body: [String: Any]?,
        authToken: String?
    ) async throws -> [String: Any] {
        guard LocalNetworkAddress.isPrivateHost(device.host),
              LocalNetworkAddress.isSupportedSmartCastPort(device.port) else {
            throw SmartCastError.unsupportedAddress
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = device.host
        components.port = device.port
        components.path = path
        guard let url = components.url else { throw SmartCastError.invalidAddress }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 6
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let authToken { request.setValue(authToken, forHTTPHeaderField: "AUTH") }
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }

        do {
            let (data, response) = try await transport.data(for: request)
            if authToken != nil && (response.statusCode == 401 || response.statusCode == 403) {
                throw SmartCastError.authenticationRequired
            }
            guard (200...299).contains(response.statusCode) else {
                let format = String(localized: "The TV returned HTTP %lld.")
                throw SmartCastError.network(String(format: format, Int64(response.statusCode)))
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw SmartCastError.malformedResponse
            }
            return json
        } catch let error as SmartCastError {
            throw error
        } catch is CancellationError {
            throw SmartCastError.cancelled
        } catch {
            throw SmartCastError.network(String(localized: "Could not reach the TV. Check that it is on and connected to the same Wi-Fi."))
        }
    }

    private func validateStatus(_ response: [String: Any], pairing: Bool = false) throws {
        guard let status = response["STATUS"] as? [String: Any],
              let rawResult = status["RESULT"] as? String else {
            throw SmartCastError.malformedResponse
        }
        let safeResult = safeDetail(rawResult)
        let result = safeResult.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let detail = safeDetail(status["DETAIL"] as? String)
        if result == "success" { return }
        if result == "requires_pairing" {
            throw SmartCastError.authenticationRequired
        }
        if result == "pairing_denied" || result == "challenge_incorrect" || pairing {
            throw SmartCastError.pairingDenied(detail)
        }
        throw SmartCastError.tvRejected(detail.isEmpty ? safeResult : detail)
    }

    private func integer(_ value: Any?) -> Int? {
        if let value = value as? NSNumber {
            guard CFGetTypeID(value) != CFBooleanGetTypeID() else { return nil }
            let representation = value.stringValue
            guard !representation.isEmpty,
                  representation.utf8.allSatisfy({ (48...57).contains($0) }),
                  let parsed = Int64(representation),
                  parsed <= Int64(Int32.max) else { return nil }
            return Int(parsed)
        }
        if let value = value as? String,
           !value.isEmpty,
           value.utf8.allSatisfy({ (48...57).contains($0) }),
           let parsed = Int64(value),
           parsed <= Int64(Int32.max) {
            return Int(parsed)
        }
        return nil
    }

    private func safeDetail(_ value: String?) -> String {
        guard let value else { return "" }
        let scalars = value.unicodeScalars.filter { scalar in
            guard scalar.value >= 32, scalar.value != 127 else { return false }
            switch scalar.properties.generalCategory {
            case .control, .format, .lineSeparator, .paragraphSeparator, .surrogate:
                return false
            default:
                return true
            }
        }
        return String(String.UnicodeScalarView(scalars).prefix(240))
    }
}

final class SmartCastHTTPTransport: SmartCastTransporting, @unchecked Sendable {
    private static let maximumResponseBytes = 262_144
    fileprivate static let requestIDHeader = "X-TVRemote-Request-ID"
    private let delegate: SmartCastSessionDelegate
    private let configuration: URLSessionConfiguration
    private let sessionLock = NSLock()
    private var session: URLSession

    init(
        configuration: URLSessionConfiguration = .ephemeral,
        certificatePins: CertificatePinStoring = KeychainCertificatePinStore()
    ) {
        let delegate = SmartCastSessionDelegate(certificatePins: certificatePins)
        let hardenedConfiguration = configuration.copy() as! URLSessionConfiguration
        hardenedConfiguration.timeoutIntervalForRequest = 6
        hardenedConfiguration.timeoutIntervalForResource = 8
        hardenedConfiguration.waitsForConnectivity = false
        hardenedConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
        hardenedConfiguration.urlCache = nil
        hardenedConfiguration.httpCookieStorage = nil
        hardenedConfiguration.httpShouldSetCookies = false
        self.configuration = hardenedConfiguration
        self.delegate = delegate
        self.session = URLSession(configuration: hardenedConfiguration, delegate: delegate, delegateQueue: nil)
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var securedRequest = request
        let requestID = UUID().uuidString
        securedRequest.setValue(requestID, forHTTPHeaderField: Self.requestIDHeader)
        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            let activeSession = currentSession()
            (bytes, response) = try await activeSession.bytes(for: securedRequest)
        } catch {
            if let trustFailure = delegate.consumeTrustFailure(requestID: requestID) {
                throw trustFailure
            }
            throw error
        }
        guard let http = response as? HTTPURLResponse else {
            throw SmartCastError.malformedResponse
        }
        if http.expectedContentLength > Int64(Self.maximumResponseBytes) {
            throw SmartCastError.malformedResponse
        }

        var data = Data()
        if http.expectedContentLength > 0 {
            data.reserveCapacity(min(Int(http.expectedContentLength), Self.maximumResponseBytes))
        }
        for try await byte in bytes {
            guard data.count < Self.maximumResponseBytes else {
                throw SmartCastError.malformedResponse
            }
            data.append(byte)
        }
        return (data, http)
    }

    func commitSecurityIdentity(host: String, port: Int) throws {
        do {
            try delegate.commitSecurityIdentity(host: host, port: port)
        } catch let error as SmartCastError {
            throw error
        } catch {
            throw SmartCastError.securityStorageUnavailable
        }
    }

    func resetSecurityIdentity(host: String, port: Int) throws {
        defer { rebuildSession() }
        do {
            try delegate.resetSecurityIdentity(host: host, port: port)
        } catch {
            throw SmartCastError.securityStorageUnavailable
        }
    }

    func resetAllSecurityIdentities() throws {
        defer { rebuildSession() }
        do {
            try delegate.resetAllSecurityIdentities()
        } catch {
            throw SmartCastError.securityStorageUnavailable
        }
    }

    func discardUncommittedSecurityIdentity(host: String, port: Int) {
        delegate.discardUncommittedSecurityIdentity(host: host, port: port)
    }

    private func rebuildSession() {
        let replacement = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        sessionLock.lock()
        let previous = session
        session = replacement
        sessionLock.unlock()
        previous.invalidateAndCancel()
    }

    private func currentSession() -> URLSession {
        sessionLock.lock()
        let active = session
        sessionLock.unlock()
        return active
    }

    deinit {
        currentSession().invalidateAndCancel()
    }

}

private final class SmartCastSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    private let certificatePins: CertificatePinStoring
    private let lock = NSLock()
    private var candidateCertificates: [String: Data] = [:]
    private var validatedCertificates: [String: Data] = [:]
    private var trustFailures: [String: SmartCastError] = [:]

    init(certificatePins: CertificatePinStoring) {
        self.certificatePins = certificatePins
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              LocalNetworkAddress.isPrivateHost(challenge.protectionSpace.host),
              LocalNetworkAddress.isSupportedSmartCastPort(challenge.protectionSpace.port),
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        guard let certificates = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
              let leaf = certificates.first else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        let certificate = SecCertificateCopyData(leaf) as Data
        do {
            switch try certificatePins.status(
                for: certificate,
                host: challenge.protectionSpace.host,
                port: challenge.protectionSpace.port
            ) {
            case .matches:
                recordValidated(certificate, host: challenge.protectionSpace.host, port: challenge.protectionSpace.port)
            case .missing:
                // A saved AUTH token must never be sent over a first-contact TLS
                // connection. A pin is established only by a successful PIN-based
                // pairing response; a missing pin therefore requires re-pairing.
                if task.originalRequest?.value(forHTTPHeaderField: "AUTH") != nil {
                    recordTrustFailure(.authenticationRequired, task: task)
                    completionHandler(.cancelAuthenticationChallenge, nil)
                    return
                }
                guard recordCandidate(
                    certificate,
                    host: challenge.protectionSpace.host,
                    port: challenge.protectionSpace.port
                ) else {
                    recordTrustFailure(.securityIdentityChanged, task: task)
                    completionHandler(.cancelAuthenticationChallenge, nil)
                    return
                }
            case .mismatch:
                recordTrustFailure(.securityIdentityChanged, task: task)
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }
        } catch {
            recordTrustFailure(.securityStorageUnavailable, task: task)
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // SmartCast televisions present a manufacturer self-signed certificate whose
        // common name does not match the TV's local IP. Trust is relaxed only for the
        // exact private-network host selected by the user. Redirects are rejected
        // below so an AUTH header cannot be forwarded to another host.
        completionHandler(.useCredential, URLCredential(trust: trust))
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }

    func consumeTrustFailure(requestID: String) -> SmartCastError? {
        lock.lock()
        defer { lock.unlock() }
        return trustFailures.removeValue(forKey: requestID)
    }

    func commitSecurityIdentity(host: String, port: Int) throws {
        let key = "\(host):\(port)"
        lock.lock()
        let candidate = candidateCertificates[key]
        let validated = validatedCertificates[key]
        lock.unlock()
        guard let certificate = candidate ?? validated else {
            throw SmartCastError.securityIdentityUnavailable
        }

        do {
            switch try certificatePins.status(for: certificate, host: host, port: port) {
            case .missing:
                guard candidate != nil else { throw SmartCastError.securityIdentityUnavailable }
                try certificatePins.store(certificate, host: host, port: port)
            case .matches:
                break
            case .mismatch:
                throw SmartCastError.securityIdentityChanged
            }
        } catch let error as SmartCastError {
            throw error
        } catch {
            throw SmartCastError.securityStorageUnavailable
        }

        lock.lock()
        if candidateCertificates[key] == certificate {
            candidateCertificates.removeValue(forKey: key)
        }
        // Keep the validated leaf for the life of this transport session. A TV
        // may invalidate AUTH and require re-pairing over the existing TLS
        // connection, which does not trigger a second trust challenge.
        validatedCertificates[key] = certificate
        lock.unlock()
    }

    func resetSecurityIdentity(host: String, port: Int) throws {
        try certificatePins.delete(host: host, port: port)
        lock.lock()
        candidateCertificates.removeValue(forKey: "\(host):\(port)")
        validatedCertificates.removeValue(forKey: "\(host):\(port)")
        trustFailures.removeAll()
        lock.unlock()
    }

    func resetAllSecurityIdentities() throws {
        try certificatePins.deleteAll()
        lock.lock()
        candidateCertificates.removeAll()
        validatedCertificates.removeAll()
        trustFailures.removeAll()
        lock.unlock()
    }

    func discardUncommittedSecurityIdentity(host: String, port: Int) {
        lock.lock()
        candidateCertificates.removeValue(forKey: "\(host):\(port)")
        lock.unlock()
    }

    private func recordCandidate(_ certificate: Data, host: String, port: Int) -> Bool {
        let key = "\(host):\(port)"
        lock.lock()
        defer { lock.unlock() }
        if let existing = candidateCertificates[key] {
            return existing == certificate
        }
        candidateCertificates[key] = certificate
        return true
    }

    private func recordTrustFailure(_ error: SmartCastError, task: URLSessionTask) {
        guard let requestID = task.originalRequest?.value(forHTTPHeaderField: SmartCastHTTPTransport.requestIDHeader) else { return }
        lock.lock()
        trustFailures[requestID] = error
        lock.unlock()
    }

    private func recordValidated(_ certificate: Data, host: String, port: Int) {
        lock.lock()
        validatedCertificates["\(host):\(port)"] = certificate
        lock.unlock()
    }
}
