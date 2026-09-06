import Foundation
import SwiftData
import Observation
import HVACRestockCore

public enum InventoryStoreError: LocalizedError {
    case itemNotFound
    case eventNotFound
    case eventAlreadyReversed
    case invalidEvent
    case freeLimitReached
    case importContainsNoValidRows
    case persistence(String)

    public var errorDescription: String? {
        switch self {
        case .itemNotFound: "That item is no longer available."
        case .eventNotFound: "That activity entry is no longer available."
        case .eventAlreadyReversed: "That change has already been reversed."
        case .invalidEvent: "That activity entry is invalid and cannot be reversed."
        case .freeLimitReached: "Unlock unlimited truck stock to add more than ten items."
        case .importContainsNoValidRows: "The CSV contains no valid inventory rows."
        case .persistence(let message): "The change could not be saved. \(message)"
        }
    }
}

@MainActor
@Observable
public final class InventoryStore {
    public private(set) var items: [InventoryItem] = []
    public private(set) var events: [StockEvent] = []
    public private(set) var lastError: String?
    public private(set) var lastAction: String?

    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
        refresh()
    }

    public var activeItemCount: Int { items.count }
    public var lowStockItems: [InventoryItem] {
        items.filter { InventoryRules.isLowStock(onHand: $0.quantity, restockAt: $0.restockAt) }
    }
    public var recentItems: [InventoryItem] {
        Array(items.filter { $0.lastUsedAt != nil }.sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }.prefix(6))
    }

    public func clearMessages() {
        lastError = nil
        lastAction = nil
    }

    public func refresh() {
        do {
            items = try context.fetch(FetchDescriptor<InventoryItem>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))
            events = try context.fetch(FetchDescriptor<StockEvent>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
            lastError = nil
        } catch {
            lastError = InventoryStoreError.persistence(error.localizedDescription).localizedDescription
        }
    }

    public func add(_ draft: InventoryDraft, unlocked: Bool) throws {
        let valid = try InventoryRules.validate(draft)
        guard unlocked || activeItemCount < InventoryRules.freeItemLimit else {
            throw InventoryStoreError.freeLimitReached
        }
        guard !hasDuplicate(valid) else { throw InventoryValidationError.duplicateItem }

        let item = InventoryItem(draft: valid)
        context.insert(item)
        context.insert(StockEvent(
            itemID: item.id,
            itemName: item.name,
            kind: .created,
            delta: item.quantity,
            resultingQuantity: item.quantity
        ))
        try save(action: "Added \(item.name)")
    }

    public func update(_ item: InventoryItem, draft: InventoryDraft) throws {
        let item = try currentItem(for: item)
        let valid = try InventoryRules.validate(draft)
        let oldKey = InventoryRules.duplicateKey(name: item.name, partNumber: item.partNumber, category: item.category, location: item.location)
        let newKey = InventoryRules.duplicateKey(name: valid.name, partNumber: valid.partNumber, category: valid.category, location: valid.location)
        if oldKey != newKey, hasDuplicate(valid) { throw InventoryValidationError.duplicateItem }

        let delta = valid.quantity - item.quantity
        item.name = valid.name
        item.partNumber = valid.partNumber
        item.category = valid.category
        item.location = valid.location
        item.quantity = valid.quantity
        item.restockAt = valid.restockAt
        item.restockTo = valid.restockTo
        item.updatedAt = .now
        if delta != 0 {
            context.insert(StockEvent(itemID: item.id, itemName: item.name, kind: .adjustment, delta: delta, resultingQuantity: item.quantity))
        }
        try save(action: "Updated \(item.name)")
    }

    public func useOne(_ item: InventoryItem) throws {
        let item = try currentItem(for: item)
        let newQuantity = try InventoryRules.quantity(afterApplying: -1, to: item.quantity)
        item.quantity = newQuantity
        item.lastUsedAt = .now
        item.updatedAt = .now
        context.insert(StockEvent(
            itemID: item.id,
            itemName: item.name,
            kind: .used,
            delta: -1,
            resultingQuantity: newQuantity
        ))
        try save(action: "Used \(item.name)")
    }

    public func addOne(_ item: InventoryItem) throws {
        let item = try currentItem(for: item)
        try mutate(item, delta: 1, kind: .adjustment, action: "Added one \(item.name)")
    }

    public func stock(_ item: InventoryItem, amount: Int) throws {
        guard amount > 0 else { throw InventoryValidationError.emptyAdjustment }
        let item = try currentItem(for: item)
        try mutate(item, delta: amount, kind: .stocked, action: "Stocked \(item.name)")
    }

    public func delete(_ item: InventoryItem) throws {
        let item = try currentItem(for: item)
        let name = item.name
        context.delete(item)
        try save(action: "Deleted \(name)")
    }

    public func deleteAllData() throws {
        for event in events { context.delete(event) }
        for item in items { context.delete(item) }
        try save(action: "Deleted all app data")
    }

    public func reverse(_ event: StockEvent) throws {
        guard let currentEvent = events.first(where: { $0.id == event.id }) else { throw InventoryStoreError.eventNotFound }
        guard currentEvent.canReverse else { throw InventoryStoreError.eventAlreadyReversed }
        guard currentEvent.delta != Int.min else { throw InventoryStoreError.invalidEvent }
        guard let item = items.first(where: { $0.id == currentEvent.itemID }) else { throw InventoryStoreError.itemNotFound }

        let inverse = -currentEvent.delta
        let newQuantity = try InventoryRules.quantity(afterApplying: inverse, to: item.quantity)
        item.quantity = newQuantity
        item.updatedAt = .now
        currentEvent.reversedAt = .now
        context.insert(StockEvent(
            itemID: item.id,
            itemName: item.name,
            kind: .reversed,
            delta: inverse,
            resultingQuantity: newQuantity,
            reversesEventID: currentEvent.id
        ))
        try save(action: "Reversed change to \(item.name)")
    }

    public func canReverse(_ event: StockEvent) -> Bool {
        guard event.canReverse,
              let item = items.first(where: { $0.id == event.itemID }) else { return false }
        return InventoryRules.canReverse(currentQuantity: item.quantity, eventDelta: event.delta)
    }

    public func importRows(_ rows: [CSVImportRow], mergeDuplicates: Bool, unlocked: Bool) throws {
        guard !rows.isEmpty else { throw InventoryStoreError.importContainsNoValidRows }

        let validatedRows = try rows.map { row in
            CSVImportRow(id: row.id, sourceLine: row.sourceLine, draft: try InventoryRules.validate(row.draft))
        }
        let existingKeys = Set(items.map { duplicateKey($0) })
        let incomingKeys = validatedRows.map { duplicateKey($0.draft) }
        let newItemCount = InventoryRules.newItemCount(
            existingKeys: existingKeys,
            incomingKeys: incomingKeys,
            mergeDuplicates: mergeDuplicates
        )
        guard !InventoryRules.requiresLifetimeUnlock(
            currentItems: activeItemCount,
            newItems: newItemCount,
            unlocked: unlocked
        ) else {
            throw InventoryStoreError.freeLimitReached
        }

        var itemsByKey: [String: InventoryItem] = [:]
        for item in items where itemsByKey[duplicateKey(item)] == nil {
            itemsByKey[duplicateKey(item)] = item
        }

        do {
            for row in validatedRows {
                let valid = row.draft
                let key = duplicateKey(valid)
                if mergeDuplicates, let existing = itemsByKey[key] {
                    let newQuantity = try InventoryRules.quantity(afterApplying: valid.quantity, to: existing.quantity)
                    existing.quantity = newQuantity
                    existing.restockAt = valid.restockAt
                    existing.restockTo = valid.restockTo
                    existing.updatedAt = .now
                    context.insert(StockEvent(itemID: existing.id, itemName: existing.name, kind: .imported, delta: valid.quantity, resultingQuantity: newQuantity))
                } else {
                    let item = InventoryItem(draft: valid)
                    context.insert(item)
                    if mergeDuplicates { itemsByKey[key] = item }
                    context.insert(StockEvent(itemID: item.id, itemName: item.name, kind: .imported, delta: item.quantity, resultingQuantity: item.quantity))
                }
            }
            try save(action: "Imported \(validatedRows.count) item\(validatedRows.count == 1 ? "" : "s")")
        } catch {
            context.rollback()
            refresh()
            throw error
        }
    }

    public func inventoryCSV() -> String { InventoryCSVCodec.exportInventory(items.map(\.snapshot)) }
    public func restockCSV() -> String { InventoryCSVCodec.exportRestock(items.map(\.snapshot)) }

    public func activityCSV() -> String {
        let header = "Date,Item,Action,Change,Result,Reversed\r\n"
        let formatter = ISO8601DateFormatter()
        let body = events.map { event in
            [
                formatter.string(from: event.createdAt),
                csvEscape(event.itemName),
                event.kind.label,
                String(event.delta),
                String(event.resultingQuantity),
                event.reversedAt == nil ? "No" : "Yes"
            ].joined(separator: ",")
        }.joined(separator: "\r\n")
        return header + body + (body.isEmpty ? "" : "\r\n")
    }

    private func mutate(_ item: InventoryItem, delta: Int, kind: StockEventKind, action: String) throws {
        let newQuantity = try InventoryRules.quantity(afterApplying: delta, to: item.quantity)
        item.quantity = newQuantity
        item.updatedAt = .now
        context.insert(StockEvent(itemID: item.id, itemName: item.name, kind: kind, delta: delta, resultingQuantity: newQuantity))
        try save(action: action)
    }

    private func save(action: String) throws {
        do {
            try context.save()
            lastError = nil
            lastAction = action
            refresh()
        } catch {
            context.rollback()
            refresh()
            throw InventoryStoreError.persistence(error.localizedDescription)
        }
    }

    private func hasDuplicate(_ draft: InventoryDraft) -> Bool {
        let key = duplicateKey(draft)
        return items.contains { duplicateKey($0) == key }
    }

    private func currentItem(for item: InventoryItem) throws -> InventoryItem {
        guard let current = items.first(where: { $0.id == item.id }) else {
            throw InventoryStoreError.itemNotFound
        }
        return current
    }

    private func duplicateKey(_ draft: InventoryDraft) -> String {
        InventoryRules.duplicateKey(name: draft.name, partNumber: draft.partNumber, category: draft.category, location: draft.location)
    }

    private func duplicateKey(_ item: InventoryItem) -> String {
        InventoryRules.duplicateKey(name: item.name, partNumber: item.partNumber, category: item.category, location: item.location)
    }

    private func csvEscape(_ value: String) -> String {
        let candidate = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let safe: String
        if value.first == "'",
           let first = String(value.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines).first,
           ["=", "+", "-", "@"].contains(first) { safe = "'" + value }
        else if let first = candidate.first, ["=", "+", "-", "@"].contains(first) { safe = "'" + value }
        else { safe = value }
        guard safe.contains(",") || safe.contains("\"") || safe.contains("\n") || safe.contains("\r") else { return safe }
        return "\"\(safe.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
