import Foundation

enum ToolKind: String, CaseIterable, Identifiable, Hashable {
    case clipboardHistory
    case pdfMerge
    case imageStitch
    case imagePDFConversion
    case jsonDiff
    case jsonFormatter
    case chineseConversion

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .clipboardHistory: "tool.clipboard.title"
        case .pdfMerge: "tool.pdfMerge.title"
        case .imageStitch: "tool.imageStitch.title"
        case .imagePDFConversion: "tool.imagePDF.title"
        case .jsonDiff: "tool.jsonDiff.title"
        case .jsonFormatter: "tool.jsonFormatter.title"
        case .chineseConversion: "tool.chineseConversion.title"
        }
    }

    var subtitleKey: String {
        switch self {
        case .clipboardHistory: "tool.clipboard.subtitle"
        case .pdfMerge: "tool.pdfMerge.subtitle"
        case .imageStitch: "tool.imageStitch.subtitle"
        case .imagePDFConversion: "tool.imagePDF.subtitle"
        case .jsonDiff: "tool.jsonDiff.subtitle"
        case .jsonFormatter: "tool.jsonFormatter.subtitle"
        case .chineseConversion: "tool.chineseConversion.subtitle"
        }
    }

    var systemImage: String {
        switch self {
        case .clipboardHistory: "clipboard"
        case .pdfMerge: "doc.on.doc"
        case .imageStitch: "rectangle.3.group"
        case .imagePDFConversion: "photo.on.rectangle.angled"
        case .jsonDiff: "arrow.left.arrow.right"
        case .jsonFormatter: "curlybraces"
        case .chineseConversion: "character.book.closed"
        }
    }

    var pinyinSortKey: String {
        switch self {
        case .clipboardHistory: "jian tie ban li shi"
        case .pdfMerge: "duo pdf wen jian he bing"
        case .imageStitch: "duo tu pian pin cheng chang tu"
        case .imagePDFConversion: "duo tu pian yu pdf hu zhuan"
        case .jsonDiff: "json dui bi"
        case .jsonFormatter: "json ge shi hua"
        case .chineseConversion: "zhong wen jian fan zhuan huan"
        }
    }

    var pinyinInitial: String {
        String(pinyinSortKey.prefix(1)).uppercased()
    }

    func matches(searchText: String, localize: (String) -> String) -> Bool {
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return true }
        return localize(titleKey).lowercased().contains(needle)
            || localize(subtitleKey).lowercased().contains(needle)
            || pinyinSortKey.contains(needle)
    }

    static var pinyinSorted: [ToolKind] {
        allCases.sorted {
            $0.pinyinSortKey.localizedStandardCompare($1.pinyinSortKey) == .orderedAscending
        }
    }

    static func filtered(
        matching searchText: String,
        localize: (String) -> String
    ) -> [ToolKind] {
        pinyinSorted.filter { $0.matches(searchText: searchText, localize: localize) }
    }
}
