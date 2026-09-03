import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct JSONFormatterView: View {
    @State private var sourceText = ""
    @State private var formattedText = ""
    @State private var sortedKeys = false
    @State private var statusMessage = ""
    @State private var hasError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ToolHeader(
                title: "JSON 格式化",
                description: "校验 JSON 语法，并用统一缩进输出易读格式。支持对象、数组和基础值。",
                systemImage: "curlybraces"
            )

            HSplitView {
                EditorPane(
                    title: "原始 JSON",
                    text: $sourceText,
                    placeholder: "粘贴 JSON，例如 {\"name\":\"Mac Gadgets\"}"
                )
                .frame(minWidth: 300)

                EditorPane(
                    title: "格式化结果",
                    text: $formattedText,
                    placeholder: "格式化结果会显示在这里",
                    isEditable: false
                )
                .frame(minWidth: 300)
            }

            HStack {
                Button("格式化", systemImage: "wand.and.stars") { formatJSON() }
                    .buttonStyle(.borderedProminent)
                    .disabled(sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Toggle("按键名排序", isOn: $sortedKeys)
                    .toggleStyle(.checkbox)

                Button("打开文件…", systemImage: "folder") { openJSONFile() }
                Button("复制结果", systemImage: "doc.on.doc") {
                    PasteboardHelper.copy(formattedText)
                    showStatus("已复制到剪贴板")
                }
                .disabled(formattedText.isEmpty)
                Button("保存…", systemImage: "square.and.arrow.down") { saveJSONFile() }
                    .disabled(formattedText.isEmpty)

                Spacer()
                StatusMessageView(message: statusMessage, isError: hasError)
            }
        }
        .padding(24)
    }

    private func formatJSON() {
        do {
            formattedText = try JSONService.format(sourceText, sortedKeys: sortedKeys)
            showStatus("JSON 格式正确，格式化完成")
        } catch {
            formattedText = ""
            showStatus("格式化失败：\(error.localizedDescription)", isError: true)
        }
    }

    private func openJSONFile() {
        guard let url = FilePanels.openFiles(
            title: "选择 JSON 文件",
            types: [.json, .plainText],
            allowsMultipleSelection: false
        ).first else { return }

        do {
            sourceText = try String(contentsOf: url, encoding: .utf8)
            formattedText = ""
            showStatus("已读取 \(url.lastPathComponent)")
        } catch {
            showStatus("读取失败：\(error.localizedDescription)", isError: true)
        }
    }

    private func saveJSONFile() {
        guard let url = FilePanels.saveFile(
            title: "保存格式化 JSON",
            suggestedName: "formatted.json",
            type: .json
        ) else { return }

        do {
            try formattedText.write(to: url, atomically: true, encoding: .utf8)
            showStatus("已保存为 \(url.lastPathComponent)")
        } catch {
            showStatus("保存失败：\(error.localizedDescription)", isError: true)
        }
    }

    private func showStatus(_ message: String, isError: Bool = false) {
        statusMessage = message
        hasError = isError
    }
}
