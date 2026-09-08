import XCTest
@testable import VizioRemote

final class TrialAccessPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_000_000)

    func testNoPurchasesLeavesTrialAvailable() {
        XCTAssertEqual(
            TrialAccessPolicy.state(purchaseDate: nil, lifetimeUnlocked: false, now: now),
            .trialAvailable
        )
    }

    func testTrialIsActiveUntilExactlyTwentyFourHours() {
        let purchaseDate = now.addingTimeInterval(-TrialAccessPolicy.duration + 1)
        XCTAssertEqual(
            TrialAccessPolicy.state(purchaseDate: purchaseDate, lifetimeUnlocked: false, now: now),
            .trialActive(endsAt: purchaseDate.addingTimeInterval(TrialAccessPolicy.duration))
        )
    }

    func testTrialExpiresAtBoundary() {
        let purchaseDate = now.addingTimeInterval(-TrialAccessPolicy.duration)
        XCTAssertEqual(
            TrialAccessPolicy.state(purchaseDate: purchaseDate, lifetimeUnlocked: false, now: now),
            .trialExpired
        )
    }

    func testLifetimeUnlockOverridesExpiredTrial() {
        let purchaseDate = now.addingTimeInterval(-TrialAccessPolicy.duration * 2)
        XCTAssertEqual(
            TrialAccessPolicy.state(purchaseDate: purchaseDate, lifetimeUnlocked: true, now: now),
            .lifetimeUnlocked
        )
    }

    func testUnverifiedOwnershipFailsClosedAfterVerifiedTrialExpires() {
        let purchaseDate = now.addingTimeInterval(-TrialAccessPolicy.duration)
        XCTAssertEqual(
            EntitlementAccessPolicy.state(
                trialPurchaseDate: purchaseDate,
                lifetimeUnlocked: false,
                ownedVerificationFailed: true,
                now: now
            ),
            .verificationFailed
        )
    }

    func testVerifiedActiveTrialStillGrantsAccessWhileAnotherTransactionIsUnverified() {
        let purchaseDate = now.addingTimeInterval(-60)
        XCTAssertEqual(
            EntitlementAccessPolicy.state(
                trialPurchaseDate: purchaseDate,
                lifetimeUnlocked: false,
                ownedVerificationFailed: true,
                now: now
            ),
            .trialActive(endsAt: purchaseDate.addingTimeInterval(TrialAccessPolicy.duration))
        )
    }

    func testVerifiedLifetimeOverridesUnverifiedOwnership() {
        XCTAssertEqual(
            EntitlementAccessPolicy.state(
                trialPurchaseDate: nil,
                lifetimeUnlocked: true,
                ownedVerificationFailed: true,
                now: now
            ),
            .lifetimeUnlocked
        )
    }
}
