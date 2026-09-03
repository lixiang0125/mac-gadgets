import AppKit
import SwiftUI

struct MenuBarToolsView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var localization: LocalizationStore
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        Section(localization.text("menuBar.tools")) {
            ForEach(ToolKind.pinyinSorted) { tool in
                Button {
                    router.reveal(tool) {
                        openWindow(id: MacGadgetsApp.mainWindowID)
                    }
                } label: {
                    Label(localization.text(tool.titleKey), systemImage: tool.systemImage)
                }
            }
        }

        Divider()

        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            Label(localization.text("menuBar.quit"), systemImage: "power")
        }
        .keyboardShortcut("q")
    }
}

struct MainWindowReader: NSViewRepresentable {
    let onWindowAvailable: (NSWindow) -> Void

    func makeNSView(context: Context) -> WindowObservationView {
        let view = WindowObservationView()
        view.onWindowAvailable = onWindowAvailable
        return view
    }

    func updateNSView(_ view: WindowObservationView, context: Context) {
        view.onWindowAvailable = onWindowAvailable
        view.reportWindowIfAvailable()
    }
}

final class WindowObservationView: NSView {
    var onWindowAvailable: ((NSWindow) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        reportWindowIfAvailable()
    }

    func reportWindowIfAvailable() {
        guard let window else { return }
        onWindowAvailable?(window)
    }
}
