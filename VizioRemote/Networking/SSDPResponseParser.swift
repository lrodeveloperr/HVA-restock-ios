import Foundation

enum SSDPResponseParser {
    static func parse(_ data: Data, sourceHost: String? = nil) -> TVDevice? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        return parse(text, sourceHost: sourceHost)
    }

    static func parse(_ text: String, sourceHost: String? = nil) -> TVDevice? {
        guard text.utf8.count <= 16_384 else { return nil }
        let lines = text.components(separatedBy: .newlines)
        guard lines.count <= 100,
              let statusLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        let statusTokens = statusLine.split(whereSeparator: { $0.isWhitespace })
        guard statusTokens.count >= 2,
              statusTokens[0] == "HTTP/1.1" || statusTokens[0] == "HTTP/1.0",
              statusTokens[1] == "200" else { return nil }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let separator = line.firstIndex(of: ":") else { continue }
            let key = line[..<separator].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
            guard key.count <= 128, value.count <= 1_024 else { return nil }
            headers[key] = value
        }

        guard let location = headers["location"],
              let components = URLComponents(string: location),
              components.scheme?.lowercased() == "https",
              let host = components.host,
              let normalizedHost = LocalNetworkAddress.normalizedIPv4(host),
              host == normalizedHost else { return nil }

        if let sourceHost {
            guard LocalNetworkAddress.normalizedIPv4(sourceHost) == normalizedHost else { return nil }
        }

        let searchTarget = headers["st"]?.lowercased() ?? ""
        guard searchTarget == "urn:schemas-kinoma-com:device:shell:1" else { return nil }

        let port = components.port ?? 7345
        guard LocalNetworkAddress.isSupportedSmartCastPort(port) else { return nil }
        // SSDP header values are attacker-controlled on the local network. Bind
        // persistence and Keychain lookup to the validated endpoint instead of
        // accepting USN/UUID as a security-sensitive identifier.
        let identifier = "smartcast-\(normalizedHost):\(port)"
        return TVDevice(id: identifier, name: String(localized: "Vizio SmartCast TV"), host: normalizedHost, port: port)
    }
}
