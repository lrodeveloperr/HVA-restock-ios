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

    func testImplausibleFutureTrialDateFailsClosed() {
        let futureDate = now.addingTimeInterval(TrialAccessPolicy.maximumClockSkew + 1)
        XCTAssertEqual(
            TrialAccessPolicy.state(purchaseDate: futureDate, lifetimeUnlocked: false, now: now),
            .verificationFailed
        )
    }

    func testSmallClockSkewDoesNotLockValidTrial() {
        let futureDate = now.addingTimeInterval(TrialAccessPolicy.maximumClockSkew)
        XCTAssertEqual(
            TrialAccessPolicy.state(purchaseDate: futureDate, lifetimeUnlocked: false, now: now),
            .trialActive(endsAt: futureDate.addingTimeInterval(TrialAccessPolicy.duration))
        )
    }

    func testUnverifiedOwnershipFailsClosedAfterVerifiedTrialExpires() {
        let purchaseDate = now.addingTimeInterval(-TrialAccessPolicy.duration)
        XCTAssertEqual(
            EntitlementAccessPolicy.state(
                trialPurchaseDate: purchaseDate,
                lifetimeUnlocked: false,
                trialVerificationFailed: true,
                lifetimeVerificationFailed: false,
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
                trialVerificationFailed: false,
                lifetimeVerificationFailed: true,
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
                trialVerificationFailed: true,
                lifetimeVerificationFailed: false,
                now: now
            ),
            .lifetimeUnlocked
        )
    }

    func testTrialVerificationFailureDoesNotBecomeLifetimeFailure() {
        XCTAssertEqual(
            EntitlementAccessPolicy.state(
                trialPurchaseDate: nil,
                lifetimeUnlocked: false,
                trialVerificationFailed: true,
                lifetimeVerificationFailed: false,
                now: now
            ),
            .verificationFailed
        )
    }

    func testProductCatalogRequiresFreeTrialAndPaidLifetimeUnlock() {
        XCTAssertTrue(ProductCatalogPolicy.isValid(trialPrice: .zero, lifetimePrice: 2.99))
        XCTAssertFalse(ProductCatalogPolicy.isValid(trialPrice: 0.99, lifetimePrice: 2.99))
        XCTAssertFalse(ProductCatalogPolicy.isValid(trialPrice: .zero, lifetimePrice: .zero))
        XCTAssertFalse(ProductCatalogPolicy.isValid(trialPrice: nil, lifetimePrice: 2.99))
        XCTAssertFalse(ProductCatalogPolicy.isValid(trialPrice: .zero, lifetimePrice: nil))
    }

    func testLifetimePurchaseRemainsAvailableForTrialVerificationFailure() {
        XCTAssertTrue(
            PurchaseActionPolicy.canBuyLifetime(
                accessState: .verificationFailed,
                lifetimeVerificationFailed: false
            )
        )
    }

    func testLifetimePurchaseIsBlockedForLifetimeVerificationFailure() {
        XCTAssertFalse(
            PurchaseActionPolicy.canBuyLifetime(
                accessState: .verificationFailed,
                lifetimeVerificationFailed: true
            )
        )
    }
}
