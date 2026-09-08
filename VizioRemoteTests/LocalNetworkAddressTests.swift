import XCTest
@testable import VizioRemote

final class LocalNetworkAddressTests: XCTestCase {
    func testAcceptsPrivateIPv4Ranges() {
        XCTAssertEqual(LocalNetworkAddress.normalizedIPv4("192.168.1.25"), "192.168.1.25")
        XCTAssertEqual(LocalNetworkAddress.normalizedIPv4("10.0.0.8"), "10.0.0.8")
        XCTAssertEqual(LocalNetworkAddress.normalizedIPv4("172.16.4.9"), "172.16.4.9")
        XCTAssertEqual(LocalNetworkAddress.normalizedIPv4("172.31.255.255"), "172.31.255.255")
    }

    func testRejectsPublicAndMalformedAddresses() {
        XCTAssertNil(LocalNetworkAddress.normalizedIPv4("8.8.8.8"))
        XCTAssertNil(LocalNetworkAddress.normalizedIPv4("172.32.0.1"))
        XCTAssertNil(LocalNetworkAddress.normalizedIPv4("192.168.1"))
        XCTAssertNil(LocalNetworkAddress.normalizedIPv4("192.168.1.999"))
        XCTAssertNil(LocalNetworkAddress.normalizedIPv4("example.com"))
        XCTAssertFalse(LocalNetworkAddress.isPrivateHost("010.000.000.008"))
        XCTAssertFalse(LocalNetworkAddress.isPrivateHost("192.168.001.010"))
        XCTAssertFalse(LocalNetworkAddress.isPrivateHost("television.local"))
    }

    func testOnlyKnownSmartCastPortsAreAccepted() {
        XCTAssertTrue(LocalNetworkAddress.isSupportedSmartCastPort(7345))
        XCTAssertTrue(LocalNetworkAddress.isSupportedSmartCastPort(9000))
        XCTAssertFalse(LocalNetworkAddress.isSupportedSmartCastPort(443))
        XCTAssertFalse(LocalNetworkAddress.isSupportedSmartCastPort(65_535))
    }
}
