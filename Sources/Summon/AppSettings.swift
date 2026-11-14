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

    var playsSounds: Bool {
        didSet { defaults.set(playsSounds, forKey: Key.playsSounds) }
    }

    @ObservationIgnored private let defaults = UserDefaults.standard

    private enum Key {
        static let showsInDock = "showsInDock"
        static let showsMenuBarIcon = "showsMenuBarIcon"
        static let hidesWhenFrontmost = "hidesWhenFrontmost"
        static let playsSounds = "playsSounds"
    }

    init() {
        defaults.register(defaults: [Key.showsMenuBarIcon: true, Key.playsSounds: true])
        showsInDock = defaults.bool(forKey: Key.showsInDock)
        showsMenuBarIcon = defaults.bool(forKey: Key.showsMenuBarIcon)
        hidesWhenFrontmost = defaults.bool(forKey: Key.hidesWhenFrontmost)
        playsSounds = defaults.bool(forKey: Key.playsSounds)
        applyActivationPolicy()
    }

    private func applyActivationPolicy() {
        NSApplication.shared.setActivationPolicy(showsInDock ? .regular : .accessory)
    }
}
