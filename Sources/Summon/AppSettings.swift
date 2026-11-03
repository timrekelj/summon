import AppKit
import Observation

/// User preferences that live in UserDefaults and take effect immediately.
@Observable
final class AppSettings {
    /// Shows Summon in the Dock and app switcher instead of running as a background app.
    var showsInDock: Bool {
        didSet {
            defaults.set(showsInDock, forKey: Key.showsInDock)
            applyActivationPolicy()
        }
    }

    var showsMenuBarIcon: Bool {
        didSet { defaults.set(showsMenuBarIcon, forKey: Key.showsMenuBarIcon) }
    }

    /// Pressing an app's shortcut while it's already in front hides it.
    var hidesWhenFrontmost: Bool {
        didSet { defaults.set(hidesWhenFrontmost, forKey: Key.hidesWhenFrontmost) }
    }

    @ObservationIgnored private let defaults = UserDefaults.standard

    private enum Key {
        static let showsInDock = "showsInDock"
        static let showsMenuBarIcon = "showsMenuBarIcon"
        static let hidesWhenFrontmost = "hidesWhenFrontmost"
    }

    init() {
        defaults.register(defaults: [Key.showsMenuBarIcon: true])
        showsInDock = defaults.bool(forKey: Key.showsInDock)
        showsMenuBarIcon = defaults.bool(forKey: Key.showsMenuBarIcon)
        hidesWhenFrontmost = defaults.bool(forKey: Key.hidesWhenFrontmost)
        applyActivationPolicy()
    }

    private func applyActivationPolicy() {
        NSApplication.shared.setActivationPolicy(showsInDock ? .regular : .accessory)
    }
}
