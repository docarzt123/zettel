// Zettel — Einstiegspunkt. Die App hat kein Dock-Symbol (LSUIElement in der
// Info.plist), deshalb hier zusätzlich die Activation-Policy "accessory".
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
