import AppKit
import PDFKit
import XCTest

let testRepositoryRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()

let testLocaleDirectory = testRepositoryRoot
    .appendingPathComponent("locale", isDirectory: true)

class TemporaryDirectoryTestCase: XCTestCase {
    var temporaryDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacGadgetsTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
        try super.tearDownWithError()
    }

    func makeImage(width: Int, height: Int, color: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        color.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        image.unlockFocus()
        return image
    }

    func makePNG(width: Int, height: Int, color: NSColor, name: String) throws -> URL {
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
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            .write(to: url, options: .atomic)
        return url
    }

    func makePDF(
        pageSizes: [CGSize],
        colors: [NSColor],
        name: String
    ) throws -> URL {
        XCTAssertEqual(pageSizes.count, colors.count)
        let document = PDFDocument()

        for index in pageSizes.indices {
            let size = pageSizes[index]
            let image = makeImage(
                width: Int(size.width),
                height: Int(size.height),
                color: colors[index]
            )
            document.insert(try XCTUnwrap(PDFPage(image: image)), at: index)
        }

        let url = temporaryDirectory.appendingPathComponent(name)
        XCTAssertTrue(document.write(to: url))
        return url
    }

    func makeUnreadableFile(name: String = "invalid.dat") throws -> URL {
        let url = temporaryDirectory.appendingPathComponent(name)
        try Data("not a supported file".utf8).write(to: url, options: .atomic)
        return url
    }

    func centerColor(of image: NSImage) throws -> NSColor {
        let data = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: data))
        return try XCTUnwrap(
            bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2)
        ).usingColorSpace(.deviceRGB) ?? .clear
    }
}
