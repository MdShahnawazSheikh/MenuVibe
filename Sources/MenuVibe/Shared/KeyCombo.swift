import Foundation
import Carbon.HIToolbox
import AppKit

/// A single global shortcut: a virtual key code plus Carbon modifier flags.
/// Codable so shortcuts persist, Equatable so the recorder can detect conflicts.
struct KeyCombo: Codable, Equatable, Hashable {
    /// Virtual key code (kVK_*), independent of keyboard layout.
    let keyCode: UInt32
    /// Carbon modifier mask (cmdKey, optionKey, controlKey, shiftKey).
    let modifiers: UInt32

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Build from an AppKit event's `keyCode` + `NSEvent.ModifierFlags`.
    init(keyCode: UInt16, nsModifiers: NSEvent.ModifierFlags) {
        self.keyCode = UInt32(keyCode)
        var carbon: UInt32 = 0
        if nsModifiers.contains(.command) { carbon |= UInt32(cmdKey) }
        if nsModifiers.contains(.option)  { carbon |= UInt32(optionKey) }
        if nsModifiers.contains(.control) { carbon |= UInt32(controlKey) }
        if nsModifiers.contains(.shift)   { carbon |= UInt32(shiftKey) }
        self.modifiers = carbon
    }

    /// A human-readable rendering using the standard macOS glyphs (⌘⌥⌃⇧ + key).
    var displayString: String {
        var parts = ""
        if modifiers & UInt32(controlKey) != 0 { parts += "⌃" }
        if modifiers & UInt32(optionKey)  != 0 { parts += "⌥" }
        if modifiers & UInt32(shiftKey)   != 0 { parts += "⇧" }
        if modifiers & UInt32(cmdKey)     != 0 { parts += "⌘" }
        parts += KeyCombo.keyName(for: keyCode)
        return parts
    }

    /// Whether the combo carries at least one non-shift modifier. Global hotkeys
    /// without a real modifier are almost always a mistake, so the recorder rejects them.
    var hasRequiredModifier: Bool {
        modifiers & (UInt32(cmdKey) | UInt32(optionKey) | UInt32(controlKey)) != 0
    }

    private static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_Escape: return "⎋"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        default:
            // Resolve the printable character for the current keyboard layout.
            if let char = Self.character(for: keyCode) { return char.uppercased() }
            return "key\(keyCode)"
        }
    }

    /// Translate a virtual key code to its printable character using the active
    /// input source, so QWERTY/AZERTY/Dvorak users see the right letter.
    private static func character(for keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }

        let data = Unmanaged<CFData>.fromOpaque(layoutData).takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0

        let status = data.withUnsafeBytes { raw -> OSStatus in
            guard let ptr = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return -1 }
            return UCKeyTranslate(
                ptr,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &length,
                &chars
            )
        }
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length)
    }
}

// MARK: - Named shortcut slots

/// Every remappable shortcut in the app, addressed by a stable identifier. The
/// hotkey center registers one Carbon handler per slot and the settings UI edits them.
enum ShortcutID: String, CaseIterable, Codable {
    // Global summon / feature launchers
    case summonPanel
    case quickNote

    // Window snapping (Rectangle-style defaults, spec §5)
    case snapLeftHalf
    case snapRightHalf
    case snapTopHalf
    case snapBottomHalf
    case snapFullscreen
    case snapCenter
    case snapLeftThird
    case snapCenterThird
    case snapRightThird
    case snapNextDisplay

    var title: String {
        switch self {
        case .summonPanel:    return "Summon MenuVibe"
        case .quickNote:      return "Open Quick Note"
        case .snapLeftHalf:   return "Left Half"
        case .snapRightHalf:  return "Right Half"
        case .snapTopHalf:    return "Top Half"
        case .snapBottomHalf: return "Bottom Half"
        case .snapFullscreen: return "Fullscreen"
        case .snapCenter:     return "Center"
        case .snapLeftThird:  return "Left Third"
        case .snapCenterThird:return "Center Third"
        case .snapRightThird: return "Right Third"
        case .snapNextDisplay:return "Move to Next Display"
        }
    }

    /// The shipped default combo for this slot.
    var defaultCombo: KeyCombo {
        let ctrlOpt = UInt32(controlKey | optionKey)
        let cmdShift = UInt32(cmdKey | shiftKey)
        switch self {
        case .summonPanel:    return KeyCombo(keyCode: UInt32(kVK_Space), modifiers: cmdShift)
        // ⌃⌘N, deliberately NOT ⌘⇧N — that is macOS's system-wide "New Folder" and
        // clashes in Finder and many apps. Control+Command+N is unclaimed system-wide.
        case .quickNote:      return KeyCombo(keyCode: UInt32(kVK_ANSI_N), modifiers: UInt32(controlKey | cmdKey))
        case .snapLeftHalf:   return KeyCombo(keyCode: UInt32(kVK_LeftArrow), modifiers: ctrlOpt)
        case .snapRightHalf:  return KeyCombo(keyCode: UInt32(kVK_RightArrow), modifiers: ctrlOpt)
        case .snapTopHalf:    return KeyCombo(keyCode: UInt32(kVK_UpArrow), modifiers: ctrlOpt)
        case .snapBottomHalf: return KeyCombo(keyCode: UInt32(kVK_DownArrow), modifiers: ctrlOpt)
        case .snapFullscreen: return KeyCombo(keyCode: UInt32(kVK_Return), modifiers: ctrlOpt)
        case .snapCenter:     return KeyCombo(keyCode: UInt32(kVK_ANSI_C), modifiers: ctrlOpt)
        case .snapLeftThird:  return KeyCombo(keyCode: UInt32(kVK_ANSI_D), modifiers: ctrlOpt)
        case .snapCenterThird:return KeyCombo(keyCode: UInt32(kVK_ANSI_F), modifiers: ctrlOpt)
        case .snapRightThird: return KeyCombo(keyCode: UInt32(kVK_ANSI_G), modifiers: ctrlOpt)
        case .snapNextDisplay:return KeyCombo(keyCode: UInt32(kVK_ANSI_N), modifiers: UInt32(controlKey | optionKey))
        }
    }
}
