import SwiftUI

struct ClipboardHistoryView: View {
    @EnvironmentObject private var historyStore: ClipboardHistoryStore
    @EnvironmentObject private var localization: LocalizationStore
    @State private var copiedEntryID: UUID?
    @State private var isShowingClearConfirmation = false

    private var groupedEntries: [(date: Date, entries: [ClipboardHistoryEntry])] {
        Dictionary(grouping: historyStore.entries) {
            Calendar.current.startOfDay(for: $0.createdAt)
        }
        .map { (date: $0.key, entries: $0.value) }
        .sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.pageSpacing) {
            ToolHeader(
                titleKey: "tool.clipboard.title",
                descriptionKey: "tool.clipboard.description",
                systemImage: "clipboard"
            )

            ToolControlBar {
                Label(
                    "\(historyStore.entries.count) / \(ClipboardHistoryService.maximumEntryCount)",
                    systemImage: "text.document"
                )
                .font(.callout.monospacedDigit().weight(.medium))

                Spacer()

                StatusMessageView(
                    message: localization.text(historyStore.storageErrorKey),
                    isError: true
                )

                Button(localization.text("clipboard.clearHistory"), systemImage: "trash") {
                    isShowingClearConfirmation = true
                }
                .disabled(historyStore.entries.isEmpty)
            }

            Group {
                if historyStore.entries.isEmpty {
                    ContentUnavailableView(
                        localization.text("clipboard.empty.title"),
                        systemImage: "clipboard",
                        description: Text(localization.text("clipboard.empty.description"))
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(groupedEntries, id: \.date) { group in
                            Section(sectionTitle(for: group.date)) {
                                ForEach(group.entries) { entry in
                                    ClipboardHistoryRow(
                                        entry: entry,
                                        isCopied: copiedEntryID == entry.id,
                                        onCopy: { copy(entry) },
                                        onDelete: { historyStore.delete(entry) }
                                    )
                                }
                            }
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .workspaceSurface()
        }
        .toolPageStyle()
        .confirmationDialog(
            localization.text("clipboard.confirm.title"),
            isPresented: $isShowingClearConfirmation
        ) {
            Button(
                localization.text("clipboard.confirm.action", Int64(historyStore.entries.count)),
                role: .destructive
            ) {
                historyStore.clearHistory()
            }
            Button(localization.text("clipboard.confirm.cancel"), role: .cancel) {}
        } message: {
            Text(localization.text("clipboard.confirm.message"))
        }
        .task(id: copiedEntryID) {
            guard copiedEntryID != nil else { return }
            try? await Task.sleep(for: .seconds(1.2))
            copiedEntryID = nil
        }
    }

    private func copy(_ entry: ClipboardHistoryEntry) {
        historyStore.copyToPasteboard(entry)
        copiedEntryID = historyStore.entries.first?.id
    }

    private func sectionTitle(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return localization.text("clipboard.date.today")
        }
        if Calendar.current.isDateInYesterday(date) {
            return localization.text("clipboard.date.yesterday")
        }
        return date.formatted(
            .dateTime
                .year()
                .month()
                .day()
                .locale(localization.language.locale)
        )
    }
}

private struct ClipboardHistoryRow: View {
    @EnvironmentObject private var localization: LocalizationStore
    let entry: ClipboardHistoryEntry
    let isCopied: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.text)
                    .font(.body)
                    .lineLimit(5)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    Text(entry.createdAt.formatted(
                        .dateTime.hour().minute().locale(localization.language.locale)
                    ))
                    Text(localization.text("clipboard.characters", Int64(entry.text.count)))
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
            }

            HStack(alignment: .center, spacing: 8) {
                Button(action: onCopy) {
                    Label(
                        localization.text(isCopied ? "clipboard.copied" : "clipboard.copy"),
                        systemImage: isCopied ? "checkmark" : "doc.on.doc"
                    )
                    .frame(height: AppTheme.compactControlHitSize)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .controlSize(.large)
                .help(localization.text("clipboard.copy.help"))

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .frame(
                            width: AppTheme.compactControlHitSize,
                            height: AppTheme.compactControlHitSize
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .help(localization.text("clipboard.delete.help"))
                .accessibilityLabel(localization.text("clipboard.delete.accessibility"))
            }
            .frame(height: AppTheme.compactControlHitSize, alignment: .center)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onCopy)
        .help(localization.text("clipboard.doubleClick.help"))
    }
}
