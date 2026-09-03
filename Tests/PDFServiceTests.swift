import AppKit
import PDFKit
import XCTest
@testable import MacGadgets

final class PDFServiceTests: TemporaryDirectoryTestCase {
    func testPageCountReturnsCountForPDFAndNilForUnreadableFile() throws {
        let pdf = try makePDF(
            pageSizes: [CGSize(width: 80, height: 100), CGSize(width: 90, height: 110)],
            colors: [.red, .blue],
            name: "two-pages.pdf"
        )
        let invalid = try makeUnreadableFile(name: "invalid.pdf")

        XCTAssertEqual(PDFService.pageCount(at: pdf), 2)
        XCTAssertNil(PDFService.pageCount(at: invalid))
        XCTAssertNil(PDFService.pageCount(at: temporaryDirectory.appendingPathComponent("missing.pdf")))
    }

    func testMergePreservesDocumentAndPageOrder() throws {
        let first = try makePDF(
            pageSizes: [CGSize(width: 80, height: 100)],
            colors: [.red],
            name: "first.pdf"
        )
        let second = try makePDF(
            pageSizes: [CGSize(width: 80, height: 100), CGSize(width: 80, height: 100)],
            colors: [.blue, .green],
            name: "second.pdf"
        )
        let output = temporaryDirectory.appendingPathComponent("merged.pdf")

        XCTAssertEqual(try PDFService.merge([first, second], to: output), 3)

        let merged = try XCTUnwrap(PDFDocument(url: output))
        XCTAssertEqual(merged.pageCount, 3)
        try assertPage(merged, at: 0, isDominatedBy: .red)
        try assertPage(merged, at: 1, isDominatedBy: .blue)
        try assertPage(merged, at: 2, isDominatedBy: .green)
    }

    func testMergeRejectsEmptyAndUnreadableDocuments() throws {
        let output = temporaryDirectory.appendingPathComponent("output.pdf")

        XCTAssertThrowsError(try PDFService.merge([], to: output)) { error in
            guard case PDFServiceError.emptyDocument = error else {
                return XCTFail("Expected emptyDocument, got \(error)")
            }
        }

        let invalid = try makeUnreadableFile(name: "broken.pdf")
        XCTAssertThrowsError(try PDFService.merge([invalid], to: output)) { error in
            guard case PDFServiceError.unreadablePDF(let name) = error else {
                return XCTFail("Expected unreadablePDF, got \(error)")
            }
            XCTAssertEqual(name, "broken.pdf")
        }
    }

    func testMergeReportsDestinationWriteFailure() throws {
        let source = try makePDF(
            pageSizes: [CGSize(width: 40, height: 40)],
            colors: [.orange],
            name: "source.pdf"
        )
        let parentFile = temporaryDirectory.appendingPathComponent("not-a-directory")
        try Data("occupied".utf8).write(to: parentFile)
        let destination = parentFile.appendingPathComponent("output.pdf")

        XCTAssertThrowsError(try PDFService.merge([source], to: destination)) { error in
            guard case PDFServiceError.cannotWrite(let name) = error else {
                return XCTFail("Expected cannotWrite, got \(error)")
            }
            XCTAssertEqual(name, "output.pdf")
        }
    }

    func testImagesToPDFSkipsUnreadableFilesAndPreservesImageOrder() throws {
        let red = try makePNG(width: 40, height: 30, color: .red, name: "red.png")
        let invalid = try makeUnreadableFile(name: "invalid.png")
        let blue = try makePNG(width: 20, height: 50, color: .blue, name: "blue.png")
        let output = temporaryDirectory.appendingPathComponent("images.pdf")

        XCTAssertEqual(try PDFService.imagesToPDF([red, invalid, blue], to: output), 2)

        let document = try XCTUnwrap(PDFDocument(url: output))
        XCTAssertEqual(document.pageCount, 2)
        try assertPage(document, at: 0, isDominatedBy: .red)
        try assertPage(document, at: 1, isDominatedBy: .blue)
    }

    func testImagesToPDFRejectsEmptyOrEntirelyUnreadableInput() throws {
        let output = temporaryDirectory.appendingPathComponent("empty.pdf")

        XCTAssertThrowsError(try PDFService.imagesToPDF([], to: output)) { error in
            guard case PDFServiceError.emptyDocument = error else {
                return XCTFail("Expected emptyDocument, got \(error)")
            }
        }

        let invalid = try makeUnreadableFile(name: "invalid.png")
        XCTAssertThrowsError(try PDFService.imagesToPDF([invalid], to: output)) { error in
            guard case PDFServiceError.emptyDocument = error else {
                return XCTFail("Expected emptyDocument, got \(error)")
            }
        }
    }

    func testPDFPageExportCreatesOrderedPaddedPNGNamesAtRequestedScale() throws {
        let pdf = try makePDF(
            pageSizes: [CGSize(width: 40, height: 60), CGSize(width: 30, height: 50)],
            colors: [.red, .blue],
            name: "sample.pdf"
        )
        let outputDirectory = temporaryDirectory.appendingPathComponent("pages", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let files = try PDFService.pdfToPNGFiles(
            pdf,
            outputDirectory: outputDirectory,
            scale: 2
        )

        XCTAssertEqual(files.map(\.lastPathComponent), ["sample-001.png", "sample-002.png"])
        XCTAssertTrue(files.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })

        let firstBitmap = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: files[0])))
        let secondBitmap = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: files[1])))
        XCTAssertEqual(firstBitmap.pixelsWide, 80)
        XCTAssertEqual(firstBitmap.pixelsHigh, 120)
        XCTAssertEqual(secondBitmap.pixelsWide, 60)
        XCTAssertEqual(secondBitmap.pixelsHigh, 100)
    }

    func testPDFPageExportRejectsUnreadableInput() throws {
        let invalid = try makeUnreadableFile(name: "broken.pdf")

        XCTAssertThrowsError(
            try PDFService.pdfToPNGFiles(
                invalid,
                outputDirectory: temporaryDirectory,
                scale: 1
            )
        ) { error in
            guard case PDFServiceError.unreadablePDF(let name) = error else {
                return XCTFail("Expected unreadablePDF, got \(error)")
            }
            XCTAssertEqual(name, "broken.pdf")
        }
    }

    private func assertPage(
        _ document: PDFDocument,
        at index: Int,
        isDominatedBy expectedColor: NSColor,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let page = try XCTUnwrap(document.page(at: index), file: file, line: line)
        let actual = try centerColor(
            of: page.thumbnail(of: NSSize(width: 40, height: 40), for: .mediaBox)
        )
        let expected = try XCTUnwrap(
            expectedColor.usingColorSpace(.deviceRGB),
            file: file,
            line: line
        )

        if expected.redComponent >= expected.greenComponent,
           expected.redComponent >= expected.blueComponent {
            XCTAssertGreaterThan(actual.redComponent, actual.greenComponent, file: file, line: line)
            XCTAssertGreaterThan(actual.redComponent, actual.blueComponent, file: file, line: line)
        } else if expected.greenComponent >= expected.redComponent,
                  expected.greenComponent >= expected.blueComponent {
            XCTAssertGreaterThan(actual.greenComponent, actual.redComponent, file: file, line: line)
            XCTAssertGreaterThan(actual.greenComponent, actual.blueComponent, file: file, line: line)
        } else {
            XCTAssertGreaterThan(actual.blueComponent, actual.redComponent, file: file, line: line)
            XCTAssertGreaterThan(actual.blueComponent, actual.greenComponent, file: file, line: line)
        }
    }
}
