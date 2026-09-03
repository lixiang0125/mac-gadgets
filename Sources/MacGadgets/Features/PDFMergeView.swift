import SwiftUI
import UniformTypeIdentifiers

struct PDFMergeView: View {
    @EnvironmentObject private var localization: LocalizationStore
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
                titleKey: "tool.pdfMerge.title",
                descriptionKey: "tool.pdfMerge.description",
                systemImage: "doc.on.doc"
            )

            ToolControlBar {
                Button(localization.text("pdfMerge.add"), systemImage: "plus") { addFiles() }
                    .keyboardShortcut("o", modifiers: .command)
                Button(localization.text("common.remove"), systemImage: "minus") { removeSelected() }
                    .disabled(selectedFile == nil)
                Button(localization.text("common.clear"), systemImage: "trash") {
                    files.removeAll()
                    selectedFile = nil
                    statusMessage = ""
                }
                .disabled(files.isEmpty)

                Spacer()
                Text(localization.text(
                    "pdfMerge.summary",
                    Int64(files.count),
                    Int64(totalPages)
                ))
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
                                Text(PDFService.pageCount(at: url).map {
                                    localization.text("pdfMerge.pages", Int64($0))
                                } ?? localization.text("common.unreadable"))
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
                    title: localization.text("pdfMerge.drop.title"),
                    description: localization.text("pdfMerge.drop.description"),
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
                Button(localization.text("pdfMerge.merge"), systemImage: "square.and.arrow.down") {
                    mergeFiles()
                }
                    .appPrimaryActionStyle()
                    .disabled(files.count < 2)
                    .keyboardShortcut("s", modifiers: .command)
                Spacer()
                StatusMessageView(message: statusMessage, isError: hasError)
            }
        }
        .toolPageStyle()
        .onChange(of: localization.language) { statusMessage = "" }
    }

    private var selectedIndex: Int? {
        guard let selectedFile else { return nil }
        return files.firstIndex(of: selectedFile)
    }

    private func addFiles() {
        let urls = FilePanels.openFiles(
            title: localization.text("pdfMerge.panel.select"),
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
            showStatus(localization.text("pdfMerge.status.onlyPDF"), isError: true)
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
            title: localization.text("pdfMerge.panel.save"),
            suggestedName: localization.text("pdfMerge.file.defaultName"),
            type: .pdf
        ) else { return }

        do {
            let pageCount = try PDFService.merge(files, to: destination)
            showStatus(localization.text(
                "pdfMerge.status.completed",
                Int64(pageCount),
                destination.lastPathComponent
            ))
        } catch {
            showStatus(
                localization.text(
                    "pdfMerge.status.failed",
                    localization.errorMessage(for: error)
                ),
                isError: true
            )
        }
    }

    private func showStatus(_ message: String, isError: Bool = false) {
        statusMessage = message
        hasError = isError
    }
}
