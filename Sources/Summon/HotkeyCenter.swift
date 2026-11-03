import Carbon.HIToolbox
import Foundation

/// Registers system-wide hotkeys through Carbon, which doesn't need Accessibility permissions.
final class HotkeyCenter {
    var onTrigger: ((UUID) -> Void)?

    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var ids: [UInt32: UUID] = [:]
    private var nextID: UInt32 = 1
    private static let signature: OSType = 0x534D_4F4E // "SMON"

    init() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return status }
                // Carbon delivers hotkey events on the main thread.
                MainActor.assumeIsolated {
                    let center = Unmanaged<HotkeyCenter>.fromOpaque(userData).takeUnretainedValue()
                    center.fire(hotKeyID.id)
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            nil
        )
    }

    func register(_ combo: KeyCombo, for id: UUID) -> OSStatus {
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: nextID)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(combo.keyCode, combo.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref {
            refs[nextID] = ref
            ids[nextID] = id
            nextID += 1
        }
        return status
    }

    func unregisterAll() {
        for ref in refs.values {
            UnregisterEventHotKey(ref)
        }
        refs.removeAll()
        ids.removeAll()
    }

    private func fire(_ hotKeyID: UInt32) {
        guard let id = ids[hotKeyID] else { return }
        onTrigger?(id)
    }
}
