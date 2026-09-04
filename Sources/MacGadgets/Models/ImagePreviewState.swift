import AppKit

struct ImageStitchPaneWidths {
    let list: CGFloat
    let preview: CGFloat

    init(availableWidth: CGFloat, spacing: CGFloat) {
        let contentWidth = max(0, availableWidth - spacing)
        list = contentWidth * 0.3
        preview = contentWidth - list
    }
}

struct ImagePreviewZoom {
    static let minimum: CGFloat = 0.25
    static let maximum: CGFloat = 8
    private static let step: CGFloat = 1.25

    private(set) var factor: CGFloat = 1
    private(set) var resetID = 0

    var canZoomIn: Bool { factor < Self.maximum }
    var canZoomOut: Bool { factor > Self.minimum }

    mutating func zoomIn() {
        factor = min(Self.maximum, factor * Self.step)
    }

    mutating func zoomOut() {
        factor = max(Self.minimum, factor / Self.step)
    }

    mutating func fit() {
        factor = 1
        resetID += 1
    }
}

struct ImagePreviewGeometry {
    let scale: CGFloat
    let imageSize: CGSize
    let contentSize: CGSize

    init(pixelSize: CGSize, viewport: CGSize, zoom: CGFloat = 1) {
        guard pixelSize.width.isFinite, pixelSize.height.isFinite,
              viewport.width.isFinite, viewport.height.isFinite, zoom.isFinite,
              pixelSize.width > 0, pixelSize.height > 0,
              viewport.width > 0, viewport.height > 0, zoom > 0 else {
            scale = 0
            imageSize = .zero
            contentSize = .zero
            return
        }

        // A bidirectional ScrollView offers unbounded space; size the image
        // against the visible viewport before putting it in the scroll view.
        scale = min(viewport.width / pixelSize.width, viewport.height / pixelSize.height) * zoom
        imageSize = CGSize(width: pixelSize.width * scale, height: pixelSize.height * scale)
        contentSize = CGSize(
            width: max(viewport.width, imageSize.width),
            height: max(viewport.height, imageSize.height)
        )
    }
}

struct SourceImagePreview: Identifiable {
    let id: URL
    let image: NSImage

    init?(url: URL) {
        guard let image = NSImage(contentsOf: url), image.isValid else { return nil }
        id = url
        self.image = image
    }
}
