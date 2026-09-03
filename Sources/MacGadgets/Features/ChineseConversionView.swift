import SwiftUI
import UniformTypeIdentifiers

struct ChineseConversionView: View {
    @State private var direction: ChineseConversionDirection = .simplifiedToTraditional
    @State private var sourceText = ""
    @State private var convertedText = ""
    @State private var loadedFileName = ""
    @State private var statusMessage = ""
    @State private var hasError = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.pageSpacing) {
            ToolHeader(
                title: "中文简繁转换",
                description: "转换输入文本，或读取 TXT 文件后另存为 UTF-8 文本。",
                systemImage: "character.book.closed"
            )

            ToolControlBar {
                Text("转换方向")
                    .font(.callout.weight(.medium))
                Picker("转换方向", selection: $direction) {
                    ForEach(ChineseConversionDirection.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)
                .labelsHidden()
                .onChange(of: direction) {
                    guard !sourceText.isEmpty else { return }
                    convertedText = ChineseConversionService.convert(sourceText, direction: direction)
                    showStatus("已按新方向转换")
                }

                Spacer()

                if !loadedFileName.isEmpty {
                    Label(loadedFileName, systemImage: "doc.text")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Button("打开 TXT…", systemImage: "folder") {
                    openTextFile()
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            HSplitView {
                EditorPane(
                    title: "原文",
                    text: $sourceText,
                    placeholder: "在这里粘贴或输入中文文本…"
                )
                .frame(minWidth: 300)

                EditorPane(
                    title: "转换结果",
                    text: $convertedText,
                    placeholder: "转换结果会显示在这里",
                    isEditable: false
                )
                .frame(minWidth: 300)
            }

            ToolControlBar {
                Button("转换", systemImage: "arrow.left.arrow.right") {
                    convertedText = ChineseConversionService.convert(sourceText, direction: direction)
                    showStatus("转换完成")
                }
                .appPrimaryActionStyle()
                .disabled(sourceText.isEmpty)
                .keyboardShortcut(.return, modifiers: .command)

                Button("交换内容", systemImage: "arrow.triangle.2.circlepath") {
                    swap(&sourceText, &convertedText)
                    direction = direction == .simplifiedToTraditional
                        ? .traditionalToSimplified
                        : .simplifiedToTraditional
                    statusMessage = ""
                }
                .disabled(convertedText.isEmpty)

                Button("复制结果", systemImage: "doc.on.doc") {
                    PasteboardHelper.copy(convertedText)
                    showStatus("已复制到剪贴板")
                }
                .disabled(convertedText.isEmpty)

                Button("保存 TXT…", systemImage: "square.and.arrow.down") {
                    saveTextFile()
                }
                .disabled(convertedText.isEmpty)
                .keyboardShortcut("s", modifiers: .command)

                Spacer()
                StatusMessageView(message: statusMessage, isError: hasError)
            }
        }
        .toolPageStyle()
    }

    private func openTextFile() {
        guard let url = FilePanels.openFiles(
            title: "选择 TXT 文件",
            types: [.plainText],
            allowsMultipleSelection: false
        ).first else { return }

        do {
            sourceText = try ChineseConversionService.readTextFile(at: url)
            convertedText = ""
            loadedFileName = url.lastPathComponent
            showStatus("已读取 \(url.lastPathComponent)")
        } catch {
            showStatus("读取失败：\(error.localizedDescription)", isError: true)
        }
    }

    private func saveTextFile() {
        let sourceBaseName = loadedFileName.isEmpty
            ? "转换结果"
            : URL(fileURLWithPath: loadedFileName).deletingPathExtension().lastPathComponent + "-转换结果"
        guard let url = FilePanels.saveFile(
            title: "保存转换结果",
            suggestedName: sourceBaseName + ".txt",
            type: .plainText
        ) else { return }

        do {
            try ChineseConversionService.writeTextFile(convertedText, to: url)
            showStatus("已保存到 \(url.lastPathComponent)")
        } catch {
            showStatus("保存失败：\(error.localizedDescription)", isError: true)
        }
    }

    private func showStatus(_ message: String, isError: Bool = false) {
        statusMessage = message
        hasError = isError
    }
}
