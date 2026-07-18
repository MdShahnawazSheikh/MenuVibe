import AppKit

// MenuVibe is a menu bar agent, not a windowed/dock app. We construct the
// application manually (rather than via @main / SwiftUI App) so we can set the
// activation policy to .accessory before anything draws — that is what keeps the
// app out of the Dock and the ⌘-Tab switcher while still owning a status item.

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
