import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ImageStitchView: View {
    @EnvironmentObject private var localization: LocalizationStore
    @State private var files: [URL] = []
    @State private var selectedFile: URL?
    @State private var direction: ImageStitchDirection = .vertical
    @State private var previewImage: NSImage?
    @State private var sourcePreview: SourceImagePreview?
    @State private var statusMessage = ""
    @State private var hasError = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.pageSpacing) {
            ToolHeader(
                titleKey: "tool.imageStitch.title",
                descriptionKey: "tool.imageStitch.description",
                systemImage: "rectangle.3.group"
            )

            ToolControlBar {
                Text(localization.text("imageStitch.direction.label"))
                    .font(.callout.weight(.medium))
                Picker(localization.text("imageStitch.direction.label"), selection: $direction) {
                    ForEach(ImageStitchDirection.allCases) { item in
                        Label(localization.text(item.titleKey), systemImage: item.systemImage).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 340)
                .labelsHidden()
                .onChange(of: direction) { previewImage = nil }

                Spacer()
                Button(localization.text("imageStitch.addImages"), systemImage: "plus") { addImages() }
                    .keyboardShortcut("o", modifiers: .command)
                Button(localization.text("common.remove"), systemImage: "minus") { removeSelected() }
                    .disabled(selectedFile == nil)
                Button(localization.text("common.clear"), systemImage: "trash") {
                    files.removeAll()
                    selectedFile = nil
                    previewImage = nil
                }
                .disabled(files.isEmpty)
            }

            GeometryReader { geometry in
                let widths = ImageStitchPaneWidths(
                    availableWidth: geometry.size.width,
                    spacing: AppTheme.splitPaneSpacing
                )
                HStack(spacing: AppTheme.splitPaneSpacing) {
                    imageList
                        .frame(width: widths.list, height: geometry.size.height)
                    previewPane
                        .frame(width: widths.preview, height: geometry.size.height)
                }
            }

            ToolControlBar {
                Button(localization.text("imageStitch.preview.generate"), systemImage: "eye") {
                    generatePreview()
                }
                    .disabled(files.isEmpty)
                Button(localization.text("imageStitch.save"), systemImage: "square.and.arrow.down") {
                    saveStitchedImage()
                }
                    .appPrimaryActionStyle()
                    .disabled(files.isEmpty)
                    .keyboardShortcut("s", modifiers: .command)
                Spacer()
                StatusMessageView(message: statusMessage, isError: hasError)
            }
        }
        .toolPageStyle()
        .onChange(of: localization.language) { statusMessage = "" }
        .sheet(item: $sourcePreview) { source in
            SourceImagePreviewSheet(source: source)
                .environmentObject(localization)
        }
    }

    private var imageList: some View {
        VStack(spacing: 0) {
            List(selection: $selectedFile) {
                ForEach(Array(files.enumerated()), id: \.element) { index, url in
                    HStack(spacing: 8) {
                        Button {
                            showSourcePreview(at: url)
                        } label: {
                            Group {
                                if let image = NSImage(contentsOf: url) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .scaledToFit()
                                } else {
                                    Image(systemName: "photo")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .help(localization.text("imageStitch.source.preview", url.lastPathComponent))
                        .accessibilityLabel(localization.text("imageStitch.source.preview", url.lastPathComponent))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(url.lastPathComponent)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .help(url.lastPathComponent)
                            Text(dimensions(at: url))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(index + 1)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .tag(url)
                    .padding(.vertical, 3)
                    .accessibilityElement(children: .contain)
                    .accessibilityAction(named: Text(localization.text("imageStitch.source.preview", url.lastPathComponent))) {
                        showSourcePreview(at: url)
                    }
                }
                .onMove { offsets, destination in
                    files.move(fromOffsets: offsets, toOffset: destination)
                    previewImage = nil
                }
            }
            .fileDropTarget(
                isEmpty: files.isEmpty,
                title: localization.text("imageStitch.drop.title"),
                description: localization.text("imageStitch.drop.description"),
                systemImage: "photo.stack",
                onDrop: addDroppedImages
            )

            Divider()
            HStack(spacing: 8) {
                Text(localization.text("imageStitch.source.hint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                FileOrderButtons(
                    canMoveUp: selectedIndex.map { $0 > 0 } ?? false,
                    canMoveDown: selectedIndex.map { $0 < files.count - 1 } ?? false,
                    moveUp: { moveSelected(by: -1) },
                    moveDown: { moveSelected(by: 1) },
                    axis: .horizontal
                )
            }
            .padding(10)
        }
        .workspaceSurface()
    }

    private var previewPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(localization.text("imageStitch.preview.title"))
                    .font(.headline)
                Spacer()
                if let previewImage {
                    let size = ImageStitchService.pixelSize(of: previewImage)
                    Text("\(Int(size.width)) × \(Int(size.height))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            if let previewImage {
                ZoomableImagePreview(
                    image: previewImage,
                    accessibilityLabel: localization.text("imageStitch.preview.title")
                )
                // Every newly generated result starts at fit-to-window, even
                // when it has the same dimensions as the previous image.
                .id(ObjectIdentifier(previewImage))
            } else {
                ContentUnavailableView(
                    localization.text("imageStitch.preview.empty"),
                    systemImage: direction.systemImage,
                    description: Text(localization.text("imageStitch.preview.description"))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.canvas)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
        }
        .padding(12)
        .workspaceSurface()
    }

    private func showSourcePreview(at url: URL) {
        selectedFile = url
        guard let source = SourceImagePreview(url: url) else {
            showStatus(localization.text("imageStitch.status.sourcePreviewFailed"), isError: true)
            return
        }
        sourcePreview = source
    }

    private var selectedIndex: Int? {
        guard let selectedFile else { return nil }
        return files.firstIndex(of: selectedFile)
    }

    private func addImages() {
        let urls = FilePanels.openFiles(
            title: localization.text("imageStitch.panel.selectImages"),
            types: [.image],
            allowsMultipleSelection: true
        )
        addDroppedImages(urls)
    }

    private func addDroppedImages(_ urls: [URL]) {
        let images = urls.filter { NSImage(contentsOf: $0) != nil }
        for url in images where !files.contains(url) { files.append(url) }
        if selectedFile == nil { selectedFile = images.first }
        previewImage = nil
        if images.isEmpty && !urls.isEmpty {
            showStatus(localization.text("imageStitch.status.noReadableImages"), isError: true)
        } else {
            statusMessage = ""
        }
    }

    private func removeSelected() {
        guard let index = selectedIndex else { return }
        files.remove(at: index)
        selectedFile = files.indices.contains(index) ? files[index] : files.last
        previewImage = nil
    }

    private func moveSelected(by offset: Int) {
        guard let from = selectedIndex else { return }
        let to = from + offset
        guard files.indices.contains(to) else { return }
        files.swapAt(from, to)
        previewImage = nil
    }

    private func dimensions(at url: URL) -> String {
        guard let image = NSImage(contentsOf: url) else {
            return localization.text("common.unreadable")
        }
        let size = ImageStitchService.pixelSize(of: image)
        return "\(Int(size.width)) × \(Int(size.height))"
    }

    private func generatePreview() {
        do {
            let result = try ImageStitchService.stitch(files, direction: direction)
            previewImage = NSImage(data: result.data)
            showStatus(localization.text(
                "imageStitch.status.previewSize",
                Int64(result.pixelSize.width),
                Int64(result.pixelSize.height)
            ))
        } catch {
            showStatus(
                localization.text(
                    "imageStitch.status.previewFailed",
                    localization.errorMessage(for: error)
                ),
                isError: true
            )
        }
    }

    private func saveStitchedImage() {
        guard let destination = FilePanels.saveFile(
            title: localization.text("imageStitch.panel.save"),
            suggestedName: localization.text("imageStitch.file.defaultName"),
            type: .png
        ) else { return }

        do {
            let result = try ImageStitchService.stitch(files, direction: direction)
            try result.data.write(to: destination, options: .atomic)
            previewImage = NSImage(data: result.data)
            showStatus(localization.text(
                "imageStitch.status.saved",
                Int64(result.pixelSize.width),
                Int64(result.pixelSize.height)
            ))
        } catch {
            showStatus(
                localization.text(
                    "common.status.saveFailed",
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
