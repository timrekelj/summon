import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Closing the settings window (⌘W or ⌘Q) leaves Summon running in the background.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Opening Summon again (Dock, Finder, Spotlight) is the way back to settings once the menu bar icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            EnvironmentValues().openWindow(id: SettingsView.windowID)
        }
        NSApp.activate()
        return false
    }
}
