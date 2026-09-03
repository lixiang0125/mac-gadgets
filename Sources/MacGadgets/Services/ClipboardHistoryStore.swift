import AppKit
import Combine
import Foundation

@MainActor
final class ClipboardHistoryStore: ObservableObject {
    @Published private(set) var entries: [ClipboardHistoryEntry] = []
    @Published private(set) var storageErrorKey = ""

    private let storageURL: URL
    private let pasteboard: NSPasteboard
    private var lastPasteboardChangeCount: Int
    private var monitoringTimer: AnyCancellable?

    init(
        storageURL: URL = ClipboardHistoryPersistence.defaultStorageURL(),
        pasteboard: NSPasteboard = .general,
        startsMonitoring: Bool = true
    ) {
        self.storageURL = storageURL
        self.pasteboard = pasteboard
        lastPasteboardChangeCount = pasteboard.changeCount
        loadHistory()
        if startsMonitoring {
            startMonitoring()
        }
    }

    func capturePasteboardChange() {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastPasteboardChangeCount else { return }
        lastPasteboardChangeCount = changeCount

        guard let text = pasteboard.string(forType: .string) else { return }
        entries = ClipboardHistoryService.adding(text, to: entries)
        saveHistory()
    }

    func copyToPasteboard(_ entry: ClipboardHistoryEntry) {
        pasteboard.clearContents()
        pasteboard.setString(entry.text, forType: .string)
        capturePasteboardChange()
    }

    func delete(_ entry: ClipboardHistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        saveHistory()
    }

    func clearHistory() {
        entries.removeAll()
        saveHistory()
    }

    private func startMonitoring() {
        guard monitoringTimer == nil else { return }

        monitoringTimer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.capturePasteboardChange()
            }
    }

    private func loadHistory() {
        do {
            entries = ClipboardHistoryService.normalized(
                try ClipboardHistoryPersistence.load(from: storageURL)
            )
        } catch {
            storageErrorKey = "clipboard.error.load"
        }
    }

    private func saveHistory() {
        do {
            try ClipboardHistoryPersistence.save(entries, to: storageURL)
            storageErrorKey = ""
        } catch {
            storageErrorKey = "clipboard.error.save"
        }
    }
}
