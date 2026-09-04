import AppKit
import SwiftUI

struct ZoomableImagePreview: View {
    @EnvironmentObject private var localization: LocalizationStore
    let image: NSImage
    let accessibilityLabel: String
    @State private var zoom = ImagePreviewZoom()

    private let controlsHeight: CGFloat = 34
    private let controlsSpacing: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            let viewport = CGSize(
                width: proxy.size.width,
                height: max(0, proxy.size.height - controlsHeight - controlsSpacing)
            )
            let geometry = ImagePreviewGeometry(
                pixelSize: ImageStitchService.pixelSize(of: image),
                viewport: viewport,
                zoom: zoom.factor
            )

            VStack(spacing: controlsSpacing) {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: geometry.imageSize.width, height: geometry.imageSize.height)
                        .accessibilityLabel(accessibilityLabel)
                        .frame(width: geometry.contentSize.width, height: geometry.contentSize.height)
                }
                .id(zoom.resetID)
                .frame(width: viewport.width, height: viewport.height)
                .background(AppTheme.canvas)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    zoomButton("common.imagePreview.zoomOut", symbol: "minus.magnifyingglass") {
                        zoom.zoomOut()
                    }
                    .disabled(!zoom.canZoomOut)

                    Text(geometry.scale, format: .percent.precision(.fractionLength(0...1)))
                        .font(.caption.monospacedDigit())
                        .frame(minWidth: 54)
                        .accessibilityLabel(localization.text("common.imagePreview.scale"))
                        .accessibilityValue(Text(geometry.scale, format: .percent.precision(.fractionLength(0...1))))

                    zoomButton("common.imagePreview.zoomIn", symbol: "plus.magnifyingglass") {
                        zoom.zoomIn()
                    }
                    .disabled(!zoom.canZoomIn)

                    Divider().frame(height: 18)
                    Button(localization.text("common.imagePreview.fit")) {
                        zoom.fit()
                    }
                    .help(localization.text("common.imagePreview.fitHelp"))
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(height: controlsHeight)
            }
        }
    }

    private func zoomButton(_ key: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .foregroundStyle(Color.primary)
                .frame(width: AppTheme.compactControlHitSize, height: AppTheme.compactControlHitSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(localization.text(key))
        .accessibilityLabel(localization.text(key))
    }
}

struct SourceImagePreviewSheet: View {
    @EnvironmentObject private var localization: LocalizationStore
    @Environment(\.dismiss) private var dismiss
    let source: SourceImagePreview

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(source.id.lastPathComponent)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    let size = ImageStitchService.pixelSize(of: source.image)
                    Text("\(Int(size.width)) × \(Int(size.height))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(localization.text("common.imagePreview.close"), systemImage: "xmark") {
                    dismiss()
                }
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
            }

            ZoomableImagePreview(image: source.image, accessibilityLabel: source.id.lastPathComponent)
                .id(source.id)
        }
        .padding(20)
        .frame(width: 760, height: 560)
        .background(AppTheme.surface)
    }
}
