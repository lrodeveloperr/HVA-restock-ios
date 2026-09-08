import Foundation
import Combine
import StoreKit

enum AccessState: Equatable {
    case loading
    case trialAvailable
    case trialActive(endsAt: Date)
    case trialExpired
    case verificationFailed
    case lifetimeUnlocked

    var grantsRemoteAccess: Bool {
        switch self {
        case .trialActive, .lifetimeUnlocked:
            return true
        case .loading, .trialAvailable, .trialExpired, .verificationFailed:
            return false
        }
    }
}

enum TrialAccessPolicy {
    static let duration: TimeInterval = 24 * 60 * 60
    static let maximumClockSkew: TimeInterval = 5 * 60

    static func state(purchaseDate: Date?, lifetimeUnlocked: Bool, now: Date) -> AccessState {
        if lifetimeUnlocked { return .lifetimeUnlocked }
        guard let purchaseDate else { return .trialAvailable }
        guard purchaseDate.timeIntervalSince(now) <= maximumClockSkew else {
            return .verificationFailed
        }

        let end = purchaseDate.addingTimeInterval(duration)
        return now < end ? .trialActive(endsAt: end) : .trialExpired
    }
}

enum EntitlementAccessPolicy {
    static func state(
        trialPurchaseDate: Date?,
        lifetimeUnlocked: Bool,
        ownedVerificationFailed: Bool,
        now: Date
    ) -> AccessState {
        let evaluated = TrialAccessPolicy.state(
            purchaseDate: trialPurchaseDate,
            lifetimeUnlocked: lifetimeUnlocked,
            now: now
        )
        return ownedVerificationFailed && !evaluated.grantsRemoteAccess
            ? .verificationFailed
            : evaluated
    }
}

@MainActor
final class PurchaseManager: ObservableObject {
    static let trialProductID = "com.worksbienstudios.clearmote.trial.1day"
    static let lifetimeProductID = "com.worksbienstudios.clearmote.lifetime"

    @Published private(set) var accessState: AccessState = .loading
    @Published private(set) var trialProduct: Product?
    @Published private(set) var lifetimeProduct: Product?
    @Published private(set) var isWorking = false
    @Published private(set) var isLoadingProducts = false
    @Published var errorMessage: String?
    @Published var showPurchaseSheet = false

    private var updatesTask: Task<Void, Never>?
    private var expiryTask: Task<Void, Never>?
    private var refreshGeneration = 0
    private let now: @Sendable () -> Date

    init(now: @escaping @Sendable () -> Date = { Date() }, listenForTransactions: Bool = true) {
        self.now = now
        if listenForTransactions {
            updatesTask = Task { [weak self] in
                for await result in Transaction.updates {
                    guard !Task.isCancelled else { return }
                    guard let self else { return }
                    await self.handleTransactionUpdate(result)
                }
            }
        }
    }

    deinit {
        updatesTask?.cancel()
        expiryTask?.cancel()
    }

    var hasRemoteAccess: Bool { accessState.grantsRemoteAccess }

    var trialEnd: Date? {
        guard case .trialActive(let end) = accessState else { return nil }
        return end
    }

    func prepare() async {
        await refreshEntitlements()
        if trialProduct == nil || lifetimeProduct == nil {
            await loadProducts()
        }
    }

    func loadProducts() async {
        guard !isLoadingProducts else { return }
        errorMessage = nil
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let products = try await Product.products(for: [Self.trialProductID, Self.lifetimeProductID])
            trialProduct = products.first { $0.id == Self.trialProductID && $0.type == .nonConsumable }
            lifetimeProduct = products.first { $0.id == Self.lifetimeProductID && $0.type == .nonConsumable }

            guard trialProduct != nil, lifetimeProduct != nil else {
                errorMessage = String(localized: "Purchases are temporarily unavailable. Please try again later.")
                return
            }
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = String(localized: "The App Store could not be reached. Please try again.")
        }
    }

    func startTrial() async {
        errorMessage = nil
        guard accessState == .trialAvailable else { return }
        guard let trialProduct else {
            errorMessage = String(localized: "The 1-day trial is temporarily unavailable.")
            return
        }
        guard lifetimeProduct != nil else {
            errorMessage = String(localized: "The one-time unlock price is temporarily unavailable. Please try again later.")
            return
        }
        await purchase(trialProduct)
    }

    func buyLifetime() async {
        errorMessage = nil
        if accessState == .lifetimeUnlocked { return }
        guard let lifetimeProduct else {
            errorMessage = String(localized: "The one-time unlock is temporarily unavailable.")
            return
        }
        await purchase(lifetimeProduct)
    }

    func restorePurchases() async {
        guard !isWorking else { return }
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = String(localized: "Purchases could not be restored. Check your App Store connection and try again.")
        }
    }

    func refreshEntitlements() async {
        refreshGeneration += 1
        let generation = refreshGeneration
        var lifetimeUnlocked = false
        var trialPurchaseDate: Date?
        var ownedVerificationFailed = false

        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                guard transaction.revocationDate == nil,
                      transaction.productType == .nonConsumable else { continue }
                switch transaction.productID {
                case Self.lifetimeProductID:
                    lifetimeUnlocked = true
                case Self.trialProductID:
                    if trialPurchaseDate == nil || transaction.originalPurchaseDate < trialPurchaseDate! {
                        trialPurchaseDate = transaction.originalPurchaseDate
                    }
                default:
                    continue
                }
            case .unverified(let transaction, _):
                if transaction.productID == Self.trialProductID || transaction.productID == Self.lifetimeProductID {
                    ownedVerificationFailed = true
                }
            }
        }

        guard generation == refreshGeneration else { return }

        accessState = EntitlementAccessPolicy.state(
            trialPurchaseDate: trialPurchaseDate,
            lifetimeUnlocked: lifetimeUnlocked,
            ownedVerificationFailed: ownedVerificationFailed,
            now: now()
        )
        scheduleTrialExpiryIfNeeded()
    }

    private func purchase(_ product: Product) async {
        guard !isWorking else { return }
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    await refreshEntitlements()
                    errorMessage = String(localized: "The App Store could not verify this purchase.")
                    return
                }
                guard transaction.productID == product.id,
                      transaction.productType == .nonConsumable else {
                    errorMessage = String(localized: "The App Store returned an unexpected purchase. Nothing was unlocked.")
                    return
                }
                deliver(transaction)
                await transaction.finish()
                await refreshEntitlements()
                errorMessage = nil
                if accessState.grantsRemoteAccess { showPurchaseSheet = false }
            case .pending:
                errorMessage = String(localized: "This purchase is pending approval. Access will update automatically when it completes.")
            case .userCancelled:
                break
            @unknown default:
                errorMessage = String(localized: "The purchase did not complete. Please try again.")
            }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = String(localized: "The purchase did not complete. Please try again.")
        }
    }

    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        switch result {
        case .verified(let transaction):
            guard transaction.productType == .nonConsumable,
                  transaction.productID == Self.trialProductID || transaction.productID == Self.lifetimeProductID else { return }
            if transaction.revocationDate == nil {
                deliver(transaction)
            } else {
                await refreshEntitlements()
            }
            await transaction.finish()
            await refreshEntitlements()
            errorMessage = nil
            if accessState.grantsRemoteAccess { showPurchaseSheet = false }
        case .unverified(let transaction, _):
            guard transaction.productID == Self.trialProductID || transaction.productID == Self.lifetimeProductID else { return }
            await refreshEntitlements()
            errorMessage = accessState.grantsRemoteAccess
                ? String(localized: "The App Store could not verify this purchase.")
                : String(localized: "An App Store purchase could not be verified. Remote access remains locked. Try Restore Purchases or contact Apple Support.")
        }
    }

    private func deliver(_ transaction: Transaction) {
        switch transaction.productID {
        case Self.lifetimeProductID:
            accessState = .lifetimeUnlocked
        case Self.trialProductID where accessState != .lifetimeUnlocked:
            accessState = TrialAccessPolicy.state(
                purchaseDate: transaction.originalPurchaseDate,
                lifetimeUnlocked: false,
                now: now()
            )
        default:
            return
        }
        scheduleTrialExpiryIfNeeded()
        if accessState.grantsRemoteAccess { showPurchaseSheet = false }
    }

    private func scheduleTrialExpiryIfNeeded() {
        expiryTask?.cancel()
        guard case .trialActive(let end) = accessState else { return }

        let delay = max(0, end.timeIntervalSince(now()))
        expiryTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                await self?.refreshEntitlements()
            } catch {
                return
            }
        }
    }
}
