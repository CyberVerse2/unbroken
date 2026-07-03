import AppKit
import UnbrokenCore

// iconpreview — renders every menu-bar icon state to PNGs so a human can eyeball
// legibility before wiring the icon into the app. It constructs IconState values
// directly and never touches the (stubbed) engine.
//
// Output: dist/icon-preview/
//   <state>_<light|dark>_<1|2>x.png   — one tile per state/appearance/scale
//   contact-sheet.png                 — everything, magnified, side by side
//
// Template states are tinted here the way AppKit would tint them in a real menu
// bar (near-black on a light bar, near-white on a dark bar). atRisk is a
// non-template orange glyph and is drawn as-is on both — that's the whole point.

// MARK: - Appearance model

struct MenuBar {
    let name: String
    let background: NSColor
    /// Tint applied to template glyphs, mimicking AppKit's menu-bar tinting.
    let templateTint: NSColor
}

let lightBar = MenuBar(name: "light",
                       background: NSColor(calibratedWhite: 0.96, alpha: 1),
                       templateTint: NSColor(calibratedWhite: 0.13, alpha: 1))
let darkBar = MenuBar(name: "dark",
                      background: NSColor(calibratedWhite: 0.14, alpha: 1),
                      templateTint: NSColor(calibratedWhite: 0.92, alpha: 1))
let bars = [lightBar, darkBar]

// MARK: - Helpers

/// Colourize a template glyph, preserving its alpha mask.
func tinted(_ image: NSImage, _ color: NSColor) -> NSImage {
    let out = NSImage(size: image.size)
    out.lockFocus()
    let rect = NSRect(origin: .zero, size: image.size)
    image.draw(in: rect, from: rect, operation: .sourceOver, fraction: 1)
    color.set()
    rect.fill(using: .sourceAtop)
    out.unlockFocus()
    return out
}

/// Draw `icon` centred on a `bar` swatch of `tilePt` points, rasterized at
/// `scale`× (so 1x/2x produce genuinely different pixel resolutions), as PNG.
func renderTile(icon: NSImage, isTemplate: Bool, bar: MenuBar,
                tilePt: CGFloat, scale: Int) -> Data {
    let px = Int(tilePt) * scale
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                              pixelsWide: px, pixelsHigh: px,
                              bitsPerSample: 8, samplesPerPixel: 4,
                              hasAlpha: true, isPlanar: false,
                              colorSpaceName: .calibratedRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: tilePt, height: tilePt) // points → context scale = px/pt

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    bar.background.set()
    NSRect(x: 0, y: 0, width: tilePt, height: tilePt).fill()

    let glyph = isTemplate ? tinted(icon, bar.templateTint) : icon
    let ox = (tilePt - icon.size.width) / 2
    let oy = (tilePt - icon.size.height) / 2
    glyph.draw(at: NSPoint(x: ox, y: oy),
               from: NSRect(origin: .zero, size: icon.size),
               operation: .sourceOver, fraction: 1)

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// MARK: - Output location

let cwd = FileManager.default.currentDirectoryPath
let outDir = URL(fileURLWithPath: cwd)
    .appendingPathComponent("dist")
    .appendingPathComponent("icon-preview")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func write(_ data: Data, _ name: String) throws {
    try data.write(to: outDir.appendingPathComponent(name))
}

// MARK: - Per-state / per-appearance / per-scale tiles

let states = IconState.allCases
let tilePt: CGFloat = 26 // 18pt glyph + 4pt padding each side
var written: [String] = []

for state in states {
    let icon = MenuBarIcon.image(for: state)
    for bar in bars {
        for scale in [1, 2] {
            let data = renderTile(icon: icon, isTemplate: icon.isTemplate,
                                  bar: bar, tilePt: tilePt, scale: scale)
            let name = "\(state.rawValue)_\(bar.name)_\(scale)x.png"
            try write(data, name)
            written.append(name)
        }
    }
}

// MARK: - Contact sheet (magnified, labelled — for human review)

func drawContactSheet() -> Data {
    let magnified: CGFloat = 72   // enlarged glyph so 18px art is inspectable
    let actual: CGFloat = 26      // an actual-size (1x) swatch alongside
    let labelW: CGFloat = 96
    let colGap: CGFloat = 12
    let rowH: CGFloat = magnified + 16
    let pad: CGFloat = 16
    let headerH: CGFloat = 26

    // columns: light-magnified | dark-magnified | light-1x | dark-1x
    let colWidths: [CGFloat] = [magnified, magnified, actual, actual]
    let contentW = labelW + colWidths.reduce(0, +) + colGap * CGFloat(colWidths.count)
    let width = pad * 2 + contentW
    let height = pad * 2 + headerH + rowH * CGFloat(states.count)

    let scale = 2
    let px = Int(width) * scale
    let pyh = Int(height) * scale
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                              pixelsWide: px, pixelsHigh: pyh,
                              bitsPerSample: 8, samplesPerPixel: 4,
                              hasAlpha: true, isPlanar: false,
                              colorSpaceName: .calibratedRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: width, height: height)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Page background (neutral).
    NSColor(calibratedWhite: 0.5, alpha: 1).set()
    NSRect(x: 0, y: 0, width: width, height: height).fill()

    // Column headers (top of image; y is flipped-from-bottom in AppKit).
    let headerTitles = ["light ×4", "dark ×4", "light 1x", "dark 1x"]
    let headerAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
        .foregroundColor: NSColor.white,
    ]
    var hx = pad + labelW + colGap
    for (i, title) in headerTitles.enumerated() {
        let y = height - pad - headerH + 6
        NSString(string: title).draw(at: NSPoint(x: hx, y: y), withAttributes: headerAttrs)
        hx += colWidths[i] + colGap
    }

    let labelAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 11, weight: .medium),
        .foregroundColor: NSColor.white,
    ]

    for (row, state) in states.enumerated() {
        let icon = MenuBarIcon.image(for: state)
        let rowTop = height - pad - headerH - rowH * CGFloat(row)
        let rowBottom = rowTop - rowH

        // Row label.
        NSString(string: state.rawValue).draw(
            at: NSPoint(x: pad, y: rowBottom + rowH / 2 - 7),
            withAttributes: labelAttrs)

        var x = pad + labelW + colGap
        let cells: [(MenuBar, CGFloat)] = [
            (lightBar, magnified), (darkBar, magnified),
            (lightBar, actual), (darkBar, actual),
        ]
        for (bar, size) in cells {
            let cellY = rowBottom + (rowH - size) / 2
            let cellRect = NSRect(x: x, y: cellY, width: size, height: size)
            bar.background.set()
            cellRect.fill()

            let glyph = icon.isTemplate ? tinted(icon, bar.templateTint) : icon
            let gx = x + (size - icon.size.width * (size / 26)) / 2
            let gy = cellY + (size - icon.size.height * (size / 26)) / 2
            let drawSize = NSSize(width: icon.size.width * (size / 26),
                                  height: icon.size.height * (size / 26))
            glyph.draw(in: NSRect(x: gx, y: gy, width: drawSize.width, height: drawSize.height),
                       from: NSRect(origin: .zero, size: icon.size),
                       operation: .sourceOver, fraction: 1)
            x += size + colGap
        }
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

try write(drawContactSheet(), "contact-sheet.png")
written.append("contact-sheet.png")

print("Wrote \(written.count) PNG(s) to \(outDir.path):")
for name in written.sorted() { print("  \(name)") }
