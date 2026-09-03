import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ImageStitchView: View {
    @State private var files: [URL] = []
    @State private var selectedFile: URL?
    @State private var direction: ImageStitchDirection = .vertical
    @State private var previewImage: NSImage?
    @State private var statusMessage = ""
    @State private var hasError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ToolHeader(
                title: "多图片拼成长图",
                description: "按列表顺序横向或竖向拼接；较短边会居中对齐，透明区域会被保留。",
                systemImage: "rectangle.3.group"
            )

            HStack {
                Picker("拼接方向", selection: $direction) {
                    ForEach(ImageStitchDirection.allCases) { item in
                        Label(item.title, systemImage: item.systemImage).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 340)
                .onChange(of: direction) { previewImage = nil }

                Spacer()
                Button("添加图片…", systemImage: "plus") { addImages() }
                Button("移除", systemImage: "minus") { removeSelected() }
                    .disabled(selectedFile == nil)
                Button("清空", systemImage: "trash") {
                    files.removeAll()
                    selectedFile = nil
                    previewImage = nil
                }
                .disabled(files.isEmpty)
            }

            HSplitView {
                HStack(spacing: 10) {
                    List(selection: $selectedFile) {
                        ForEach(Array(files.enumerated()), id: \.element) { index, url in
                            HStack(spacing: 10) {
                                if let image = NSImage(contentsOf: url) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 44, height: 38)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(url.lastPathComponent).lineLimit(1)
                                    Text(dimensions(at: url))
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
                    }
                    .overlay {
                        if files.isEmpty {
                            ContentUnavailableView("尚未添加图片", systemImage: "photo.stack")
                        }
                    }

                    FileOrderButtons(
                        canMoveUp: selectedIndex.map { $0 > 0 } ?? false,
                        canMoveDown: selectedIndex.map { $0 < files.count - 1 } ?? false,
                        moveUp: { moveSelected(by: -1) },
                        moveDown: { moveSelected(by: 1) }
                    )
                }
                .frame(minWidth: 330)

                GroupBox("预览") {
                    ZStack {
                        Color(nsColor: .windowBackgroundColor)
                        if let previewImage {
                            ScrollView([.horizontal, .vertical]) {
                                Image(nsImage: previewImage)
                                    .resizable()
                                    .scaledToFit()
                                    .padding()
                            }
                        } else {
                            ContentUnavailableView(
                                "暂无预览",
                                systemImage: direction.systemImage,
                                description: Text("添加图片后点击“生成预览”。")
                            )
                        }
                    }
                }
                .frame(minWidth: 330)
            }

            HStack {
                Button("生成预览", systemImage: "eye") { generatePreview() }
                    .disabled(files.isEmpty)
                Button("保存长图…", systemImage: "square.and.arrow.down") { saveStitchedImage() }
                    .buttonStyle(.borderedProminent)
                    .disabled(files.isEmpty)
                Spacer()
                StatusMessageView(message: statusMessage, isError: hasError)
            }
        }
        .padding(24)
    }

    private var selectedIndex: Int? {
        guard let selectedFile else { return nil }
        return files.firstIndex(of: selectedFile)
    }

    private func addImages() {
        let urls = FilePanels.openFiles(
            title: "选择要拼接的图片",
            types: [.image],
            allowsMultipleSelection: true
        )
        for url in urls where !files.contains(url) { files.append(url) }
        if selectedFile == nil { selectedFile = urls.first }
        previewImage = nil
        statusMessage = ""
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
        guard let image = NSImage(contentsOf: url) else { return "无法读取" }
        let size = ImageStitchService.pixelSize(of: image)
        return "\(Int(size.width)) × \(Int(size.height))"
    }

    private func generatePreview() {
        do {
            let result = try ImageStitchService.stitch(files, direction: direction)
            previewImage = NSImage(data: result.data)
            showStatus("预览尺寸：\(Int(result.pixelSize.width)) × \(Int(result.pixelSize.height))")
        } catch {
            showStatus("预览失败：\(error.localizedDescription)", isError: true)
        }
    }

    private func saveStitchedImage() {
        guard let destination = FilePanels.saveFile(
            title: "保存拼接长图",
            suggestedName: "拼接长图.png",
            type: .png
        ) else { return }

        do {
            let result = try ImageStitchService.stitch(files, direction: direction)
            try result.data.write(to: destination, options: .atomic)
            previewImage = NSImage(data: result.data)
            showStatus("已保存 \(Int(result.pixelSize.width)) × \(Int(result.pixelSize.height)) 长图")
        } catch {
            showStatus("保存失败：\(error.localizedDescription)", isError: true)
        }
    }

    private func showStatus(_ message: String, isError: Bool = false) {
        statusMessage = message
        hasError = isError
    }
}
