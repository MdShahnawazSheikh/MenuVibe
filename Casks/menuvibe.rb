cask "menuvibe" do
  version "1.1.0"
  sha256 "393abd6e5481eb5bf6f2ec53783ec92c056fba5afcffde466148b33796b4b023"

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
    refuses to open the app, either right-click it and choose Open, or run:

      xattr -dr com.apple.quarantine "/Applications/MenuVibe.app"
  EOS
end
