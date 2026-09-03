import SwiftUI

struct ToolHeader: View {
    let title: String
    let description: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 23, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 48, height: 48)
                .appGlassSurface()

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .tracking(-0.35)
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct EditorPane: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var isEditable = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Text(editorSummary)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.system(.body, design: .monospaced))
                    .lineSpacing(3)
                    .scrollContentBackground(.hidden)
                    .padding(9)
                    .background(AppTheme.editorSurface)
                    .disabled(!isEditable)

                if text.isEmpty && !placeholder.isEmpty {
                    Text(placeholder)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 17)
                        .allowsHitTesting(false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.surfaceRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.surfaceRadius, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            }
        }
    }

    private var editorSummary: String {
        let lineCount = text.isEmpty ? 0 : text.split(separator: "\n", omittingEmptySubsequences: false).count
        return "\(lineCount) 行  \(text.count) 字符"
    }
}

struct StatusMessageView: View {
    let message: String
    var isError = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if !message.isEmpty {
            Label(message, systemImage: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(isError ? Color.red : Color.green)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    (isError ? Color.red : Color.green).opacity(0.10),
                    in: RoundedRectangle(cornerRadius: AppTheme.surfaceRadius, style: .continuous)
                )
                .textSelection(.enabled)
                .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
        }
    }
}

struct ToolControlBar<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 10) {
            content
        }
        .controlSize(.regular)
        .padding(10)
        .appGlassSurface()
    }
}

struct FileOrderButtons: View {
    let canMoveUp: Bool
    let canMoveDown: Bool
    let moveUp: () -> Void
    let moveDown: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            Button(action: moveUp) {
                Image(systemName: "chevron.up")
                    .frame(width: 24, height: 24)
            }
            .disabled(!canMoveUp)
            .help("上移")

            Divider().frame(width: 18)

            Button(action: moveDown) {
                Image(systemName: "chevron.down")
                    .frame(width: 24, height: 24)
            }
            .disabled(!canMoveDown)
            .help("下移")
        }
        .buttonStyle(.borderless)
        .padding(4)
        .appGlassSurface(cornerRadius: 10, interactive: true)
    }
}

private struct FileDropTargetModifier: ViewModifier {
    let isEmpty: Bool
    let title: String
    let description: String
    let systemImage: String
    let onDrop: ([URL]) -> Void
    @State private var isTargeted = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if isEmpty {
                    VStack(spacing: 9) {
                        Image(systemName: systemImage)
                            .font(.system(size: 28, weight: .medium))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(AppTheme.accent)
                        Text(title)
                            .font(.headline)
                        Text(description)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .allowsHitTesting(false)
                }

                if isTargeted {
                    RoundedRectangle(cornerRadius: AppTheme.surfaceRadius, style: .continuous)
                        .fill(AppTheme.accent.opacity(0.08))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppTheme.surfaceRadius, style: .continuous)
                                .stroke(AppTheme.accent, style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
                        }
                        .padding(3)
                        .allowsHitTesting(false)
                }
            }
            .dropDestination(for: URL.self) { urls, _ in
                guard !urls.isEmpty else { return false }
                onDrop(urls)
                return true
            } isTargeted: { value in
                isTargeted = value
            }
    }
}

extension View {
    func fileDropTarget(
        isEmpty: Bool,
        title: String,
        description: String,
        systemImage: String,
        onDrop: @escaping ([URL]) -> Void
    ) -> some View {
        modifier(FileDropTargetModifier(
            isEmpty: isEmpty,
            title: title,
            description: description,
            systemImage: systemImage,
            onDrop: onDrop
        ))
    }
}
