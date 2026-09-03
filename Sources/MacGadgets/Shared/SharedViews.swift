import SwiftUI

struct ToolHeader: View {
    let title: String
    let description: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 42, height: 42)
                .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2.weight(.semibold))
                Text(description)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EditorPane: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var isEditable = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(Color(nsColor: .textBackgroundColor))
                    .disabled(!isEditable)

                if text.isEmpty && !placeholder.isEmpty {
                    Text(placeholder)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.separator, lineWidth: 1)
            }
        }
    }
}

struct StatusMessageView: View {
    let message: String
    var isError = false

    var body: some View {
        if !message.isEmpty {
            Label(message, systemImage: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.callout)
                .foregroundStyle(isError ? Color.red : Color.green)
                .textSelection(.enabled)
        }
    }
}

struct FileOrderButtons: View {
    let canMoveUp: Bool
    let canMoveDown: Bool
    let moveUp: () -> Void
    let moveDown: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Button(action: moveUp) {
                Image(systemName: "chevron.up")
            }
            .disabled(!canMoveUp)
            .help("上移")

            Button(action: moveDown) {
                Image(systemName: "chevron.down")
            }
            .disabled(!canMoveDown)
            .help("下移")
        }
        .buttonStyle(.borderless)
    }
}
