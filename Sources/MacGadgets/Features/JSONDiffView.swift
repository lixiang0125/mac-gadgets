import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct JSONDiffView: View {
    @State private var leftText = ""
    @State private var rightText = ""
    @State private var diffResult: JSONDiffResult?
    @State private var statusMessage = ""
    @State private var hasError = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.pageSpacing) {
            ToolHeader(
                title: "JSON 对比",
                description: "先格式化两侧 JSON，再按行对齐并高亮新增、删除和修改内容。",
                systemImage: "arrow.left.arrow.right"
            )

            HSplitView {
                jsonInputPane(title: "JSON A", text: $leftText, side: .left)
                    .padding(.trailing, AppTheme.splitPaneSpacing / 2)
                jsonInputPane(title: "JSON B", text: $rightText, side: .right)
                    .padding(.leading, AppTheme.splitPaneSpacing / 2)
            }
            .frame(minHeight: 190, idealHeight: 230, maxHeight: 300)

            ToolControlBar {
                Button("格式化并对比", systemImage: "arrow.left.arrow.right") { compareJSON() }
                    .appPrimaryActionStyle()
                    .disabled(leftText.isEmpty || rightText.isEmpty)
                    .keyboardShortcut(.return, modifiers: .command)
                Button("交换两侧", systemImage: "arrow.triangle.2.circlepath") {
                    swap(&leftText, &rightText)
                    diffResult = nil
                    statusMessage = ""
                }
                Button("清空", systemImage: "trash") {
                    leftText = ""
                    rightText = ""
                    diffResult = nil
                    statusMessage = ""
                }
                .disabled(leftText.isEmpty && rightText.isEmpty)

                Spacer()
                StatusMessageView(message: statusMessage, isError: hasError)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("差异结果")
                        .font(.headline)
                    Spacer()
                    if let result = diffResult, !result.isIdentical {
                        HStack(spacing: 12) {
                            diffLegend(color: .yellow, text: "修改 \(result.modifiedCount)")
                            diffLegend(color: .green, text: "新增 \(result.addedCount)")
                            diffLegend(color: .red, text: "删除 \(result.removedCount)")
                        }
                        .font(.caption)
                    }
                }

                if let diffResult {
                    JSONDiffResultView(result: diffResult)
                } else {
                    ContentUnavailableView(
                        "等待对比",
                        systemImage: "arrow.left.arrow.right",
                        description: Text("输入或打开两个 JSON，然后点击“格式化并对比”。")
                    )
                }
            }
            .padding(12)
            .workspaceSurface()
        }
        .toolPageStyle()
    }

    private enum InputSide { case left, right }

    private func jsonInputPane(title: String, text: Binding<String>, side: InputSide) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Button("打开…", systemImage: "folder") { openFile(for: side) }
                    .labelStyle(.titleAndIcon)
            }
            EditorPane(title: "", text: text, placeholder: "粘贴 JSON…")
        }
        .frame(minWidth: 300)
    }

    private func diffLegend(color: Color, text: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Circle().fill(color.opacity(0.7)).frame(width: 8, height: 8)
        }
    }

    private func compareJSON() {
        do {
            let formattedLeft = try JSONService.format(leftText)
            let formattedRight = try JSONService.format(rightText)
            leftText = formattedLeft
            rightText = formattedRight
            let result = JSONDiffService.compare(left: formattedLeft, right: formattedRight)
            diffResult = result
            showStatus(result.isIdentical ? "两个 JSON 完全一致" : "对比完成")
        } catch {
            diffResult = nil
            showStatus("对比失败：请检查两侧 JSON。\(error.localizedDescription)", isError: true)
        }
    }

    private func openFile(for side: InputSide) {
        guard let url = FilePanels.openFiles(
            title: side == .left ? "选择 JSON A" : "选择 JSON B",
            types: [.json, .plainText],
            allowsMultipleSelection: false
        ).first else { return }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            if side == .left { leftText = content } else { rightText = content }
            diffResult = nil
            showStatus("已读取 \(url.lastPathComponent)")
        } catch {
            showStatus("读取失败：\(error.localizedDescription)", isError: true)
        }
    }

    private func showStatus(_ message: String, isError: Bool = false) {
        statusMessage = message
        hasError = isError
    }
}

private struct JSONDiffResultView: View {
    let result: JSONDiffResult

    var body: some View {
        if result.isIdentical {
            ContentUnavailableView(
                "内容一致",
                systemImage: "checkmark.circle.fill",
                description: Text("格式化后的两个 JSON 没有差异。")
            )
        } else {
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        Text("JSON A")
                            .font(.caption.weight(.semibold))
                            .frame(width: 470, alignment: .leading)
                            .padding(.leading, 46)
                        Divider()
                        Text("JSON B")
                            .font(.caption.weight(.semibold))
                            .frame(width: 470, alignment: .leading)
                            .padding(.leading, 46)
                    }
                    .padding(.vertical, 6)
                    .background(.bar)

                    ForEach(result.rows) { row in
                        HStack(spacing: 0) {
                            diffCell(
                                number: row.leftLineNumber,
                                text: row.leftText,
                                color: leftColor(for: row.kind)
                            )
                            Divider()
                            diffCell(
                                number: row.rightLineNumber,
                                text: row.rightText,
                                color: rightColor(for: row.kind)
                            )
                        }
                    }
                }
            }
            .textSelection(.enabled)
        }
    }

    private func diffCell(number: Int?, text: String?, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number.map(String.init) ?? "")
                .foregroundStyle(.tertiary)
                .frame(width: 34, alignment: .trailing)
            Text(text ?? "")
                .foregroundStyle(text == nil ? .tertiary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(.caption, design: .monospaced))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .frame(width: 470, alignment: .topLeading)
        .frame(minHeight: 24, alignment: .topLeading)
        .background(color)
    }

    private func leftColor(for kind: JSONDiffLineKind) -> Color {
        switch kind {
        case .modified: .yellow.opacity(0.22)
        case .removed: .red.opacity(0.20)
        case .added, .unchanged: .clear
        }
    }

    private func rightColor(for kind: JSONDiffLineKind) -> Color {
        switch kind {
        case .modified: .yellow.opacity(0.22)
        case .added: .green.opacity(0.20)
        case .removed, .unchanged: .clear
        }
    }
}
