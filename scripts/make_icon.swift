// Erzeugt das App-Symbol: gelber Notizzettel mit drei Textzeilen.
// Aufruf (durch build.sh):  swift scripts/make_icon.swift <ziel.png>
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// macOS-Symbole haben einen Rand von ~10 % um die eigentliche Form.
let inset = size * 0.1
let rect = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
let path = NSBezierPath(roundedRect: rect, xRadius: size * 0.18, yRadius: size * 0.18)
let shadow = NSShadow()
shadow.shadowBlurRadius = size * 0.02
shadow.shadowOffset = NSSize(width: 0, height: -size * 0.01)
shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
shadow.set()
NSGradient(starting: NSColor(calibratedRed: 1.00, green: 0.88, blue: 0.36, alpha: 1),
           ending: NSColor(calibratedRed: 0.97, green: 0.74, blue: 0.10, alpha: 1))!
    .draw(in: path, angle: -90)

// Drei „Textzeilen"
NSShadow().set()
let ink = NSColor(calibratedWhite: 0.25, alpha: 0.85)
ink.setFill()
let lineH = size * 0.06
let lineX = rect.minX + rect.width * 0.16
let widths: [CGFloat] = [0.68, 0.52, 0.60]
for (i, w) in widths.enumerated() {
    let y = rect.maxY - rect.height * (0.30 + CGFloat(i) * 0.19)
    NSBezierPath(roundedRect: NSRect(x: lineX, y: y, width: rect.width * w, height: lineH),
                 xRadius: lineH / 2, yRadius: lineH / 2).fill()
}

image.unlockFocus()
guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fputs("Icon konnte nicht gerendert werden\n", stderr)
    exit(1)
}
try! png.write(to: URL(fileURLWithPath: out))
