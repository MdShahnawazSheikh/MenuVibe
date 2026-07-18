import SwiftUI
import AppKit

/// Canonical project links, in one place so they never drift between the About pane,
/// the panel, and the "check for updates" fallback.
enum AppLinks {
    static let repo = URL(string: "https://github.com/MdShahnawazSheikh/MenuVibe")!
    static let issues = URL(string: "https://github.com/MdShahnawazSheikh/MenuVibe/issues")!
    static let releases = URL(string: "https://github.com/MdShahnawazSheikh/MenuVibe/releases")!
    static let license = URL(string: "https://github.com/MdShahnawazSheikh/MenuVibe/blob/main/LICENSE")!
    static let stargazers = URL(string: "https://github.com/MdShahnawazSheikh/MenuVibe/stargazers")!
}

/// A tasteful "Star on GitHub" call-to-action. Uses the accent tint, a filled star,
/// and a gentle hover lift — inviting without being needy, and it opens the repo's
/// star page directly.
struct StarOnGitHubButton: View {
    var compact = false
    @State private var hovering = false

    var body: some View {
        Button {
            NSWorkspace.shared.open(AppLinks.stargazers)
        } label: {
            HStack(spacing: DS.Spacing.snug) {
                Image(systemName: "star.fill")
                    .font(.system(size: compact ? 11 : 12, weight: .semibold))
                    .foregroundStyle(hovering ? .yellow : DS.Color.accent)
                    .scaleEffect(hovering ? 1.12 : 1)
                Text(compact ? "Star" : "Star on GitHub")
                    .font(DS.Font.interactive)
                    .foregroundStyle(DS.Color.primaryLabel)
            }
            .padding(.horizontal, compact ? DS.Spacing.base : DS.Spacing.comfy)
            .frame(height: compact ? 24 : 30)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                    .fill(DS.Color.accent.opacity(hovering ? 0.18 : 0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
                    .strokeBorder(DS.Color.accent.opacity(0.25), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { inside in withAnimation(DS.Motion.quick) { hovering = inside } }
        .help("Enjoying MenuVibe? A star really helps.")
    }
}
