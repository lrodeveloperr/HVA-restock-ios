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
        guard !hasImplausibleFutureDate(purchaseDate, now: now) else {
            return .verificationFailed
        }

        let end = purchaseDate.addingTimeInterval(duration)
        return now < end ? .trialActive(endsAt: end) : .trialExpired
    }

    static func hasImplausibleFutureDate(_ purchaseDate: Date?, now: Date) -> Bool {
        guard let purchaseDate else { return false }
        return purchaseDate.timeIntervalSince(now) > maximumClockSkew
    }
}

enum EntitlementAccessPolicy {
    static func state(
        trialPurchaseDate: Date?,
        lifetimeUnlocked: Bool,
        trialVerificationFailed: Bool,
        lifetimeVerificationFailed: Bool,
        now: Date
    ) -> AccessState {
        let evaluated = TrialAccessPolicy.state(
            purchaseDate: trialPurchaseDate,
            lifetimeUnlocked: lifetimeUnlocked,
            now: now
        )
        return (trialVerificationFailed || lifetimeVerificationFailed) && !evaluated.grantsRemoteAccess
            ? .verificationFailed
            : evaluated
    }
}

enum ProductCatalogPolicy {
    static func isValid(trialPrice: Decimal?, lifetimePrice: Decimal?) -> Bool {
        trialPrice == .zero && lifetimePrice.map { $0 > .zero } == true
    }
}

enum PurchaseActionPolicy {
    static func canBuyLifetime(accessState: AccessState, lifetimeVerificationFailed: Bool) -> Bool {
        accessState != .lifetimeUnlocked && !lifetimeVerificationFailed
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
    @Published private(set) var trialVerificationFailed = false
    @Published private(set) var lifetimeVerificationFailed = false
    @Published var errorMessage: String?
    @Published var showPurchaseSheet = false

    private var updatesTask: Task<Void, Never>?
    private var expiryTask: Task<Void, Never>?
    private var refreshGeneration = 0
    private let now: @Sendable () -> Date
    private let shouldListenForTransactions: Bool

    init(now: @escaping @Sendable () -> Date = { Date() }, listenForTransactions: Bool = true) {
        self.now = now
        shouldListenForTransactions = listenForTransactions
    }

    deinit {
        updatesTask?.cancel()
        expiryTask?.cancel()
    }

    var hasRemoteAccess: Bool { accessState.grantsRemoteAccess }
    var canBuyLifetime: Bool {
        PurchaseActionPolicy.canBuyLifetime(
            accessState: accessState,
            lifetimeVerificationFailed: lifetimeVerificationFailed
        )
    }

    var trialEnd: Date? {
        guard case .trialActive(let end) = accessState else { return nil }
        return end
    }

#if DEBUG
    func configureForScreenshot(accessState: AccessState) {
        self.accessState = accessState
    }
#endif

    func prepare() async {
        await processUnfinishedTransactions()
        startTransactionListenerIfNeeded()
        await refreshEntitlements()
        if trialProduct == nil || lifetimeProduct == nil {
            await loadProducts()
        }
    }

    func stopTransactionListener() async {
        updatesTask?.cancel()
        await updatesTask?.value
        updatesTask = nil
    }

    func loadProducts() async {
        guard !isLoadingProducts else { return }
        if accessState != .verificationFailed { errorMessage = nil }
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let products = try await Product.products(for: [Self.trialProductID, Self.lifetimeProductID])
            let loadedTrial = products.first { $0.id == Self.trialProductID && $0.type == .nonConsumable }
            let loadedLifetime = products.first { $0.id == Self.lifetimeProductID && $0.type == .nonConsumable }

            guard let loadedTrial, let loadedLifetime else {
                trialProduct = nil
                lifetimeProduct = nil
                errorMessage = String(localized: "Purchases are temporarily unavailable. Please try again later.")
                return
            }
            guard ProductCatalogPolicy.isValid(
                trialPrice: loadedTrial.price,
                lifetimePrice: loadedLifetime.price
            ) else {
                trialProduct = nil
                lifetimeProduct = nil
                errorMessage = String(localized: "Purchases are configured incorrectly. Please contact support.")
                return
            }
            trialProduct = loadedTrial
            lifetimeProduct = loadedLifetime
            if accessState != .verificationFailed { errorMessage = nil }
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
        guard !lifetimeVerificationFailed else {
            errorMessage = String(localized: "Your full unlock could not be verified. Use Restore Purchases or contact Apple Support; do not buy it again.")
            return
        }
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
            if accessState != .verificationFailed { errorMessage = nil }
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
        var trialVerificationFailed = false
        var lifetimeVerificationFailed = false

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
                switch transaction.productID {
                case Self.trialProductID:
                    trialVerificationFailed = true
                case Self.lifetimeProductID:
                    lifetimeVerificationFailed = true
                default:
                    continue
                }
            }
        }

        guard generation == refreshGeneration else { return }

        self.trialVerificationFailed = trialVerificationFailed
        self.lifetimeVerificationFailed = lifetimeVerificationFailed
        let evaluationTime = now()
        accessState = EntitlementAccessPolicy.state(
            trialPurchaseDate: trialPurchaseDate,
            lifetimeUnlocked: lifetimeUnlocked,
            trialVerificationFailed: trialVerificationFailed,
            lifetimeVerificationFailed: lifetimeVerificationFailed,
            now: evaluationTime
        )
        if !lifetimeUnlocked,
           TrialAccessPolicy.hasImplausibleFutureDate(trialPurchaseDate, now: evaluationTime) {
            errorMessage = String(localized: "The purchase date could not be verified. Turn on automatic date and time, then try Restore Purchases.")
        }
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
                guard deliver(transaction) else { return }
                await transaction.finish()
                await refreshEntitlements()
                if accessState != .verificationFailed { errorMessage = nil }
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

    private func processUnfinishedTransactions() async {
        for await result in Transaction.unfinished {
            guard !Task.isCancelled else { return }
            await handleTransactionUpdate(result)
        }
    }

    private func startTransactionListenerIfNeeded() {
        guard shouldListenForTransactions, updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard let self else { return }
                await self.handleTransactionUpdate(result)
            }
        }
    }

    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        switch result {
        case .verified(let transaction):
            guard transaction.productType == .nonConsumable,
                  transaction.productID == Self.trialProductID || transaction.productID == Self.lifetimeProductID else { return }
            if transaction.revocationDate == nil {
                guard deliver(transaction) else { return }
            } else {
                await refreshEntitlements()
            }
            await transaction.finish()
            await refreshEntitlements()
            if accessState != .verificationFailed { errorMessage = nil }
            if accessState.grantsRemoteAccess { showPurchaseSheet = false }
        case .unverified(let transaction, _):
            guard transaction.productID == Self.trialProductID || transaction.productID == Self.lifetimeProductID else { return }
            await refreshEntitlements()
            errorMessage = accessState.grantsRemoteAccess
                ? String(localized: "The App Store could not verify this purchase.")
                : String(localized: "An App Store purchase could not be verified. Remote access remains locked. Try Restore Purchases or contact Apple Support.")
        }
    }

    @discardableResult
    private func deliver(_ transaction: Transaction) -> Bool {
        switch transaction.productID {
        case Self.lifetimeProductID:
            lifetimeVerificationFailed = false
            accessState = .lifetimeUnlocked
        case Self.trialProductID where accessState != .lifetimeUnlocked:
            trialVerificationFailed = false
            let trialState = TrialAccessPolicy.state(
                purchaseDate: transaction.originalPurchaseDate,
                lifetimeUnlocked: false,
                now: now()
            )
            guard trialState != .verificationFailed else {
                accessState = .verificationFailed
                errorMessage = String(localized: "The purchase date could not be verified. Turn on automatic date and time, then try Restore Purchases.")
                scheduleTrialExpiryIfNeeded()
                return false
            }
            accessState = trialState
        default:
            return false
        }
        scheduleTrialExpiryIfNeeded()
        if accessState.grantsRemoteAccess { showPurchaseSheet = false }
        return true
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
