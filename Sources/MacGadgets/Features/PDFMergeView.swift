import SwiftUI
import UniformTypeIdentifiers

struct PDFMergeView: View {
    @State private var files: [URL] = []
    @State private var selectedFile: URL?
    @State private var statusMessage = ""
    @State private var hasError = false

    private var totalPages: Int {
        files.compactMap(PDFService.pageCount).reduce(0, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.pageSpacing) {
            ToolHeader(
                title: "多 PDF 文件合并",
                description: "添加多个 PDF，调整顺序后合并为一个新文件。",
                systemImage: "doc.on.doc"
            )

            ToolControlBar {
                Button("添加 PDF…", systemImage: "plus") { addFiles() }
                    .keyboardShortcut("o", modifiers: .command)
                Button("移除", systemImage: "minus") { removeSelected() }
                    .disabled(selectedFile == nil)
                Button("清空", systemImage: "trash") {
                    files.removeAll()
                    selectedFile = nil
                    statusMessage = ""
                }
                .disabled(files.isEmpty)

                Spacer()
                Text("\(files.count) 个文件 · 共 \(totalPages) 页")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                List(selection: $selectedFile) {
                    ForEach(Array(files.enumerated()), id: \.element) { index, url in
                        HStack(spacing: 10) {
                            Image(systemName: "doc.richtext")
                                .foregroundStyle(AppTheme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(url.lastPathComponent)
                                    .lineLimit(1)
                                Text(PDFService.pageCount(at: url).map { "\($0) 页" } ?? "无法读取")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(index + 1)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                        .tag(url)
                        .padding(.vertical, 3)
                    }
                    .onMove { offsets, destination in
                        files.move(fromOffsets: offsets, toOffset: destination)
                    }
                }
                .workspaceSurface()
                .fileDropTarget(
                    isEmpty: files.isEmpty,
                    title: "拖入 PDF 开始",
                    description: "也可以点击“添加 PDF”，支持拖动行或使用右侧按钮排序。",
                    systemImage: "doc.badge.plus",
                    onDrop: addDroppedPDFs
                )

                FileOrderButtons(
                    canMoveUp: selectedIndex.map { $0 > 0 } ?? false,
                    canMoveDown: selectedIndex.map { $0 < files.count - 1 } ?? false,
                    moveUp: { moveSelected(by: -1) },
                    moveDown: { moveSelected(by: 1) }
                )
            }

            ToolControlBar {
                Button("合并并保存…", systemImage: "square.and.arrow.down") { mergeFiles() }
                    .appPrimaryActionStyle()
                    .disabled(files.count < 2)
                    .keyboardShortcut("s", modifiers: .command)
                Spacer()
                StatusMessageView(message: statusMessage, isError: hasError)
            }
        }
        .toolPageStyle()
    }

    private var selectedIndex: Int? {
        guard let selectedFile else { return nil }
        return files.firstIndex(of: selectedFile)
    }

    private func addFiles() {
        let urls = FilePanels.openFiles(
            title: "选择要合并的 PDF",
            types: [.pdf],
            allowsMultipleSelection: true
        )
        addDroppedPDFs(urls)
    }

    private func addDroppedPDFs(_ urls: [URL]) {
        let pdfs = urls.filter { $0.pathExtension.lowercased() == "pdf" }
        for url in pdfs where !files.contains(url) { files.append(url) }
        if selectedFile == nil { selectedFile = pdfs.first }
        if pdfs.isEmpty && !urls.isEmpty {
            showStatus("仅支持 PDF 文件", isError: true)
        } else {
            statusMessage = ""
        }
    }

    private func removeSelected() {
        guard let selectedIndex else { return }
        files.remove(at: selectedIndex)
        selectedFile = files.indices.contains(selectedIndex)
            ? files[selectedIndex]
            : files.last
        statusMessage = ""
    }

    private func moveSelected(by offset: Int) {
        guard let from = selectedIndex else { return }
        let to = from + offset
        guard files.indices.contains(to) else { return }
        files.swapAt(from, to)
    }

    private func mergeFiles() {
        guard let destination = FilePanels.saveFile(
            title: "保存合并后的 PDF",
            suggestedName: "合并结果.pdf",
            type: .pdf
        ) else { return }

        do {
            let pageCount = try PDFService.merge(files, to: destination)
            showStatus("合并完成：\(pageCount) 页，已保存为 \(destination.lastPathComponent)")
        } catch {
            showStatus("合并失败：\(error.localizedDescription)", isError: true)
        }
    }

    private func showStatus(_ message: String, isError: Bool = false) {
        statusMessage = message
        hasError = isError
    }
}
