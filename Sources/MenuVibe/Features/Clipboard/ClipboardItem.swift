import Foundation
import AppKit

/// One entry in the clipboard history. Value-type, `Codable` for the on-disk index.
///
/// Image payloads are *not* inlined into the codable record — only a filename
/// reference is stored, and the bytes live beside the index. This keeps the JSON
/// index tiny and fast to load at launch (spec §10 cold-start budget).
struct ClipboardItem: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case text
        case richText
        case image
        case fileURL
    }

    let id: UUID
    var kind: Kind
    /// The canonical string payload: plain text, or a file path/URL string. Empty for images.
    var text: String
    /// RTF data for rich text, so formatting round-trips when pasted back.
    var rtfData: Data?
    /// Filename (relative to the image cache dir) of the full-res image, if `kind == .image`.
    var imageFilename: String?
    /// Bundle identifier of the app that was frontmost when the copy happened.
    var sourceBundleID: String?
    var sourceAppName: String?
    var createdAt: Date
    var isPinned: Bool

    init(id: UUID = UUID(),
         kind: Kind,
         text: String = "",
         rtfData: Data? = nil,
         imageFilename: String? = nil,
         sourceBundleID: String? = nil,
         sourceAppName: String? = nil,
         createdAt: Date = Date(),
         isPinned: Bool = false) {
        self.id = id
        self.kind = kind
        self.text = text
        self.rtfData = rtfData
        self.imageFilename = imageFilename
        self.sourceBundleID = sourceBundleID
        self.sourceAppName = sourceAppName
        self.createdAt = createdAt
        self.isPinned = isPinned
    }

    /// A short, single-line preview for the list row.
    var preview: String {
        switch kind {
        case .image:
            return "Image"
        case .fileURL:
            return (URL(string: text)?.lastPathComponent) ?? text
        case .text, .richText:
            let collapsed = text
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\t", with: " ")
                .trimmingCharacters(in: .whitespaces)
            return collapsed.isEmpty ? "(whitespace)" : collapsed
        }
    }

    /// SF Symbol used as the type glyph when there's no source app icon.
    var kindSymbol: String {
        switch kind {
        case .text:     return "text.alignleft"
        case .richText: return "textformat"
        case .image:    return "photo"
        case .fileURL:  return "doc"
        }
    }

    /// Two items are "the same copy" if their payloads match, regardless of when or
    /// where — used for de-duplication (spec §4).
    func hasSamePayload(as other: ClipboardItem) -> Bool {
        guard kind == other.kind else { return false }
        switch kind {
        case .image:
            return imageFilename != nil && imageFilename == other.imageFilename
        default:
            return text == other.text
        }
    }
}
