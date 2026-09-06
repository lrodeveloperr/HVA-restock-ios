import Foundation

public enum InventoryCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    case capacitor
    case contactor
    case fuse
    case filter
    case motor
    case fitting
    case thermostat
    case consumable
    case other

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .capacitor: "Capacitor"
        case .contactor: "Contactor"
        case .fuse: "Fuse"
        case .filter: "Filter"
        case .motor: "Motor"
        case .fitting: "Fitting"
        case .thermostat: "Thermostat"
        case .consumable: "Consumable"
        case .other: "Other"
        }
    }
}

public struct InventoryDraft: Equatable, Sendable {
    public var name: String
    public var partNumber: String
    public var category: InventoryCategory
    public var location: String
    public var quantity: Int
    public var restockAt: Int
    public var restockTo: Int

    public init(
        name: String = "",
        partNumber: String = "",
        category: InventoryCategory = .capacitor,
        location: String = "",
        quantity: Int = 1,
        restockAt: Int = 1,
        restockTo: Int = 2
    ) {
        self.name = name
        self.partNumber = partNumber
        self.category = category
        self.location = location
        self.quantity = quantity
        self.restockAt = restockAt
        self.restockTo = restockTo
    }
}

public struct InventorySnapshot: Equatable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var partNumber: String
    public var category: InventoryCategory
    public var location: String
    public var quantity: Int
    public var restockAt: Int
    public var restockTo: Int
    public var updatedAt: Date
    public var lastUsedAt: Date?

    public init(
        id: UUID,
        name: String,
        partNumber: String,
        category: InventoryCategory,
        location: String,
        quantity: Int,
        restockAt: Int,
        restockTo: Int,
        updatedAt: Date,
        lastUsedAt: Date?
    ) {
        self.id = id
        self.name = name
        self.partNumber = partNumber
        self.category = category
        self.location = location
        self.quantity = quantity
        self.restockAt = restockAt
        self.restockTo = restockTo
        self.updatedAt = updatedAt
        self.lastUsedAt = lastUsedAt
    }
}

public enum InventoryValidationError: LocalizedError, Equatable, Sendable {
    case missingName
    case negativeQuantity
    case invalidRestockLevels
    case emptyAdjustment
    case insufficientStock
    case duplicateItem

    public var errorDescription: String? {
        switch self {
        case .missingName: "Enter an item name."
        case .negativeQuantity: "Quantity cannot be negative."
        case .invalidRestockLevels: "Restock-to quantity must be greater than the restock level."
        case .emptyAdjustment: "Enter a quantity greater than zero."
        case .insufficientStock: "There is not enough stock for that change."
        case .duplicateItem: "That item already exists."
        }
    }
}

public enum InventoryRules {
    public static let freeItemLimit = 10
    public static let maximumQuantity = 999_999
    public static let maximumTextLength = 120

    public static func normalized(_ value: String) -> String {
        String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maximumTextLength))
    }

    public static func validate(_ draft: InventoryDraft) throws -> InventoryDraft {
        var result = draft
        result.name = normalized(result.name)
        result.partNumber = normalized(result.partNumber)
        result.location = normalized(result.location)

        guard !result.name.isEmpty else { throw InventoryValidationError.missingName }
        guard result.quantity >= 0, result.restockAt >= 0, result.restockTo >= 0 else {
            throw InventoryValidationError.negativeQuantity
        }
        guard result.quantity <= maximumQuantity,
              result.restockAt <= maximumQuantity,
              result.restockTo <= maximumQuantity,
              result.restockTo > result.restockAt else {
            throw InventoryValidationError.invalidRestockLevels
        }
        return result
    }

    public static func suggestedPurchase(onHand: Int, restockTo: Int) -> Int {
        let safeOnHand = min(maximumQuantity, max(0, onHand))
        let safeTarget = min(maximumQuantity, max(0, restockTo))
        return max(0, safeTarget - safeOnHand)
    }

    public static func isLowStock(onHand: Int, restockAt: Int) -> Bool {
        max(0, onHand) <= max(0, restockAt)
    }

    public static func quantity(afterApplying delta: Int, to current: Int) throws -> Int {
        let (candidate, overflow) = current.addingReportingOverflow(delta)
        guard !overflow, candidate >= 0, candidate <= maximumQuantity else {
            throw InventoryValidationError.insufficientStock
        }
        return candidate
    }

    public static func duplicateKey(name: String, partNumber: String, category: InventoryCategory, location: String) -> String {
        [normalized(name), normalized(partNumber), category.rawValue, normalized(location)]
            .map { $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")) }
            .joined(separator: "|")
    }

    public static func newItemCount(
        existingKeys: Set<String>,
        incomingKeys: [String],
        mergeDuplicates: Bool
    ) -> Int {
        mergeDuplicates ? Set(incomingKeys).subtracting(existingKeys).count : incomingKeys.count
    }

    public static func requiresLifetimeUnlock(currentItems: Int, newItems: Int, unlocked: Bool) -> Bool {
        guard !unlocked else { return false }
        guard currentItems >= 0, newItems >= 0 else { return true }
        let (total, overflow) = currentItems.addingReportingOverflow(newItems)
        return overflow || total > freeItemLimit
    }

    public static func canReverse(currentQuantity: Int, eventDelta: Int) -> Bool {
        guard eventDelta != 0, eventDelta != Int.min else { return false }
        return (try? quantity(afterApplying: -eventDelta, to: currentQuantity)) != nil
    }
}
