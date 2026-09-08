import Foundation

enum LocalNetworkAddress {
    static func normalizedIPv4(_ input: String) -> String? {
        let candidate = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = candidate.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }

        var octets: [Int] = []
        for part in parts {
            guard !part.isEmpty,
                  part.utf8.allSatisfy({ (48...57).contains($0) }),
                  let value = Int(part),
                  (0...255).contains(value) else { return nil }
            octets.append(value)
        }

        guard isPrivate(octets) else { return nil }
        return octets.map(String.init).joined(separator: ".")
    }

    static func isPrivateHost(_ host: String) -> Bool {
        guard let normalized = normalizedIPv4(host) else { return false }
        return host == normalized
    }

    static func isSupportedSmartCastPort(_ port: Int) -> Bool {
        port == 7345 || port == 9000
    }

    private static func isPrivate(_ octets: [Int]) -> Bool {
        guard octets.count == 4 else { return false }
        if octets[0] == 10 { return true }
        if octets[0] == 172 && (16...31).contains(octets[1]) { return true }
        if octets[0] == 192 && octets[1] == 168 { return true }
        if octets[0] == 169 && octets[1] == 254 { return true }
#if DEBUG
        if octets[0] == 127 { return true }
#endif
        return false
    }
}
