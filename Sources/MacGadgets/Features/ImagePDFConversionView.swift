import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ImagePDFConversionView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case imagesToPDF
        case pdfToImages

        var id: String { rawValue }
        var title: String {
            switch self {
            case .imagesToPDF: "图片转 PDF"
            case .pdfToImages: "PDF 转图片"
            }
        }
    }

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
                title: "多图片与 PDF 互转",
                description: "将多张图片按顺序生成 PDF，或把 PDF 的每一页导出为 PNG。",
                systemImage: "photo.on.rectangle.angled"
            )

            ToolControlBar {
                Text("转换模式")
                    .font(.callout.weight(.medium))
                Picker("转换模式", selection: $mode) {
                    ForEach(Mode.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)
                .labelsHidden()
                .onChange(of: mode) {
                    statusMessage = ""
                }
                Spacer()
                Text(mode == .imagesToPDF ? "每张图片生成一页" : "每页导出一张 PNG")
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
                    Button("生成并保存 PDF…", systemImage: "doc.badge.plus") {
                        saveImagesAsPDF()
                    }
                    .appPrimaryActionStyle()
                    .disabled(imageFiles.isEmpty)
                    .keyboardShortcut("s", modifiers: .command)
                } else {
                    Button("选择目录并导出…", systemImage: "photo.stack") {
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
    }

    private var imagesToPDFContent: some View {
        VStack(spacing: 12) {
            ToolControlBar {
                Button("添加图片…", systemImage: "plus") { addImages() }
                    .keyboardShortcut("o", modifiers: .command)
                Button("移除", systemImage: "minus") { removeSelectedImage() }
                    .disabled(selectedImageFile == nil)
                Button("清空", systemImage: "trash") {
                    imageFiles.removeAll()
                    selectedImageFile = nil
                }
                .disabled(imageFiles.isEmpty)
                Spacer()
                Text("\(imageFiles.count) 张图片")
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
                    title: "拖入图片开始",
                    description: "支持 macOS 可读取的图片格式，可拖动行调整 PDF 页序。",
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
                        Text(pdfFile?.lastPathComponent ?? "尚未选择 PDF")
                            .font(.headline)
                        if let pdfFile, let count = PDFService.pageCount(at: pdfFile) {
                            Text("共 \(count) 页，将导出 \(count) 张 PNG 图片")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("选择一个 PDF 文件，每一页会生成一张图片。")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button(pdfFile == nil ? "选择 PDF…" : "更换 PDF…") {
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
                Text("导出清晰度")
                    .font(.headline)
                Picker("导出清晰度", selection: $renderScale) {
                    Text("标准 1×").tag(CGFloat(1))
                    Text("高清 2×").tag(CGFloat(2))
                    Text("超清 3×").tag(CGFloat(3))
                }
                .labelsHidden()
                .frame(width: 160)
                Text("更高倍数会生成更大的图片文件。")
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
            title: "选择图片",
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
            showStatus("未找到可读取的图片", isError: true)
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
        guard let image = NSImage(contentsOf: url) else { return "无法读取" }
        let size = ImageStitchService.pixelSize(of: image)
        return "\(Int(size.width)) × \(Int(size.height))"
    }

    private func saveImagesAsPDF() {
        guard let destination = FilePanels.saveFile(
            title: "保存 PDF",
            suggestedName: "图片合集.pdf",
            type: .pdf
        ) else { return }

        do {
            let count = try PDFService.imagesToPDF(imageFiles, to: destination)
            showStatus("已生成 \(count) 页 PDF：\(destination.lastPathComponent)")
        } catch {
            showStatus("生成失败：\(error.localizedDescription)", isError: true)
        }
    }

    private func selectPDF() {
        let urls = FilePanels.openFiles(
            title: "选择 PDF",
            types: [.pdf],
            allowsMultipleSelection: false
        )
        selectDroppedPDF(urls)
    }

    private func selectDroppedPDF(_ urls: [URL]) {
        guard let url = urls.first(where: { $0.pathExtension.lowercased() == "pdf" }) else {
            if !urls.isEmpty { showStatus("仅支持 PDF 文件", isError: true) }
            return
        }
        pdfFile = url
        statusMessage = ""
    }

    private func exportPDFPages() {
        guard let pdfFile,
              let directory = FilePanels.chooseDirectory(title: "选择图片输出目录") else { return }

        do {
            let files = try PDFService.pdfToPNGFiles(
                pdfFile,
                outputDirectory: directory,
                scale: renderScale
            )
            showStatus("已导出 \(files.count) 张图片到 \(directory.lastPathComponent)")
            NSWorkspace.shared.activateFileViewerSelecting(files)
        } catch {
            showStatus("导出失败：\(error.localizedDescription)", isError: true)
        }
    }

    private func showStatus(_ message: String, isError: Bool = false) {
        statusMessage = message
        hasError = isError
    }
}
