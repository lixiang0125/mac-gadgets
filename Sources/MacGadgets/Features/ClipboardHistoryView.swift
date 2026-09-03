import SwiftUI

struct ClipboardHistoryView: View {
    @EnvironmentObject private var historyStore: ClipboardHistoryStore
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
                title: "剪贴板历史",
                description: "自动保存应用运行期间复制或剪切的最近 100 条文本，仅存储在本机。",
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
                    message: historyStore.storageErrorMessage,
                    isError: true
                )

                Button("清空历史", systemImage: "trash") {
                    isShowingClearConfirmation = true
                }
                .disabled(historyStore.entries.isEmpty)
            }

            Group {
                if historyStore.entries.isEmpty {
                    ContentUnavailableView(
                        "暂无剪贴板记录",
                        systemImage: "clipboard",
                        description: Text("复制或剪切文本后，记录会自动出现在这里。")
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
            "清空所有剪贴板记录？",
            isPresented: $isShowingClearConfirmation
        ) {
            Button("清空 \(historyStore.entries.count) 条记录", role: .destructive) {
                historyStore.clearHistory()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作不会清空系统当前剪贴板，但无法恢复历史记录。")
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
            return "今天"
        }
        if Calendar.current.isDateInYesterday(date) {
            return "昨天"
        }
        return date.formatted(
            .dateTime
                .year()
                .month()
                .day()
                .locale(Locale(identifier: "zh_CN"))
        )
    }
}

private struct ClipboardHistoryRow: View {
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
                    Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                    Text("\(entry.text.count) 字符")
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
            }

            HStack(alignment: .center, spacing: 8) {
                Button(action: onCopy) {
                    Label(
                        isCopied ? "已复制" : "复制",
                        systemImage: isCopied ? "checkmark" : "doc.on.doc"
                    )
                    .frame(height: AppTheme.compactControlHitSize)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .controlSize(.large)
                .help("复制这条文本")

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .frame(
                            width: AppTheme.compactControlHitSize,
                            height: AppTheme.compactControlHitSize
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .help("删除这条记录")
                .accessibilityLabel("删除记录")
            }
            .frame(height: AppTheme.compactControlHitSize, alignment: .center)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onCopy)
        .help("双击复制这条文本")
    }
}
