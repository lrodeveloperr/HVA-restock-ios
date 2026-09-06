import Foundation
import XCTest
@testable import HVACRestockCore

final class CSVCodecTests: XCTestCase {
    func testParserHandlesCommasQuotesNewlinesAndCRLF() {
        let csv = "Item,Part number,Location\r\n\"Filter, pleated\",\"A\"\"1\",\"Shelf\nTwo\"\r\n"
        let rows = InventoryCSVCodec.parse(csv)

        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[1], ["Filter, pleated", "A\"1", "Shelf\nTwo"])
    }

    func testPreviewAcceptsAliasesAndReportsBadRows() throws {
        let csv = "Name,SKU,Type,Qty,Min,Par,Bin\nContactor,C40,Contactor,2,1,4,A1\nBad,B1,Fuse,nope,1,3,A2\n"
        let preview = try InventoryCSVCodec.preview(text: csv)

        XCTAssertEqual(preview.rows.count, 1)
        XCTAssertEqual(preview.rows[0].draft.name, "Contactor")
        XCTAssertEqual(preview.rows[0].draft.quantity, 2)
        XCTAssertEqual(preview.issues.count, 1)
        XCTAssertEqual(preview.issues[0].sourceLine, 3)
    }

    func testPreviewRejectsMissingItemColumn() {
        XCTAssertThrowsError(try InventoryCSVCodec.preview(text: "SKU,Qty\nA1,2\n")) { error in
            XCTAssertEqual(error as? CSVCodecError, .missingItemColumn)
        }
    }

    func testPreviewRejectsMalformedAndOversizedFiles() {
        XCTAssertThrowsError(try InventoryCSVCodec.preview(text: "Item,Location\nFuse,\"Truck")) { error in
            XCTAssertEqual(error as? CSVCodecError, .malformedCSV)
        }

        let oversized = Data(repeating: 65, count: InventoryCSVCodec.maximumImportBytes + 1)
        XCTAssertThrowsError(try InventoryCSVCodec.preview(data: oversized)) { error in
            XCTAssertEqual(error as? CSVCodecError, .fileTooLarge)
        }
    }

    func testSpreadsheetFormulaValuesAreNeutralizedAndRoundTrip() throws {
        let item = InventorySnapshot(
            id: UUID(),
            name: "=2+2",
            partNumber: "+SUM(A1:A2)",
            category: .other,
            location: "@remote",
            quantity: 1,
            restockAt: 1,
            restockTo: 2,
            updatedAt: .now,
            lastUsedAt: nil
        )

        let exported = InventoryCSVCodec.exportInventory([item])
        XCTAssertTrue(exported.contains("'=2+2"))
        XCTAssertTrue(exported.contains("'+SUM(A1:A2)"))
        let preview = try InventoryCSVCodec.preview(text: exported)
        XCTAssertEqual(preview.rows.first?.draft.name, item.name)
        XCTAssertEqual(preview.rows.first?.draft.partNumber, item.partNumber)
        XCTAssertEqual(preview.rows.first?.draft.location, item.location)
    }

    func testLiteralApostropheFormulaAndLeadingWhitespaceCanonicalization() throws {
        let first = snapshot(name: "'=literal", quantity: 1, threshold: 0)
        let second = snapshot(name: "  =formula", quantity: 1, threshold: 0)
        let preview = try InventoryCSVCodec.preview(text: InventoryCSVCodec.exportInventory([first, second]))
        XCTAssertEqual(Set(preview.rows.map(\.draft.name)), Set([first.name, second.name.trimmingCharacters(in: .whitespacesAndNewlines)]))
    }

    func testIssueLineTracksEmbeddedNewlinesInPriorRecords() throws {
        let csv = "Item,Location,Qty,Min,Par\n\"Filter\nPleated\",Truck,1,0,2\nBad,Truck,nope,0,2\n"
        let preview = try InventoryCSVCodec.preview(text: csv)
        XCTAssertEqual(preview.rows.count, 1)
        XCTAssertEqual(preview.issues.first?.sourceLine, 4)
    }

    func testExportEscapesFieldsAndRoundTripsThroughPreview() throws {
        let item = InventorySnapshot(
            id: UUID(),
            name: "Filter, 20\" x 20\"",
            partNumber: "F-20",
            category: .filter,
            location: "Shelf\nB",
            quantity: 2,
            restockAt: 2,
            restockTo: 8,
            updatedAt: Date(timeIntervalSince1970: 0),
            lastUsedAt: nil
        )

        let exported = InventoryCSVCodec.exportInventory([item])
        let preview = try InventoryCSVCodec.preview(text: exported)

        XCTAssertEqual(preview.issues, [])
        XCTAssertEqual(preview.rows.count, 1)
        XCTAssertEqual(preview.rows[0].draft.name, item.name)
        XCTAssertEqual(preview.rows[0].draft.location, item.location)
        XCTAssertEqual(preview.rows[0].draft.restockTo, 8)
    }

    func testRestockExportOnlyIncludesLowItems() {
        let low = snapshot(name: "Fuse", quantity: 1, threshold: 1)
        let healthy = snapshot(name: "Contactor", quantity: 5, threshold: 1)
        let exported = InventoryCSVCodec.exportRestock([healthy, low])

        XCTAssertTrue(exported.contains("Fuse"))
        XCTAssertFalse(exported.contains("Contactor"))
    }

    private func snapshot(name: String, quantity: Int, threshold: Int) -> InventorySnapshot {
        InventorySnapshot(
            id: UUID(),
            name: name,
            partNumber: "",
            category: .other,
            location: "",
            quantity: quantity,
            restockAt: threshold,
            restockTo: threshold + 3,
            updatedAt: .now,
            lastUsedAt: nil
        )
    }
}
