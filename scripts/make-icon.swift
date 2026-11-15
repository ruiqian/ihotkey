// Renders the iHotkey app icon (1024x1024 PNG) with AppKit — no design tools needed.
// Usage: swift scripts/make-icon.swift <output.png>
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// macOS Big Sur+ icon grid: 824pt rounded square centered in 1024.
let inset: CGFloat = 100
let body = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let radius: CGFloat = 185

// Drop shadow
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.shadowBlurRadius = 28
shadow.set()

let squircle = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)
NSGradient(colors: [
    NSColor(srgbRed: 0.36, green: 0.42, blue: 1.00, alpha: 1),
    NSColor(srgbRed: 0.53, green: 0.29, blue: 0.96, alpha: 1),
])!.draw(in: squircle, angle: -60)
NSShadow().set()

// Split-screen window glyph
let pad: CGFloat = 175
let win = NSRect(x: body.minX + pad, y: body.minY + pad + 40,
                 width: body.width - pad * 2, height: body.height - pad * 2 - 40)
let winPath = NSBezierPath(roundedRect: win, xRadius: 46, yRadius: 46)
NSColor.white.withAlphaComponent(0.20).setFill()
winPath.fill()
NSColor.white.setStroke()
winPath.lineWidth = 30
winPath.stroke()

let left = NSRect(x: win.minX + 44, y: win.minY + 44, width: win.width / 2 - 66, height: win.height - 88)
NSColor.white.setFill()
NSBezierPath(roundedRect: left, xRadius: 22, yRadius: 22).fill()
let right = NSRect(x: win.midX + 22, y: win.minY + 44, width: win.width / 2 - 66, height: win.height - 88)
NSColor.white.withAlphaComponent(0.55).setFill()
NSBezierPath(roundedRect: right, xRadius: 22, yRadius: 22).fill()

// ⌘ key cap, bottom-right
let cap = NSRect(x: body.maxX - 330, y: body.minY + 70, width: 250, height: 250)
let shadow2 = NSShadow()
shadow2.shadowColor = NSColor.black.withAlphaComponent(0.3)
shadow2.shadowOffset = NSSize(width: 0, height: -8)
shadow2.shadowBlurRadius = 20
shadow2.set()
NSColor.white.setFill()
NSBezierPath(roundedRect: cap, xRadius: 56, yRadius: 56).fill()
NSShadow().set()
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 170, weight: .semibold),
    .foregroundColor: NSColor(srgbRed: 0.45, green: 0.35, blue: 0.98, alpha: 1),
]
let glyph = NSAttributedString(string: "⌘", attributes: attrs)
let gs = glyph.size()
glyph.draw(at: NSPoint(x: cap.midX - gs.width / 2, y: cap.midY - gs.height / 2 + 4))

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
