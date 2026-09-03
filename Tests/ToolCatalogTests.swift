import SwiftUI
import XCTest
@testable import MacGadgets

final class ToolCatalogTests: XCTestCase {
    private var catalog: LocalizationCatalog {
        get throws { try LocalizationCatalog(directoryURL: testLocaleDirectory) }
    }

    func testEveryToolHasUniqueStableMetadata() {
        let tools = ToolKind.allCases

        XCTAssertEqual(tools.count, 7)
        XCTAssertEqual(Set(tools.map(\.id)).count, tools.count)
        XCTAssertEqual(Set(tools.map(\.titleKey)).count, tools.count)
        XCTAssertTrue(tools.allSatisfy { !$0.titleKey.isEmpty })
        XCTAssertTrue(tools.allSatisfy { !$0.subtitleKey.isEmpty })
        XCTAssertTrue(tools.allSatisfy { !$0.systemImage.isEmpty })
        XCTAssertTrue(tools.allSatisfy { !$0.pinyinSortKey.isEmpty })
    }

    func testToolListUsesPinyinOrderAndExpectedGroups() {
        let keys = ToolKind.pinyinSorted.map(\.pinyinSortKey)

        XCTAssertEqual(keys, keys.sorted())
        XCTAssertEqual(Set(ToolKind.pinyinSorted.map(\.pinyinInitial)), Set(["D", "J", "Z"]))
        XCTAssertEqual(ToolKind.pinyinSorted.first, .pdfMerge)
        XCTAssertEqual(ToolKind.pinyinSorted.last, .chineseConversion)
    }

    func testToolSearchMatchesBothLanguagesAndPinyin() throws {
        let catalog = try catalog
        let chinese: (String) -> String = {
            catalog.text($0, language: .simplifiedChinese)
        }
        let english: (String) -> String = {
            catalog.text($0, language: .english)
        }

        XCTAssertEqual(ToolKind.filtered(matching: "剪贴板", localize: chinese), [.clipboardHistory])
        XCTAssertEqual(ToolKind.filtered(matching: "  jian tie  ", localize: chinese), [.clipboardHistory])
        XCTAssertEqual(ToolKind.filtered(matching: "最近 100", localize: chinese), [.clipboardHistory])
        XCTAssertEqual(ToolKind.filtered(matching: "clipboard", localize: english), [.clipboardHistory])
        XCTAssertEqual(ToolKind.filtered(matching: "JSON", localize: english), [.jsonDiff, .jsonFormatter])
        XCTAssertEqual(ToolKind.filtered(matching: "不存在的工具", localize: chinese), [])
        XCTAssertEqual(
            ToolKind.filtered(matching: " \n", localize: english),
            ToolKind.pinyinSorted
        )
    }

    func testAppearanceMetadataAndColorSchemeMappingIsComplete() {
        XCTAssertEqual(AppAppearance.allCases, [.system, .light, .dark])
        XCTAssertNil(AppAppearance.system.colorScheme)
        XCTAssertEqual(AppAppearance.light.colorScheme, ColorScheme.light)
        XCTAssertEqual(AppAppearance.dark.colorScheme, ColorScheme.dark)
        XCTAssertTrue(AppAppearance.allCases.allSatisfy { !$0.titleKey.isEmpty })
        XCTAssertTrue(AppAppearance.allCases.allSatisfy { !$0.systemImage.isEmpty })
    }
}
