import Foundation

/// Centralizes MenuVibe's on-disk locations under Application Support. Everything the
/// app persists lives here so it is easy to reason about, back up, or delete — and
/// so nothing is ever written somewhere surprising (spec §4, §6).
enum AppPaths {
    static let folderName = "MenuVibe"

    /// ~/Library/Application Support/MenuVibe/
    static var support: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent(folderName, isDirectory: true)
        ensureDirectory(dir)
        return dir
    }

    /// Clipboard index (JSON) — small metadata records only.
    static var clipboardIndex: URL {
        support.appendingPathComponent("clipboard.json", isDirectory: false)
    }

    /// Full-resolution clipboard image payloads live here, one file per image.
    static var clipboardImages: URL {
        let dir = support.appendingPathComponent("ClipboardImages", isDirectory: true)
        ensureDirectory(dir)
        return dir
    }

    /// The single Quick Notes scratchpad — a plain, human-readable Markdown file so
    /// power users can sync it themselves (spec §6).
    static var quickNote: URL {
        support.appendingPathComponent("quicknote.md", isDirectory: false)
    }

    private static func ensureDirectory(_ url: URL) {
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
