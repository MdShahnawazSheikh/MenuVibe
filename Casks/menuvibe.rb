cask "menuvibe" do
  version "1.2.0"
  sha256 "8b3f83fa495f1d5008211ab6c911dfcbd4f430e88e697dd31d9907c9936d834d"

  url "https://github.com/MdShahnawazSheikh/MenuVibe/releases/download/v#{version}/MenuVibe.dmg",
      verified: "github.com/MdShahnawazSheikh/MenuVibe/"
  name "MenuVibe"
  desc "Menu bar suite: clipboard history, window snapping, and quick notes"
  homepage "https://github.com/MdShahnawazSheikh/MenuVibe"

  # No auto-update yet (Sparkle is on the roadmap); Homebrew handles upgrades.
  auto_updates false
  depends_on macos: :ventura

  app "MenuVibe.app"

  zap trash: [
    "~/Library/Application Support/MenuVibe",
    "~/Library/Preferences/app.menuvibe.MenuVibe.plist",
  ]

  caveats <<~EOS
    MenuVibe uses Accessibility (for window snapping). Grant it in
    System Settings › Privacy & Security › Accessibility on first run.

    Release builds are currently ad-hoc signed (not yet notarized). If macOS
    refuses to open the app, or if Accessibility keeps asking for access even
    after you grant it (the app is running from a quarantined location), run:

      xattr -dr com.apple.quarantine "/Applications/MenuVibe.app"

    then reopen MenuVibe and grant Accessibility once — it will stick.
  EOS
end
