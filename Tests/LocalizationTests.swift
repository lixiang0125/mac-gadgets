import Foundation
import XCTest
@testable import MacGadgets

final class LocalizationTests: TemporaryDirectoryTestCase {
    func testBothLanguageFilesLoadWithTheSameCompleteKeySet() throws {
        let catalog = try LocalizationCatalog(directoryURL: testLocaleDirectory)

        XCTAssertGreaterThan(catalog.keys.count, 100)
        for language in AppLanguage.allCases {
            for key in catalog.keys {
                let value = catalog.text(key, language: language)
                XCTAssertFalse(value.isEmpty, "\(language.rawValue) is empty for \(key)")
                XCTAssertNotEqual(value, key, "\(language.rawValue) is missing \(key)")
            }
        }

        for key in catalog.keys {
            XCTAssertEqual(
                formatTokens(in: catalog.text(key, language: .simplifiedChinese)),
                formatTokens(in: catalog.text(key, language: .english)),
                "Format arguments differ for \(key)"
            )
        }
    }

    func testProductionLocalizationKeysAndCatalogStayInSync() throws {
        let catalog = try LocalizationCatalog(directoryURL: testLocaleDirectory)
        let sourcesDirectory = testRepositoryRoot
            .appendingPathComponent("Sources/MacGadgets", isDirectory: true)
        let keyPattern = try NSRegularExpression(
            pattern: #"\"((?:app|appearance|language|common|tool|chinese|clipboard|imagePDF|imageStitch|jsonFormatter|jsonDiff|pdfMerge|error)\.[A-Za-z0-9.-]+)\""#
        )
        let enumerator = try XCTUnwrap(
            FileManager.default.enumerator(
                at: sourcesDirectory,
                includingPropertiesForKeys: nil
            )
        )
        var referencedKeys: Set<String> = []

        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let source = try String(contentsOf: url, encoding: .utf8)
            let range = NSRange(source.startIndex..., in: source)
            for match in keyPattern.matches(in: source, range: range) {
                guard let keyRange = Range(match.range(at: 1), in: source) else { continue }
                referencedKeys.insert(String(source[keyRange]))
            }
        }

        XCTAssertEqual(
            referencedKeys.subtracting(catalog.keys),
            [],
            "Production code references missing localization keys"
        )
        XCTAssertEqual(
            catalog.keys.subtracting(referencedKeys),
            [],
            "Locale files contain unused localization keys"
        )
    }

    func testCatalogFormatsArgumentsAndFallsBackToTheKey() throws {
        let catalog = try LocalizationCatalog(directoryURL: testLocaleDirectory)

        XCTAssertEqual(
            catalog.text(
                "app.toolCount",
                language: .simplifiedChinese,
                arguments: [Int64(7)]
            ),
            "7 个本地工具"
        )
        XCTAssertEqual(
            catalog.text(
                "app.toolCount",
                language: .english,
                arguments: [Int64(7)]
            ),
            "7 local tools"
        )
        XCTAssertEqual(catalog.text("missing.key", language: .english), "missing.key")
        XCTAssertEqual(catalog.text("", language: .english), "")
    }

    @MainActor
    func testLanguageSelectionPersistsOnlyToInjectedDefaults() throws {
        let suiteName = "MacGadgets.LocalizationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = LocalizationStore(
            resourceDirectory: testLocaleDirectory,
            userDefaults: defaults
        )
        XCTAssertEqual(store.language, .simplifiedChinese)
        XCTAssertEqual(store.text("clipboard.copy"), "复制")

        store.select(.english)

        XCTAssertEqual(store.language, .english)
        XCTAssertEqual(store.text("clipboard.copy"), "Copy")
        XCTAssertEqual(
            defaults.string(forKey: LocalizationStore.preferenceKey),
            AppLanguage.english.rawValue
        )

        let restored = LocalizationStore(
            resourceDirectory: testLocaleDirectory,
            userDefaults: defaults
        )
        XCTAssertEqual(restored.language, .english)
    }

    @MainActor
    func testAppErrorsAreLocalizedForBothLanguages() {
        let chinese = LocalizationStore(
            language: .simplifiedChinese,
            resourceDirectory: testLocaleDirectory,
            userDefaults: nil
        )
        let english = LocalizationStore(
            language: .english,
            resourceDirectory: testLocaleDirectory,
            userDefaults: nil
        )

        XCTAssertEqual(chinese.errorMessage(for: JSONServiceError.emptyInput), "JSON 内容为空")
        XCTAssertEqual(english.errorMessage(for: JSONServiceError.emptyInput), "JSON content is empty")
        XCTAssertEqual(
            chinese.errorMessage(for: PDFServiceError.cannotRenderPage(3)),
            "无法渲染第 3 页"
        )
        XCTAssertEqual(
            english.errorMessage(for: ImageStitchError.canvasTooLarge(width: 60_000, height: 2)),
            "The stitched image is too large (60,000 × 2). Use fewer or smaller images."
        )
    }

    func testCatalogRejectsMissingLanguageFiles() {
        XCTAssertThrowsError(try LocalizationCatalog(directoryURL: temporaryDirectory)) { error in
            guard case LocalizationCatalogError.missingResource("zh-CN.json") = error else {
                return XCTFail("Expected missing zh-CN.json, got \(error)")
            }
        }
    }

    private func formatTokens(in template: String) -> [String] {
        let pattern = try! NSRegularExpression(pattern: #"%(?:lld|@)"#)
        let range = NSRange(template.startIndex..., in: template)
        return pattern.matches(in: template, range: range).compactMap {
            guard let tokenRange = Range($0.range, in: template) else { return nil }
            return String(template[tokenRange])
        }
    }
}
