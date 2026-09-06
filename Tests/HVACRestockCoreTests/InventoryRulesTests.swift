import XCTest
@testable import HVACRestockCore

final class InventoryRulesTests: XCTestCase {
    func testValidationTrimsAndAcceptsZeroStock() throws {
        let draft = InventoryDraft(
            name: "  45/5 capacitor  ",
            partNumber: " CAP-455 ",
            category: .capacitor,
            location: " Bin A ",
            quantity: 0,
            restockAt: 1,
            restockTo: 4
        )

        let result = try InventoryRules.validate(draft)

        XCTAssertEqual(result.name, "45/5 capacitor")
        XCTAssertEqual(result.partNumber, "CAP-455")
        XCTAssertEqual(result.location, "Bin A")
        XCTAssertEqual(result.quantity, 0)
    }

    func testValidationRejectsMissingNameAndInvalidLevels() {
        XCTAssertThrowsError(try InventoryRules.validate(InventoryDraft(name: "  ")))
        XCTAssertThrowsError(try InventoryRules.validate(InventoryDraft(name: "Fuse", restockAt: 5, restockTo: 5)))
        XCTAssertThrowsError(try InventoryRules.validate(InventoryDraft(name: "Fuse", quantity: -1)))
    }

    func testSuggestedPurchaseAndLowStockBoundary() {
        XCTAssertTrue(InventoryRules.isLowStock(onHand: 2, restockAt: 2))
        XCTAssertFalse(InventoryRules.isLowStock(onHand: 3, restockAt: 2))
        XCTAssertEqual(InventoryRules.suggestedPurchase(onHand: 2, restockTo: 8), 6)
        XCTAssertEqual(InventoryRules.suggestedPurchase(onHand: 10, restockTo: 8), 0)
        XCTAssertEqual(InventoryRules.suggestedPurchase(onHand: Int.min, restockTo: Int.max), InventoryRules.maximumQuantity)
    }

    func testQuantityMutationGuardsUnderflowOverflowAndMaximum() throws {
        XCTAssertEqual(try InventoryRules.quantity(afterApplying: -1, to: 1), 0)
        XCTAssertThrowsError(try InventoryRules.quantity(afterApplying: -1, to: 0))
        XCTAssertThrowsError(try InventoryRules.quantity(afterApplying: 1, to: InventoryRules.maximumQuantity))
        XCTAssertThrowsError(try InventoryRules.quantity(afterApplying: Int.max, to: 1))
    }

    func testReversalRejectsOverflowAndImpossibleBalances() {
        XCTAssertTrue(InventoryRules.canReverse(currentQuantity: 1, eventDelta: -1))
        XCTAssertFalse(InventoryRules.canReverse(currentQuantity: 0, eventDelta: 1))
        XCTAssertFalse(InventoryRules.canReverse(currentQuantity: 1, eventDelta: Int.min))
    }

    func testDuplicateKeyIgnoresCaseWhitespaceAndDiacritics() {
        let first = InventoryRules.duplicateKey(name: "  Fusé ", partNumber: "ABC", category: .fuse, location: "Bin 1")
        let second = InventoryRules.duplicateKey(name: "fuse", partNumber: "abc", category: .fuse, location: "bin 1")
        XCTAssertEqual(first, second)
    }

    func testFreeLimitCountsMergedAndSeparateRowsCorrectly() {
        let existing: Set<String> = ["a"]
        let incoming = ["a", "b", "b"]

        XCTAssertEqual(InventoryRules.newItemCount(existingKeys: existing, incomingKeys: incoming, mergeDuplicates: true), 1)
        XCTAssertEqual(InventoryRules.newItemCount(existingKeys: existing, incomingKeys: incoming, mergeDuplicates: false), 3)
        XCTAssertFalse(InventoryRules.requiresLifetimeUnlock(currentItems: 9, newItems: 1, unlocked: false))
        XCTAssertTrue(InventoryRules.requiresLifetimeUnlock(currentItems: 10, newItems: 1, unlocked: false))
        XCTAssertFalse(InventoryRules.requiresLifetimeUnlock(currentItems: 10, newItems: 100, unlocked: true))
        XCTAssertTrue(InventoryRules.requiresLifetimeUnlock(currentItems: Int.max, newItems: 1, unlocked: false))
        XCTAssertTrue(InventoryRules.requiresLifetimeUnlock(currentItems: -1, newItems: 1, unlocked: false))
    }
}
