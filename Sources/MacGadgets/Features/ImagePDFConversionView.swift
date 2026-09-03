import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ImagePDFConversionView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case imagesToPDF
        case pdfToImages

        var id: String { rawValue }
        var titleKey: String {
            switch self {
            case .imagesToPDF: "imagePDF.mode.imagesToPDF"
            case .pdfToImages: "imagePDF.mode.pdfToImages"
            }
        }
    }

    @EnvironmentObject private var localization: LocalizationStore
    @State private var mode: Mode = .imagesToPDF
    @State private var imageFiles: [URL] = []
    @State private var selectedImageFile: URL?
    @State private var pdfFile: URL?
    @State private var renderScale: CGFloat = 2
    @State private var statusMessage = ""
    @State private var hasError = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.pageSpacing) {
            ToolHeader(
                titleKey: "tool.imagePDF.title",
                descriptionKey: "tool.imagePDF.description",
                systemImage: "photo.on.rectangle.angled"
            )

            ToolControlBar {
                Text(localization.text("imagePDF.mode.label"))
                    .font(.callout.weight(.medium))
                Picker(localization.text("imagePDF.mode.label"), selection: $mode) {
                    ForEach(Mode.allCases) { item in
                        Text(localization.text(item.titleKey)).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)
                .labelsHidden()
                .onChange(of: mode) {
                    statusMessage = ""
                }
                Spacer()
                Text(localization.text(
                    mode == .imagesToPDF
                        ? "imagePDF.mode.imagesToPDFHint"
                        : "imagePDF.mode.pdfToImagesHint"
                ))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Group {
                switch mode {
                case .imagesToPDF:
                    imagesToPDFContent
                case .pdfToImages:
                    pdfToImagesContent
                }
            }

            ToolControlBar {
                if mode == .imagesToPDF {
                    Button(localization.text("imagePDF.savePDF"), systemImage: "doc.badge.plus") {
                        saveImagesAsPDF()
                    }
                    .appPrimaryActionStyle()
                    .disabled(imageFiles.isEmpty)
                    .keyboardShortcut("s", modifiers: .command)
                } else {
                    Button(localization.text("imagePDF.export"), systemImage: "photo.stack") {
                        exportPDFPages()
                    }
                    .appPrimaryActionStyle()
                    .disabled(pdfFile == nil)
                    .keyboardShortcut("s", modifiers: .command)
                }

                Spacer()
                StatusMessageView(message: statusMessage, isError: hasError)
            }
        }
        .toolPageStyle()
        .onChange(of: localization.language) { statusMessage = "" }
    }

    private var imagesToPDFContent: some View {
        VStack(spacing: 12) {
            ToolControlBar {
                Button(localization.text("imagePDF.addImages"), systemImage: "plus") { addImages() }
                    .keyboardShortcut("o", modifiers: .command)
                Button(localization.text("common.remove"), systemImage: "minus") { removeSelectedImage() }
                    .disabled(selectedImageFile == nil)
                Button(localization.text("common.clear"), systemImage: "trash") {
                    imageFiles.removeAll()
                    selectedImageFile = nil
                }
                .disabled(imageFiles.isEmpty)
                Spacer()
                Text(localization.text("imagePDF.imageCount", Int64(imageFiles.count)))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                List(selection: $selectedImageFile) {
                    ForEach(Array(imageFiles.enumerated()), id: \.element) { index, url in
                        HStack(spacing: 10) {
                            if let image = NSImage(contentsOf: url) {
                                Image(nsImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 42, height: 36)
                                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(url.lastPathComponent).lineLimit(1)
                                Text(imageDimensions(at: url))
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
                        imageFiles.move(fromOffsets: offsets, toOffset: destination)
                    }
                }
                .workspaceSurface()
                .fileDropTarget(
                    isEmpty: imageFiles.isEmpty,
                    title: localization.text("imagePDF.drop.title"),
                    description: localization.text("imagePDF.drop.description"),
                    systemImage: "photo.badge.plus",
                    onDrop: addDroppedImages
                )

                FileOrderButtons(
                    canMoveUp: selectedImageIndex.map { $0 > 0 } ?? false,
                    canMoveDown: selectedImageIndex.map { $0 < imageFiles.count - 1 } ?? false,
                    moveUp: { moveSelectedImage(by: -1) },
                    moveDown: { moveSelectedImage(by: 1) }
                )
            }
        }
    }

    private var pdfToImagesContent: some View {
        VStack(spacing: 18) {
            HStack(spacing: 14) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 34))
                        .foregroundStyle(AppTheme.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pdfFile?.lastPathComponent ?? localization.text("imagePDF.noPDF"))
                            .font(.headline)
                        if let pdfFile, let count = PDFService.pageCount(at: pdfFile) {
                            Text(localization.text(
                                "imagePDF.pageSummary",
                                Int64(count),
                                Int64(count)
                            ))
                                .foregroundStyle(.secondary)
                        } else {
                            Text(localization.text("imagePDF.selectPDFDescription"))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button(localization.text(
                        pdfFile == nil ? "imagePDF.selectPDF" : "imagePDF.changePDF"
                    )) {
                        selectPDF()
                    }
                    .controlSize(.large)
                    .keyboardShortcut("o", modifiers: .command)
                }
                .padding(16)
                .workspaceSurface()
                .fileDropTarget(
                    isEmpty: false,
                    title: "",
                    description: "",
                    systemImage: "doc.richtext",
                    onDrop: selectDroppedPDF
                )

            ToolControlBar {
                Text(localization.text("imagePDF.quality.label"))
                    .font(.headline)
                Picker(localization.text("imagePDF.quality.label"), selection: $renderScale) {
                    Text(localization.text("imagePDF.quality.standard")).tag(CGFloat(1))
                    Text(localization.text("imagePDF.quality.high")).tag(CGFloat(2))
                    Text(localization.text("imagePDF.quality.ultra")).tag(CGFloat(3))
                }
                .labelsHidden()
                .frame(width: 160)
                Text(localization.text("imagePDF.quality.hint"))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Spacer()
        }
    }

    private var selectedImageIndex: Int? {
        guard let selectedImageFile else { return nil }
        return imageFiles.firstIndex(of: selectedImageFile)
    }

    private func addImages() {
        let urls = FilePanels.openFiles(
            title: localization.text("imagePDF.panel.selectImages"),
            types: [.image],
            allowsMultipleSelection: true
        )
        addDroppedImages(urls)
    }

    private func addDroppedImages(_ urls: [URL]) {
        let images = urls.filter { NSImage(contentsOf: $0) != nil }
        for url in images where !imageFiles.contains(url) { imageFiles.append(url) }
        if selectedImageFile == nil { selectedImageFile = images.first }
        if images.isEmpty && !urls.isEmpty {
            showStatus(localization.text("imagePDF.status.noReadableImages"), isError: true)
        } else {
            statusMessage = ""
        }
    }

    private func removeSelectedImage() {
        guard let index = selectedImageIndex else { return }
        imageFiles.remove(at: index)
        selectedImageFile = imageFiles.indices.contains(index) ? imageFiles[index] : imageFiles.last
    }

    private func moveSelectedImage(by offset: Int) {
        guard let from = selectedImageIndex else { return }
        let to = from + offset
        guard imageFiles.indices.contains(to) else { return }
        imageFiles.swapAt(from, to)
    }

    private func imageDimensions(at url: URL) -> String {
        guard let image = NSImage(contentsOf: url) else {
            return localization.text("common.unreadable")
        }
        let size = ImageStitchService.pixelSize(of: image)
        return "\(Int(size.width)) × \(Int(size.height))"
    }

    private func saveImagesAsPDF() {
        guard let destination = FilePanels.saveFile(
            title: localization.text("imagePDF.panel.savePDF"),
            suggestedName: localization.text("imagePDF.file.defaultPDFName"),
            type: .pdf
        ) else { return }

        do {
            let count = try PDFService.imagesToPDF(imageFiles, to: destination)
            showStatus(localization.text(
                "imagePDF.status.generated",
                Int64(count),
                destination.lastPathComponent
            ))
        } catch {
            showStatus(
                localization.text(
                    "imagePDF.status.generateFailed",
                    localization.errorMessage(for: error)
                ),
                isError: true
            )
        }
    }

    private func selectPDF() {
        let urls = FilePanels.openFiles(
            title: localization.text("imagePDF.panel.selectPDF"),
            types: [.pdf],
            allowsMultipleSelection: false
        )
        selectDroppedPDF(urls)
    }

    private func selectDroppedPDF(_ urls: [URL]) {
        guard let url = urls.first(where: { $0.pathExtension.lowercased() == "pdf" }) else {
            if !urls.isEmpty {
                showStatus(localization.text("imagePDF.status.onlyPDF"), isError: true)
            }
            return
        }
        pdfFile = url
        statusMessage = ""
    }

    private func exportPDFPages() {
        guard let pdfFile,
              let directory = FilePanels.chooseDirectory(
                title: localization.text("imagePDF.panel.outputDirectory")
              ) else { return }

        do {
            let files = try PDFService.pdfToPNGFiles(
                pdfFile,
                outputDirectory: directory,
                scale: renderScale
            )
            showStatus(localization.text(
                "imagePDF.status.exported",
                Int64(files.count),
                directory.lastPathComponent
            ))
            NSWorkspace.shared.activateFileViewerSelecting(files)
        } catch {
            showStatus(
                localization.text(
                    "imagePDF.status.exportFailed",
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
