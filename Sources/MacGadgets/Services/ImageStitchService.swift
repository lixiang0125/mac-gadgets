import AppKit
import Foundation

enum ImageStitchDirection: String, CaseIterable, Identifiable {
    case vertical
    case horizontal

    var id: String { rawValue }
    var title: String { self == .vertical ? "竖向拼接" : "横向拼接" }
    var systemImage: String { self == .vertical ? "rectangle.split.1x2" : "rectangle.split.2x1" }
}

struct StitchedImageResult {
    let data: Data
    let pixelSize: CGSize
}

enum ImageStitchError: LocalizedError {
    case noReadableImages
    case canvasTooLarge(width: Int, height: Int)
    case cannotCreateBitmap
    case cannotEncode

    var errorDescription: String? {
        switch self {
        case .noReadableImages: "没有可读取的图片"
        case .canvasTooLarge(let width, let height):
            "拼接结果过大（\(width) × \(height)），请减少图片数量或尺寸"
        case .cannotCreateBitmap: "无法创建拼接画布"
        case .cannotEncode: "无法编码 PNG 图片"
        }
    }
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
            return (image, pixelSize(of: image))
        }
        guard !inputs.isEmpty else { throw ImageStitchError.noReadableImages }

        let width: Int
        let height: Int
        switch direction {
        case .vertical:
            width = Int(inputs.map(\.size.width).max() ?? 0)
            height = inputs.reduce(0) { $0 + Int($1.size.height) }
        case .horizontal:
            width = inputs.reduce(0) { $0 + Int($1.size.width) }
            height = Int(inputs.map(\.size.height).max() ?? 0)
        }

        guard width > 0, height > 0,
              width <= maximumDimension,
              height <= maximumDimension,
              width.multipliedReportingOverflow(by: height).overflow == false,
              width * height <= maximumPixels else {
            throw ImageStitchError.canvasTooLarge(width: width, height: height)
        }

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
        NSGraphicsContext.current = graphicsContext
        graphicsContext.cgContext.clear(CGRect(x: 0, y: 0, width: width, height: height))

        var offset: CGFloat = 0
        for input in inputs {
            let rect: CGRect
            switch direction {
            case .vertical:
                let x = (CGFloat(width) - input.size.width) / 2
                let y = CGFloat(height) - offset - input.size.height
                rect = CGRect(x: x, y: y, width: input.size.width, height: input.size.height)
                offset += input.size.height
            case .horizontal:
                let y = (CGFloat(height) - input.size.height) / 2
                rect = CGRect(x: offset, y: y, width: input.size.width, height: input.size.height)
                offset += input.size.width
            }

            input.image.draw(
                in: rect,
                from: .zero,
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: false,
                hints: [.interpolation: NSImageInterpolation.high]
            )
        }

        NSGraphicsContext.restoreGraphicsState()
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw ImageStitchError.cannotEncode
        }
        return StitchedImageResult(data: data, pixelSize: CGSize(width: width, height: height))
    }
}
