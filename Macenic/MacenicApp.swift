import SwiftUI

@main
struct MacenicApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            DashboardView()
                .environment(appState)
        } label: {
            Image("MenuBarIcon")
        }
        .menuBarExtraStyle(.window)

        MenuBarExtra {
            ClipboardMenuBarView(service: appState.clipboard, hotKey: appState.hotKey)
                .environment(appState)
        } label: {
            Image(systemName: "clipboard")
        }
        .menuBarExtraStyle(.window)
    }
}
