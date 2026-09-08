import XCTest
@testable import VizioRemote

final class SmartCastServiceTests: XCTestCase {
    private let device = TVDevice(id: "test-tv", name: "Test TV", host: "192.168.1.50", port: 7345)

    func testVerifyUsesExpectedEndpointAndAuthHeader() async throws {
        let transport = RecordingTransport(responseData: responseData(successResponse))
        let service = SmartCastService(transport: transport)

        try await service.verify(device: device, authToken: "secret-token")

        let requests = await transport.requests
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://192.168.1.50:7345/state/device/power_mode")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "AUTH"), "secret-token")
    }

    func testRejectsUnsupportedPortBeforeTransport() async {
        let transport = RecordingTransport(responseData: responseData(successResponse))
        let service = SmartCastService(transport: transport)
        let unsafe = TVDevice(id: "unsafe", name: "Unsafe", host: "192.168.1.50", port: 443)

        do {
            try await service.verify(device: unsafe, authToken: "token")
            XCTFail("Expected unsupportedAddress")
        } catch {
            XCTAssertEqual(error as? SmartCastError, .unsupportedAddress)
        }
    }

    func testCancelPairingUsesDocumentedCancellationShape() async throws {
        let transport = RecordingTransport(responseData: responseData(successResponse))
        let service = SmartCastService(transport: transport)
        let challenge = PairingChallenge(requestToken: 2468, challengeType: 1, deviceID: "client-id")

        await service.cancelPairing(with: device, challenge: challenge)

        let requests = await transport.requests
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url?.path, "/pairing/cancel")
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["DEVICE_ID"] as? String, "client-id")
        XCTAssertEqual(json["CHALLENGE_TYPE"] as? Int, 1)
        XCTAssertEqual(json["RESPONSE_VALUE"] as? String, "1111")
        XCTAssertEqual(json["PAIRING_REQ_TOKEN"] as? Int, 2468)
    }

    func testRejectsBooleanOrFractionalPairingChallengeValues() async {
        let invalidItems: [[String: Any]] = [
            ["PAIRING_REQ_TOKEN": true, "CHALLENGE_TYPE": 1],
            ["PAIRING_REQ_TOKEN": 1.5, "CHALLENGE_TYPE": 1],
            ["PAIRING_REQ_TOKEN": Int64(Int32.max) + 1, "CHALLENGE_TYPE": 1],
            ["PAIRING_REQ_TOKEN": Int64.max, "CHALLENGE_TYPE": 1],
            ["PAIRING_REQ_TOKEN": "18446744073709551615", "CHALLENGE_TYPE": 1]
        ]
        for item in invalidItems {
            let transport = RecordingTransport(responseData: responseData([
                "STATUS": ["RESULT": "SUCCESS", "DETAIL": "Success"],
                "ITEM": item
            ]))
            let service = SmartCastService(transport: transport)
            do {
                _ = try await service.startPairing(with: device)
                XCTFail("Expected malformedResponse")
            } catch {
                XCTAssertEqual(error as? SmartCastError, .malformedResponse)
            }
        }
    }

    func testAcceptsMaximumInt32PairingChallengeValue() async throws {
        let transport = RecordingTransport(responseData: responseData([
            "STATUS": ["RESULT": "SUCCESS", "DETAIL": "Success"],
            "ITEM": ["PAIRING_REQ_TOKEN": Int32.max, "CHALLENGE_TYPE": 1]
        ]))
        let service = SmartCastService(transport: transport)

        let challenge = try await service.startPairing(with: device)
        XCTAssertEqual(challenge.requestToken, Int(Int32.max))
    }

    func testAuthTokenValidationBoundaries() {
        XCTAssertFalse(SmartCastAuthToken.isValid(""))
        XCTAssertFalse(SmartCastAuthToken.isValid("line\nbreak"))
        XCTAssertFalse(SmartCastAuthToken.isValid("token with space"))
        XCTAssertTrue(SmartCastAuthToken.isValid(String(repeating: "A", count: 1_024)))
        XCTAssertFalse(SmartCastAuthToken.isValid(String(repeating: "A", count: 1_025)))
    }

    func testAuthenticatedUnauthorizedResponseRequiresPairingAgain() async {
        let transport = RecordingTransport(responseData: responseData(successResponse), statusCode: 401)
        let service = SmartCastService(transport: transport)

        do {
            try await service.verify(device: device, authToken: "secret-token")
            XCTFail("Expected authenticationRequired")
        } catch {
            XCTAssertEqual(error as? SmartCastError, .authenticationRequired)
        }
    }

    func testTextEntryUsesSmartCastSpaceCode() async throws {
        let transport = RecordingTransport(responseData: responseData(successResponse))
        let service = SmartCastService(transport: transport)

        try await service.sendText("A B", to: device, authToken: "secret-token")

        let requests = await transport.requests
        let request = try XCTUnwrap(requests.first)
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let keys = try XCTUnwrap(json["KEYLIST"] as? [[String: Any]])
        XCTAssertEqual(keys.compactMap { $0["CODE"] as? Int }, [65, 52, 66])
    }

    func testStripsUnicodeDirectionControlsFromTVErrorDetail() async {
        let transport = RecordingTransport(responseData: responseData([
            "STATUS": ["RESULT": "FAILURE", "DETAIL": "safe\u{202E}spoof"]
        ]))
        let service = SmartCastService(transport: transport)

        do {
            try await service.verify(device: device, authToken: "secret-token")
            XCTFail("Expected tvRejected")
        } catch let SmartCastError.tvRejected(detail) {
            XCTAssertEqual(detail, "safespoof")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private var successResponse: [String: Any] {
        ["STATUS": ["RESULT": "SUCCESS", "DETAIL": "Success"]]
    }

    private func responseData(_ object: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: object)
    }
}

private actor RecordingTransport: SmartCastTransporting {
    private let responseData: Data
    private let statusCode: Int
    private(set) var requests: [URLRequest] = []

    init(responseData: Data, statusCode: Int = 200) {
        self.responseData = responseData
        self.statusCode = statusCode
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        return (responseData, response)
    }

    nonisolated func commitSecurityIdentity(host: String, port: Int) throws {}
    nonisolated func resetSecurityIdentity(host: String, port: Int) throws {}
    nonisolated func resetAllSecurityIdentities() throws {}
    nonisolated func discardUncommittedSecurityIdentity(host: String, port: Int) {}
}
