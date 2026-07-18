import Foundation
import Combine

/// Backs the single Quick Notes scratchpad. Loads once at launch and autosaves the
/// text to a plain `.md` file on every change, debounced ~300ms so continuous typing
/// doesn't hammer the disk while still never requiring a manual save (spec §6).
///
/// The file is intentionally human-readable Markdown at a stable path, so users can
/// point Syncthing / a dotfiles repo at it themselves. There is no database blob.
final class QuickNotesStore: ObservableObject {
    @Published var text: String {
        didSet { scheduleSave() }
    }

    private var saveCancellable: AnyCancellable?
    private let saveSubject = PassthroughSubject<Void, Never>()
    private let io = DispatchQueue(label: "app.menuvibe.notes.io", qos: .utility)

    init() {
        text = (try? String(contentsOf: AppPaths.quickNote, encoding: .utf8)) ?? ""

        saveCancellable = saveSubject
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.writeToDisk() }
    }

    private func scheduleSave() {
        saveSubject.send(())
    }

    private func writeToDisk() {
        let snapshot = text
        io.async {
            try? snapshot.write(to: AppPaths.quickNote, atomically: true, encoding: .utf8)
        }
    }

    /// Flush immediately — called on app termination so the last keystrokes survive
    /// even inside the debounce window.
    func flush() {
        writeToDisk()
    }

    // MARK: Derived stats

    var characterCount: Int { text.count }

    var wordCount: Int {
        text.split { $0 == " " || $0.isNewline || $0 == "\t" }.count
    }
}
