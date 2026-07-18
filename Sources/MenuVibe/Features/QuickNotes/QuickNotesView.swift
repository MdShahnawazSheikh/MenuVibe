import SwiftUI
import AppKit

/// The Quick Notes tab: a raw Markdown editor by default with a one-tap rendered
/// preview, a subtle word/character count, and copy actions. Speed is the whole point
/// (spec §6), so it's a plain, instant editor — no heavyweight editor component.
struct QuickNotesView: View {
    @ObservedObject var store: QuickNotesStore
    @ObservedObject var preferences: Preferences
    @Binding var focusRequest: PanelTab?
    @FocusState private var editorFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            DSDivider()
            Group {
                if preferences.notesPreviewEnabled {
                    if store.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        emptyState
                    } else {
                        MarkdownPreview(source: store.text)
                    }
                } else {
                    editor
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            DSDivider()
            statusBar
        }
        .frame(maxHeight: .infinity) // fill the fixed panel height (spec §3)
        .onChange(of: focusRequest) { request in
            // Summoned via the Quick Note hotkey → drop straight into the editor.
            if request == .notes {
                preferences.notesPreviewEnabled = false
                DispatchQueue.main.async { editorFocused = true }
                focusRequest = nil
            }
        }
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: DS.Spacing.snug) {
            Text("Quick Note")
                .font(DS.Font.title)
                .foregroundStyle(DS.Color.primaryLabel)
            Spacer()
            toolbarButton(preferences.notesPreviewEnabled ? "pencil" : "eye",
                          help: preferences.notesPreviewEnabled ? "Edit" : "Preview") {
                withAnimation(DS.Motion.crossfade) {
                    preferences.notesPreviewEnabled.toggle()
                }
            }
            Menu {
                Button("Copy as Markdown") { copy(store.text) }
                Button("Copy as Plain Text") { copy(plainText(store.text)) }
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DS.Color.secondaryLabel)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Copy note")
        }
        .padding(.horizontal, DS.Spacing.comfy)
        .frame(height: 40)
    }

    private func toolbarButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DS.Color.secondaryLabel)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: Editor

    private var editor: some View {
        TextEditor(text: $store.text)
            .font(DS.Font.mono)
            .foregroundStyle(DS.Color.primaryLabel)
            .scrollContentBackground(.hidden)
            .focused($editorFocused)
            .padding(.horizontal, DS.Spacing.base)
            .padding(.vertical, DS.Spacing.snug)
            .overlay(alignment: .topLeading) {
                if store.text.isEmpty {
                    Text("Jot something down… Markdown works here.")
                        .font(DS.Font.mono)
                        .foregroundStyle(DS.Color.tertiaryLabel)
                        .padding(.horizontal, DS.Spacing.comfy)
                        .padding(.vertical, DS.Spacing.comfy)
                        .allowsHitTesting(false)
                }
            }
    }

    private var emptyState: some View {
        EmptyStateView(
            symbol: "note.text",
            title: "Nothing to preview",
            message: "Switch back to edit mode and start writing."
        )
    }

    // MARK: Status bar (subtle counts — spec §6)

    private var statusBar: some View {
        HStack {
            Text(preferences.notesPreviewEnabled ? "Preview" : "Editing")
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.tertiaryLabel)
            Spacer()
            Text("\(store.wordCount) words · \(store.characterCount) chars")
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.tertiaryLabel)
                .monospacedDigit()
        }
        .padding(.horizontal, DS.Spacing.comfy)
        .frame(height: 24)
    }

    // MARK: Actions

    private func copy(_ string: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(string, forType: .string)
    }

    /// Strip the most common Markdown syntax for a clean plain-text copy.
    private func plainText(_ markdown: String) -> String {
        var out = markdown
        for token in ["**", "__", "`", "#", ">"] {
            out = out.replacingOccurrences(of: token, with: "")
        }
        return out
    }
}
