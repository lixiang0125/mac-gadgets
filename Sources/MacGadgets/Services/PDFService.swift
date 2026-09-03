import AppKit
import Foundation
import PDFKit

enum PDFServiceError: LocalizedError {
    case unreadablePDF(String)
    case emptyDocument
    case cannotWrite(String)
    case cannotRenderPage(Int)

    var errorDescription: String? {
        switch self {
        case .unreadablePDF(let name): "无法读取 PDF：\(name)"
        case .emptyDocument: "没有可处理的 PDF 页面"
        case .cannotWrite(let name): "无法写入文件：\(name)"
        case .cannotRenderPage(let page): "无法渲染第 \(page) 页"
        }
    }
}

enum PDFService {
    static func pageCount(at url: URL) -> Int? {
        PDFDocument(url: url)?.pageCount
    }

    static func merge(_ sourceURLs: [URL], to destinationURL: URL) throws -> Int {
        let output = PDFDocument()
        var outputIndex = 0

        for url in sourceURLs {
            guard let document = PDFDocument(url: url) else {
                throw PDFServiceError.unreadablePDF(url.lastPathComponent)
            }

            for pageIndex in 0..<document.pageCount {
                if let page = document.page(at: pageIndex)?.copy() as? PDFPage {
                    output.insert(page, at: outputIndex)
                    outputIndex += 1
                }
            }
        }

        guard outputIndex > 0 else { throw PDFServiceError.emptyDocument }
        guard output.write(to: destinationURL) else {
            throw PDFServiceError.cannotWrite(destinationURL.lastPathComponent)
        }
        return outputIndex
    }

    static func imagesToPDF(_ imageURLs: [URL], to destinationURL: URL) throws -> Int {
        let output = PDFDocument()
        var outputIndex = 0

        for url in imageURLs {
            guard let image = NSImage(contentsOf: url), let page = PDFPage(image: image) else {
                continue
            }
            output.insert(page, at: outputIndex)
            outputIndex += 1
        }

        guard outputIndex > 0 else { throw PDFServiceError.emptyDocument }
        guard output.write(to: destinationURL) else {
            throw PDFServiceError.cannotWrite(destinationURL.lastPathComponent)
        }
        return outputIndex
    }

    static func pdfToPNGFiles(_ pdfURL: URL, outputDirectory: URL, scale: CGFloat) throws -> [URL] {
        guard let document = PDFDocument(url: pdfURL) else {
            throw PDFServiceError.unreadablePDF(pdfURL.lastPathComponent)
        }
        guard document.pageCount > 0 else { throw PDFServiceError.emptyDocument }

        let baseName = pdfURL.deletingPathExtension().lastPathComponent
        let digits = max(3, String(document.pageCount).count)
        var outputURLs: [URL] = []

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else {
                throw PDFServiceError.cannotRenderPage(pageIndex + 1)
            }

            let bounds = page.bounds(for: .mediaBox)
            let targetSize = NSSize(
                width: max(1, bounds.width * scale),
                height: max(1, bounds.height * scale)
            )
            let image = page.thumbnail(of: targetSize, for: .mediaBox)
            guard let data = image.pngData else {
                throw PDFServiceError.cannotRenderPage(pageIndex + 1)
            }

            let pageNumber = String(format: "%0*d", digits, pageIndex + 1)
            let outputURL = outputDirectory.appendingPathComponent("\(baseName)-\(pageNumber).png")
            try data.write(to: outputURL, options: .atomic)
            outputURLs.append(outputURL)
        }

        return outputURLs
    }
}

extension NSImage {
    var pngData: Data? {
        guard let tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
