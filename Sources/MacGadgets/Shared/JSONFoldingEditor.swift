import AppKit
import SwiftUI

struct JSONFoldCommand: Equatable {
    enum Kind { case foldAll, expandAll }
    let id = UUID()
    let kind: Kind
}

struct JSONFoldingEditorPane: View {
    @EnvironmentObject private var localization: LocalizationStore
    @Binding var text: String
    @State private var command: JSONFoldCommand?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(localization.text("jsonFormatter.editor.title")).font(.headline)
                Text(localization.text("common.editorSummary",
                                       Int64(text.isEmpty ? 0 : text.split(separator: "\n", omittingEmptySubsequences: false).count),
                                       Int64(text.count)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Button(localization.text("jsonFormatter.foldAll"), systemImage: "chevron.right.2") {
                    command = JSONFoldCommand(kind: .foldAll)
                }
                Button(localization.text("jsonFormatter.expandAll"), systemImage: "chevron.down.2") {
                    command = JSONFoldCommand(kind: .expandAll)
                }
            }
            .controlSize(.large)
            .disabled(text.isEmpty)

            JSONFoldingEditor(text: $text, command: command, localization: localization)
                .background(AppTheme.editorSurface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.surfaceRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.surfaceRadius, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                }
        }
    }
}

struct JSONFoldingEditor: NSViewRepresentable {
    @Binding var text: String
    let command: JSONFoldCommand?
    @ObservedObject var localization: LocalizationStore

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = JSONFoldingScrollView.make(frame: .zero)
        let editor = scroll.documentView as! JSONFoldingTextView
        configure(editor)
        editor.setSource(text)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let editor = scroll.documentView as? JSONFoldingTextView else { return }
        configure(editor)
        if editor.document.source != text { editor.setSource(text) }
        if let command, context.coordinator.lastCommand != command.id {
            context.coordinator.lastCommand = command.id
            switch command.kind {
            case .foldAll: editor.foldAll()
            case .expandAll: editor.expandAll()
            }
        }
    }

    private func configure(_ editor: JSONFoldingTextView) {
        editor.onSourceChange = { text = $0 }
        editor.placeholder = localization.text("jsonFormatter.editor.placeholder")
        editor.setAccessibilityPlaceholderValue(editor.placeholder)
        editor.setAccessibilityLabel(localization.text("jsonFormatter.editor.title"))
        editor.foldingRuler?.foldLabel = localization.text("jsonFormatter.foldLine")
        editor.foldingRuler?.expandLabel = localization.text("jsonFormatter.expandLine")
        editor.foldingRuler?.needsDisplay = true
    }

    final class Coordinator {
        var lastCommand: UUID?
    }
}

final class JSONFoldingScrollView: NSScrollView {
    static func make(frame: NSRect) -> JSONFoldingScrollView {
        let scroll = JSONFoldingScrollView(frame: frame)
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        let editor = JSONFoldingTextView.make(frame: NSRect(origin: .zero, size: scroll.contentSize))
        scroll.documentView = editor
        let ruler = JSONFoldingRulerView(scrollView: scroll, orientation: .verticalRuler)
        ruler.clientView = editor
        ruler.ruleThickness = 74
        scroll.verticalRulerView = ruler
        scroll.hasVerticalRuler = true
        scroll.rulersVisible = true
        editor.foldingRuler = ruler
        scroll.tile()
        return scroll
    }

    override func tile() {
        super.tile()
        guard let editor = documentView as? JSONFoldingTextView else { return }
        // SwiftUI creates this scroll view at zero size; refresh the minimum once
        // laid out so clicks anywhere in an empty editor can focus the text view.
        let minimumHeight = contentSize.height
        if editor.minSize.height != minimumHeight {
            editor.minSize = NSSize(width: 0, height: minimumHeight)
        }
        if editor.frame.height < minimumHeight {
            editor.setFrameSize(NSSize(width: contentSize.width, height: minimumHeight))
        }
    }
}

@MainActor
private final class JSONEditorUndoManager: UndoManager {
    var beforeHistoryChange: (() -> Void)?
    override func undo() { beforeHistoryChange?(); super.undo() }
    override func redo() { beforeHistoryChange?(); super.redo() }
}

final class JSONFoldingTextView: PlaceholderTextView {
    private(set) var document = JSONFoldingDocument()
    weak var foldingRuler: JSONFoldingRulerView?
    var onSourceChange: ((String) -> Void)?
    private var isRendering = false
    private lazy var history: JSONEditorUndoManager = {
        let manager = JSONEditorUndoManager()
        manager.beforeHistoryChange = { [weak self] in self?.expandAll() }
        return manager
    }()

    override var undoManager: UndoManager? { history }

    static func make(frame: NSRect) -> JSONFoldingTextView {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: NSSize(width: frame.width, height: .greatestFiniteMagnitude))
        container.widthTracksTextView = true
        container.lineFragmentPadding = 5
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        let view = JSONFoldingTextView(frame: frame, textContainer: container)
        view.autoresizingMask = [.width]
        view.minSize = NSSize(width: 0, height: frame.height)
        view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.drawsBackground = false
        view.textContainerInset = NSSize(width: 10, height: 10)
        let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        view.font = font
        view.textColor = .labelColor
        view.insertionPointColor = .controlAccentColor
        let paragraph = NSMutableParagraphStyle()
        // Reserve space between JSON lines for gutter controls without stretching
        // the glyph/selection/caret rect. A forced line height also enlarges AppKit's caret.
        paragraph.paragraphSpacing = max(0, AppTheme.compactControlHitSize - layout.defaultLineHeight(for: font))
        view.defaultParagraphStyle = paragraph
        view.typingAttributes = view.baseAttributes
        view.isRichText = false
        view.isEditable = true
        view.isSelectable = true
        view.importsGraphics = false
        view.allowsUndo = true
        view.usesFindBar = true
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.isAutomaticSpellingCorrectionEnabled = false
        return view
    }

    private var baseAttributes: [NSAttributedString.Key: Any] {
        [.font: font ?? NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
         .foregroundColor: NSColor.labelColor,
         .paragraphStyle: defaultParagraphStyle ?? NSParagraphStyle.default]
    }

    func setSource(_ text: String) {
        let selection = document.projection.sourceRange(for: selectedRange())
        document.setSource(text)
        // Opening/formatting replaces the document and invalidates prior edit ranges.
        history.removeAllActions()
        render(sourceSelection: NSRange(location: min(selection.location, (text as NSString).length), length: 0))
    }

    func toggleFold(at offset: Int) {
        guard !hasMarkedText() else { return }
        let selection = document.projection.sourceRange(for: selectedRange())
        document.toggle(offset)
        render(sourceSelection: selection)
    }

    func foldAll() {
        guard !hasMarkedText() else { return }
        let selection = document.projection.sourceRange(for: selectedRange())
        document.foldAll()
        render(sourceSelection: selection)
    }

    func expandAll() {
        guard !document.collapsed.isEmpty else { return }
        let selection = document.projection.sourceRange(for: selectedRange())
        document.expandAll()
        render(sourceSelection: selection)
    }

    private func render(sourceSelection: NSRange) {
        isRendering = true
        history.disableUndoRegistration()
        defer { history.enableUndoRegistration(); isRendering = false }
        let attributed = NSMutableAttributedString(string: document.projection.text, attributes: baseAttributes)
        for span in document.projection.spans {
            attributed.addAttributes([.foregroundColor: NSColor.secondaryLabelColor,
                                      .backgroundColor: NSColor.quaternaryLabelColor], range: span.displayRange)
        }
        textStorage?.setAttributedString(attributed)
        typingAttributes = baseAttributes
        setSelectedRange(document.projection.displayedRange(for: sourceSelection))
        needsDisplay = true
        foldingRuler?.needsDisplay = true
    }

    override func didChangeText() {
        guard !isRendering else { return }
        // Native editing always occurs on the full document, never on ellipses.
        document.setSource(string)
        super.didChangeText()
        onSourceChange?(document.source)
        foldingRuler?.needsDisplay = true
    }

    private func prepareForEditing(_ replacementRange: NSRange) -> NSRange {
        guard !document.collapsed.isEmpty else { return replacementRange }
        // Preserve NSNotFound so AppKit can replace its marked range during IME composition.
        let fullRange = replacementRange.location == NSNotFound
            ? replacementRange : document.projection.sourceRange(for: replacementRange)
        expandAll()
        return fullRange
    }

    override func insertText(_ string: Any, replacementRange: NSRange) {
        let fullRange = prepareForEditing(replacementRange)
        super.insertText(string, replacementRange: fullRange)
    }

    override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        let fullRange = prepareForEditing(replacementRange)
        super.setMarkedText(string, selectedRange: selectedRange, replacementRange: fullRange)
    }

    override func doCommand(by selector: Selector) {
        let name = NSStringFromSelector(selector)
        if !["move", "select", "scroll"].contains(where: { name.hasPrefix($0) }) { expandAll() }
        super.doCommand(by: selector)
    }

    override func cut(_ sender: Any?) { expandAll(); super.cut(sender) }
    override func paste(_ sender: Any?) { expandAll(); super.paste(sender) }
    override func performFindPanelAction(_ sender: Any?) { expandAll(); super.performFindPanelAction(sender) }

    override func shouldChangeText(in affectedCharRange: NSRange, replacementString: String?) -> Bool {
        if !document.collapsed.isEmpty {
            // Covers less common mutations, such as Services or drag/drop.
            // Unfold and reject the stale projected range rather than corrupt JSON.
            expandAll()
            return false
        }
        return super.shouldChangeText(in: affectedCharRange, replacementString: replacementString)
    }

    override func writeSelection(to pasteboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        guard type == .string else { return super.writeSelection(to: pasteboard, type: type) }
        return pasteboard.setString(document.projection.copiedText(in: selectedRange()), forType: .string)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let index = characterIndexForInsertion(at: point)
        if let span = document.projection.spans.first(where: { NSLocationInRange(index, $0.displayRange) }) {
            toggleFold(at: span.region.openingOffset)
            return
        }
        super.mouseDown(with: event)
    }
}

final class JSONFoldingRulerView: NSRulerView {
    var foldLabel = ""
    var expandLabel = ""
    private var buttons: [Int: NSButton] = [:]
    override var isFlipped: Bool { true }

    override func accessibilityRole() -> NSAccessibility.Role? { .group }

    override func accessibilityChildren() -> [Any]? {
        buttons.sorted { $0.key < $1.key }.map(\.value)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let editor = clientView as? JSONFoldingTextView,
              let layout = editor.layoutManager, let container = editor.textContainer else { return }
        NSColor.controlBackgroundColor.setFill()
        bounds.fill()
        let visible = editor.visibleRect.offsetBy(dx: -editor.textContainerOrigin.x, dy: -editor.textContainerOrigin.y)
        let glyphs = layout.glyphRange(forBoundingRect: visible, in: container)
        let characters = layout.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
        var used: Set<Int> = []
        for line in editor.document.projection.lines {
            guard line.displayOffset >= characters.location,
                  line.displayOffset <= NSMaxRange(characters), line.displayOffset < (editor.string as NSString).length else { continue }
            let glyph = layout.glyphIndexForCharacter(at: line.displayOffset)
            let fragment = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            let origin = convert(NSPoint(x: 0, y: fragment.minY + editor.textContainerOrigin.y), from: editor)
            let baseline = origin.y + layout.location(forGlyphAt: glyph).y
            let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            let number = "\(line.sourceLine)" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let numberSize = number.size(withAttributes: attributes)
            number.draw(at: NSPoint(x: 38 - numberSize.width, y: baseline - ceil(font.ascender)), withAttributes: attributes)
            guard let region = line.region else { continue }
            let button: NSButton
            if let existing = buttons[region.openingOffset] { button = existing }
            else {
                button = NSButton()
                button.isBordered = false
                button.imagePosition = .imageOnly
                button.setButtonType(.momentaryPushIn)
                button.target = self
                button.action = #selector(toggle(_:))
                button.tag = region.openingOffset
                buttons[region.openingOffset] = button
                addSubview(button)
            }
            let folded = editor.document.collapsed.contains(region.openingOffset)
            let label = String(format: folded ? expandLabel : foldLabel, Int64(region.line))
            button.image = NSImage(systemSymbolName: folded ? "chevron.right" : "chevron.down", accessibilityDescription: label)
            button.contentTintColor = .labelColor
            button.toolTip = label
            button.setAccessibilityLabel(label)
            let centerY = baseline - (editor.font?.capHeight ?? font.capHeight) / 2
            button.frame = NSRect(x: 42, y: centerY - 15, width: 30, height: 30)
            used.insert(region.openingOffset)
        }
        for key in Array(buttons.keys) where !used.contains(key) {
            buttons.removeValue(forKey: key)?.removeFromSuperview()
        }
    }

    @objc private func toggle(_ sender: NSButton) {
        (clientView as? JSONFoldingTextView)?.toggleFold(at: sender.tag)
    }
}
