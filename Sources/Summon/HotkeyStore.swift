import AppKit
import Carbon.HIToolbox
import Observation
import UniformTypeIdentifiers

struct AppHotkey: Identifiable, Codable, Equatable {
    var id = UUID()
    var appURL: URL
    var bundleID: String?
    var combo: KeyCombo?

    init(appURL: URL, combo: KeyCombo? = nil) {
        self.appURL = appURL
        self.bundleID = Bundle(url: appURL)?.bundleIdentifier
        self.combo = combo
    }

    var name: String {
        let name = FileManager.default.displayName(atPath: appURL.path)
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }

    /// Follows the app by bundle identifier so it still works if the app moves.
    var resolvedURL: URL? {
        if FileManager.default.fileExists(atPath: appURL.path) { return appURL }
        guard let bundleID else { return nil }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: (resolvedURL ?? appURL).path)
    }
}

@Observable
final class HotkeyStore {
    private(set) var hotkeys: [AppHotkey] = []
    private(set) var errors: [AppHotkey.ID: String] = [:]
    private(set) var recordingID: AppHotkey.ID?

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let sounds: SoundEffects
    @ObservationIgnored private let center = HotkeyCenter()
    @ObservationIgnored private var recordingMonitor: Any?
    @ObservationIgnored private let defaultsKey = "hotkeys"

    init(settings: AppSettings, sounds: SoundEffects) {
        self.settings = settings
        self.sounds = sounds
        center.onTrigger = { [weak self] id in
            guard let self, let hotkey = hotkeys.first(where: { $0.id == id }) else { return }
            launch(hotkey)
        }
        load()
        registerAll()
    }

    // MARK: Editing

    func addApps() {
        let panel = NSOpenPanel()
        panel.title = "Choose Apps"
        panel.prompt = "Add"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(filePath: "/Applications")
        NSApp.activate()
        guard panel.runModal() == .OK else { return }

        let added = panel.urls.map { AppHotkey(appURL: $0) }
        hotkeys.append(contentsOf: added)
        save()
        if let first = added.first {
            startRecording(first.id)
        }
    }

    func changeApp(for id: AppHotkey.ID) {
        guard let index = hotkeys.firstIndex(where: { $0.id == id }) else { return }
        let panel = NSOpenPanel()
        panel.title = "Choose App"
        panel.prompt = "Choose"
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(filePath: "/Applications")
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }

        var updated = AppHotkey(appURL: url, combo: hotkeys[index].combo)
        updated.id = id
        hotkeys[index] = updated
        save()
        registerAll()
    }

    func remove(_ id: AppHotkey.ID) {
        if recordingID == id { stopRecording() }
        hotkeys.removeAll { $0.id == id }
        save()
        registerAll()
    }

    /// Moves a shortcut into the gap before the row at `gap` (`hotkeys.count` is after the last row).
    func move(_ id: AppHotkey.ID, toGap gap: Int) {
        guard let source = hotkeys.firstIndex(where: { $0.id == id }),
              gap != source, gap != source + 1
        else { return }

        let hotkey = hotkeys.remove(at: source)
        hotkeys.insert(hotkey, at: gap > source ? gap - 1 : gap)
        save()
    }

    func setCombo(_ combo: KeyCombo?, for id: AppHotkey.ID) {
        guard let index = hotkeys.firstIndex(where: { $0.id == id }) else { return }
        // A shortcut can only launch one app, so take it away from any other row.
        if let combo {
            for other in hotkeys.indices where other != index && hotkeys[other].combo == combo {
                hotkeys[other].combo = nil
            }
        }
        hotkeys[index].combo = combo
        save()
        // While recording, hotkeys are re-registered once recording stops.
        if recordingID == nil {
            registerAll()
        }
    }

    // MARK: Recording

    func startRecording(_ id: AppHotkey.ID) {
        stopRecording()
        recordingID = id
        sounds.play(.recordStart)
        // Global hotkeys would swallow the keys being recorded.
        center.unregisterAll()
        recordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleRecording(event)
            return nil
        }
    }

    func stopRecording() {
        if let recordingMonitor {
            NSEvent.removeMonitor(recordingMonitor)
        }
        recordingMonitor = nil
        guard recordingID != nil else { return }
        recordingID = nil
        registerAll()
    }

    private func handleRecording(_ event: NSEvent) {
        guard let recordingID else { return }
        let combo = KeyCombo(event: event)

        if combo.modifiers == 0 {
            switch Int(event.keyCode) {
            case kVK_Escape:
                cancelRecording()
                return
            case kVK_Delete, kVK_ForwardDelete:
                setCombo(nil, for: recordingID)
                stopRecording()
                sounds.play(.recordClear)
                return
            default:
                break
            }
        }

        guard combo.isValid else {
            sounds.play(.invalid)
            return
        }
        setCombo(combo, for: recordingID)
        stopRecording()
        sounds.play(.recorded)
    }

    /// Stops recording because the user backed out, as opposed to the window closing.
    func cancelRecording() {
        stopRecording()
        sounds.play(.recordCancel)
    }

    // MARK: Launching

    func launch(_ hotkey: AppHotkey) {
        guard let url = hotkey.resolvedURL else {
            errors[hotkey.id] = "App not found"
            sounds.play(.invalid)
            return
        }
        if settings.hidesWhenFrontmost,
           let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.bundleURL == url || (hotkey.bundleID != nil && frontmost.bundleIdentifier == hotkey.bundleID) {
            frontmost.hide()
            sounds.play(.hide)
            return
        }
        sounds.play(.summon)
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        // Launches the app if needed, otherwise brings it forward (and reopens a window if it has none).
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            guard let error else { return }
            Task { @MainActor in
                self.errors[hotkey.id] = error.localizedDescription
            }
        }
    }

    // MARK: Registration

    private func registerAll() {
        center.unregisterAll()
        var errors: [AppHotkey.ID: String] = [:]
        for hotkey in hotkeys {
            if hotkey.resolvedURL == nil {
                errors[hotkey.id] = "App not found"
            }
            guard let combo = hotkey.combo else { continue }
            let status = center.register(combo, for: hotkey.id)
            switch status {
            case noErr:
                break
            case OSStatus(eventHotKeyExistsErr):
                errors[hotkey.id] = "\(combo.displayString) is already used by another app"
            default:
                errors[hotkey.id] = "Couldn't register \(combo.displayString) (error \(status))"
            }
        }
        self.errors = errors
    }

    // MARK: Persistence

    private func load() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: defaultsKey),
           let saved = try? JSONDecoder().decode([AppHotkey].self, from: data) {
            hotkeys = saved
            return
        }

        // First launch: start with Ghostty on ⌃⌘1 if it's installed.
        if let ghostty = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.mitchellh.ghostty") {
            hotkeys = [AppHotkey(appURL: ghostty, combo: KeyCombo(keyCode: UInt32(kVK_ANSI_1), modifiers: UInt32(controlKey | cmdKey)))]
        }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(hotkeys) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
