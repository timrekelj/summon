import SwiftUI

@main
struct SummonApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var settings: AppSettings
    @State private var store: HotkeyStore
    @State private var sounds: SoundEffects

    /// Only show the settings window on its own the first time; afterwards Summon starts quietly in the menu bar.
    private let isFirstLaunch: Bool = {
        let key = "hasLaunchedBefore"
        defer { UserDefaults.standard.set(true, forKey: key) }
        return !UserDefaults.standard.bool(forKey: key)
    }()

    init() {
        let settings = AppSettings()
        _settings = State(initialValue: settings)
        let sounds = SoundEffects(settings: settings)
        _sounds = State(initialValue: sounds)
        _store = State(initialValue: HotkeyStore(settings: settings, sounds: sounds))
    }

    var body: some Scene {
        @Bindable var settings = settings

        Window("Summon", id: SettingsView.windowID) {
            SettingsView()
                .environment(store)
                .environment(settings)
                .environment(sounds)
        }
        .defaultSize(width: 560, height: 600)
        .windowResizability(.contentMinSize)
        .defaultLaunchBehavior(isFirstLaunch ? .presented : .suppressed)
        .commands {
            // ⌘Q in the settings window works like ⌘W: Summon keeps running in the background.
            // Really quitting is done from the menu bar icon or the Dock.
            CommandGroup(replacing: .appTermination) {
                Button("Close Window") {
                    if let window = NSApp.keyWindow {
                        window.performClose(nil)
                    } else {
                        NSApp.terminate(nil)
                    }
                }
                .keyboardShortcut("q")
            }
        }

        MenuBarExtra("Summon", systemImage: "command", isInserted: $settings.showsMenuBarIcon) {
            MenuBarMenu()
                .environment(store)
        }
    }
}
