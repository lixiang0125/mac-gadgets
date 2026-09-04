import AppKit
import Foundation

enum ImageStitchDirection: String, CaseIterable, Identifiable {
    case vertical
    case horizontal

    var id: String { rawValue }
    var titleKey: String {
        self == .vertical
            ? "imageStitch.direction.vertical"
            : "imageStitch.direction.horizontal"
    }
    var systemImage: String { self == .vertical ? "rectangle.split.1x2" : "rectangle.split.2x1" }
}

struct StitchedImageResult {
    let data: Data
    let pixelSize: CGSize
}

struct ImageStitchLayout {
    let pixelSize: CGSize
    let frames: [CGRect]
}

enum ImageStitchError: LocalizedError, LocalizedMessageProviding {
    case noReadableImages
    case canvasTooLarge(width: Int, height: Int)
    case cannotCreateBitmap
    case cannotEncode

    var localizationKey: String {
        switch self {
        case .noReadableImages: "error.imageStitch.noReadableImages"
        case .canvasTooLarge: "error.imageStitch.canvasTooLarge"
        case .cannotCreateBitmap: "error.imageStitch.cannotCreateBitmap"
        case .cannotEncode: "error.imageStitch.cannotEncode"
        }
    }

    var localizationArguments: [CVarArg] {
        guard case .canvasTooLarge(let width, let height) = self else { return [] }
        return [Int64(width), Int64(height)]
    }

    var errorDescription: String? { localizationKey }
}

enum ImageStitchService {
    private static let maximumDimension = 50_000
    private static let maximumPixels = 200_000_000

    static func pixelSize(of image: NSImage) -> CGSize {
        let representations = image.representations.filter { $0.pixelsWide > 0 && $0.pixelsHigh > 0 }
        guard let best = representations.max(by: {
            $0.pixelsWide * $0.pixelsHigh < $1.pixelsWide * $1.pixelsHigh
        }) else {
            return image.size
        }
        return CGSize(width: best.pixelsWide, height: best.pixelsHigh)
    }

    static func stitch(_ urls: [URL], direction: ImageStitchDirection) throws -> StitchedImageResult {
        let inputs: [(image: NSImage, size: CGSize)] = urls.compactMap { url in
            guard let image = NSImage(contentsOf: url) else { return nil }
            let size = pixelSize(of: image)
            guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else { return nil }
            return (image, size)
        }
        let layout = try layout(for: inputs.map(\.size), direction: direction)
        let width = Int(layout.pixelSize.width)
        let height = Int(layout.pixelSize.height)

        guard let bitmap = NSBitmapImageRep(
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
        ), let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw ImageStitchError.cannotCreateBitmap
        }

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = graphicsContext
        graphicsContext.cgContext.clear(CGRect(x: 0, y: 0, width: width, height: height))

        for (input, rect) in zip(inputs, layout.frames) {
            input.image.draw(
                in: rect,
                from: .zero,
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: false,
                hints: [.interpolation: NSImageInterpolation.high]
            )
        }

        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw ImageStitchError.cannotEncode
        }
        return StitchedImageResult(data: data, pixelSize: CGSize(width: width, height: height))
    }

    static func layout(for sizes: [CGSize], direction: ImageStitchDirection) throws -> ImageStitchLayout {
        guard !sizes.isEmpty,
              sizes.allSatisfy({ $0.width.isFinite && $0.height.isFinite && $0.width > 0 && $0.height > 0 }) else {
            throw ImageStitchError.noReadableImages
        }

        let commonLength = (direction == .vertical
            ? sizes.map(\.width).max()!
            : sizes.map(\.height).max()!).rounded()
        let scaledSizes = sizes.map { size in
            switch direction {
            case .vertical:
                CGSize(width: commonLength, height: max(1, (size.height / size.width * commonLength).rounded()))
            case .horizontal:
                CGSize(width: max(1, (size.width / size.height * commonLength).rounded()), height: commonLength)
            }
        }
        let width = diagnosticPixelCount(direction == .vertical
            ? commonLength : scaledSizes.reduce(0) { $0 + $1.width })
        let height = diagnosticPixelCount(direction == .horizontal
            ? commonLength : scaledSizes.reduce(0) { $0 + $1.height })

        // Check the normalized canvas before allocating any bitmap: bringing a
        // narrow/tall source up to the widest source can multiply its area.
        guard width > 0, height > 0,
              width <= maximumDimension, height <= maximumDimension,
              width.multipliedReportingOverflow(by: height).overflow == false,
              width * height <= maximumPixels else {
            throw ImageStitchError.canvasTooLarge(width: width, height: height)
        }

        var offset: CGFloat = 0
        let frames = scaledSizes.map { size in
            let rect: CGRect
            switch direction {
            case .vertical:
                rect = CGRect(x: 0, y: CGFloat(height) - offset - size.height, width: size.width, height: size.height)
                offset += size.height
            case .horizontal:
                rect = CGRect(x: offset, y: 0, width: size.width, height: size.height)
                offset += size.width
            }
            return rect
        }
        return ImageStitchLayout(pixelSize: CGSize(width: width, height: height), frames: frames)
    }

    private static func diagnosticPixelCount(_ value: CGFloat) -> Int {
        // Invalid or enormous metadata must produce a validation error, not an
        // overflowing CGFloat-to-Int conversion while constructing that error.
        guard value.isFinite, value < CGFloat(Int.max) else { return Int.max }
        return max(0, Int(value))
    }
}
