import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct JSONFormatterView: View {
    @EnvironmentObject private var localization: LocalizationStore
    @State private var jsonText = ""
    @State private var sortedKeys = false
    @State private var statusMessage = ""
    @State private var hasError = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.pageSpacing) {
            ToolHeader(
                titleKey: "tool.jsonFormatter.title",
                descriptionKey: "tool.jsonFormatter.description",
                systemImage: "curlybraces"
            )

            EditorPane(
                title: localization.text("jsonFormatter.editor.title"),
                text: $jsonText,
                placeholder: localization.text("jsonFormatter.editor.placeholder")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            ToolControlBar {
                Button(localization.text("jsonFormatter.format"), systemImage: "wand.and.stars") {
                    formatJSON()
                }
                    .appPrimaryActionStyle()
                    .disabled(jsonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.return, modifiers: .command)

                Toggle(localization.text("jsonFormatter.sortKeys"), isOn: $sortedKeys)
                    .toggleStyle(.checkbox)

                Button(localization.text("jsonFormatter.open"), systemImage: "folder") {
                    openJSONFile()
                }
                    .keyboardShortcut("o", modifiers: .command)
                Button(localization.text("jsonFormatter.copy"), systemImage: "doc.on.doc") {
                    PasteboardHelper.copy(jsonText)
                    showStatus(localization.text("common.status.copied"))
                }
                .disabled(jsonText.isEmpty)
                Button(localization.text("jsonFormatter.save"), systemImage: "square.and.arrow.down") {
                    saveJSONFile()
                }
                    .disabled(jsonText.isEmpty)
                    .keyboardShortcut("s", modifiers: .command)

                Spacer()
                StatusMessageView(message: statusMessage, isError: hasError)
            }
        }
        .toolPageStyle()
        .onChange(of: localization.language) { statusMessage = "" }
    }

    private func formatJSON() {
        do {
            jsonText = try JSONService.format(jsonText, sortedKeys: sortedKeys)
            showStatus(localization.text("jsonFormatter.status.formatted"))
        } catch {
            showStatus(
                localization.text(
                    "jsonFormatter.status.formatFailed",
                    localization.errorMessage(for: error)
                ),
                isError: true
            )
        }
    }

    private func openJSONFile() {
        guard let url = FilePanels.openFiles(
            title: localization.text("jsonFormatter.panel.select"),
            types: [.json, .plainText],
            allowsMultipleSelection: false
        ).first else { return }

        do {
            jsonText = try String(contentsOf: url, encoding: .utf8)
            showStatus(localization.text("common.status.read", url.lastPathComponent))
        } catch {
            showStatus(
                localization.text("common.status.readFailed", localization.errorMessage(for: error)),
                isError: true
            )
        }
    }

    private func saveJSONFile() {
        guard let url = FilePanels.saveFile(
            title: localization.text("jsonFormatter.panel.save"),
            suggestedName: localization.text("jsonFormatter.file.defaultName"),
            type: .json
        ) else { return }

        do {
            try jsonText.write(to: url, atomically: true, encoding: .utf8)
            showStatus(localization.text("jsonFormatter.status.saved", url.lastPathComponent))
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
