import SwiftUI

@main
struct MacGadgetsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1_020, minHeight: 680)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1_180, height: 780)
        .commands {
            SidebarCommands()
        }
    }
}
