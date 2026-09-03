import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct JSONDiffView: View {
    @EnvironmentObject private var localization: LocalizationStore
    @State private var leftText = ""
    @State private var rightText = ""
    @State private var diffResult: JSONDiffResult?
    @State private var statusMessage = ""
    @State private var hasError = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.pageSpacing) {
            ToolHeader(
                titleKey: "tool.jsonDiff.title",
                descriptionKey: "tool.jsonDiff.description",
                systemImage: "arrow.left.arrow.right"
            )

            HSplitView {
                jsonInputPane(
                    title: localization.text("jsonDiff.inputA"),
                    text: $leftText,
                    side: .left
                )
                    .padding(.trailing, AppTheme.splitPaneSpacing / 2)
                jsonInputPane(
                    title: localization.text("jsonDiff.inputB"),
                    text: $rightText,
                    side: .right
                )
                    .padding(.leading, AppTheme.splitPaneSpacing / 2)
            }
            .frame(minHeight: 190, idealHeight: 230, maxHeight: 300)

            ToolControlBar {
                Button(localization.text("jsonDiff.compare"), systemImage: "arrow.left.arrow.right") {
                    compareJSON()
                }
                    .appPrimaryActionStyle()
                    .disabled(leftText.isEmpty || rightText.isEmpty)
                    .keyboardShortcut(.return, modifiers: .command)
                Button(localization.text("jsonDiff.swap"), systemImage: "arrow.triangle.2.circlepath") {
                    swap(&leftText, &rightText)
                    diffResult = nil
                    statusMessage = ""
                }
                Button(localization.text("common.clear"), systemImage: "trash") {
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
                    Text(localization.text("jsonDiff.result.title"))
                        .font(.headline)
                    Spacer()
                    if let result = diffResult, !result.isIdentical {
                        HStack(spacing: 12) {
                            diffLegend(
                                color: .yellow,
                                text: localization.text(
                                    "jsonDiff.legend.modified",
                                    Int64(result.modifiedCount)
                                )
                            )
                            diffLegend(
                                color: .green,
                                text: localization.text(
                                    "jsonDiff.legend.added",
                                    Int64(result.addedCount)
                                )
                            )
                            diffLegend(
                                color: .red,
                                text: localization.text(
                                    "jsonDiff.legend.removed",
                                    Int64(result.removedCount)
                                )
                            )
                        }
                        .font(.caption)
                    }
                }

                if let diffResult {
                    JSONDiffResultView(result: diffResult)
                } else {
                    ContentUnavailableView(
                        localization.text("jsonDiff.empty.title"),
                        systemImage: "arrow.left.arrow.right",
                        description: Text(localization.text("jsonDiff.empty.description"))
                    )
                }
            }
            .padding(12)
            .workspaceSurface()
        }
        .toolPageStyle()
        .onChange(of: localization.language) { statusMessage = "" }
    }

    private enum InputSide { case left, right }

    private func jsonInputPane(title: String, text: Binding<String>, side: InputSide) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Button(localization.text("jsonDiff.open"), systemImage: "folder") {
                    openFile(for: side)
                }
                    .labelStyle(.titleAndIcon)
                    .controlSize(.large)
            }
            EditorPane(
                title: "",
                text: text,
                placeholder: localization.text("jsonDiff.placeholder")
            )
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
            showStatus(localization.text(
                result.isIdentical ? "jsonDiff.status.identical" : "jsonDiff.status.completed"
            ))
        } catch {
            diffResult = nil
            showStatus(
                localization.text(
                    "jsonDiff.status.failed",
                    localization.errorMessage(for: error)
                ),
                isError: true
            )
        }
    }

    private func openFile(for side: InputSide) {
        guard let url = FilePanels.openFiles(
            title: localization.text(
                side == .left ? "jsonDiff.panel.selectA" : "jsonDiff.panel.selectB"
            ),
            types: [.json, .plainText],
            allowsMultipleSelection: false
        ).first else { return }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            if side == .left { leftText = content } else { rightText = content }
            diffResult = nil
            showStatus(localization.text("common.status.read", url.lastPathComponent))
        } catch {
            showStatus(
                localization.text("common.status.readFailed", localization.errorMessage(for: error)),
                isError: true
            )
        }
    }

    private func showStatus(_ message: String, isError: Bool = false) {
        statusMessage = message
        hasError = isError
    }
}

private struct JSONDiffResultView: View {
    @EnvironmentObject private var localization: LocalizationStore
    let result: JSONDiffResult

    var body: some View {
        if result.isIdentical {
            ContentUnavailableView(
                localization.text("jsonDiff.identical.title"),
                systemImage: "checkmark.circle.fill",
                description: Text(localization.text("jsonDiff.identical.description"))
            )
        } else {
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        Text(localization.text("jsonDiff.inputA"))
                            .font(.caption.weight(.semibold))
                            .frame(width: 470, alignment: .leading)
                            .padding(.leading, 46)
                        Divider()
                        Text(localization.text("jsonDiff.inputB"))
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
