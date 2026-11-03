import SwiftUI

@main
struct SummonApp: App {
    @State private var store = HotkeyStore()

    /// Only show the settings window on its own the first time; afterwards Summon starts quietly in the menu bar.
    private let isFirstLaunch: Bool = {
        let key = "hasLaunchedBefore"
        defer { UserDefaults.standard.set(true, forKey: key) }
        return !UserDefaults.standard.bool(forKey: key)
    }()

    var body: some Scene {
        Window("Summon", id: SettingsView.windowID) {
            SettingsView()
                .environment(store)
        }
        .defaultSize(width: 560, height: 540)
        .windowResizability(.contentMinSize)
        .defaultLaunchBehavior(isFirstLaunch ? .presented : .suppressed)

        MenuBarExtra("Summon", systemImage: "command") {
            MenuBarMenu()
                .environment(store)
        }
    }
}
