import SwiftUI
import AppKit
import Carbon.HIToolbox

/// A proper "click to record" shortcut field (spec §8) — not a text box you type a
/// combo into. Click it, press the desired chord, and it rebinds the slot live. While
/// recording it swallows key events so the chord doesn't leak to the app underneath.
struct ShortcutRecorderField: View {
    let id: ShortcutID
    @ObservedObject var hotKeys: HotKeyCenter

    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var errorFlash = false

    var body: some View {
        Button(action: toggleRecording) {
            HStack(spacing: DS.Spacing.snug) {
                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(labelColor)
                    .frame(minWidth: 64)
                if isRecording {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, DS.Spacing.base)
            .frame(height: 26)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                    .strokeBorder(isRecording ? DS.Color.accent : DS.Color.separator,
                                  lineWidth: isRecording ? 1.5 : 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isRecording ? "Press a shortcut, or Esc to cancel" : "Click to record a shortcut")
        .contextMenu {
            Button("Reset to Default") {
                hotKeys.resetToDefault(id)
            }
        }
        .onDisappear(perform: stopRecording)
    }

    private var label: String {
        if isRecording { return "Recording…" }
        return hotKeys.combo(for: id).displayString
    }

    private var labelColor: Color {
        if errorFlash { return .red }
        return isRecording ? DS.Color.accent : DS.Color.primaryLabel
    }

    private var background: Color {
        if isRecording { return DS.Color.accent.opacity(0.12) }
        return DS.Color.primaryLabel.opacity(0.05)
    }

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            guard event.type == .keyDown else { return nil }

            if event.keyCode == UInt16(kVK_Escape) {
                stopRecording()
                return nil
            }

            let combo = KeyCombo(keyCode: event.keyCode, nsModifiers: event.modifierFlags)
            guard combo.hasRequiredModifier else {
                flashError()
                return nil // a bare key is not a valid global shortcut
            }

            if hotKeys.rebind(id, to: combo) {
                stopRecording()
            } else {
                flashError() // clashes with another slot
            }
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
    }

    private func flashError() {
        withAnimation { errorFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation { errorFlash = false }
        }
    }
}
