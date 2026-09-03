import Foundation
import XCTest

final class DocumentationTests: XCTestCase {
    func testChineseAndEnglishReadmesKeepMatchingStructureAndCommands() throws {
        let chinese = try String(
            contentsOf: testRepositoryRoot.appendingPathComponent("README.md"),
            encoding: .utf8
        )
        let english = try String(
            contentsOf: testRepositoryRoot.appendingPathComponent("README.en.md"),
            encoding: .utf8
        )

        for readme in [chinese, english] {
            XCTAssertTrue(readme.contains("[中文](README.md) | [English](README.en.md)"))
            XCTAssertTrue(readme.contains("release/Mac-Gadgets-latest.dmg"))
            XCTAssertTrue(readme.contains("locale/zh-CN.json"))
            XCTAssertTrue(readme.contains("locale/en.json"))
        }

        XCTAssertEqual(markdownLines(in: chinese, prefix: "## ").count, 9)
        XCTAssertEqual(
            markdownLines(in: chinese, prefix: "## ").count,
            markdownLines(in: english, prefix: "## ").count
        )
        XCTAssertEqual(
            markdownLines(in: chinese, prefix: "- ").count,
            markdownLines(in: english, prefix: "- ").count
        )
        XCTAssertEqual(shellCommands(in: chinese), shellCommands(in: english))
    }

    private func markdownLines(in markdown: String, prefix: String) -> [String] {
        markdown.split(separator: "\n").map(String.init).filter { $0.hasPrefix(prefix) }
    }

    private func shellCommands(in markdown: String) -> [String] {
        markdown.split(separator: "\n").map(String.init).filter {
            $0.hasPrefix("swift ")
                || $0.hasPrefix("./scripts/")
                || $0.hasPrefix("open ")
        }
    }
}
