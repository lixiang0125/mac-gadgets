import Foundation
import XCTest
@testable import MacGadgets

final class JSONServiceTests: XCTestCase {
    func testFormattingPrettyPrintsObjectsAndOptionallySortsKeys() throws {
        let formatted = try JSONService.format(
            "{\"z\":2,\"a\":[true,null]}",
            sortedKeys: true
        )

        XCTAssertTrue(formatted.contains("\n"))
        XCTAssertTrue(formatted.contains("\"a\" : ["))
        XCTAssertLessThan(
            try XCTUnwrap(formatted.range(of: "\"a\"")) .lowerBound,
            try XCTUnwrap(formatted.range(of: "\"z\"")) .lowerBound
        )
    }

    func testFormattingSupportsArraysFragmentsUnicodeAndUnescapedSlashes() throws {
        XCTAssertEqual(try JSONService.format("true"), "true")
        XCTAssertEqual(try JSONService.format("42"), "42")

        let array = try JSONService.format("[\"中文\",1]")
        XCTAssertTrue(array.contains("中文"))

        let url = try JSONService.format(#"{"url":"https:\/\/example.com\/a"}"#)
        XCTAssertTrue(url.contains("https://example.com/a"))
        XCTAssertFalse(url.contains(#"https:\/\/"#))
    }

    func testFormattingRejectsEmptyAndMalformedInput() {
        XCTAssertThrowsError(try JSONService.format(" \n\t")) { error in
            guard case JSONServiceError.emptyInput = error else {
                return XCTFail("Expected emptyInput, got \(error)")
            }
            XCTAssertEqual(error.localizedDescription, "error.json.emptyInput")
        }

        XCTAssertThrowsError(try JSONService.format("{bad json}"))
    }

    func testDiffReportsIdenticalContentIncludingBlankLines() {
        let result = JSONDiffService.compare(
            left: "one\n\ntwo\n",
            right: "one\n\ntwo\n"
        )

        XCTAssertTrue(result.isIdentical)
        XCTAssertEqual(result.rows.count, 4)
        XCTAssertTrue(result.rows.allSatisfy { $0.kind == .unchanged })
        XCTAssertEqual(result.rows.map(\.id), Array(0..<4))
    }

    func testDiffReportsAddedRemovedAndModifiedLinesWithLineNumbers() throws {
        let added = JSONDiffService.compare(left: "one\ntwo", right: "one\ntwo\nthree")
        XCTAssertEqual(added.addedCount, 1)
        XCTAssertEqual(added.removedCount, 0)
        XCTAssertEqual(added.modifiedCount, 0)
        let addedRow = try XCTUnwrap(added.rows.first { $0.kind == .added })
        XCTAssertNil(addedRow.leftLineNumber)
        XCTAssertEqual(addedRow.rightLineNumber, 3)
        XCTAssertEqual(addedRow.rightText, "three")

        let removed = JSONDiffService.compare(left: "one\ntwo\nthree", right: "one\ntwo")
        XCTAssertEqual(removed.addedCount, 0)
        XCTAssertEqual(removed.removedCount, 1)
        XCTAssertEqual(removed.modifiedCount, 0)
        let removedRow = try XCTUnwrap(removed.rows.first { $0.kind == .removed })
        XCTAssertEqual(removedRow.leftLineNumber, 3)
        XCTAssertNil(removedRow.rightLineNumber)
        XCTAssertEqual(removedRow.leftText, "three")

        let modified = JSONDiffService.compare(
            left: "one\nold\nthree",
            right: "one\nnew\nthree"
        )
        XCTAssertEqual(modified.addedCount, 0)
        XCTAssertEqual(modified.removedCount, 0)
        XCTAssertEqual(modified.modifiedCount, 1)
        let modifiedRow = try XCTUnwrap(modified.rows.first { $0.kind == .modified })
        XCTAssertEqual(modifiedRow.leftLineNumber, 2)
        XCTAssertEqual(modifiedRow.rightLineNumber, 2)
        XCTAssertEqual(modifiedRow.leftText, "old")
        XCTAssertEqual(modifiedRow.rightText, "new")
    }

    func testLargeDiffUsesBoundedFallbackWithoutLosingResultCounts() {
        let leftLines = (0..<2_001).map { "line \($0)" }
        var rightLines = leftLines
        rightLines[1_000] = "changed line"

        let result = JSONDiffService.compare(
            left: leftLines.joined(separator: "\n"),
            right: rightLines.joined(separator: "\n")
        )

        XCTAssertEqual(result.rows.count, 2_001)
        XCTAssertEqual(result.modifiedCount, 1)
        XCTAssertEqual(result.addedCount, 0)
        XCTAssertEqual(result.removedCount, 0)
        XCTAssertEqual(result.rows[1_000].kind, .modified)
    }
}
