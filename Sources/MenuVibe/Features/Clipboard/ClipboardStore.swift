import Foundation
import AppKit

/// Persists the clipboard history to disk: a JSON index of `ClipboardItem` records
/// plus a sidecar image file per image entry. Kept deliberately simple (no database
/// dependency) — the history is small and bounded, so a single atomically-written
/// JSON file is both fast enough and trivially inspectable.
///
/// All disk I/O is funnelled through a private serial queue so writes never block
/// the main thread and never race each other.
final class ClipboardStore {
    private let io = DispatchQueue(label: "app.menuvibe.clipboard.store", qos: .utility)

    // MARK: Index

    func load() -> [ClipboardItem] {
        guard let data = try? Data(contentsOf: AppPaths.clipboardIndex) else { return [] }
        return (try? JSONDecoder.iso.decode([ClipboardItem].self, from: data)) ?? []
    }

    /// Persist the index atomically. Runs off the main thread.
    func save(_ items: [ClipboardItem]) {
        io.async {
            guard let data = try? JSONEncoder.iso.encode(items) else { return }
            try? data.write(to: AppPaths.clipboardIndex, options: .atomic)
        }
    }

    // MARK: Image payloads

    /// Write full-resolution PNG bytes for an image entry and return its filename.
    func writeImage(_ image: NSImage) -> String? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else { return nil }
        let filename = "\(UUID().uuidString).png"
        let url = AppPaths.clipboardImages.appendingPathComponent(filename)
        do {
            try png.write(to: url, options: .atomic)
            return filename
        } catch {
            NSLog("MenuVibe: failed to write clipboard image: \(error.localizedDescription)")
            return nil
        }
    }

    func loadImage(filename: String) -> NSImage? {
        let url = AppPaths.clipboardImages.appendingPathComponent(filename)
        return NSImage(contentsOf: url)
    }

    /// Delete an image payload that is no longer referenced by any entry.
    func deleteImage(filename: String) {
        let url = AppPaths.clipboardImages.appendingPathComponent(filename)
        io.async { try? FileManager.default.removeItem(at: url) }
    }

    /// Remove any image files on disk that no longer have a matching entry — called
    /// after trimming so pruned images don't leak storage over time.
    func pruneOrphanImages(referenced: Set<String>) {
        io.async {
            let dir = AppPaths.clipboardImages
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return }
            for file in files where !referenced.contains(file) {
                try? FileManager.default.removeItem(at: dir.appendingPathComponent(file))
            }
        }
    }
}

// MARK: - JSON coders with stable date handling

extension JSONEncoder {
    static let iso: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.withoutEscapingSlashes]
        return e
    }()
}

extension JSONDecoder {
    static let iso: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
