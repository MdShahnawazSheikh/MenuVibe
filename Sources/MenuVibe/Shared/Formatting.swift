import Foundation
import AppKit
import SwiftUI

/// Small presentation helpers shared across features.
enum Format {
    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    /// "just now" / "2m ago" / "3h ago" — the compact right-aligned timestamp used in
    /// the clipboard list (spec §4).
    static func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 45 { return "just now" }
        return relative.localizedString(for: date, relativeTo: Date())
    }
}

/// Fetches and memoises app icons by bundle identifier, so clipboard rows can show
/// the source app's icon without hitting the workspace on every redraw (spec §4).
enum AppIconProvider {
    private static var cache = NSCache<NSString, NSImage>()

    static func icon(forBundleID bundleID: String?) -> NSImage? {
        guard let bundleID else { return nil }
        if let cached = cache.object(forKey: bundleID as NSString) { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 16, height: 16)
        cache.setObject(icon, forKey: bundleID as NSString)
        return icon
    }
}

/// A lightweight subsequence fuzzy match — "the letters of `query` appear in order
/// somewhere in `text`." Case-insensitive, diacritic-insensitive. Good enough for a
/// real-time filter over a few dozen rows without a scoring dependency (spec §4).
enum Fuzzy {
    static func matches(_ query: String, in text: String) -> Bool {
        let q = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        guard !q.isEmpty else { return true }
        let t = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        var qi = q.startIndex
        for ch in t {
            if ch == q[qi] {
                qi = q.index(after: qi)
                if qi == q.endIndex { return true }
            }
        }
        return false
    }
}
