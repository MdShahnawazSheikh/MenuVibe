import SwiftUI

/// A deliberately small Markdown renderer for the notes preview. It handles the
/// blocks people actually use in a scratchpad — headings, bullet/numbered lists,
/// fenced code, blockquotes — and defers inline styling (bold/italic/`code`/links)
/// to SwiftUI's own `AttributedString(markdown:)`. No third-party parser, no bloat
/// (spec §6).
struct MarkdownPreview: View {
    let source: String

    private var blocks: [MarkdownBlock] { MarkdownBlock.parse(source) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.base) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    view(for: block)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.comfy)
        }
    }

    @ViewBuilder
    private func view(for block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(inline(text))
                .font(.system(size: [22, 18, 15, 14, 13, 12][min(level - 1, 5)],
                              weight: level <= 2 ? .semibold : .medium))
                .foregroundStyle(DS.Color.primaryLabel)
                .padding(.top, level <= 2 ? DS.Spacing.tight : 0)
        case .paragraph(let text):
            Text(inline(text))
                .font(DS.Font.rowTitle)
                .foregroundStyle(DS.Color.primaryLabel)
                .fixedSize(horizontal: false, vertical: true)
        case .bullet(let items):
            VStack(alignment: .leading, spacing: DS.Spacing.tight) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.snug) {
                        Text("•").foregroundStyle(DS.Color.accent)
                        Text(inline(item)).foregroundStyle(DS.Color.primaryLabel)
                    }
                    .font(DS.Font.rowTitle)
                }
            }
        case .numbered(let items):
            VStack(alignment: .leading, spacing: DS.Spacing.tight) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.snug) {
                        Text("\(idx + 1).")
                            .foregroundStyle(DS.Color.secondaryLabel)
                            .monospacedDigit()
                        Text(inline(item)).foregroundStyle(DS.Color.primaryLabel)
                    }
                    .font(DS.Font.rowTitle)
                }
            }
        case .code(let code):
            Text(code)
                .font(DS.Font.mono)
                .foregroundStyle(DS.Color.primaryLabel)
                .padding(DS.Spacing.base)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.thumbnail, style: .continuous)
                        .fill(DS.Color.primaryLabel.opacity(0.06))
                )
        case .quote(let text):
            HStack(spacing: DS.Spacing.base) {
                Rectangle().fill(DS.Color.accent.opacity(0.5)).frame(width: 3)
                Text(inline(text))
                    .font(DS.Font.rowTitle)
                    .foregroundStyle(DS.Color.secondaryLabel)
            }
        }
    }

    /// Inline styling via SwiftUI's own Markdown attributed string, falling back to
    /// plain text if the fragment doesn't parse.
    private func inline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text,
                               options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}

/// A parsed Markdown block. Parsing is line-oriented and forgiving — good enough for
/// a scratchpad, and it never throws on malformed input.
enum MarkdownBlock {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bullet([String])
    case numbered([String])
    case code(String)
    case quote(String)

    static func parse(_ source: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = source.components(separatedBy: "\n")
        var i = 0

        func flushParagraph(_ buffer: inout [String]) {
            guard !buffer.isEmpty else { return }
            blocks.append(.paragraph(buffer.joined(separator: " ")))
            buffer.removeAll()
        }

        var paragraph: [String] = []
        while i < lines.count {
            let raw = lines[i]
            let line = raw.trimmingCharacters(in: .whitespaces)

            // Fenced code block.
            if line.hasPrefix("```") {
                flushParagraph(&paragraph)
                var code: [String] = []
                i += 1
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(lines[i]); i += 1
                }
                blocks.append(.code(code.joined(separator: "\n")))
                i += 1
                continue
            }

            if line.isEmpty {
                flushParagraph(&paragraph)
                i += 1
                continue
            }

            // Heading.
            if let heading = headingLevel(line) {
                flushParagraph(&paragraph)
                let text = String(line.drop(while: { $0 == "#" })).trimmingCharacters(in: .whitespaces)
                blocks.append(.heading(level: heading, text: text))
                i += 1
                continue
            }

            // Blockquote.
            if line.hasPrefix(">") {
                flushParagraph(&paragraph)
                let text = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                blocks.append(.quote(text))
                i += 1
                continue
            }

            // Bulleted list (consecutive lines).
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                flushParagraph(&paragraph)
                var items: [String] = []
                while i < lines.count {
                    let l = lines[i].trimmingCharacters(in: .whitespaces)
                    guard l.hasPrefix("- ") || l.hasPrefix("* ") else { break }
                    items.append(String(l.dropFirst(2)))
                    i += 1
                }
                blocks.append(.bullet(items))
                continue
            }

            // Numbered list.
            if isNumberedItem(line) {
                flushParagraph(&paragraph)
                var items: [String] = []
                while i < lines.count {
                    let l = lines[i].trimmingCharacters(in: .whitespaces)
                    guard isNumberedItem(l) else { break }
                    if let dot = l.firstIndex(of: ".") {
                        items.append(String(l[l.index(after: dot)...]).trimmingCharacters(in: .whitespaces))
                    }
                    i += 1
                }
                blocks.append(.numbered(items))
                continue
            }

            paragraph.append(line)
            i += 1
        }
        flushParagraph(&paragraph)
        return blocks
    }

    private static func headingLevel(_ line: String) -> Int? {
        guard line.hasPrefix("#") else { return nil }
        let hashes = line.prefix(while: { $0 == "#" }).count
        guard hashes <= 6, line.dropFirst(hashes).first == " " else { return nil }
        return hashes
    }

    private static func isNumberedItem(_ line: String) -> Bool {
        guard let dot = line.firstIndex(of: ".") else { return false }
        let prefix = line[line.startIndex..<dot]
        return !prefix.isEmpty && prefix.allSatisfy(\.isNumber)
            && line.index(after: dot) < line.endIndex
            && line[line.index(after: dot)] == " "
    }
}
