import Foundation
import AppKit
import Combine

/// Watches the general pasteboard and maintains the de-duplicated, size-bounded
/// history that the Clipboard tab renders.
///
/// Design notes tied to the spec:
///   • Polls `changeCount` on a 0.5s timer rather than anything more aggressive, to
///     stay inside the idle-CPU budget (§4, §10). NSPasteboard has no change
///     notification, so polling is the only option — but 0.5s is imperceptible and
///     nearly free because we only read the board when the counter actually moves.
///   • Skips anything a password manager marked concealed/transient (§4 privacy).
///   • De-duplicates by payload, moving repeats to the top instead of duplicating.
///   • Pinned items live forever and are never trimmed.
final class ClipboardManager: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []

    private let store = ClipboardStore()
    private let preferences: Preferences
    private var timer: Timer?
    private var lastChangeCount: Int
    private var thumbnailCache = NSCache<NSString, NSImage>()
    private var cancellables = Set<AnyCancellable>()

    /// UTIs that password managers set to signal "do not persist this copy."
    private static let concealedTypes: [NSPasteboard.PasteboardType] = [
        NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"),
        NSPasteboard.PasteboardType("org.nspasteboard.TransientType"),
        NSPasteboard.PasteboardType("com.agilebits.onepassword"),
        NSPasteboard.PasteboardType("com.apple.is-sensitive")
    ]

    init(preferences: Preferences) {
        self.preferences = preferences
        self.lastChangeCount = NSPasteboard.general.changeCount
        thumbnailCache.countLimit = 120

        items = store.load()

        // Re-trim if the user lowers the history limit in Settings.
        preferences.$clipboardHistoryLimit
            .dropFirst()
            .sink { [weak self] _ in self?.trimAndPersist() }
            .store(in: &cancellables)
    }

    // MARK: Lifecycle

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
        // .common so polling continues while the user is dragging/tracking menus.
        RunLoop.main.add(timer, forMode: .common)
        timer.tolerance = 0.15 // let the OS coalesce our wakeups — kinder to the CPU budget
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit { stop() }

    // MARK: Polling

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        // Respect password-manager privacy flags — never store these (§4).
        if let types = pb.types, Self.concealedTypes.contains(where: types.contains) {
            return
        }

        guard let item = captureCurrent(pb) else { return }
        insert(item)
    }

    /// Build a `ClipboardItem` from whatever is on the board, richest type first.
    private func captureCurrent(_ pb: NSPasteboard) -> ClipboardItem? {
        let source = NSWorkspace.shared.frontmostApplication
        let bundleID = source?.bundleIdentifier
        let appName = source?.localizedName

        // File URLs take priority so "copy in Finder" is recognised as a file, not text.
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let first = urls.first {
            return ClipboardItem(kind: .fileURL, text: first.absoluteString,
                                 sourceBundleID: bundleID, sourceAppName: appName)
        }

        // Images.
        if let image = NSImage(pasteboard: pb), pb.data(forType: .png) != nil || pb.data(forType: .tiff) != nil {
            guard let filename = store.writeImage(image) else { return nil }
            return ClipboardItem(kind: .image, imageFilename: filename,
                                 sourceBundleID: bundleID, sourceAppName: appName)
        }

        // Rich text (keep RTF so formatting survives a round-trip).
        if let rtf = pb.data(forType: .rtf),
           let attributed = try? NSAttributedString(data: rtf, options: [:], documentAttributes: nil) {
            let plain = attributed.string
            guard !plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return ClipboardItem(kind: .richText, text: plain, rtfData: rtf,
                                 sourceBundleID: bundleID, sourceAppName: appName)
        }

        // Plain text.
        if let text = pb.string(forType: .string),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ClipboardItem(kind: .text, text: text,
                                 sourceBundleID: bundleID, sourceAppName: appName)
        }

        return nil
    }

    // MARK: Mutation

    private func insert(_ item: ClipboardItem) {
        // De-duplicate: if the same payload already exists, lift it to the top and
        // refresh its timestamp instead of adding a copy (§4).
        if let idx = items.firstIndex(where: { $0.hasSamePayload(as: item) }) {
            var existing = items.remove(at: idx)
            existing.createdAt = Date()
            items.insert(existing, at: 0)
            // Discard the freshly written image; the original file is still referenced.
            if let orphan = item.imageFilename { store.deleteImage(filename: orphan) }
        } else {
            items.insert(item, at: 0)
        }
        trimAndPersist()
    }

    func togglePin(_ item: ClipboardItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].isPinned.toggle()
        // Re-sort so pins float above the timeline, each group newest-first.
        items.sort { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.createdAt > rhs.createdAt
        }
        trimAndPersist()
    }

    func delete(_ item: ClipboardItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        let removed = items.remove(at: idx)
        if let filename = removed.imageFilename { store.deleteImage(filename: filename) }
        trimAndPersist()
    }

    func clearHistory() {
        // Pinned items are intentionally preserved by "Clear History".
        let kept = items.filter { $0.isPinned }
        for removed in items where !removed.isPinned {
            if let filename = removed.imageFilename { store.deleteImage(filename: filename) }
        }
        items = kept
        trimAndPersist()
    }

    /// Copy an item back to the pasteboard. Bumps `lastChangeCount` first so our own
    /// write doesn't bounce back through `poll()` as a "new" copy.
    func copyToPasteboard(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.kind {
        case .image:
            if let filename = item.imageFilename, let image = store.loadImage(filename: filename) {
                pb.writeObjects([image])
            }
        case .fileURL:
            if let url = URL(string: item.text) {
                pb.writeObjects([url as NSURL])
            }
        case .richText:
            if let rtf = item.rtfData { pb.setData(rtf, forType: .rtf) }
            pb.setString(item.text, forType: .string)
        case .text:
            pb.setString(item.text, forType: .string)
        }
        lastChangeCount = pb.changeCount
    }

    // MARK: Thumbnails

    /// A downscaled, cached thumbnail for an image row (§4). Decoded lazily and
    /// memoised so scrolling the list never re-reads disk.
    func thumbnail(for item: ClipboardItem) -> NSImage? {
        guard item.kind == .image, let filename = item.imageFilename else { return nil }
        if let cached = thumbnailCache.object(forKey: filename as NSString) { return cached }
        guard let full = store.loadImage(filename: filename) else { return nil }
        let target = NSSize(width: 44, height: 44)
        let thumb = NSImage(size: target)
        thumb.lockFocus()
        full.draw(in: NSRect(origin: .zero, size: target),
                  from: .zero, operation: .copy, fraction: 1,
                  respectFlipped: true, hints: [.interpolation: NSImageInterpolation.medium])
        thumb.unlockFocus()
        thumbnailCache.setObject(thumb, forKey: filename as NSString)
        return thumb
    }

    // MARK: Trimming

    private func trimAndPersist() {
        // Never trim pinned items; only the unpinned timeline is bounded by the limit.
        var pinned = items.filter { $0.isPinned }
        var timeline = items.filter { !$0.isPinned }
        let limit = preferences.clipboardHistoryLimit
        if timeline.count > limit {
            let overflow = timeline[limit...]
            for item in overflow {
                if let filename = item.imageFilename { store.deleteImage(filename: filename) }
            }
            timeline = Array(timeline.prefix(limit))
        }
        pinned.sort { $0.createdAt > $1.createdAt }
        timeline.sort { $0.createdAt > $1.createdAt }
        items = pinned + timeline

        store.save(items)
        let referenced = Set(items.compactMap { $0.imageFilename })
        store.pruneOrphanImages(referenced: referenced)
    }
}
