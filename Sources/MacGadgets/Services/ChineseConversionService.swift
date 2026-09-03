import Foundation

enum ChineseConversionDirection: String, CaseIterable, Identifiable {
    case simplifiedToTraditional
    case traditionalToSimplified

    var id: String { rawValue }

    var title: String {
        switch self {
        case .simplifiedToTraditional: "简体 → 繁体"
        case .traditionalToSimplified: "繁体 → 简体"
        }
    }

    fileprivate var transform: StringTransform {
        switch self {
        case .simplifiedToTraditional:
            StringTransform("Simplified-Traditional")
        case .traditionalToSimplified:
            StringTransform("Traditional-Simplified")
        }
    }
}

enum ChineseConversionService {
    static func convert(_ text: String, direction: ChineseConversionDirection) -> String {
        text.applyingTransform(direction.transform, reverse: false) ?? text
    }

    static func readTextFile(at url: URL) throws -> String {
        var detectedEncoding = String.Encoding.utf8
        return try String(contentsOf: url, usedEncoding: &detectedEncoding)
    }

    static func writeTextFile(_ text: String, to url: URL) throws {
        try text.write(to: url, atomically: true, encoding: .utf8)
    }
}
