import SwiftUI

/// The 3-screen first-run tour (spec §9): what MenuVibe is, why it needs Accessibility
/// (with the reason shown *before* the system prompt), and the default hotkeys so the
/// user isn't left guessing.
struct OnboardingView: View {
    let snapper: WindowSnapper
    @ObservedObject var hotKeys: HotKeyCenter
    let onFinish: () -> Void

    @State private var step = 0
    private let steps = 3

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))
                .id(step)
            footer
        }
        .frame(width: 460, height: 520)
        .background(VisualEffectBackground(material: .windowBackground))
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0: welcome
        case 1: permission
        default: shortcuts
        }
    }

    // MARK: Screen 1 — welcome

    private var welcome: some View {
        VStack(spacing: DS.Spacing.section) {
            Spacer()
            Image(nsImage: MenuBarIcon.image(for: .layers))
                .resizable().frame(width: 56, height: 56)
                .foregroundStyle(DS.Color.primaryLabel)
            VStack(spacing: DS.Spacing.snug) {
                Text("Welcome to MenuVibe")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(DS.Color.primaryLabel)
                Text("Three tools that live in your menu bar.")
                    .font(DS.Font.rowTitle)
                    .foregroundStyle(DS.Color.secondaryLabel)
            }
            VStack(alignment: .leading, spacing: DS.Spacing.comfy) {
                featureRow("doc.on.clipboard", "Clipboard history",
                           "Everything you copy, searchable and one click away.")
                featureRow("square.split.2x2", "Window snapping",
                           "Halves, thirds, and multi-display moves by keyboard.")
                featureRow("note.text", "Quick notes",
                           "A Markdown scratchpad that's always a keystroke away.")
            }
            .padding(.horizontal, DS.Spacing.section)
            Spacer()
        }
        .padding(DS.Spacing.section)
    }

    private func featureRow(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.comfy) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(DS.Color.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(DS.Font.rowTitleEmph).foregroundStyle(DS.Color.primaryLabel)
                Text(detail).font(DS.Font.caption).foregroundStyle(DS.Color.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Screen 2 — permission (reason first, prompt second — spec §9)

    private var permission: some View {
        VStack(spacing: DS.Spacing.section) {
            Spacer()
            Image(systemName: "lock.shield")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(DS.Color.accent)
            VStack(spacing: DS.Spacing.snug) {
                Text("Enable window snapping")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DS.Color.primaryLabel)
                Text("To move and resize other apps' windows, macOS requires Accessibility access. MenuVibe uses it only for snapping — nothing else, and nothing leaves your Mac.")
                    .font(DS.Font.rowTitle)
                    .foregroundStyle(DS.Color.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, DS.Spacing.section)
            }
            VStack(spacing: DS.Spacing.base) {
                Button("Grant Accessibility Access") {
                    snapper.requestAccessibilityPermission()
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("Open System Settings") {
                    snapper.openAccessibilitySettings()
                }
                .buttonStyle(.plain)
                .font(DS.Font.interactive)
                .foregroundStyle(DS.Color.accent)
                Text("You can skip this and enable it later in Settings.")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.tertiaryLabel)
            }
            Spacer()
        }
        .padding(DS.Spacing.section)
    }

    // MARK: Screen 3 — default shortcuts

    private var shortcuts: some View {
        VStack(spacing: DS.Spacing.comfy) {
            Spacer()
            Image(systemName: "keyboard")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(DS.Color.accent)
            Text("Your shortcuts")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(DS.Color.primaryLabel)
            Text("These are the defaults — remap any of them in Settings.")
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.secondaryLabel)

            VStack(spacing: 0) {
                shortcutRow("Summon MenuVibe", hotKeys.combo(for: .summonPanel).displayString)
                DSDivider()
                shortcutRow("Open Quick Note", hotKeys.combo(for: .quickNote).displayString)
                DSDivider()
                shortcutRow("Snap Left / Right Half",
                            "\(hotKeys.combo(for: .snapLeftHalf).displayString)  \(hotKeys.combo(for: .snapRightHalf).displayString)")
                DSDivider()
                shortcutRow("Fullscreen", hotKeys.combo(for: .snapFullscreen).displayString)
            }
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.panel, style: .continuous)
                    .fill(DS.Color.primaryLabel.opacity(0.04))
            )
            .padding(.horizontal, DS.Spacing.section)
            Spacer()
        }
        .padding(DS.Spacing.section)
    }

    private func shortcutRow(_ title: String, _ combo: String) -> some View {
        HStack {
            Text(title).font(DS.Font.rowTitle).foregroundStyle(DS.Color.primaryLabel)
            Spacer()
            Text(combo)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(DS.Color.secondaryLabel)
        }
        .padding(.horizontal, DS.Spacing.comfy)
        .frame(height: 38)
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            // Page dots
            HStack(spacing: DS.Spacing.snug) {
                ForEach(0..<steps, id: \.self) { i in
                    Circle()
                        .fill(i == step ? DS.Color.accent : DS.Color.tertiaryLabel.opacity(0.4))
                        .frame(width: 6, height: 6)
                }
            }
            Spacer()
            if step > 0 {
                Button("Back") { withAnimation(DS.Motion.spring) { step -= 1 } }
                    .buttonStyle(.plain)
                    .font(DS.Font.interactive)
                    .foregroundStyle(DS.Color.secondaryLabel)
            }
            Button(step == steps - 1 ? "Get Started" : "Continue") {
                if step == steps - 1 {
                    onFinish()
                } else {
                    withAnimation(DS.Motion.spring) { step += 1 }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(DS.Spacing.loose)
    }
}

/// The single filled/accented primary button used sparingly for the main action on a
/// screen (spec §2 — one accent, used for primary actions only).
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Font.interactive)
            .foregroundStyle(.white)
            .padding(.horizontal, DS.Spacing.loose)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                    .fill(DS.Color.accent.opacity(configuration.isPressed ? 0.8 : 1))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(DS.Motion.quick, value: configuration.isPressed)
    }
}
