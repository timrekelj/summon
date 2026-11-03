import SwiftUI

struct MenuBarMenu: View {
    @Environment(HotkeyStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ForEach(store.hotkeys) { hotkey in
            Button {
                store.launch(hotkey)
            } label: {
                Label {
                    Text(hotkey.name)
                } icon: {
                    Image(nsImage: hotkey.menuIcon)
                }
            }
            .keyboardShortcut(hotkey.combo?.keyboardShortcut)
        }

        if !store.hotkeys.isEmpty {
            Divider()
        }

        Button("Settings…") {
            openWindow(id: SettingsView.windowID)
            NSApp.activate()
        }
        .keyboardShortcut(",")

        Divider()

        Button("Quit Summon") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

private extension AppHotkey {
    var menuIcon: NSImage {
        let image = icon
        image.size = NSSize(width: 16, height: 16)
        return image
    }
}
