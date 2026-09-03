import AppKit
import SwiftUI

enum AppTheme {
    static let accent = Color(red: 0.12, green: 0.38, blue: 0.76)
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let editorSurface = Color(nsColor: .textBackgroundColor)
    static let border = Color(nsColor: .separatorColor).opacity(0.72)
    static let surfaceRadius: CGFloat = 12
    static let pageSpacing: CGFloat = 18
    static let splitPaneSpacing: CGFloat = 12
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }

    var systemImage: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

private struct ToolPageModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: 1_160, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .background(AppTheme.canvas)
            .tint(AppTheme.accent)
    }
}

private struct WorkspaceSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.surfaceRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.surfaceRadius, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            }
    }
}

private struct AppGlassSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let interactive: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if reduceTransparency {
            content
                .background(AppTheme.surface, in: shape)
                .overlay {
                    shape.stroke(AppTheme.border, lineWidth: 1)
                }
        } else {
            if #available(macOS 26.0, *) {
                content
                    .glassEffect(
                        interactive ? .regular.interactive() : .regular,
                        in: shape
                    )
            } else {
                content
                    .background(.regularMaterial, in: shape)
                    .overlay {
                        shape.stroke(AppTheme.border, lineWidth: 1)
                    }
            }
        }
    }
}

private struct AppPrimaryActionModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.buttonStyle(.glassProminent)
        } else {
            content.buttonStyle(.borderedProminent)
        }
    }
}

extension View {
    func toolPageStyle() -> some View {
        modifier(ToolPageModifier())
    }

    func workspaceSurface() -> some View {
        modifier(WorkspaceSurfaceModifier())
    }

    func appGlassSurface(
        cornerRadius: CGFloat = AppTheme.surfaceRadius,
        interactive: Bool = false
    ) -> some View {
        modifier(AppGlassSurfaceModifier(
            cornerRadius: cornerRadius,
            interactive: interactive
        ))
    }

    func appPrimaryActionStyle() -> some View {
        modifier(AppPrimaryActionModifier())
    }
}
