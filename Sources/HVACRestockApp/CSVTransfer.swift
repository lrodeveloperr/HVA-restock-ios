import Foundation
import CoreTransferable
import UniformTypeIdentifiers

public struct CSVShareFile: Transferable, Sendable {
    public let text: String
    public let filename: String

    public init(text: String, filename: String) {
        self.text = text
        self.filename = filename
    }

    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { file in
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let requestedName = (file.filename as NSString).lastPathComponent
            let safeName = requestedName.isEmpty || requestedName == "." || requestedName == ".."
                ? "HVAC-Export.csv"
                : requestedName
            let url = directory.appendingPathComponent(safeName)
            try Data(file.text.utf8).write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}
