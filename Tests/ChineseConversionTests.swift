import Foundation
import XCTest
@testable import MacGadgets

final class ChineseConversionTests: TemporaryDirectoryTestCase {
    func testConversionWorksInBothDirectionsAndPreservesOtherContent() {
        let source = "汉语转换与软件开发 Mac Gadgets 123"
        let traditional = ChineseConversionService.convert(
            source,
            direction: .simplifiedToTraditional
        )

        XCTAssertEqual(traditional, "漢語轉換與軟件開發 Mac Gadgets 123")
        XCTAssertEqual(
            ChineseConversionService.convert(
                traditional,
                direction: .traditionalToSimplified
            ),
            source
        )
        XCTAssertEqual(
            ChineseConversionService.convert("", direction: .simplifiedToTraditional),
            ""
        )
    }

    func testDirectionMetadataIsCompleteAndStable() {
        XCTAssertEqual(ChineseConversionDirection.allCases.count, 2)
        XCTAssertEqual(
            ChineseConversionDirection.simplifiedToTraditional.titleKey,
            "chinese.direction.simplifiedToTraditional"
        )
        XCTAssertEqual(
            ChineseConversionDirection.traditionalToSimplified.titleKey,
            "chinese.direction.traditionalToSimplified"
        )
        XCTAssertEqual(
            Set(ChineseConversionDirection.allCases.map(\.id)).count,
            ChineseConversionDirection.allCases.count
        )
    }

    func testUTF8TextFileRoundTripDoesNotLeaveTemporaryData() throws {
        let url = temporaryDirectory.appendingPathComponent("sample.txt")
        let text = "繁體中文\n第二行\nEmoji: 🧰"

        try ChineseConversionService.writeTextFile(text, to: url)

        XCTAssertEqual(try ChineseConversionService.readTextFile(at: url), text)
        XCTAssertEqual(try Data(contentsOf: url), text.data(using: .utf8))
        XCTAssertTrue(url.path.hasPrefix(temporaryDirectory.path))
    }

    func testReadingDetectsUTF16Text() throws {
        let url = temporaryDirectory.appendingPathComponent("utf16.txt")
        let text = "简繁轉換"
        try text.write(to: url, atomically: true, encoding: .utf16)

        XCTAssertEqual(try ChineseConversionService.readTextFile(at: url), text)
    }

    func testReadingMissingFileThrows() {
        let url = temporaryDirectory.appendingPathComponent("missing.txt")

        XCTAssertThrowsError(try ChineseConversionService.readTextFile(at: url))
    }
}
