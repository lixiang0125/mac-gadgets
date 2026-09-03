import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct JSONFormatterView: View {
    @State private var jsonText = ""
    @State private var sortedKeys = false
    @State private var statusMessage = ""
    @State private var hasError = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.pageSpacing) {
            ToolHeader(
                title: "JSON 格式化",
                description: "在当前编辑器内校验并格式化 JSON。支持对象、数组和基础值。",
                systemImage: "curlybraces"
            )

            EditorPane(
                title: "JSON",
                text: $jsonText,
                placeholder: "粘贴 JSON，例如 {\"name\":\"Mac Gadgets\"}"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            ToolControlBar {
                Button("格式化", systemImage: "wand.and.stars") { formatJSON() }
                    .appPrimaryActionStyle()
                    .disabled(jsonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.return, modifiers: .command)

                Toggle("按键名排序", isOn: $sortedKeys)
                    .toggleStyle(.checkbox)

                Button("打开文件…", systemImage: "folder") { openJSONFile() }
                    .keyboardShortcut("o", modifiers: .command)
                Button("复制内容", systemImage: "doc.on.doc") {
                    PasteboardHelper.copy(jsonText)
                    showStatus("已复制到剪贴板")
                }
                .disabled(jsonText.isEmpty)
                Button("保存…", systemImage: "square.and.arrow.down") { saveJSONFile() }
                    .disabled(jsonText.isEmpty)
                    .keyboardShortcut("s", modifiers: .command)

                Spacer()
                StatusMessageView(message: statusMessage, isError: hasError)
            }
        }
        .toolPageStyle()
    }

    private func formatJSON() {
        do {
            jsonText = try JSONService.format(jsonText, sortedKeys: sortedKeys)
            showStatus("JSON 格式正确，格式化完成")
        } catch {
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
            jsonText = try String(contentsOf: url, encoding: .utf8)
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
            try jsonText.write(to: url, atomically: true, encoding: .utf8)
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
