import SwiftUI

@main
struct MacGadgetsApp: App {
    static let mainWindowID = "main"

    @StateObject private var clipboardHistoryStore = ClipboardHistoryStore()
    @StateObject private var localizationStore = LocalizationStore()
    @StateObject private var router = AppRouter()

    var body: some Scene {
        WindowGroup(id: Self.mainWindowID) {
            ContentView()
                .environmentObject(clipboardHistoryStore)
                .environmentObject(localizationStore)
                .environmentObject(router)
                .frame(minWidth: 1_020, minHeight: 680)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1_180, height: 780)
        .commands {
            SidebarCommands()
        }

        MenuBarExtra {
            MenuBarToolsView()
                .environmentObject(localizationStore)
                .environmentObject(router)
        } label: {
            Label(
                localizationStore.text("app.name"),
                systemImage: "square.grid.2x2"
            )
            .labelStyle(.iconOnly)
        }
        .menuBarExtraStyle(.menu)
    }
}
