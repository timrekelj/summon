import ServiceManagement
import SwiftUI

struct SettingsView: View {
    static let windowID = "settings"

    @Environment(HotkeyStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(SoundEffects.self) private var sounds
    @State private var rowMidpoints: [AppHotkey.ID: CGFloat] = [:]
    @State private var dropGap: Int?
    @State private var draggingID: AppHotkey.ID?
    @State private var dragPoint: CGPoint = .zero

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            sectionTitle("Shortcuts")
                            Text("\(store.hotkeys.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(.quaternary, in: Capsule())
                        }

                        if store.hotkeys.isEmpty {
                            emptyState
                        } else {
                            shortcutList

                            Text("Click a shortcut to change it. Drag an app to reorder.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("Settings")
                        settingsList
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            }
            .scrollBounceBehavior(.basedOnSize)
            .onChange(of: store.recordingID) { _, id in
                if let id {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea())
        .frame(minWidth: 480, minHeight: 480)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add App…", systemImage: "plus", action: store.addApps)
                    .help("Add an app")
            }
        }
        .onDisappear(perform: store.stopRecording)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            store.stopRecording()
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .padding(.horizontal, 4)
    }

    // MARK: Shortcuts

    private var shortcutList: some View {
        VStack(spacing: 0) {
            ForEach(Array(store.hotkeys.enumerated()), id: \.element.id) { index, hotkey in
                if index > 0 {
                    RowSeparator(isLit: litGap == index)
                }
                HotkeyRow(
                    hotkey: hotkey,
                    isDragging: draggingID == hotkey.id,
                    onDrag: { dragChanged(hotkey.id, to: $0) },
                    onDrop: dragEnded
                )
                    .id(hotkey.id)
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.listSpace)).midY } action: {
                        rowMidpoints[hotkey.id] = $0
                    }
            }
        }
        .overlay(alignment: .top) {
            RowSeparator(isLit: litGap == 0, showsRule: false).padding(.horizontal, 12)
        }
        .overlay(alignment: .bottom) {
            RowSeparator(isLit: litGap == store.hotkeys.count, showsRule: false).padding(.horizontal, 12)
        }
        .coordinateSpace(.named(Self.listSpace))
        .card()
        .overlay(alignment: .topLeading) {
            if let draggingID, let hotkey = store.hotkeys.first(where: { $0.id == draggingID }) {
                DragGhost(hotkey: hotkey)
                    // Keep the cursor over the ghost's icon.
                    .offset(x: dragPoint.x - 24, y: dragPoint.y - 24)
                    // Retargeting a spring keeps its velocity, so fast moves lag, catch up and overshoot.
                    .animation(.spring(response: 0.32, dampingFraction: 0.62), value: dragPoint)
                    .allowsHitTesting(false)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.12), value: dropGap)
    }

    nonisolated static let listSpace = "shortcutList"

    private func dragChanged(_ id: AppHotkey.ID, to point: CGPoint) {
        dragPoint = point
        let newGap = gap(at: point.y)
        if draggingID == nil {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { draggingID = id }
            NSCursor.closedHand.push()
            sounds.play(.pickUp)
        } else if newGap != dropGap {
            sounds.play(.tick)
        }
        dropGap = newGap
    }

    private func dragEnded() {
        guard let draggingID else { return }
        NSCursor.pop()
        sounds.play(.drop)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if let dropGap {
                store.move(draggingID, toGap: dropGap)
            }
            self.draggingID = nil
            dropGap = nil
        }
    }

    /// The gap a drop at `y` lands in: the index of the first row whose middle is below it.
    private func gap(at y: CGFloat) -> Int {
        store.hotkeys.firstIndex { (rowMidpoints[$0.id] ?? .infinity) > y } ?? store.hotkeys.count
    }

    /// Only light gaps where dropping would actually move something.
    private var litGap: Int? {
        guard let dropGap else { return nil }
        if let draggingID, let source = store.hotkeys.firstIndex(where: { $0.id == draggingID }),
           dropGap == source || dropGap == source + 1 {
            return nil
        }
        return dropGap
    }

    // MARK: Settings

    private var settingsList: some View {
        @Bindable var settings = settings

        return VStack(spacing: 0) {
            LaunchAtLoginRow()

            RowSeparator(isLit: false)

            SettingRow(
                "Show in Dock",
                detail: "Also lists Summon in the app switcher.",
                systemImage: "dock.rectangle"
            ) {
                Toggle("Show in Dock", isOn: sounds.clicking($settings.showsInDock))
            }

            RowSeparator(isLit: false)

            SettingRow(
                "Show menu bar icon",
                detail: menuBarDetail,
                systemImage: "menubar.rectangle"
            ) {
                Toggle("Show menu bar icon", isOn: sounds.clicking($settings.showsMenuBarIcon))
            }

            RowSeparator(isLit: false)

            SettingRow(
                "Press again to hide",
                detail: "Using a shortcut while its app is in front hides the app.",
                systemImage: "eye.slash"
            ) {
                Toggle("Press again to hide", isOn: sounds.clicking($settings.hidesWhenFrontmost))
            }

            RowSeparator(isLit: false)

            SettingRow(
                "Sound effects",
                detail: "Soft clicks when you summon, reorder and record.",
                systemImage: settings.playsSounds ? "speaker.wave.2" : "speaker.slash"
            ) {
                Toggle("Sound effects", isOn: sounds.clicking($settings.playsSounds))
            }
        }
        .card()
    }

    private var menuBarDetail: String {
        if settings.showsMenuBarIcon {
            return "Your shortcuts and these settings, one click away."
        }
        return settings.showsInDock
            ? "Click Summon in the Dock to get back here."
            : "Open Summon from Finder or Spotlight to get back here."
    }

    // MARK: Header & empty state

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "command")
                .font(.system(size: 22, weight: .medium))
                .frame(width: 48, height: 48)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Your apps, on call.")
                    .font(.system(size: 22, weight: .semibold))
                Text("Launch or focus. Just a keystroke away.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 20)
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                decorativeKey("⌃", angle: -8)
                decorativeKey("⌘", angle: 0)
                decorativeKey("1", angle: 8)
            }
            .accessibilityHidden(true)
            .padding(.bottom, 22)

            Text("A little shortcut. A lot less clicking.")
                .font(.headline)
                .padding(.bottom, 7)
            Text("Choose an app and give it a key combination.\nIt’s ready whenever you are.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 20)

            Button("Add Your First App…", systemImage: "plus", action: store.addApps)
                .labelStyle(.titleAndIcon)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 28)
        .card()
    }

    private func decorativeKey(_ label: String, angle: Double) -> some View {
        Text(label)
            .font(.system(size: 26, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .frame(width: 52, height: 54)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            .rotationEffect(.degrees(angle))
    }
}

private extension View {
    /// The flat, bordered panel that groups rows together.
    func card() -> some View {
        background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.primary.opacity(0.06))
            }
    }
}

private struct HotkeyRow: View {
    let hotkey: AppHotkey
    let isDragging: Bool
    let onDrag: (CGPoint) -> Void
    let onDrop: () -> Void

    @Environment(HotkeyStore.self) private var store

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(nsImage: hotkey.icon)
                    .resizable()
                    .frame(width: 38, height: 38)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(hotkey.name)
                        .font(.body.weight(.medium))
                    if let error = store.errors[hotkey.id] {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Text(hotkey.combo == nil ? "Set a shortcut to get started" : "Launch or focus")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .help("Drag to reorder")
            .gesture(
                DragGesture(minimumDistance: 3, coordinateSpace: .named(SettingsView.listSpace))
                    .onChanged { onDrag($0.location) }
                    .onEnded { _ in onDrop() }
            )
            .allowsHitTesting(store.recordingID == nil)

            ShortcutRecorder(hotkey: hotkey)

            Menu {
                Button("Change App…") { store.changeApp(for: hotkey.id) }
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([hotkey.resolvedURL ?? hotkey.appURL])
                }
                Button("Clear Shortcut") { store.setCombo(nil, for: hotkey.id) }
                    .disabled(hotkey.combo == nil)
                Divider()
                Button("Remove", role: .destructive) { store.remove(hotkey.id) }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Options for \(hotkey.name)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .opacity(isDragging ? 0.35 : 1)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Launch \(hotkey.name)") { store.launch(hotkey) }
            Button("Change App…") { store.changeApp(for: hotkey.id) }
            Divider()
            Button("Remove", role: .destructive) { store.remove(hotkey.id) }
        }
    }
}

/// The floating copy of a row that springs after the cursor while reordering.
private struct DragGhost: View {
    let hotkey: AppHotkey

    var body: some View {
        Label {
            Text(hotkey.name)
                .font(.body.weight(.medium))
        } icon: {
            Image(nsImage: hotkey.icon)
                .resizable()
                .frame(width: 24, height: 24)
        }
        .padding(12)
        .fixedSize()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.primary.opacity(0.1))
        }
        .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
    }
}

/// A full-width line between rows that lights up where a dragged shortcut will land.
private struct RowSeparator: View {
    let isLit: Bool
    var showsRule = true

    var body: some View {
        Rectangle()
            .fill(showsRule ? Color(nsColor: .separatorColor) : .clear)
            .frame(height: 1)
            .overlay {
                Capsule()
                    .fill(Color.accentColor)
                    .frame(height: 2)
                    .opacity(isLit ? 1 : 0)
            }
            .accessibilityHidden(true)
    }
}

private struct ShortcutRecorder: View {
    let hotkey: AppHotkey

    @Environment(HotkeyStore.self) private var store

    private var isRecording: Bool { store.recordingID == hotkey.id }

    var body: some View {
        let button = Button {
            if isRecording {
                store.cancelRecording()
            } else {
                store.startRecording(hotkey.id)
            }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: hotkey.combo == nil ? .regular : .medium, design: .monospaced))
                .foregroundStyle(hotkey.combo == nil && !isRecording ? .secondary : .primary)
                .frame(minWidth: 100)
                .padding(.vertical, 3)
        }
        .accessibilityLabel("Shortcut for \(hotkey.name)")
        .accessibilityValue(title)
        .help(isRecording ? "Press a shortcut, Esc to cancel, or Delete to clear" : "Click to record a shortcut")

        if isRecording {
            VStack(alignment: .trailing, spacing: 5) {
                button.buttonStyle(.borderedProminent)
                Text("Esc to cancel · Delete to clear")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        } else {
            button.buttonStyle(.bordered)
        }
    }

    private var title: String {
        if isRecording { return "Press keys…" }
        return hotkey.combo?.displayString ?? "Record…"
    }
}

/// One line in the settings card: an icon, a title with a caption, and a control on the right.
private struct SettingRow<Control: View>: View {
    let title: String
    let detail: String
    let systemImage: String
    var isWarning = false
    @ViewBuilder let control: Control

    init(
        _ title: String,
        detail: String,
        systemImage: String,
        isWarning: Bool = false,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
        self.isWarning = isWarning
        self.control = control()
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(isWarning ? Color.orange : .secondary)
            }

            Spacer(minLength: 12)

            control
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct LaunchAtLoginRow: View {
    @Environment(SoundEffects.self) private var sounds
    @State private var isEnabled = SMAppService.mainApp.status == .enabled
    @State private var error: String?

    var body: some View {
        SettingRow(
            "Launch at login",
            detail: error ?? "Your shortcuts, ready when you are.",
            systemImage: "power",
            isWarning: error != nil
        ) {
            Toggle("Launch at login", isOn: sounds.clicking($isEnabled))
        }
        .onChange(of: isEnabled) { _, enabled in
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                error = nil
            } catch {
                self.error = error.localizedDescription
                isEnabled = SMAppService.mainApp.status == .enabled
            }
        }
    }
}
