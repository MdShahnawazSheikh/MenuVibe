import Foundation
import Carbon.HIToolbox
import Combine

/// Registers system-wide hotkeys via the Carbon Event Manager and dispatches them
/// to Swift callbacks on the main thread.
///
/// Carbon's `RegisterEventHotKey` is used deliberately: it is the only API that fires
/// reliably when MenuVibe is *not* the frontmost app (spec §3). AppKit local monitors
/// and SwiftUI `.keyboardShortcut` do not qualify, and `CGEventTap` requires the same
/// Accessibility grant we would rather reserve for window snapping alone.
final class HotKeyCenter: ObservableObject {
    static let shared = HotKeyCenter()

    /// The user's current binding for each slot, published so the settings UI updates live.
    @Published private(set) var bindings: [ShortcutID: KeyCombo] = [:]

    private var handlers: [ShortcutID: () -> Void] = [:]
    private var registered: [UInt32: (id: ShortcutID, ref: EventHotKeyRef)] = [:]
    private var nextHotKeyID: UInt32 = 1
    private var eventHandler: EventHandlerRef?
    private let signature: OSType = 0x4D_56_69_62 // 'MVib'

    private let defaultsKey = "shortcutBindings"

    private init() {
        loadBindings()
        installEventHandler()
    }

    // MARK: Public API

    /// Attach the action to run when a slot fires. Registration happens lazily via
    /// `activate()` once all handlers are wired at launch.
    func setHandler(for id: ShortcutID, _ action: @escaping () -> Void) {
        handlers[id] = action
    }

    /// Register (or re-register) every known binding with the system.
    func activate() {
        for id in ShortcutID.allCases {
            register(id: id, combo: bindings[id] ?? id.defaultCombo)
        }
    }

    /// Change a binding and immediately re-register it. Returns `false` (without
    /// changing anything) if the combo is already claimed by another slot.
    @discardableResult
    func rebind(_ id: ShortcutID, to combo: KeyCombo) -> Bool {
        if let clash = bindings.first(where: { $0.key != id && $0.value == combo }) {
            NSLog("MenuVibe: refusing to bind \(id.rawValue) — combo already used by \(clash.key.rawValue)")
            return false
        }
        bindings[id] = combo
        persistBindings()
        register(id: id, combo: combo)
        return true
    }

    /// Restore a single slot to its shipped default.
    func resetToDefault(_ id: ShortcutID) {
        rebind(id, to: id.defaultCombo)
    }

    func combo(for id: ShortcutID) -> KeyCombo {
        bindings[id] ?? id.defaultCombo
    }

    // MARK: Registration

    private func register(id: ShortcutID, combo: KeyCombo) {
        // Tear down any existing registration for this slot first.
        if let existing = registered.first(where: { $0.value.id == id }) {
            UnregisterEventHotKey(existing.value.ref)
            registered[existing.key] = nil
        }

        let hotKeyID = EventHotKeyID(signature: signature, id: nextHotKeyID)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            combo.keyCode,
            combo.modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else {
            NSLog("MenuVibe: RegisterEventHotKey failed for \(id.rawValue) (status \(status))")
            return
        }
        registered[nextHotKeyID] = (id, ref)
        nextHotKeyID += 1
    }

    private func installEventHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetEventDispatcherTarget(), { _, event, userData -> OSStatus in
            guard let userData, let event else { return OSStatus(eventNotHandledErr) }
            let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard status == noErr else { return status }
            center.fire(hotKeyID.id)
            return noErr
        }, 1, &spec, selfPtr, &eventHandler)
    }

    private func fire(_ rawID: UInt32) {
        guard let entry = registered[rawID], let action = handlers[entry.id] else { return }
        DispatchQueue.main.async(execute: action)
    }

    // MARK: Persistence

    private func loadBindings() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([String: KeyCombo].self, from: data)
        else { return }
        for (raw, combo) in decoded {
            if let id = ShortcutID(rawValue: raw) { bindings[id] = combo }
        }
    }

    private func persistBindings() {
        let encodable = Dictionary(uniqueKeysWithValues: bindings.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(encodable) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
