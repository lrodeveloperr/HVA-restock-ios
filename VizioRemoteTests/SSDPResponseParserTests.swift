import XCTest
@testable import VizioRemote

final class SSDPResponseParserTests: XCTestCase {
    func testParsesVizioDiscoveryResponseCaseInsensitively() {
        let response = """
        HTTP/1.1 200 OK\r
        LOCATION: https://192.168.1.42:7345/ssdp/device-desc.xml\r
        St: urn:schemas-kinoma-com:device:shell:1\r
        USN: uuid:living-room-tv\r
        SERVER: Kinoma/1.0 VIZIO SmartCast\r
        \r

        """

        let device = SSDPResponseParser.parse(response)
        XCTAssertEqual(device?.id, "smartcast-192.168.1.42:7345")
        XCTAssertEqual(device?.host, "192.168.1.42")
        XCTAssertEqual(device?.port, 7345)
    }

    func testRejectsPublicOrUnrelatedDevices() {
        let publicHost = "HTTP/1.1 200 OK\r\nLOCATION: https://8.8.8.8:7345/device\r\nST: urn:schemas-kinoma-com:device:shell:1\r\n"
        let unrelated = "HTTP/1.1 200 OK\r\nLOCATION: https://192.168.1.50:7345/device\r\nSERVER: Printer\r\nST: upnp:rootdevice\r\n"
        XCTAssertNil(SSDPResponseParser.parse(publicHost))
        XCTAssertNil(SSDPResponseParser.parse(unrelated))
    }

    func testRejectsUnsafeSchemePortAndNonCanonicalHost() {
        let http = "HTTP/1.1 200 OK\r\nLOCATION: http://192.168.1.50:7345/device\r\nST: urn:schemas-kinoma-com:device:shell:1\r\n"
        let port = "HTTP/1.1 200 OK\r\nLOCATION: https://192.168.1.50:443/device\r\nST: urn:schemas-kinoma-com:device:shell:1\r\n"
        let ambiguous = "HTTP/1.1 200 OK\r\nLOCATION: https://010.000.000.008:7345/device\r\nST: urn:schemas-kinoma-com:device:shell:1\r\n"
        XCTAssertNil(SSDPResponseParser.parse(http))
        XCTAssertNil(SSDPResponseParser.parse(port))
        XCTAssertNil(SSDPResponseParser.parse(ambiguous))
    }

    func testRejectsOversizedResponse() {
        let oversized = "HTTP/1.1 200 OK\r\n" + String(repeating: "A", count: 16_385)
        XCTAssertNil(SSDPResponseParser.parse(oversized))
    }

    func testRejectsStatusCodePrefixAttack() {
        let response = "HTTP/1.1 2000 EVIL\r\nLOCATION: https://192.168.1.50:7345/device\r\nST: urn:schemas-kinoma-com:device:shell:1\r\n"
        XCTAssertNil(SSDPResponseParser.parse(response))
    }

    func testBindsAdvertisedLocationToDatagramSource() {
        let response = "HTTP/1.1 200 OK\r\nLOCATION: https://192.168.1.50:7345/device\r\nST: urn:schemas-kinoma-com:device:shell:1\r\n"
        XCTAssertNotNil(SSDPResponseParser.parse(response, sourceHost: "192.168.1.50"))
        XCTAssertNil(SSDPResponseParser.parse(response, sourceHost: "192.168.1.51"))
    }

    func testIgnoresEmptyOrHostileAdvertisedIdentifier() {
        let empty = "HTTP/1.1 200 OK\r\nLOCATION: https://192.168.1.50:7345/device\r\nST: urn:schemas-kinoma-com:device:shell:1\r\nUSN:\r\n"
        let duplicate = "HTTP/1.1 200 OK\r\nLOCATION: https://192.168.1.51:7345/device\r\nST: urn:schemas-kinoma-com:device:shell:1\r\nUSN: uuid:same-id\r\n"

        XCTAssertEqual(SSDPResponseParser.parse(empty)?.id, "smartcast-192.168.1.50:7345")
        XCTAssertEqual(SSDPResponseParser.parse(duplicate)?.id, "smartcast-192.168.1.51:7345")
    }
}
