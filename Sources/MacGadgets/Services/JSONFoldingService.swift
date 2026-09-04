import Foundation

struct JSONFoldRegion: Equatable {
    let openingOffset: Int
    let closingOffset: Int
    let line: Int

    var interior: NSRange {
        NSRange(location: openingOffset + 1, length: closingOffset - openingOffset - 1)
    }
}

enum JSONFoldingService {
    static func regions(in text: String) -> [JSONFoldRegion] {
        let units = Array(text.utf16)
        var stack: [(offset: Int, bracket: UInt16, line: Int)] = []
        var result: [JSONFoldRegion] = []
        var inString = false
        var escaped = false
        var line = 1
        for (index, unit) in units.enumerated() {
            if unit == 10 || (unit == 13 && (index + 1 == units.count || units[index + 1] != 10)) { line += 1 }
            if inString {
                if escaped { escaped = false }
                else if unit == 92 { escaped = true }
                else if unit == 34 { inString = false }
                continue
            }
            if unit == 34 { inString = true; continue }
            if unit == 123 || unit == 91 {
                stack.append((index, unit, line))
            } else if unit == 125 || unit == 93 {
                guard let opening = stack.last,
                      (opening.bracket == 123 && unit == 125) || (opening.bracket == 91 && unit == 93) else {
                    stack.removeAll()
                    continue
                }
                stack.removeLast()
                // Empty containers have nothing to hide. Braces in strings are ignored.
                let interior = units[(opening.offset + 1)..<index]
                if interior.contains(where: { ![9, 10, 13, 32].contains($0) }) {
                    result.append(JSONFoldRegion(openingOffset: opening.offset, closingOffset: index, line: opening.line))
                }
            }
        }
        return result.sorted { $0.openingOffset < $1.openingOffset }
    }
}

struct JSONFoldSpan {
    let region: JSONFoldRegion
    let displayRange: NSRange
}

struct JSONFoldLine {
    let displayOffset: Int
    let sourceLine: Int
    let region: JSONFoldRegion?
}

struct JSONFoldProjection {
    let source: String
    let text: String
    let spans: [JSONFoldSpan]
    let lines: [JSONFoldLine]

    init(source: String, regions: [JSONFoldRegion], collapsed: Set<Int>) {
        let original = source as NSString
        var rendered = ""
        var spans: [JSONFoldSpan] = []
        var cursor = 0
        for region in regions where collapsed.contains(region.openingOffset) {
            guard region.interior.location >= cursor else { continue }
            rendered += original.substring(with: NSRange(location: cursor, length: region.interior.location - cursor))
            spans.append(JSONFoldSpan(region: region, displayRange: NSRange(location: (rendered as NSString).length, length: 3)))
            rendered += " … "
            cursor = NSMaxRange(region.interior)
        }
        rendered += original.substring(from: cursor)
        self.source = source
        text = rendered
        self.spans = spans

        let display = rendered as NSString
        var lines: [JSONFoldLine] = []
        var displayOffset = 0
        var sourceLine = 1
        var originalOffset = 0
        var regionIndex = 0
        while displayOffset < display.length {
            let range = display.lineRange(for: NSRange(location: displayOffset, length: 0))
            let sourceOffset = Self.sourceOffset(displayOffset, spans: spans, upper: false)
            while originalOffset < sourceOffset {
                let character = original.character(at: originalOffset)
                if character == 10 || (character == 13 && (originalOffset + 1 == original.length || original.character(at: originalOffset + 1) != 10)) { sourceLine += 1 }
                originalOffset += 1
            }
            while regionIndex < regions.count && regions[regionIndex].openingOffset < sourceOffset { regionIndex += 1 }
            let region = regions.indices.contains(regionIndex) ? regions[regionIndex] : nil
            let end = Self.sourceOffset(NSMaxRange(range), spans: spans, upper: false)
            lines.append(JSONFoldLine(displayOffset: displayOffset, sourceLine: sourceLine,
                                      region: region.flatMap { $0.openingOffset < end ? $0 : nil }))
            displayOffset = NSMaxRange(range)
        }
        self.lines = lines
    }

    func sourceRange(for displayedRange: NSRange) -> NSRange {
        let length = (text as NSString).length
        let start = min(max(0, displayedRange.location), length)
        let end = start + min(max(0, displayedRange.length), length - start)
        let lower = Self.sourceOffset(start, spans: spans, upper: false)
        let upper = Self.sourceOffset(end, spans: spans, upper: end > start)
        return NSRange(location: lower, length: max(0, upper - lower))
    }

    func displayedRange(for sourceRange: NSRange) -> NSRange {
        func offset(_ sourceOffset: Int, upper: Bool) -> Int {
            var removed = 0
            for span in spans {
                if sourceOffset <= span.region.interior.location { break }
                if sourceOffset < NSMaxRange(span.region.interior) {
                    return upper ? NSMaxRange(span.displayRange) : span.displayRange.location
                }
                removed += span.region.interior.length - span.displayRange.length
            }
            return sourceOffset - removed
        }
        let length = (source as NSString).length
        let start = min(max(0, sourceRange.location), length)
        let end = start + min(max(0, sourceRange.length), length - start)
        let lower = offset(start, upper: false)
        let upper = offset(end, upper: end > start)
        return NSRange(location: lower, length: max(0, upper - lower))
    }

    func copiedText(in range: NSRange) -> String {
        (source as NSString).substring(with: sourceRange(for: range))
    }

    private static func sourceOffset(_ offset: Int, spans: [JSONFoldSpan], upper: Bool) -> Int {
        var removed = 0
        for span in spans {
            if offset <= span.displayRange.location { break }
            if offset < NSMaxRange(span.displayRange) {
                return upper ? NSMaxRange(span.region.interior) : span.region.interior.location
            }
            removed += span.region.interior.length - span.displayRange.length
        }
        return offset + removed
    }
}

struct JSONFoldingDocument {
    private(set) var source: String
    private(set) var regions: [JSONFoldRegion]
    private(set) var collapsed: Set<Int> = []
    private(set) var projection: JSONFoldProjection

    init(source: String = "") {
        self.source = source
        regions = JSONFoldingService.regions(in: source)
        projection = JSONFoldProjection(source: source, regions: regions, collapsed: [])
    }

    mutating func setSource(_ text: String) { self = Self(source: text) }

    mutating func toggle(_ openingOffset: Int) {
        guard regions.contains(where: { $0.openingOffset == openingOffset }) else { return }
        if collapsed.contains(openingOffset) { collapsed.remove(openingOffset) }
        else { collapsed.insert(openingOffset) }
        rebuild()
    }

    mutating func foldAll() {
        collapsed = Set(regions.map(\.openingOffset))
        rebuild()
    }

    mutating func expandAll() { collapsed.removeAll(); rebuild() }

    private mutating func rebuild() {
        projection = JSONFoldProjection(source: source, regions: regions, collapsed: collapsed)
    }
}
