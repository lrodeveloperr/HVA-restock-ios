import Foundation
import Observation
import StoreKit

public enum PurchaseError: LocalizedError {
    case productUnavailable
    case failedVerification
    case pending
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .productUnavailable: "The lifetime unlock is temporarily unavailable."
        case .failedVerification: "The purchase could not be verified."
        case .pending: "The purchase is awaiting approval."
        case .cancelled: "The purchase was cancelled."
        }
    }
}

@MainActor
@Observable
public final class PurchaseManager {
    public static let productID = "com.worksbienstudios.hvacrestock.lifetime"

    public private(set) var product: Product?
    public private(set) var isUnlocked = false
    public private(set) var isBusy = false
    public private(set) var message: String?

    public init() {}

    public var priceText: String { product?.displayPrice ?? "Unavailable" }
    public var canPurchase: Bool { product != nil && !isBusy && !isUnlocked }

    public func load() async {
        isBusy = true
        defer { isBusy = false }
        do {
            product = try await Product.products(for: [Self.productID]).first
            await refreshEntitlement()
            message = product == nil && !isUnlocked ? PurchaseError.productUnavailable.localizedDescription : nil
        } catch {
            message = error.localizedDescription
        }
    }

    public func purchase() async {
        guard let product else {
            message = PurchaseError.productUnavailable.localizedDescription
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verified(verification)
                await transaction.finish()
                await refreshEntitlement()
                message = isUnlocked ? "Lifetime access unlocked." : PurchaseError.failedVerification.localizedDescription
            case .pending:
                message = PurchaseError.pending.localizedDescription
            case .userCancelled:
                message = nil
            @unknown default:
                message = PurchaseError.failedVerification.localizedDescription
            }
        } catch {
            message = error.localizedDescription
        }
    }

    public func restore() async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            message = isUnlocked ? "Lifetime access restored." : "No lifetime purchase was found."
        } catch {
            message = error.localizedDescription
        }
    }

    public func refreshEntitlement() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == Self.productID,
                  transaction.revocationDate == nil,
                  !transaction.isUpgraded else { continue }
            unlocked = true
            break
        }
        isUnlocked = unlocked
    }

    public func observeTransactionUpdates() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result,
                  transaction.productID == Self.productID else { continue }
            await transaction.finish()
            await refreshEntitlement()
            if isUnlocked { message = "Lifetime access unlocked." }
        }
    }

    public func clearMessage() { message = nil }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): value
        case .unverified: throw PurchaseError.failedVerification
        }
    }
}
