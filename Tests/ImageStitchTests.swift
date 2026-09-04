import AppKit
import SwiftUI
import XCTest
@testable import MacGadgets

final class ImageStitchTests: TemporaryDirectoryTestCase {
    func testWorkspaceKeepsThirtySeventyRatioAfterSubtractingGutter() {
        for width: CGFloat in [640, 900, 1_160] {
            let panes = ImageStitchPaneWidths(availableWidth: width, spacing: 12)
            XCTAssertEqual(panes.list + panes.preview + 12, width, accuracy: 0.001)
            XCTAssertEqual(panes.list / panes.preview, 3.0 / 7.0, accuracy: 0.001)
        }
        let empty = ImageStitchPaneWidths(availableWidth: 5, spacing: 12)
        XCTAssertEqual(empty.list, 0)
        XCTAssertEqual(empty.preview, 0)
    }

    func testPreviewFitsPortraitLandscapeSquareAndSmallImagesWithoutCropping() {
        let viewport = CGSize(width: 700, height: 400)
        for pixels in [
            CGSize(width: 1_179, height: 5_112),
            CGSize(width: 5_112, height: 1_179),
            CGSize(width: 800, height: 800),
            CGSize(width: 20, height: 10)
        ] {
            let geometry = ImagePreviewGeometry(pixelSize: pixels, viewport: viewport)
            XCTAssertLessThanOrEqual(geometry.imageSize.width, viewport.width + 0.001)
            XCTAssertLessThanOrEqual(geometry.imageSize.height, viewport.height + 0.001)
            XCTAssertEqual(
                max(geometry.imageSize.width / viewport.width, geometry.imageSize.height / viewport.height),
                1,
                accuracy: 0.001
            )
            XCTAssertEqual(
                geometry.imageSize.width / geometry.imageSize.height,
                pixels.width / pixels.height,
                accuracy: 0.001
            )
            XCTAssertEqual(geometry.contentSize, viewport)
        }
    }

    func testPreviewRefitsWhenViewportChangesAndScrollsWhenZoomedIn() {
        let pixels = CGSize(width: 1_000, height: 5_000)
        let small = ImagePreviewGeometry(pixelSize: pixels, viewport: CGSize(width: 600, height: 300))
        let large = ImagePreviewGeometry(pixelSize: pixels, viewport: CGSize(width: 800, height: 600))
        XCTAssertEqual(small.imageSize, CGSize(width: 60, height: 300))
        XCTAssertEqual(large.imageSize, CGSize(width: 120, height: 600))

        let zoomed = ImagePreviewGeometry(pixelSize: pixels, viewport: CGSize(width: 600, height: 300), zoom: 4)
        XCTAssertEqual(zoomed.imageSize, CGSize(width: 240, height: 1_200))
        XCTAssertEqual(zoomed.contentSize, CGSize(width: 600, height: 1_200))

        let wide = ImagePreviewGeometry(
            pixelSize: CGSize(width: 5_000, height: 1_000),
            viewport: CGSize(width: 600, height: 300),
            zoom: 2
        )
        XCTAssertEqual(wide.contentSize, CGSize(width: 1_200, height: 300))
    }

    func testPreviewGeometryIgnoresInvalidAndZeroSizes() {
        for pixels in [CGSize.zero, CGSize(width: -1, height: 2), CGSize(width: CGFloat.infinity, height: 2)] {
            XCTAssertEqual(ImagePreviewGeometry(pixelSize: pixels, viewport: CGSize(width: 500, height: 400)).imageSize, .zero)
        }
        XCTAssertEqual(ImagePreviewGeometry(pixelSize: CGSize(width: 10, height: 10), viewport: .zero).imageSize, .zero)
    }

    func testZoomControlsRespectLimitsAndFitResetsZoomAndScrolling() {
        var zoom = ImagePreviewZoom()
        XCTAssertEqual(zoom.factor, 1)
        zoom.zoomIn()
        XCTAssertEqual(zoom.factor, 1.25)
        zoom.zoomOut()
        XCTAssertEqual(zoom.factor, 1)
        for _ in 0..<100 { zoom.zoomIn() }
        XCTAssertEqual(zoom.factor, ImagePreviewZoom.maximum)
        XCTAssertFalse(zoom.canZoomIn)
        XCTAssertTrue(zoom.canZoomOut)
        for _ in 0..<100 { zoom.zoomOut() }
        XCTAssertEqual(zoom.factor, ImagePreviewZoom.minimum)
        XCTAssertFalse(zoom.canZoomOut)
        XCTAssertTrue(zoom.canZoomIn)
        let previousResetID = zoom.resetID
        zoom.fit()
        XCTAssertEqual(zoom.factor, 1)
        XCTAssertEqual(zoom.resetID, previousResetID + 1)
    }

    func testSourcePreviewLoadsChosenImageWithoutChangingFilesAndRejectsUnreadableFiles() throws {
        let first = try makePNG(width: 24, height: 120, color: .red, name: "portrait.png")
        let second = try makePNG(width: 160, height: 40, color: .blue, name: "landscape.png")
        for url in [first, second] {
            let original = try Data(contentsOf: url)
            let preview = try XCTUnwrap(SourceImagePreview(url: url))
            XCTAssertEqual(preview.id, url)
            XCTAssertEqual(ImageStitchService.pixelSize(of: preview.image), url == first ? CGSize(width: 24, height: 120) : CGSize(width: 160, height: 40))
            XCTAssertEqual(try Data(contentsOf: url), original)
        }
        XCTAssertNil(SourceImagePreview(url: try makeUnreadableFile()))
        XCTAssertNil(SourceImagePreview(url: temporaryDirectory.appendingPathComponent("missing.png")))
    }

    @MainActor
    func testPopulatedPreviewAndSourceDialogLayOutInBothLanguagesAndAppearances() throws {
        let url = try makePNG(width: 120, height: 900, color: .systemBlue, name: "preview.png")
        let source = try XCTUnwrap(SourceImagePreview(url: url))
        for language in AppLanguage.allCases {
            let localization = LocalizationStore(language: language, resourceDirectory: testLocaleDirectory, userDefaults: nil)
            for appearance in [NSAppearance.Name.aqua, .darkAqua] {
                let views = [
                    AnyView(ZoomableImagePreview(image: source.image, accessibilityLabel: "fixture")),
                    AnyView(SourceImagePreviewSheet(source: source))
                ]
                for view in views {
                    let host = NSHostingView(rootView: view.environmentObject(localization))
                    host.appearance = NSAppearance(named: appearance)
                    host.frame = NSRect(x: 0, y: 0, width: 760, height: 560)
                    host.layoutSubtreeIfNeeded()
                    XCTAssertGreaterThan(host.fittingSize.width, 0)
                    XCTAssertLessThanOrEqual(host.fittingSize.width, 760)
                    XCTAssertLessThanOrEqual(host.fittingSize.height, 560)
                }
            }
        }
    }

    func testVerticalAndHorizontalStitchUseExpectedCanvasDimensions() throws {
        let red = try makePNG(width: 40, height: 30, color: .red, name: "red.png")
        let blue = try makePNG(width: 20, height: 50, color: .blue, name: "blue.png")

        let vertical = try ImageStitchService.stitch([red, blue], direction: .vertical)
        XCTAssertEqual(vertical.pixelSize, CGSize(width: 40, height: 130))
        XCTAssertEqual(try XCTUnwrap(NSBitmapImageRep(data: vertical.data)).pixelsWide, 40)
        XCTAssertEqual(try XCTUnwrap(NSBitmapImageRep(data: vertical.data)).pixelsHigh, 130)

        let horizontal = try ImageStitchService.stitch([red, blue], direction: .horizontal)
        XCTAssertEqual(horizontal.pixelSize, CGSize(width: 87, height: 50))
        XCTAssertEqual(try XCTUnwrap(NSBitmapImageRep(data: horizontal.data)).pixelsWide, 87)
        XCTAssertEqual(try XCTUnwrap(NSBitmapImageRep(data: horizontal.data)).pixelsHigh, 50)
    }

    func testStitchFillsBothAxesWithoutMarginsAndPreservesImageOrder() throws {
        let red = try makePNG(width: 40, height: 30, color: .red, name: "red.png")
        let blue = try makePNG(width: 20, height: 50, color: .blue, name: "blue.png")
        for direction in ImageStitchDirection.allCases {
            for urls in [[red, blue], [blue, red]] {
                let result = try ImageStitchService.stitch(urls, direction: direction)
                let bitmap = try XCTUnwrap(NSBitmapImageRep(data: result.data))
                let redFirst = urls.first == red
                let firstLength = direction == .vertical
                    ? (redFirst ? 30 : 100)
                    : (redFirst ? 67 : 20)
                for y in 0..<bitmap.pixelsHigh {
                    for x in 0..<bitmap.pixelsWide {
                        let color = try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB))
                        let isFirst = (direction == .vertical ? y : x) < firstLength
                        let expectsRed = isFirst == redFirst
                        XCTAssertGreaterThan(color.alphaComponent, 0.99, "No added transparent margins or seams")
                        XCTAssertGreaterThan(expectsRed ? color.redComponent : color.blueComponent, 0.95)
                        XCTAssertLessThan(expectsRed ? color.blueComponent : color.redComponent, 0.05)
                    }
                }
            }
        }
    }

    func testNormalizationPreservesOriginalAlphaAndDoesNotModifySourceFiles() throws {
        let opaque = try makePNG(width: 4, height: 2, color: .red, name: "opaque.png")
        let translucent = try makePNG(width: 2, height: 2, color: .blue.withAlphaComponent(0.4), name: "alpha.png")
        let originals = try [opaque, translucent].map { try Data(contentsOf: $0) }
        let result = try ImageStitchService.stitch([opaque, translucent], direction: .vertical)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: result.data))
        XCTAssertEqual(result.pixelSize, CGSize(width: 4, height: 6))
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                let color = try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB))
                XCTAssertEqual(color.alphaComponent, y < 2 ? 1 : 0.4, accuracy: 0.03)
            }
        }
        XCTAssertEqual(try [opaque, translucent].map { try Data(contentsOf: $0) }, originals)
    }

    func testNormalizationMatchesUserPhotoDimensionsInBothDirections() throws {
        let sizes = [CGSize(width: 4_032, height: 3_024), CGSize(width: 7_008, height: 4_672)]
        let vertical = try ImageStitchService.layout(for: sizes, direction: .vertical)
        XCTAssertEqual(vertical.pixelSize, CGSize(width: 7_008, height: 9_928))
        XCTAssertEqual(vertical.frames, [
            CGRect(x: 0, y: 4_672, width: 7_008, height: 5_256),
            CGRect(x: 0, y: 0, width: 7_008, height: 4_672)
        ])
        let horizontal = try ImageStitchService.layout(for: sizes, direction: .horizontal)
        XCTAssertEqual(horizontal.pixelSize, CGSize(width: 13_237, height: 4_672))
        XCTAssertEqual(horizontal.frames, [
            CGRect(x: 0, y: 0, width: 6_229, height: 4_672),
            CGRect(x: 6_229, y: 0, width: 7_008, height: 4_672)
        ])
    }

    func testScaledEdgesRoundToWholePixelsWithoutGapsAndPreserveProportions() throws {
        let sizes = [CGSize(width: 3, height: 2), CGSize(width: 5, height: 3), CGSize(width: 7, height: 5)]
        for direction in ImageStitchDirection.allCases {
            let layout = try ImageStitchService.layout(for: sizes, direction: direction)
            for (source, frame) in zip(sizes, layout.frames) {
                let idealLength = direction == .vertical
                    ? source.height / source.width * 7
                    : source.width / source.height * 5
                let actualLength = direction == .vertical ? frame.height : frame.width
                XCTAssertEqual(actualLength, actualLength.rounded())
                XCTAssertLessThanOrEqual(abs(actualLength - idealLength), 0.5)
                XCTAssertEqual(direction == .vertical ? frame.width : frame.height, direction == .vertical ? 7 : 5)
            }
            for index in 1..<layout.frames.count {
                let previous = layout.frames[index - 1]
                let current = layout.frames[index]
                XCTAssertEqual(direction == .vertical ? previous.minY : previous.maxX,
                               direction == .vertical ? current.maxY : current.minX)
            }
        }
    }

    func testSingleImageKeepsItsOriginalDimensionsInBothDirections() throws {
        let url = try makePNG(width: 13, height: 7, color: .green, name: "single.png")
        for direction in ImageStitchDirection.allCases {
            XCTAssertEqual(try ImageStitchService.stitch([url], direction: direction).pixelSize, CGSize(width: 13, height: 7))
        }
    }

    func testNormalizedCanvasLimitsApplyBeforeBitmapAllocation() throws {
        let dimensionOverflow = [CGSize(width: 10_000, height: 10), CGSize(width: 10, height: 100)]
        let pixelOverflow = [CGSize(width: 20_000, height: 5_000), CGSize(width: 10_000, height: 5_000)]
        for direction in ImageStitchDirection.allCases {
            // Transpose the fixtures to exercise the same safety rules on both axes.
            for sizes in [dimensionOverflow, pixelOverflow] {
                let inputs = direction == .vertical ? sizes : sizes.map { CGSize(width: $0.height, height: $0.width) }
                XCTAssertThrowsError(try ImageStitchService.layout(for: inputs, direction: direction)) { error in
                    guard case ImageStitchError.canvasTooLarge = error else {
                        return XCTFail("Expected a scaled-canvas limit error, got \(error)")
                    }
                }
            }
        }
        let boundary = try ImageStitchService.layout(
            for: [CGSize(width: 10_000, height: 10_000), CGSize(width: 5_000, height: 5_000)],
            direction: .vertical
        )
        XCTAssertEqual(boundary.pixelSize, CGSize(width: 10_000, height: 20_000))
    }

    func testLayoutRejectsInvalidAndEnormousMetadataWithoutIntegerOverflow() {
        for sizes in [[], [.zero], [CGSize(width: -1, height: 2)], [CGSize(width: CGFloat.nan, height: 2)]] {
            XCTAssertThrowsError(try ImageStitchService.layout(for: sizes, direction: .vertical))
        }
        XCTAssertThrowsError(try ImageStitchService.layout(
            for: [CGSize(width: CGFloat.greatestFiniteMagnitude, height: 1), CGSize(width: 1, height: 10)],
            direction: .vertical
        ))
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
