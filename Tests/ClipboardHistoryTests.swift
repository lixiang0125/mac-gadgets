import AppKit
import XCTest
@testable import MacGadgets

final class ClipboardHistoryTests: TemporaryDirectoryTestCase {
    func testAddingKeepsNewestUniqueEntriesAndDropsOldestBeyondLimit() throws {
        var entries: [ClipboardHistoryEntry] = []
        let startDate = Date(timeIntervalSince1970: 1_700_000_000)

        for index in 0...100 {
            entries = ClipboardHistoryService.adding(
                "记录 \(index)",
                at: startDate.addingTimeInterval(TimeInterval(index)),
                to: entries
            )
        }

        XCTAssertEqual(entries.count, 100)
        XCTAssertEqual(entries.first?.text, "记录 100")
        XCTAssertEqual(entries.last?.text, "记录 1")

        let existingID = try XCTUnwrap(entries.first { $0.text == "记录 50" }?.id)
        let newestDate = startDate.addingTimeInterval(200)
        entries = ClipboardHistoryService.adding("记录 50", at: newestDate, to: entries)

        XCTAssertEqual(entries.count, 100)
        XCTAssertEqual(entries.first?.id, existingID)
        XCTAssertEqual(entries.first?.createdAt, newestDate)
        XCTAssertEqual(entries.filter { $0.text == "记录 50" }.count, 1)
    }

    func testAddingIgnoresEmptyAndWhitespaceOnlyText() {
        let original = [ClipboardHistoryEntry(text: "保留")]

        XCTAssertEqual(ClipboardHistoryService.adding("", to: original), original)
        XCTAssertEqual(ClipboardHistoryService.adding(" \n\t", to: original), original)
    }

    func testNormalizedHistoryPreservesNewestOrderRemovesDuplicatesAndAppliesLimit() {
        let entries = [
            ClipboardHistoryEntry(text: "最新", createdAt: Date(timeIntervalSince1970: 3)),
            ClipboardHistoryEntry(text: "重复", createdAt: Date(timeIntervalSince1970: 2)),
            ClipboardHistoryEntry(text: "重复", createdAt: Date(timeIntervalSince1970: 1)),
            ClipboardHistoryEntry(text: "最早", createdAt: Date(timeIntervalSince1970: 0))
        ]

        let normalized = ClipboardHistoryService.normalized(entries, maximumEntryCount: 2)

        XCTAssertEqual(normalized.map(\.text), ["最新", "重复"])
    }

    func testPersistenceRoundTripUsesOnlyInjectedTemporaryFile() throws {
        let storageURL = temporaryDirectory.appendingPathComponent("ClipboardHistory.json")
        let entries = [
            ClipboardHistoryEntry(
                text: "第二条",
                createdAt: Date(timeIntervalSince1970: 1_700_000_002)
            ),
            ClipboardHistoryEntry(
                text: "第一条",
                createdAt: Date(timeIntervalSince1970: 1_700_000_001)
            )
        ]

        try ClipboardHistoryPersistence.save(entries, to: storageURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: storageURL.path))
        XCTAssertEqual(try ClipboardHistoryPersistence.load(from: storageURL), entries)
        XCTAssertTrue(storageURL.path.hasPrefix(temporaryDirectory.path))
    }

    func testLoadingMissingHistoryReturnsEmptyWithoutCreatingAFile() throws {
        let storageURL = temporaryDirectory.appendingPathComponent("missing.json")

        XCTAssertEqual(try ClipboardHistoryPersistence.load(from: storageURL), [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: storageURL.path))
    }

    func testDefaultStorageURLLivesInUserApplicationSupport() {
        let url = ClipboardHistoryPersistence.defaultStorageURL()

        XCTAssertEqual(url.lastPathComponent, "ClipboardHistory.json")
        XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, "Mac Gadgets")
        XCTAssertTrue(url.path.contains("Application Support"))
    }

    @MainActor
    func testStoreCapturesCopiesDeduplicatesPersistsDeletesAndClearsInIsolation() throws {
        let storageURL = temporaryDirectory.appendingPathComponent("isolated-history.json")
        let pasteboard = NSPasteboard(
            name: NSPasteboard.Name("MacGadgetsTests.\(UUID().uuidString)")
        )
        pasteboard.clearContents()
        defer { pasteboard.releaseGlobally() }

        let store = ClipboardHistoryStore(
            storageURL: storageURL,
            pasteboard: pasteboard,
            startsMonitoring: false
        )

        pasteboard.clearContents()
        pasteboard.setString("第一条", forType: .string)
        store.capturePasteboardChange()
        pasteboard.clearContents()
        pasteboard.setString("第二条", forType: .string)
        store.capturePasteboardChange()

        XCTAssertEqual(store.entries.map(\.text), ["第二条", "第一条"])
        XCTAssertEqual(
            try ClipboardHistoryPersistence.load(from: storageURL).map(\.text),
            ["第二条", "第一条"]
        )

        let firstEntry = try XCTUnwrap(store.entries.last)
        store.copyToPasteboard(firstEntry)
        XCTAssertEqual(pasteboard.string(forType: .string), "第一条")
        XCTAssertEqual(store.entries.map(\.text), ["第一条", "第二条"])
        XCTAssertEqual(store.entries.count, 2)

        store.delete(try XCTUnwrap(store.entries.last))
        XCTAssertEqual(store.entries.map(\.text), ["第一条"])

        store.clearHistory()
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertEqual(try ClipboardHistoryPersistence.load(from: storageURL), [])
        XCTAssertTrue(store.storageErrorKey.isEmpty)
    }

    @MainActor
    func testStoreReportsCorruptLocalHistoryWithoutTouchingGeneralPasteboard() throws {
        let storageURL = temporaryDirectory.appendingPathComponent("corrupt-history.json")
        try Data("not json".utf8).write(to: storageURL, options: .atomic)
        let pasteboard = NSPasteboard(
            name: NSPasteboard.Name("MacGadgetsTests.\(UUID().uuidString)")
        )
        defer { pasteboard.releaseGlobally() }

        let store = ClipboardHistoryStore(
            storageURL: storageURL,
            pasteboard: pasteboard,
            startsMonitoring: false
        )

        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertEqual(store.storageErrorKey, "clipboard.error.load")
    }
}
