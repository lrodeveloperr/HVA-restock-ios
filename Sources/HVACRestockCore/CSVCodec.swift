import Foundation

public struct CSVImportRow: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let sourceLine: Int
    public var draft: InventoryDraft

    public init(id: UUID = UUID(), sourceLine: Int, draft: InventoryDraft) {
        self.id = id
        self.sourceLine = sourceLine
        self.draft = draft
    }
}

public struct CSVImportIssue: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let sourceLine: Int
    public let message: String

    public init(id: UUID = UUID(), sourceLine: Int, message: String) {
        self.id = id
        self.sourceLine = sourceLine
        self.message = message
    }
}

public struct CSVImportPreview: Equatable, Sendable, Identifiable {
    public let id: UUID
    public var rows: [CSVImportRow]
    public var issues: [CSVImportIssue]

    public init(id: UUID = UUID(), rows: [CSVImportRow], issues: [CSVImportIssue]) {
        self.id = id
        self.rows = rows
        self.issues = issues
    }
}

public enum CSVCodecError: LocalizedError, Equatable, Sendable {
    case emptyFile
    case missingItemColumn
    case unreadableEncoding
    case fileTooLarge
    case malformedCSV

    public var errorDescription: String? {
        switch self {
        case .emptyFile: "The CSV file is empty."
        case .missingItemColumn: "The CSV needs an Item column."
        case .unreadableEncoding: "The CSV must use UTF-8 text."
        case .fileTooLarge: "The CSV is larger than the 5 MB import limit."
        case .malformedCSV: "The CSV contains an unfinished quoted field."
        }
    }
}

public enum InventoryCSVCodec {
    public static let maximumImportBytes = 5 * 1_024 * 1_024
    public static let headers = [
        "Item", "Part number", "Category", "On hand", "Restock level", "Restock to", "Buy", "Location"
    ]

    public static func exportInventory(_ items: [InventorySnapshot]) -> String {
        let lines = items.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }.map { item in
            [
                item.name,
                item.partNumber,
                item.category.label,
                String(item.quantity),
                String(item.restockAt),
                String(item.restockTo),
                String(InventoryRules.suggestedPurchase(onHand: item.quantity, restockTo: item.restockTo)),
                item.location
            ].map(escape).joined(separator: ",")
        }
        return ([headers.map(escape).joined(separator: ",")] + lines).joined(separator: "\r\n") + "\r\n"
    }

    public static func exportRestock(_ items: [InventorySnapshot]) -> String {
        exportInventory(items.filter { InventoryRules.isLowStock(onHand: $0.quantity, restockAt: $0.restockAt) })
    }

    public static func preview(data: Data) throws -> CSVImportPreview {
        guard data.count <= maximumImportBytes else { throw CSVCodecError.fileTooLarge }
        guard let text = String(data: data, encoding: .utf8) else { throw CSVCodecError.unreadableEncoding }
        return try preview(text: text)
    }

    public static func preview(text: String) throws -> CSVImportPreview {
        guard text.utf8.count <= maximumImportBytes else { throw CSVCodecError.fileTooLarge }
        guard hasBalancedQuotes(text) else { throw CSVCodecError.malformedCSV }
        let records = parseRecords(text)
        guard let firstRecord = records.first,
              !firstRecord.columns.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw CSVCodecError.emptyFile
        }

        let normalizedHeaders = firstRecord.columns.map(normalizeHeader)
        guard let itemIndex = normalizedHeaders.firstIndex(where: { ["item", "name"].contains($0) }) else {
            throw CSVCodecError.missingItemColumn
        }

        func index(_ aliases: [String]) -> Int? {
            normalizedHeaders.firstIndex { aliases.contains($0) }
        }

        let partIndex = index(["partnumber", "part", "sku"])
        let categoryIndex = index(["category", "type"])
        let quantityIndex = index(["onhand", "quantity", "qty"])
        let restockAtIndex = index(["restocklevel", "restockat", "minimum", "min"])
        let restockToIndex = index(["restockto", "target", "par"])
        let locationIndex = index(["location", "bin", "shelf"])

        var validRows: [CSVImportRow] = []
        var issues: [CSVImportIssue] = []

        for record in records.dropFirst() {
            let columns = record.columns
            let line = record.sourceLine
            if columns.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { continue }

            func value(_ index: Int?) -> String {
                guard let index, columns.indices.contains(index) else { return "" }
                return columns[index]
            }

            let name = restoreSpreadsheetValue(value(itemIndex))
            let quantity = integer(value(quantityIndex), default: 0)
            let restockAt = integer(value(restockAtIndex), default: 1)
            let defaultRestockTo = restockAt < InventoryRules.maximumQuantity
                ? max(2, restockAt + 1)
                : InventoryRules.maximumQuantity
            let restockTo = integer(value(restockToIndex), default: defaultRestockTo)
            let categoryText = value(categoryIndex).trimmingCharacters(in: .whitespacesAndNewlines)
            let category = InventoryCategory.allCases.first {
                $0.rawValue.caseInsensitiveCompare(categoryText) == .orderedSame ||
                $0.label.caseInsensitiveCompare(categoryText) == .orderedSame
            } ?? .other

            let draft = InventoryDraft(
                name: name,
                partNumber: restoreSpreadsheetValue(value(partIndex)),
                category: category,
                location: restoreSpreadsheetValue(value(locationIndex)),
                quantity: quantity,
                restockAt: restockAt,
                restockTo: restockTo
            )

            do {
                validRows.append(CSVImportRow(sourceLine: line, draft: try InventoryRules.validate(draft)))
            } catch {
                issues.append(CSVImportIssue(sourceLine: line, message: error.localizedDescription))
            }
        }

        return CSVImportPreview(rows: validRows, issues: issues)
    }

    public static func parse(_ input: String) -> [[String]] {
        parseRecords(input).map { $0.columns }
    }

    private static func parseRecords(_ input: String) -> [(columns: [String], sourceLine: Int)] {
        var records: [(columns: [String], sourceLine: Int)] = []
        var row: [String] = []
        var field = ""
        var insideQuotes = false
        let normalizedInput = input
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let characters = Array(normalizedInput)
        var index = 0
        var currentLine = 1
        var rowStartLine = 1

        while index < characters.count {
            let character = characters[index]
            if insideQuotes {
                if character == "\"" {
                    if index + 1 < characters.count, characters[index + 1] == "\"" {
                        field.append("\"")
                        index += 1
                    } else {
                        insideQuotes = false
                    }
                } else {
                    field.append(character)
                    if character == "\n" { currentLine += 1 }
                }
            } else {
                switch character {
                case "\"": insideQuotes = true
                case ",":
                    row.append(field)
                    field = ""
                case "\n":
                    row.append(field.trimmingCharacters(in: CharacterSet(charactersIn: "\r")))
                    records.append((row, rowStartLine))
                    row = []
                    field = ""
                    currentLine += 1
                    rowStartLine = currentLine
                default: field.append(character)
                }
            }
            index += 1
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field.trimmingCharacters(in: CharacterSet(charactersIn: "\r")))
            records.append((row, rowStartLine))
        }
        return records
    }

    private static func integer(_ value: String, default defaultValue: Int) -> Int {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultValue : (Int(trimmed) ?? -1)
    }

    private static func normalizeHeader(_ value: String) -> String {
        value.lowercased().filter(\.isLetter)
    }

    private static func escape(_ value: String) -> String {
        let safe = spreadsheetSafe(value)
        if safe.contains(",") || safe.contains("\"") || safe.contains("\n") || safe.contains("\r") {
            return "\"\(safe.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return safe
    }

    private static func spreadsheetSafe(_ value: String) -> String {
        let candidate = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.first == "'" {
            let literal = String(value.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            if let first = literal.first, ["=", "+", "-", "@"].contains(first) { return "'" + value }
        }
        guard let first = candidate.first, ["=", "+", "-", "@"].contains(first) else { return value }
        return "'" + value
    }

    private static func restoreSpreadsheetValue(_ value: String) -> String {
        guard value.count >= 2, value.first == "'" else { return value }
        let candidate = String(value.dropFirst())
        if candidate.first == "'" {
            let literal = String(candidate.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            if let first = literal.first, ["=", "+", "-", "@"].contains(first) { return candidate }
        }
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first, ["=", "+", "-", "@"].contains(first) else { return value }
        return candidate
    }

    private static func hasBalancedQuotes(_ input: String) -> Bool {
        var insideQuotes = false
        let characters = Array(input)
        var index = 0
        while index < characters.count {
            if characters[index] == "\"" {
                if insideQuotes, index + 1 < characters.count, characters[index + 1] == "\"" {
                    index += 1
                } else {
                    insideQuotes.toggle()
                }
            }
            index += 1
        }
        return !insideQuotes
    }
}
