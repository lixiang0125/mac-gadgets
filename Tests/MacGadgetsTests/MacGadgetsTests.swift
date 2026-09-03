import AppKit
import PDFKit
import XCTest
@testable import MacGadgets

final class MacGadgetsTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacGadgetsTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
    }

    func testToolListUsesPinyinOrder() {
        let keys = ToolKind.pinyinSorted.map(\.pinyinSortKey)
        XCTAssertEqual(keys, keys.sorted())
        XCTAssertEqual(Set(ToolKind.pinyinSorted.map(\.pinyinInitial)), Set(["D", "J", "Z"]))
    }

    func testChineseConversionInBothDirections() {
        let traditional = ChineseConversionService.convert(
            "汉语转换与软件开发",
            direction: .simplifiedToTraditional
        )
        XCTAssertEqual(traditional, "漢語轉換與軟件開發")

        let simplified = ChineseConversionService.convert(
            "漢語轉換與軟件開發",
            direction: .traditionalToSimplified
        )
        XCTAssertEqual(simplified, "汉语转换与软件开发")
    }

    func testTextFileRoundTrip() throws {
        let url = temporaryDirectory.appendingPathComponent("sample.txt")
        try ChineseConversionService.writeTextFile("繁體中文", to: url)
        XCTAssertEqual(try ChineseConversionService.readTextFile(at: url), "繁體中文")
    }

    func testJSONFormattingAndValidation() throws {
        let formatted = try JSONService.format("{\"b\":2,\"a\":[true,null]}", sortedKeys: true)
        XCTAssertTrue(formatted.contains("\"a\" : ["))
        XCTAssertLessThan(
            try XCTUnwrap(formatted.range(of: "\"a\"")) .lowerBound,
            try XCTUnwrap(formatted.range(of: "\"b\"")) .lowerBound
        )
        XCTAssertThrowsError(try JSONService.format("{bad json}"))
    }

    func testJSONDiffHighlightsModifiedAddedAndRemovedLines() {
        let modified = JSONDiffService.compare(
            left: "{\n  \"name\" : \"old\"\n}",
            right: "{\n  \"name\" : \"new\"\n}"
        )
        XCTAssertEqual(modified.modifiedCount, 1)
        XCTAssertTrue(modified.rows.contains { $0.kind == .modified })

        let structural = JSONDiffService.compare(
            left: "one\ntwo\nthree",
            right: "one\nthree\nfour"
        )
        XCTAssertFalse(structural.isIdentical)
        XCTAssertTrue(structural.rows.contains { $0.kind != .unchanged })
    }

    func testPDFMergeAndPageExport() throws {
        let firstPDF = temporaryDirectory.appendingPathComponent("first.pdf")
        let secondPDF = temporaryDirectory.appendingPathComponent("second.pdf")
        try makePDF(pageCount: 1, at: firstPDF)
        try makePDF(pageCount: 2, at: secondPDF)

        let mergedPDF = temporaryDirectory.appendingPathComponent("merged.pdf")
        XCTAssertEqual(try PDFService.merge([firstPDF, secondPDF], to: mergedPDF), 3)
        XCTAssertEqual(PDFDocument(url: mergedPDF)?.pageCount, 3)

        let outputDirectory = temporaryDirectory.appendingPathComponent("pages", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let images = try PDFService.pdfToPNGFiles(mergedPDF, outputDirectory: outputDirectory, scale: 1)
        XCTAssertEqual(images.count, 3)
        XCTAssertTrue(images.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
    }

    func testImagesToPDF() throws {
        let image1 = try makePNG(width: 40, height: 30, color: .red, name: "red.png")
        let image2 = try makePNG(width: 20, height: 50, color: .blue, name: "blue.png")
        let output = temporaryDirectory.appendingPathComponent("images.pdf")

        XCTAssertEqual(try PDFService.imagesToPDF([image1, image2], to: output), 2)
        XCTAssertEqual(PDFDocument(url: output)?.pageCount, 2)
    }

    func testImageStitchVerticalAndHorizontal() throws {
        let image1 = try makePNG(width: 40, height: 30, color: .red, name: "first.png")
        let image2 = try makePNG(width: 20, height: 50, color: .blue, name: "second.png")

        let vertical = try ImageStitchService.stitch([image1, image2], direction: .vertical)
        XCTAssertEqual(vertical.pixelSize, CGSize(width: 40, height: 80))
        XCTAssertNotNil(NSImage(data: vertical.data))

        let horizontal = try ImageStitchService.stitch([image1, image2], direction: .horizontal)
        XCTAssertEqual(horizontal.pixelSize, CGSize(width: 60, height: 50))
        XCTAssertNotNil(NSImage(data: horizontal.data))
    }

    private func makePDF(pageCount: Int, at url: URL) throws {
        let document = PDFDocument()
        for index in 0..<pageCount {
            let image = makeImage(width: 120, height: 160, color: index.isMultiple(of: 2) ? .orange : .purple)
            document.insert(try XCTUnwrap(PDFPage(image: image)), at: index)
        }
        XCTAssertTrue(document.write(to: url))
    }

    private func makePNG(width: Int, height: Int, color: NSColor, name: String) throws -> URL {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ))
        let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        color.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        NSGraphicsContext.restoreGraphicsState()

        let url = temporaryDirectory.appendingPathComponent(name)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: url)
        return url
    }

    private func makeImage(width: Int, height: Int, color: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        color.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        image.unlockFocus()
        return image
    }
}
