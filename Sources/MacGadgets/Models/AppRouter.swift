import AppKit
import SwiftUI

@MainActor
protocol AppWindowControlling: AnyObject {
    var isMiniaturized: Bool { get }
    func deminiaturize(_ sender: Any?)
    func makeKeyAndOrderFront(_ sender: Any?)
}

extension NSWindow: AppWindowControlling {}

@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedTool: ToolKind? = .chineseConversion

    private weak var mainWindow: (any AppWindowControlling)?
    private var isActivationPending = false
    private let activateApplication: () -> Void

    init(activateApplication: @escaping () -> Void = {
        NSApplication.shared.activate(ignoringOtherApps: true)
    }) {
        self.activateApplication = activateApplication
    }

    func select(_ tool: ToolKind) {
        selectedTool = tool
    }

    func reveal(_ tool: ToolKind, openWindow: () -> Void) {
        selectedTool = tool
        isActivationPending = true

        if let mainWindow {
            activate(mainWindow)
            return
        }

        openWindow()
    }

    func registerMainWindow(_ window: any AppWindowControlling) {
        if let mainWindow, mainWindow === window {
            activatePendingWindow()
            return
        }
        mainWindow = window
        activatePendingWindow()
    }

    private func activatePendingWindow() {
        guard isActivationPending, let mainWindow else { return }
        activate(mainWindow)
    }

    private func activate(_ window: any AppWindowControlling) {
        isActivationPending = false
        activateApplication()
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
    }
}
