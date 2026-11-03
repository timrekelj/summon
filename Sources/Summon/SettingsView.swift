import ServiceManagement
import SwiftUI

struct SettingsView: View {
    static let windowID = "settings"

    @Environment(HotkeyStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Text("Shortcuts")
                                .font(.headline)
                            Text("\(store.hotkeys.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(.quaternary, in: Capsule())
                            Spacer()
                        }

                        if store.hotkeys.isEmpty {
                            emptyState
                        } else {
                            VStack(spacing: 0) {
                                ForEach(store.hotkeys) { hotkey in
                                    HotkeyRow(hotkey: hotkey)
                                        .id(hotkey.id)
                                    if hotkey.id != store.hotkeys.last?.id {
                                        Divider().padding(.leading, 94)
                                    }
                                }
                            }
                            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(.primary.opacity(0.05))
                            }

                            Label("Click to edit a shortcut. Drag the handle to reorder.", systemImage: "keyboard")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 24)
                }
                .scrollBounceBehavior(.basedOnSize)
                .onChange(of: store.recordingID) { _, id in
                    if let id {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }

            Divider().padding(.horizontal, 28)

            VStack(spacing: 16) {
                LaunchAtLoginToggle()

                Label("Summon lives in your menu bar", systemImage: "menubar.rectangle")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 28)
            .padding(.top, 18)
            .padding(.bottom, 20)
        }
        .background {
            Color(nsColor: .windowBackgroundColor)
                .overlay(alignment: .topLeading) {
                    RadialGradient(
                        colors: [.indigo.opacity(0.09), .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 340
                    )
                }
                .ignoresSafeArea()
        }
        .tint(.indigo)
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

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "command")
                .font(.system(size: 23, weight: .medium))
                .foregroundStyle(.indigo)
                .frame(width: 48, height: 48)
                .glassEffect(.regular.tint(.indigo.opacity(0.12)), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text("Your apps, on call.")
                    .font(.system(size: 22, weight: .semibold))
                Text("Launch or focus. Just a keystroke away.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .padding(.top, 20)
        .padding(.bottom, 28)
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 10) {
                    decorativeKey("⌃", angle: -8)
                    decorativeKey("⌘", angle: 0)
                    decorativeKey("1", angle: 8)
                }
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
                .buttonStyle(.glassProminent)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 28)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.65), in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.primary.opacity(0.05))
        }
    }

    private func decorativeKey(_ label: String, angle: Double) -> some View {
        Text(label)
            .font(.system(size: 27, weight: .medium, design: .rounded))
            .foregroundStyle(.indigo)
            .frame(width: 52, height: 54)
            .glassEffect(.regular.tint(.indigo.opacity(0.06)), in: RoundedRectangle(cornerRadius: 12))
            .rotationEffect(.degrees(angle))
    }
}

private struct HotkeyRow: View {
    let hotkey: AppHotkey

    @Environment(HotkeyStore.self) private var store
    @State private var isDropTarget = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(width: 16, height: 32)
                .contentShape(Rectangle())
                .help("Drag to reorder \(hotkey.name)")
                .accessibilityLabel("Reorder \(hotkey.name)")
                .draggable(ShortcutDrag(id: hotkey.id)) {
                    Label {
                        Text(hotkey.name)
                    } icon: {
                        Image(nsImage: hotkey.icon)
                            .resizable()
                            .frame(width: 24, height: 24)
                    }
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .dragConfiguration(DragConfiguration(
                    operationsWithinApp: .init(allowCopy: false, allowMove: true),
                    operationsOutsideApp: .init(allowCopy: false)
                ))
                .allowsHitTesting(store.recordingID == nil)

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

            Spacer()

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
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Options for \(hotkey.name)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.indigo.opacity(isDropTarget ? 0.12 : 0))
                .padding(4)
        }
        .dropDestination(for: ShortcutDrag.self, isEnabled: store.recordingID == nil) { items, _ in
            guard items.count == 1, let item = items.first else { return }
            store.move(item.id, to: hotkey.id)
            isDropTarget = false
        }
        .dropConfiguration { _ in DropConfiguration(operation: .move) }
        .onDropSessionUpdated { session in
            isDropTarget = session.phase == .entering || session.phase == .active
        }
        .contextMenu {
            Button("Launch \(hotkey.name)") { store.launch(hotkey) }
            Button("Change App…") { store.changeApp(for: hotkey.id) }
            Divider()
            Button("Remove", role: .destructive) { store.remove(hotkey.id) }
        }
    }
}

private struct ShortcutRecorder: View {
    let hotkey: AppHotkey

    @Environment(HotkeyStore.self) private var store

    private var isRecording: Bool { store.recordingID == hotkey.id }

    var body: some View {
        let button = Button {
            if isRecording {
                store.stopRecording()
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
                button.buttonStyle(.glassProminent)
                Text("Esc to cancel · Delete to clear")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        } else {
            button.buttonStyle(.glass)
        }
    }

    private var title: String {
        if isRecording { return "Press keys…" }
        return hotkey.combo?.displayString ?? "Record…"
    }
}

private struct LaunchAtLoginToggle: View {
    @State private var isEnabled = SMAppService.mainApp.status == .enabled
    @State private var error: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "power")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 9))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("Launch at login")
                    .font(.body.weight(.medium))
                Text(error ?? "Your shortcuts, ready when you are.")
                    .font(.caption)
                    .foregroundStyle(error == nil ? Color.secondary : .orange)
            }

            Spacer(minLength: 12)

            Toggle("Launch at login", isOn: $isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
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
