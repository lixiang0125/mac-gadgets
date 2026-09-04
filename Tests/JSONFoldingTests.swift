import AppKit
import SwiftUI
import XCTest
@testable import MacGadgets

final class JSONFoldingTests: XCTestCase {
    private let sample = """
    {
      "profile": {
        "name": "中文 👩🏽‍💻",
        "active": true
      },
      "items": [
        {"id": 1},
        {"id": 2}
      ]
    }
    """

    func testFindsNestedObjectsAndArraysWithUTF16Offsets() {
        let regions = JSONFoldingService.regions(in: sample)
        XCTAssertEqual(regions.count, 5)
        XCTAssertEqual(regions.map(\.line), [1, 2, 6, 7, 8])
        let source = sample as NSString
        for region in regions {
            let opening = source.substring(with: NSRange(location: region.openingOffset, length: 1))
            let closing = source.substring(with: NSRange(location: region.closingOffset, length: 1))
            XCTAssertTrue((opening == "{" && closing == "}") || (opening == "[" && closing == "]"))
        }
    }

    func testIgnoresBracketsEscapedQuotesAndBackslashesInsideStrings() {
        let source = #"{"text":"{ [ } ] \" \\", "array":["}","["]}"#
        XCTAssertNoThrow(try JSONService.format(source))
        XCTAssertEqual(JSONFoldingService.regions(in: source).count, 2)
        XCTAssertTrue(JSONFoldingService.regions(in: #""{escaped}""#).isEmpty)
    }

    func testEmptyWhitespaceAndUnmatchedContainersDoNotCreateInvalidFolds() {
        for source in ["", "{}", "[ ]", "{\r\n\t}", "true", "null", "{\"a\": 1", "{]", "[}", "}"] {
            XCTAssertTrue(JSONFoldingService.regions(in: source).isEmpty, source)
        }
        let source = "{\"a\":{\"b\":1}, \"unfinished\": ["
        var document = JSONFoldingDocument(source: source)
        document.foldAll()
        XCTAssertEqual(document.projection.text, "{\"a\":{ … }, \"unfinished\": [")
        XCTAssertEqual(document.source, source)
    }

    func testLineNumbersSupportCRLFAndCRWithoutDoubleCounting() {
        let source = "{\r\n\"a\":{\r\"b\":1\r},\r\n\"c\":[1]\r\n}"
        var document = JSONFoldingDocument(source: source)
        XCTAssertEqual(document.regions.map(\.line), [1, 2, 5])
        document.toggle(document.regions[1].openingOffset)
        XCTAssertEqual(document.projection.lines.map(\.sourceLine), [1, 2, 5, 6])
    }

    func testFoldAllExpandAllAndParentTogglePreserveNestedState() {
        var document = JSONFoldingDocument(source: sample)
        document.foldAll()
        XCTAssertEqual(document.projection.text, "{ … }")
        XCTAssertEqual(document.projection.spans.count, 1)
        XCTAssertEqual(document.collapsed.count, 5)
        document.toggle(0)
        XCTAssertEqual(document.projection.text, "{\n  \"profile\": { … },\n  \"items\": [ … ]\n}")
        XCTAssertEqual(document.projection.lines.map(\.sourceLine), [1, 2, 6, 10])
        XCTAssertEqual(document.projection.spans.count, 2)
        document.expandAll()
        XCTAssertEqual(document.projection.text, sample)
        XCTAssertEqual(document.source, sample)
        XCTAssertTrue(document.collapsed.isEmpty)
    }

    func testSingleNestedFoldKeepsSiblingsAndTheirSourceLines() {
        var document = JSONFoldingDocument(source: sample)
        let profile = document.regions[1]
        document.toggle(profile.openingOffset)
        XCTAssertTrue(document.projection.text.contains("\"profile\": { … }"))
        XCTAssertTrue(document.projection.text.contains("{\"id\": 1}"))
        XCTAssertEqual(document.projection.lines.map(\.sourceLine), [1, 2, 6, 7, 8, 9, 10])
        XCTAssertEqual(document.projection.lines.compactMap { $0.region?.line }, [1, 2, 6, 7, 8])
        document.toggle(profile.openingOffset)
        XCTAssertEqual(document.projection.text, sample)
    }

    func testNewSourceResetsFoldStateAndUnknownOffsetsAreIgnored() {
        var document = JSONFoldingDocument(source: sample)
        document.toggle(-1)
        XCTAssertTrue(document.collapsed.isEmpty)
        document.foldAll()
        document.setSource("[1, 2]")
        XCTAssertTrue(document.collapsed.isEmpty)
        XCTAssertEqual(document.projection.text, "[1, 2]")
        XCTAssertEqual(document.regions.count, 1)
        document.setSource("")
        XCTAssertTrue(document.regions.isEmpty)
        XCTAssertTrue(document.projection.lines.isEmpty)
    }

    func testCopyIncludesHiddenContentsAndMapsSelectionsAcrossSiblingFolds() {
        var document = JSONFoldingDocument(source: sample)
        document.foldAll()
        document.toggle(0)
        let projection = document.projection
        let display = projection.text as NSString
        XCTAssertEqual(projection.copiedText(in: NSRange(location: 0, length: display.length)), sample)
        for span in projection.spans {
            XCTAssertEqual(projection.sourceRange(for: span.displayRange), span.region.interior)
            XCTAssertEqual(projection.copiedText(in: span.displayRange), (sample as NSString).substring(with: span.region.interior))
            let insideEllipsis = NSRange(location: span.displayRange.location + 1, length: 1)
            XCTAssertEqual(projection.sourceRange(for: insideEllipsis), span.region.interior)
        }
        let first = projection.spans[0]
        let second = projection.spans[1]
        let selection = NSRange(location: first.displayRange.location, length: NSMaxRange(second.displayRange) - first.displayRange.location)
        XCTAssertEqual(projection.sourceRange(for: selection),
                       NSRange(location: first.region.interior.location,
                               length: NSMaxRange(second.region.interior) - first.region.interior.location))
    }

    func testVisibleOffsetsRoundTripAndInvalidRangesClampSafely() {
        var document = JSONFoldingDocument(source: sample)
        document.foldAll()
        document.toggle(0)
        let projection = document.projection
        for offset in 0...(projection.text as NSString).length {
            guard !projection.spans.contains(where: { offset > $0.displayRange.location && offset < NSMaxRange($0.displayRange) }) else { continue }
            let display = NSRange(location: offset, length: 0)
            XCTAssertEqual(projection.displayedRange(for: projection.sourceRange(for: display)), display)
        }
        XCTAssertEqual(projection.copiedText(in: NSRange(location: NSNotFound, length: Int.max)), "")
        XCTAssertEqual(projection.displayedRange(for: NSRange(location: Int.max, length: Int.max)),
                       NSRange(location: (projection.text as NSString).length, length: 0))
    }

    func testVeryShortContainerCanFoldWithoutNegativeOffsets() {
        var document = JSONFoldingDocument(source: "[1]")
        document.foldAll()
        XCTAssertEqual(document.projection.text, "[ … ]")
        XCTAssertEqual(document.projection.copiedText(in: NSRange(location: 0, length: 5)), "[1]")
        XCTAssertEqual(document.projection.sourceRange(for: NSRange(location: 4, length: 1)), NSRange(location: 2, length: 1))
    }

    @MainActor
    func testNativeCaretUsesFontHeightInEmptyMultilineFoldedAndEditedDocuments() throws {
        let scroll = JSONFoldingScrollView.make(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let editor = try XCTUnwrap(scroll.documentView as? JSONFoldingTextView)
        let layout = try XCTUnwrap(editor.layoutManager)
        let font = try XCTUnwrap(editor.font)
        let expectedHeight = layout.defaultLineHeight(for: font)
        let window = NSWindow(contentRect: scroll.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = scroll
        defer { window.contentView = nil; window.close() }

        func assertCaretHeight(file: StaticString = #filePath, line: UInt = #line) {
            layout.ensureLayout(for: editor.textContainer!)
            let length = (editor.string as NSString).length
            for offset in 0...length {
                let rect = editor.firstRect(forCharacterRange: NSRange(location: offset, length: 0), actualRange: nil)
                XCTAssertEqual(rect.height, expectedHeight, accuracy: 0.5, "offset \(offset)", file: file, line: line)
            }
        }

        editor.setSource("")
        assertCaretHeight()
        editor.setSource("{\n  \"nested\": {\n    \"value\": 1\n  }\n}\n")
        assertCaretHeight()
        editor.foldAll()
        assertCaretHeight()
        editor.expandAll()
        assertCaretHeight()
        editor.setSelectedRange(NSRange(location: (editor.string as NSString).length, length: 0))
        editor.insertText("\n", replacementRange: NSRange(location: NSNotFound, length: 0))
        assertCaretHeight()
        XCTAssertEqual(editor.defaultParagraphStyle?.minimumLineHeight, 0)
        XCTAssertEqual(editor.defaultParagraphStyle?.maximumLineHeight, 0)
    }

    @MainActor
    func testLanguageChangeRefreshesNativePlaceholderAndFoldLabelsWithoutResettingFolds() throws {
        let localization = LocalizationStore(language: .simplifiedChinese,
                                              resourceDirectory: testLocaleDirectory, userDefaults: nil)
        let hosting = NSHostingView(rootView: JSONFoldingEditor(text: .constant(sample), command: nil, localization: localization))
        hosting.frame = NSRect(x: 0, y: 0, width: 600, height: 400)
        hosting.layoutSubtreeIfNeeded()
        func findEditor(in view: NSView) -> JSONFoldingTextView? {
            if let editor = view as? JSONFoldingTextView { return editor }
            return view.subviews.lazy.compactMap { findEditor(in: $0) }.first
        }
        let editor = try XCTUnwrap(findEditor(in: hosting))
        editor.foldAll()
        XCTAssertEqual(editor.foldingRuler?.expandLabel, "展开第 %lld 行")
        localization.select(.english)
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        hosting.layoutSubtreeIfNeeded()
        XCTAssertEqual(editor.placeholder, localization.text("jsonFormatter.editor.placeholder"))
        XCTAssertEqual(editor.foldingRuler?.expandLabel, "Unfold line %lld")
        XCTAssertEqual(editor.string, "{ … }")
        XCTAssertEqual(editor.document.source, sample)
    }

    @MainActor
    func testEmptyNativeEditorFillsViewportAfterSwiftUILayout() throws {
        let scroll = JSONFoldingScrollView.make(frame: .zero)
        let editor = try XCTUnwrap(scroll.documentView as? JSONFoldingTextView)
        scroll.frame = NSRect(x: 0, y: 0, width: 600, height: 400)
        scroll.tile()
        editor.setSource("")
        XCTAssertGreaterThanOrEqual(editor.frame.height, scroll.contentSize.height)
        XCTAssertTrue(editor.isEditable)
        XCTAssertTrue(editor.isSelectable)
        XCTAssertTrue(editor.bounds.contains(NSPoint(x: 200, y: 350)))
        scroll.frame.size.height = 700
        scroll.tile()
        XCTAssertGreaterThanOrEqual(editor.frame.height, scroll.contentSize.height)
    }

    @MainActor
    func testGutterButtonsExposeSourceLinesAndStayAlignedWhenFoldedAndScrolled() throws {
        let scroll = JSONFoldingScrollView.make(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let editor = try XCTUnwrap(scroll.documentView as? JSONFoldingTextView)
        let ruler = try XCTUnwrap(scroll.verticalRulerView as? JSONFoldingRulerView)
        ruler.foldLabel = "Fold line %lld"
        ruler.expandLabel = "Unfold line %lld"
        editor.setSource(sample)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 600, pixelsHigh: 400,
                                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = context
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            scroll.appearance = NSAppearance(named: appearance)
            ruler.drawHashMarksAndLabels(in: ruler.bounds)
            let buttons = try XCTUnwrap(ruler.accessibilityChildren() as? [NSButton])
            XCTAssertEqual(buttons.count, 5)
            XCTAssertEqual(buttons.map { $0.accessibilityLabel() }, ["Fold line 1", "Fold line 2", "Fold line 6", "Fold line 7", "Fold line 8"])
            for button in buttons {
                XCTAssertGreaterThanOrEqual(button.frame.width, 30)
                XCTAssertGreaterThanOrEqual(button.frame.height, 30)
            }
            for (previous, next) in zip(buttons, buttons.dropFirst()) {
                XCTAssertLessThanOrEqual(previous.frame.maxY, next.frame.minY + 0.5,
                                         "Adjacent folding targets must not overlap")
            }
        }
        (ruler.accessibilityChildren()?.first as? NSButton)?.performClick(nil)
        XCTAssertEqual(editor.string, "{ … }")
        ruler.drawHashMarksAndLabels(in: ruler.bounds)
        XCTAssertEqual(ruler.accessibilityChildren()?.count, 1)
        XCTAssertEqual((ruler.accessibilityChildren()?.first as? NSButton)?.accessibilityLabel(), "Unfold line 1")
        editor.expandAll()
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 150))
        ruler.drawHashMarksAndLabels(in: ruler.bounds)
        let scrolledButtons = try XCTUnwrap(ruler.accessibilityChildren() as? [NSButton])
        XCTAssertFalse(scrolledButtons.contains { $0.tag == 0 })
        XCTAssertTrue(scrolledButtons.allSatisfy { $0.frame.minY >= 0 })
    }

    @MainActor
    func testNativeFoldingChangesOnlyDisplayAndCopiesCompleteSourceToIsolatedPasteboard() {
        let editor = JSONFoldingTextView.make(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        var changes: [String] = []
        editor.onSourceChange = { changes.append($0) }
        editor.setSource(sample)
        editor.foldAll()
        XCTAssertEqual(editor.string, "{ … }")
        XCTAssertEqual(editor.document.source, sample)
        XCTAssertTrue(changes.isEmpty)
        let pasteboard = NSPasteboard(name: .init("MacGadgetsTests.JSONFolding.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        editor.selectAll(nil)
        XCTAssertTrue(editor.writeSelection(to: pasteboard, type: .string))
        XCTAssertEqual(pasteboard.string(forType: .string), sample)
        editor.expandAll()
        XCTAssertEqual(editor.string, sample)
        XCTAssertTrue(changes.isEmpty)
    }

    @MainActor
    func testNativeInsertionAfterFoldedObjectPreservesHiddenJSONAndUndoRedo() throws {
        let editor = JSONFoldingTextView.make(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        editor.setSource(sample)
        editor.foldAll()
        editor.setSelectedRange(NSRange(location: (editor.string as NSString).length, length: 0))
        let undo = try XCTUnwrap(editor.undoManager)
        undo.groupsByEvent = false
        undo.beginUndoGrouping()
        editor.insertText("\n", replacementRange: NSRange(location: NSNotFound, length: 0))
        undo.endUndoGrouping()
        XCTAssertEqual(editor.document.source, sample + "\n")
        XCTAssertTrue(editor.document.collapsed.isEmpty)
        editor.foldAll()
        XCTAssertTrue(undo.canUndo)
        undo.undo()
        XCTAssertEqual(editor.string, sample)
        XCTAssertEqual(editor.document.source, sample)
        editor.foldAll()
        undo.redo()
        XCTAssertEqual(editor.document.source, sample + "\n")
    }

    @MainActor
    func testNativeReplacementAcrossFoldedSelectionUsesFullSourceRange() {
        let editor = JSONFoldingTextView.make(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        editor.setSource(sample)
        let profile = editor.document.regions[1]
        editor.toggleFold(at: profile.openingOffset)
        let span = editor.document.projection.spans[0]
        editor.insertText("\"replaced\"", replacementRange: NSRange(location: span.displayRange.location - 1, length: span.displayRange.length + 2))
        let expected = (sample as NSString).replacingCharacters(in: NSRange(location: profile.openingOffset, length: profile.closingOffset - profile.openingOffset + 1), with: "\"replaced\"")
        XCTAssertEqual(editor.document.source, expected)
        XCTAssertNoThrow(try JSONService.format(editor.document.source))
    }

    @MainActor
    func testNativeDeletionUnfoldsBeforeApplyingCommand() {
        let editor = JSONFoldingTextView.make(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        editor.setSource(sample)
        editor.foldAll()
        editor.setSelectedRange(NSRange(location: 5, length: 0))
        editor.doCommand(by: #selector(NSTextView.deleteBackward(_:)))
        XCTAssertEqual(editor.document.source, String(sample.dropLast()))
        XCTAssertTrue(editor.document.collapsed.isEmpty)
    }

    @MainActor
    func testNativeIMECompositionPreservesMarkedRangeAndDoesNotFoldMidComposition() {
        let editor = JSONFoldingTextView.make(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        editor.setSource(sample)
        editor.foldAll()
        editor.setSelectedRange(NSRange(location: 5, length: 0))
        let automatic = NSRange(location: NSNotFound, length: 0)
        editor.setMarkedText("zhong", selectedRange: NSRange(location: 5, length: 0), replacementRange: automatic)
        XCTAssertTrue(editor.hasMarkedText())
        editor.foldAll()
        XCTAssertTrue(editor.document.collapsed.isEmpty)
        editor.setMarkedText("zhongwen", selectedRange: NSRange(location: 8, length: 0), replacementRange: automatic)
        editor.insertText("中文", replacementRange: automatic)
        XCTAssertFalse(editor.hasMarkedText())
        XCTAssertEqual(editor.document.source, sample + "中文")
    }
}
