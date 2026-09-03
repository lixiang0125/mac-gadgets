#!/usr/bin/swift

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum AppIconError: LocalizedError {
    case invalidArguments
    case unreadableSource
    case contextCreationFailed
    case imageCreationFailed
    case destinationCreationFailed
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .invalidArguments:
            "Usage: prepare-app-icon.swift <source.png> <output.png>"
        case .unreadableSource:
            "Unable to read the source icon artwork."
        case .contextCreationFailed:
            "Unable to create the icon rendering context."
        case .imageCreationFailed:
            "Unable to render the prepared icon."
        case .destinationCreationFailed:
            "Unable to create the icon output destination."
        case .writeFailed:
            "Unable to write the prepared icon."
        }
    }
}

func superellipsePath(in rect: CGRect, exponent: Double = 5, steps: Int = 720) -> CGPath {
    let path = CGMutablePath()
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let radiusX = rect.width / 2
    let radiusY = rect.height / 2

    for step in 0...steps {
        let angle = Double(step) / Double(steps) * 2 * Double.pi
        let cosine = cos(angle)
        let sine = sin(angle)
        let x = center.x + radiusX * CGFloat(copysign(pow(abs(cosine), 2 / exponent), cosine))
        let y = center.y + radiusY * CGFloat(copysign(pow(abs(sine), 2 / exponent), sine))
        let point = CGPoint(x: x, y: y)

        if step == 0 {
            path.move(to: point)
        } else {
            path.addLine(to: point)
        }
    }

    path.closeSubpath()
    return path
}

guard CommandLine.arguments.count == 3 else {
    throw AppIconError.invalidArguments
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard
    let sourceContainer = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
    let sourceImage = CGImageSourceCreateImageAtIndex(sourceContainer, 0, nil)
else {
    throw AppIconError.unreadableSource
}

let canvasSize = 1_024
let iconInset: CGFloat = 100
let canvasRect = CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize)
let iconRect = canvasRect.insetBy(dx: iconInset, dy: iconInset)
let iconPath = superellipsePath(in: iconRect)

guard let context = CGContext(
    data: nil,
    width: canvasSize,
    height: canvasSize,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    throw AppIconError.contextCreationFailed
}

context.clear(canvasRect)
context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)
context.interpolationQuality = .high

context.saveGState()
context.setShadow(
    offset: CGSize(width: 0, height: -12),
    blur: 24,
    color: NSColor.black.withAlphaComponent(0.38).cgColor
)
context.addPath(iconPath)
context.setFillColor(NSColor.black.cgColor)
context.fillPath()
context.restoreGState()

context.saveGState()
context.addPath(iconPath)
context.clip()
context.draw(sourceImage, in: iconRect)
context.restoreGState()

guard let preparedImage = context.makeImage() else {
    throw AppIconError.imageCreationFailed
}

guard let destination = CGImageDestinationCreateWithURL(
    outputURL as CFURL,
    UTType.png.identifier as CFString,
    1,
    nil
) else {
    throw AppIconError.destinationCreationFailed
}

CGImageDestinationAddImage(destination, preparedImage, nil)
guard CGImageDestinationFinalize(destination) else {
    throw AppIconError.writeFailed
}
