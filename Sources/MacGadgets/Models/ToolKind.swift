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

    var title: String {
        switch self {
        case .clipboardHistory: "剪贴板历史"
        case .pdfMerge: "多 PDF 文件合并"
        case .imageStitch: "多图片拼成长图"
        case .imagePDFConversion: "多图片与 PDF 互转"
        case .jsonDiff: "JSON 对比"
        case .jsonFormatter: "JSON 格式化"
        case .chineseConversion: "中文简繁转换"
        }
    }

    var subtitle: String {
        switch self {
        case .clipboardHistory: "自动保存最近 100 条文本"
        case .pdfMerge: "合并并调整 PDF 顺序"
        case .imageStitch: "横向或竖向拼接图片"
        case .imagePDFConversion: "图片生成 PDF，PDF 按页导图"
        case .jsonDiff: "逐行高亮两个 JSON 的差异"
        case .jsonFormatter: "校验并美化 JSON 文本"
        case .chineseConversion: "文本与 TXT 文件互转"
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

    static var pinyinSorted: [ToolKind] {
        allCases.sorted {
            $0.pinyinSortKey.localizedStandardCompare($1.pinyinSortKey) == .orderedAscending
        }
    }
}
