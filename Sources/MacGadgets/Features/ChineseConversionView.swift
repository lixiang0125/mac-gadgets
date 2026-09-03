import SwiftUI
import UniformTypeIdentifiers

struct ChineseConversionView: View {
    @EnvironmentObject private var localization: LocalizationStore
    @State private var direction: ChineseConversionDirection = .simplifiedToTraditional
    @State private var sourceText = ""
    @State private var convertedText = ""
    @State private var loadedFileName = ""
    @State private var statusMessage = ""
    @State private var hasError = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.pageSpacing) {
            ToolHeader(
                titleKey: "tool.chineseConversion.title",
                descriptionKey: "tool.chineseConversion.description",
                systemImage: "character.book.closed"
            )

            ToolControlBar {
                Text(localization.text("chinese.direction.label"))
                    .font(.callout.weight(.medium))
                Picker(localization.text("chinese.direction.label"), selection: $direction) {
                    ForEach(ChineseConversionDirection.allCases) { item in
                        Text(localization.text(item.titleKey)).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)
                .labelsHidden()
                .onChange(of: direction) {
                    guard !sourceText.isEmpty else { return }
                    convertedText = ChineseConversionService.convert(sourceText, direction: direction)
                    showStatus(localization.text("chinese.status.directionChanged"))
                }

                Spacer()

                if !loadedFileName.isEmpty {
                    Label(loadedFileName, systemImage: "doc.text")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Button(localization.text("chinese.openTXT"), systemImage: "folder") {
                    openTextFile()
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            HSplitView {
                EditorPane(
                    title: localization.text("chinese.source.title"),
                    text: $sourceText,
                    placeholder: localization.text("chinese.source.placeholder")
                )
                .frame(minWidth: 300)
                .padding(.trailing, AppTheme.splitPaneSpacing / 2)

                EditorPane(
                    title: localization.text("chinese.result.title"),
                    text: $convertedText,
                    placeholder: localization.text("chinese.result.placeholder"),
                    isEditable: false
                )
                .frame(minWidth: 300)
                .padding(.leading, AppTheme.splitPaneSpacing / 2)
            }

            ToolControlBar {
                Button(localization.text("chinese.convert"), systemImage: "arrow.left.arrow.right") {
                    convertedText = ChineseConversionService.convert(sourceText, direction: direction)
                    showStatus(localization.text("chinese.status.converted"))
                }
                .appPrimaryActionStyle()
                .disabled(sourceText.isEmpty)
                .keyboardShortcut(.return, modifiers: .command)

                Button(localization.text("chinese.swap"), systemImage: "arrow.triangle.2.circlepath") {
                    swap(&sourceText, &convertedText)
                    direction = direction == .simplifiedToTraditional
                        ? .traditionalToSimplified
                        : .simplifiedToTraditional
                    statusMessage = ""
                }
                .disabled(convertedText.isEmpty)

                Button(localization.text("chinese.copyResult"), systemImage: "doc.on.doc") {
                    PasteboardHelper.copy(convertedText)
                    showStatus(localization.text("common.status.copied"))
                }
                .disabled(convertedText.isEmpty)

                Button(localization.text("chinese.saveTXT"), systemImage: "square.and.arrow.down") {
                    saveTextFile()
                }
                .disabled(convertedText.isEmpty)
                .keyboardShortcut("s", modifiers: .command)

                Spacer()
                StatusMessageView(message: statusMessage, isError: hasError)
            }
        }
        .toolPageStyle()
        .onChange(of: localization.language) { statusMessage = "" }
    }

    private func openTextFile() {
        guard let url = FilePanels.openFiles(
            title: localization.text("chinese.panel.selectTXT"),
            types: [.plainText],
            allowsMultipleSelection: false
        ).first else { return }

        do {
            sourceText = try ChineseConversionService.readTextFile(at: url)
            convertedText = ""
            loadedFileName = url.lastPathComponent
            showStatus(localization.text("common.status.read", url.lastPathComponent))
        } catch {
            showStatus(
                localization.text("common.status.readFailed", localization.errorMessage(for: error)),
                isError: true
            )
        }
    }

    private func saveTextFile() {
        let sourceBaseName = loadedFileName.isEmpty
            ? localization.text("chinese.file.resultBaseName")
            : URL(fileURLWithPath: loadedFileName).deletingPathExtension().lastPathComponent
                + localization.text("chinese.file.resultSuffix")
        guard let url = FilePanels.saveFile(
            title: localization.text("chinese.panel.saveResult"),
            suggestedName: sourceBaseName + ".txt",
            type: .plainText
        ) else { return }

        do {
            try ChineseConversionService.writeTextFile(convertedText, to: url)
            showStatus(localization.text("chinese.status.saved", url.lastPathComponent))
        } catch {
            showStatus(
                localization.text("common.status.saveFailed", localization.errorMessage(for: error)),
                isError: true
            )
        }
    }

    private func showStatus(_ message: String, isError: Bool = false) {
        statusMessage = message
        hasError = isError
    }
}
