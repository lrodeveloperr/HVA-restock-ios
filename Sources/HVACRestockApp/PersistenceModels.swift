import Foundation
import SwiftData
import HVACRestockCore

@Model
public final class InventoryItem {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var partNumber: String
    public var categoryRaw: String
    public var location: String
    public var quantity: Int
    public var restockAt: Int
    public var restockTo: Int
    public var createdAt: Date
    public var updatedAt: Date
    public var lastUsedAt: Date?

    public init(
        id: UUID = UUID(),
        draft: InventoryDraft,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = draft.name
        self.partNumber = draft.partNumber
        self.categoryRaw = draft.category.rawValue
        self.location = draft.location
        self.quantity = draft.quantity
        self.restockAt = draft.restockAt
        self.restockTo = draft.restockTo
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.lastUsedAt = nil
    }

    public var category: InventoryCategory {
        get { InventoryCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    public var snapshot: InventorySnapshot {
        InventorySnapshot(
            id: id,
            name: name,
            partNumber: partNumber,
            category: category,
            location: location,
            quantity: quantity,
            restockAt: restockAt,
            restockTo: restockTo,
            updatedAt: updatedAt,
            lastUsedAt: lastUsedAt
        )
    }
}

public enum StockEventKind: String, Codable, Sendable {
    case created
    case used
    case stocked
    case adjustment
    case imported
    case reversed

    public var label: String {
        switch self {
        case .created: "Created"
        case .used: "Used"
        case .stocked: "Stocked"
        case .adjustment: "Adjusted"
        case .imported: "Imported"
        case .reversed: "Reversed"
        }
    }
}

@Model
public final class StockEvent {
    @Attribute(.unique) public var id: UUID
    public var itemID: UUID
    public var itemName: String
    public var kindRaw: String
    public var delta: Int
    public var resultingQuantity: Int
    public var createdAt: Date
    public var reversedAt: Date?
    public var reversesEventID: UUID?

    public init(
        id: UUID = UUID(),
        itemID: UUID,
        itemName: String,
        kind: StockEventKind,
        delta: Int,
        resultingQuantity: Int,
        createdAt: Date = .now,
        reversesEventID: UUID? = nil
    ) {
        self.id = id
        self.itemID = itemID
        self.itemName = itemName
        self.kindRaw = kind.rawValue
        self.delta = delta
        self.resultingQuantity = resultingQuantity
        self.createdAt = createdAt
        self.reversedAt = nil
        self.reversesEventID = reversesEventID
    }

    public var kind: StockEventKind { StockEventKind(rawValue: kindRaw) ?? .adjustment }
    public var canReverse: Bool { reversedAt == nil && kind != .created && kind != .reversed && delta != 0 }
}
