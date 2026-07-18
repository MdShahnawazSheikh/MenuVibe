cask "menuvibe" do
  version "1.2.0"
  sha256 "7072bf79f4c5ea2834b466ca7edaca22c00f6217410ac8f7e1d2abd763b6d690"

  url "https://github.com/MdShahnawazSheikh/MenuVibe/releases/download/v#{version}/MenuVibe.dmg",
      verified: "github.com/MdShahnawazSheikh/MenuVibe/"
  name "MenuVibe"
  desc "Menu bar suite: clipboard history, window snapping, and quick notes"
  homepage "https://github.com/MdShahnawazSheikh/MenuVibe"

  # No auto-update yet (Sparkle is on the roadmap); Homebrew handles upgrades.
  auto_updates false
  depends_on macos: :ventura

  app "MenuVibe.app"

  # Release builds are ad-hoc signed (notarization needs a paid Apple Developer ID,
  # which is on the roadmap). Without this, Gatekeeper shows the scary
  # "Apple could not verify MenuVibe" dialog and — on macOS 15+ — there is no longer a
  # right-click → Open bypass. Since this is a trusted first-party tap, we strip the
  # quarantine flag on install so `brew install --cask menuvibe` opens cleanly and the
  # Accessibility grant sticks. Remove this once notarized builds ship.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/MenuVibe.app"],
                   sudo: false
  end

  zap trash: [
    "~/Library/Application Support/MenuVibe",
    "~/Library/Preferences/app.menuvibe.MenuVibe.plist",
  ]

  caveats <<~EOS
    MenuVibe uses Accessibility (for window snapping). Grant it in
    System Settings › Privacy & Security › Accessibility on first run.

    Release builds are ad-hoc signed (notarization is on the roadmap). This cask
    already clears the quarantine flag for you, so MenuVibe should open normally.
    If you ever move it manually and macOS still blocks it, run:

      xattr -dr com.apple.quarantine "/Applications/MenuVibe.app"
  EOS
end
