import AppKit
import XCTest
@testable import MacGadgets

final class ImageStitchTests: TemporaryDirectoryTestCase {
    func testVerticalAndHorizontalStitchUseExpectedCanvasDimensions() throws {
        let red = try makePNG(width: 40, height: 30, color: .red, name: "red.png")
        let blue = try makePNG(width: 20, height: 50, color: .blue, name: "blue.png")

        let vertical = try ImageStitchService.stitch([red, blue], direction: .vertical)
        XCTAssertEqual(vertical.pixelSize, CGSize(width: 40, height: 80))
        XCTAssertEqual(try XCTUnwrap(NSBitmapImageRep(data: vertical.data)).pixelsWide, 40)
        XCTAssertEqual(try XCTUnwrap(NSBitmapImageRep(data: vertical.data)).pixelsHigh, 80)

        let horizontal = try ImageStitchService.stitch([red, blue], direction: .horizontal)
        XCTAssertEqual(horizontal.pixelSize, CGSize(width: 60, height: 50))
        XCTAssertEqual(try XCTUnwrap(NSBitmapImageRep(data: horizontal.data)).pixelsWide, 60)
        XCTAssertEqual(try XCTUnwrap(NSBitmapImageRep(data: horizontal.data)).pixelsHigh, 50)
    }

    func testStitchPreservesColorsAndTransparentCenteringArea() throws {
        let red = try makePNG(width: 4, height: 2, color: .red, name: "wide.png")
        let blue = try makePNG(width: 2, height: 2, color: .blue, name: "narrow.png")
        let result = try ImageStitchService.stitch([red, blue], direction: .vertical)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: result.data))

        var sawRed = false
        var sawBlue = false
        var sawTransparency = false

        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                    continue
                }
                sawRed = sawRed || (color.redComponent > 0.8 && color.blueComponent < 0.2)
                sawBlue = sawBlue || (color.blueComponent > 0.8 && color.redComponent < 0.2)
                sawTransparency = sawTransparency || color.alphaComponent < 0.1
            }
        }

        XCTAssertTrue(sawRed)
        XCTAssertTrue(sawBlue)
        XCTAssertTrue(sawTransparency)
    }

    func testStitchSkipsUnreadableFilesWhenAtLeastOneImageIsValid() throws {
        let invalid = try makeUnreadableFile()
        let valid = try makePNG(width: 12, height: 8, color: .green, name: "valid.png")

        let result = try ImageStitchService.stitch([invalid, valid], direction: .horizontal)

        XCTAssertEqual(result.pixelSize, CGSize(width: 12, height: 8))
    }

    func testStitchRejectsEmptyOrUnreadableInput() throws {
        XCTAssertThrowsError(try ImageStitchService.stitch([], direction: .vertical)) { error in
            guard case ImageStitchError.noReadableImages = error else {
                return XCTFail("Expected noReadableImages, got \(error)")
            }
        }

        let invalid = try makeUnreadableFile()
        XCTAssertThrowsError(
            try ImageStitchService.stitch([invalid], direction: .horizontal)
        ) { error in
            guard case ImageStitchError.noReadableImages = error else {
                return XCTFail("Expected noReadableImages, got \(error)")
            }
        }
    }

    func testStitchRejectsCanvasBeyondSafetyLimit() throws {
        let oversized = try makePNG(
            width: 50_001,
            height: 1,
            color: .black,
            name: "oversized.png"
        )

        XCTAssertThrowsError(
            try ImageStitchService.stitch([oversized], direction: .horizontal)
        ) { error in
            guard case ImageStitchError.canvasTooLarge(let width, let height) = error else {
                return XCTFail("Expected canvasTooLarge, got \(error)")
            }
            XCTAssertEqual(width, 50_001)
            XCTAssertEqual(height, 1)
        }
    }

    func testPixelSizeUsesLargestBitmapRepresentation() throws {
        let image = NSImage(size: NSSize(width: 10, height: 10))
        let small = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 10,
            pixelsHigh: 20,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ))
        let large = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 40,
            pixelsHigh: 30,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ))
        image.addRepresentation(small)
        image.addRepresentation(large)

        XCTAssertEqual(ImageStitchService.pixelSize(of: image), CGSize(width: 40, height: 30))
    }

    func testDirectionMetadataIsComplete() {
        XCTAssertEqual(ImageStitchDirection.allCases, [.vertical, .horizontal])
        XCTAssertEqual(ImageStitchDirection.vertical.titleKey, "imageStitch.direction.vertical")
        XCTAssertEqual(ImageStitchDirection.horizontal.titleKey, "imageStitch.direction.horizontal")
        XCTAssertFalse(ImageStitchDirection.vertical.systemImage.isEmpty)
        XCTAssertFalse(ImageStitchDirection.horizontal.systemImage.isEmpty)
    }
}
