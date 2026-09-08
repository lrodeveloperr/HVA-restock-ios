import StoreKit
import StoreKitTest
import XCTest
@testable import VizioRemote

@MainActor
final class StoreKitIntegrationTests: XCTestCase {
    private func mark(_ phase: String) {
        FileHandle.standardError.write(Data("[StoreKitIntegration] \(phase)\n".utf8))
    }

    private func makeSession() throws -> SKTestSession {
        let session = try SKTestSession(configurationFileNamed: "Products")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        return session
    }

    private func unfinishedTransactions() async -> [(productID: String, verified: Bool)] {
        var transactions: [(productID: String, verified: Bool)] = []
        for await result in Transaction.unfinished {
            switch result {
            case .verified(let transaction):
                transactions.append((transaction.productID, true))
            case .unverified(let transaction, _):
                transactions.append((transaction.productID, false))
            }
        }
        return transactions
    }

    func testConfiguredProductsLoadWithSafePrices() async throws {
        let session = try makeSession()
        defer {
            session.resetToDefaultState()
            session.clearTransactions()
        }

        let manager = PurchaseManager(listenForTransactions: false)
        await manager.loadProducts()

        XCTAssertNil(manager.errorMessage)
        XCTAssertEqual(manager.trialProduct?.id, PurchaseManager.trialProductID)
        XCTAssertEqual(manager.trialProduct?.type, .nonConsumable)
        XCTAssertEqual(manager.trialProduct?.price, .zero)
        XCTAssertEqual(manager.lifetimeProduct?.id, PurchaseManager.lifetimeProductID)
        XCTAssertEqual(manager.lifetimeProduct?.type, .nonConsumable)
        XCTAssertEqual(manager.lifetimeProduct?.price, Decimal(string: "2.99"))
    }

    func testExternallyCreatedTrialDeliversAndFinishes() async throws {
        let session = try makeSession()
        defer {
            session.resetToDefaultState()
            session.clearTransactions()
        }
        mark("trial injection started")
        let transaction = try await session.buyProduct(identifier: PurchaseManager.trialProductID)
        mark("trial injection completed")
        XCTAssertEqual(transaction.productID, PurchaseManager.trialProductID)
        let manager = PurchaseManager(listenForTransactions: false)
        mark("trial recovery started")
        await manager.prepare()
        mark("trial recovery completed")

        guard case .trialActive(let endsAt) = manager.accessState else {
            return XCTFail("Expected a verified active trial, got \(manager.accessState)")
        }
        XCTAssertGreaterThan(endsAt, Date())
        XCTAssertLessThanOrEqual(endsAt.timeIntervalSinceNow, TrialAccessPolicy.duration)
        let unfinishedAfterTrial = await unfinishedTransactions()
        XCTAssertFalse(unfinishedAfterTrial.contains { $0.productID == PurchaseManager.trialProductID })
        XCTAssertTrue(unfinishedAfterTrial.allSatisfy(\.verified))
    }

    func testExternallyCreatedLifetimePurchaseDeliversAndFinishes() async throws {
        let session = try makeSession()
        defer {
            session.resetToDefaultState()
            session.clearTransactions()
        }
        mark("lifetime injection started")
        let transaction = try await session.buyProduct(identifier: PurchaseManager.lifetimeProductID)
        mark("lifetime injection completed")
        XCTAssertEqual(transaction.productID, PurchaseManager.lifetimeProductID)
        let manager = PurchaseManager(listenForTransactions: false)
        mark("lifetime recovery started")
        await manager.prepare()
        mark("lifetime recovery completed")

        XCTAssertEqual(manager.accessState, .lifetimeUnlocked)
        XCTAssertTrue(manager.hasRemoteAccess)
        let unfinishedAfterLifetime = await unfinishedTransactions()
        XCTAssertFalse(unfinishedAfterLifetime.contains { $0.productID == PurchaseManager.lifetimeProductID })
        XCTAssertTrue(unfinishedAfterLifetime.allSatisfy(\.verified))
    }

    func testFutureDatedTrialRemainsUnfinishedThenRecoversOnRelaunch() async throws {
        let session = try makeSession()
        defer {
            session.resetToDefaultState()
            session.clearTransactions()
        }
        let rejectedManager = PurchaseManager(
            now: { Date(timeIntervalSince1970: 0) },
            listenForTransactions: false
        )
        mark("future-date injection started")
        let transaction = try await session.buyProduct(identifier: PurchaseManager.trialProductID)
        mark("future-date injection completed")
        XCTAssertEqual(transaction.productID, PurchaseManager.trialProductID)
        mark("future-date rejection started")
        await rejectedManager.prepare()
        mark("future-date rejection completed")

        XCTAssertEqual(rejectedManager.accessState, .verificationFailed)
        XCTAssertEqual(
            rejectedManager.errorMessage,
            String(localized: "The purchase date could not be verified. Turn on automatic date and time, then try Restore Purchases.")
        )
        let unfinishedAfterRejection = await unfinishedTransactions()
        XCTAssertTrue(unfinishedAfterRejection.contains {
            $0.productID == PurchaseManager.trialProductID && $0.verified
        })

        let recoveredManager = PurchaseManager(listenForTransactions: false)
        mark("corrected-clock recovery started")
        await recoveredManager.prepare()
        mark("corrected-clock recovery completed")

        guard case .trialActive = recoveredManager.accessState else {
            return XCTFail("Expected the corrected clock to recover the trial")
        }
        let unfinishedAfterRecovery = await unfinishedTransactions()
        XCTAssertFalse(unfinishedAfterRecovery.contains { $0.productID == PurchaseManager.trialProductID })
        XCTAssertTrue(unfinishedAfterRecovery.allSatisfy(\.verified))
    }
}
