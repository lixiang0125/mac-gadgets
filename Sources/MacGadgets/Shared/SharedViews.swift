import AppKit
import SwiftUI

struct ToolHeader: View {
    @EnvironmentObject private var localization: LocalizationStore
    let titleKey: String
    let descriptionKey: String
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
                Text(localization.text(titleKey))
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .tracking(-0.35)
                Text(localization.text(descriptionKey))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }

            Spacer(minLength: 16)
            LanguageSwitcher()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct EditorPane: View {
    @EnvironmentObject private var localization: LocalizationStore
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

            AlignedTextEditor(
                text: $text,
                placeholder: placeholder,
                isEditable: isEditable
            )
            .background(AppTheme.editorSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.surfaceRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.surfaceRadius, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            }
        }
    }

    private var editorSummary: String {
        let lineCount = text.isEmpty ? 0 : text.split(separator: "\n", omittingEmptySubsequences: false).count
        return localization.text(
            "common.editorSummary",
            Int64(lineCount),
            Int64(text.count)
        )
    }
}

private struct AlignedTextEditor: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let isEditable: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let contentSize = scrollView.contentSize
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: NSSize(
            width: contentSize.width,
            height: .greatestFiniteMagnitude
        ))
        textContainer.widthTracksTextView = true
        textContainer.lineFragmentPadding = 5
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        let textView = PlaceholderTextView(
            frame: NSRect(origin: .zero, size: contentSize),
            textContainer: textContainer
        )
        let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 3

        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.font = font
        textView.textColor = .labelColor
        textView.insertionPointColor = .controlAccentColor
        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ]
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.delegate = context.coordinator
        textView.string = text
        textView.placeholder = placeholder
        textView.setAccessibilityPlaceholderValue(placeholder)
        textView.isEditable = isEditable
        textView.isSelectable = true

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? PlaceholderTextView else { return }

        if textView.string != text {
            let selections = textView.selectedRanges
            textView.string = text
            let validSelections = selections.filter {
                NSMaxRange($0.rangeValue) <= (text as NSString).length
            }
            if validSelections.isEmpty {
                textView.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
            } else {
                textView.selectedRanges = validSelections
            }
        }

        textView.placeholder = placeholder
        textView.setAccessibilityPlaceholderValue(placeholder)
        textView.isEditable = isEditable
        textView.needsDisplay = true
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
            textView.needsDisplay = true
        }
    }
}

class PlaceholderTextView: NSTextView {
    var placeholder = "" {
        didSet {
            if oldValue != placeholder {
                needsDisplay = true
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard string.isEmpty, !placeholder.isEmpty, window?.firstResponder !== self else { return }

        let paragraphStyle = defaultParagraphStyle ?? NSParagraphStyle.default
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
            .foregroundColor: NSColor.placeholderTextColor,
            .paragraphStyle: paragraphStyle
        ]
        let lineFragmentPadding = textContainer?.lineFragmentPadding ?? 0
        let origin = NSPoint(
            x: textContainerInset.width + lineFragmentPadding,
            y: textContainerInset.height
        )
        placeholder.draw(at: origin, withAttributes: attributes)
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        needsDisplay = true
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        needsDisplay = true
        return result
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
        .controlSize(.large)
        .padding(10)
        .appGlassSurface()
    }
}

struct FileOrderButtons: View {
    @EnvironmentObject private var localization: LocalizationStore
    let canMoveUp: Bool
    let canMoveDown: Bool
    let moveUp: () -> Void
    let moveDown: () -> Void
    var axis: Axis = .vertical

    var body: some View {
        let layout = axis == .horizontal
            ? AnyLayout(HStackLayout(spacing: 2))
            : AnyLayout(VStackLayout(spacing: 2))
        layout {
            Button(action: moveUp) {
                Image(systemName: "chevron.up")
                    .frame(
                        width: AppTheme.compactControlHitSize,
                        height: AppTheme.compactControlHitSize
                    )
                    .contentShape(Rectangle())
            }
            .disabled(!canMoveUp)
            .help(localization.text("common.moveUp"))
            .accessibilityLabel(localization.text("common.moveUp"))

            if axis == .horizontal {
                Divider().frame(height: 18)
            } else {
                Divider().frame(width: 18)
            }

            Button(action: moveDown) {
                Image(systemName: "chevron.down")
                    .frame(
                        width: AppTheme.compactControlHitSize,
                        height: AppTheme.compactControlHitSize
                    )
                    .contentShape(Rectangle())
            }
            .disabled(!canMoveDown)
            .help(localization.text("common.moveDown"))
            .accessibilityLabel(localization.text("common.moveDown"))
        }
        .buttonStyle(.borderless)
        .padding(4)
        .appGlassSurface(cornerRadius: 10, interactive: true)
        .foregroundStyle(.primary)
    }
}

private struct LanguageSwitcher: View {
    @EnvironmentObject private var localization: LocalizationStore

    var body: some View {
        Menu {
            ForEach(AppLanguage.allCases) { language in
                Button {
                    localization.select(language)
                } label: {
                    HStack {
                        Text(localization.text(language.displayNameKey))
                        if localization.language == language {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label(
                localization.text(localization.language.displayNameKey),
                systemImage: "globe"
            )
        }
        .menuStyle(.borderlessButton)
        .controlSize(.large)
        .fixedSize()
        .help(localization.text("language.switch"))
        .accessibilityLabel(localization.text("language.switch"))
        .accessibilityValue(localization.text(localization.language.displayNameKey))
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
