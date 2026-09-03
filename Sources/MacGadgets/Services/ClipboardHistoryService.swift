import Foundation

struct ClipboardHistoryEntry: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let text: String
    let createdAt: Date

    init(id: UUID = UUID(), text: String, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
    }
}

enum ClipboardHistoryService {
    static let maximumEntryCount = 100

    static func adding(
        _ text: String,
        at date: Date = Date(),
        to entries: [ClipboardHistoryEntry],
        maximumEntryCount: Int = maximumEntryCount
    ) -> [ClipboardHistoryEntry] {
        guard maximumEntryCount > 0,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return entries
        }

        let existingID = entries.first { $0.text == text }?.id ?? UUID()
        let entry = ClipboardHistoryEntry(id: existingID, text: text, createdAt: date)
        let entriesWithoutDuplicate = entries.filter { $0.text != text }
        return Array(([entry] + entriesWithoutDuplicate).prefix(maximumEntryCount))
    }

    static func normalized(
        _ entries: [ClipboardHistoryEntry],
        maximumEntryCount: Int = maximumEntryCount
    ) -> [ClipboardHistoryEntry] {
        guard maximumEntryCount > 0 else { return [] }

        var seenTexts: Set<String> = []
        let uniqueEntries = entries.filter { seenTexts.insert($0.text).inserted }
        return Array(uniqueEntries.prefix(maximumEntryCount))
    }
}

enum ClipboardHistoryPersistence {
    static func defaultStorageURL(fileManager: FileManager = .default) -> URL {
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)

        return applicationSupport
            .appendingPathComponent("Mac Gadgets", isDirectory: true)
            .appendingPathComponent("ClipboardHistory.json")
    }

    static func load(from url: URL) throws -> [ClipboardHistoryEntry] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([ClipboardHistoryEntry].self, from: Data(contentsOf: url))
    }

    static func save(_ entries: [ClipboardHistoryEntry], to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(entries).write(to: url, options: .atomic)
    }
}
