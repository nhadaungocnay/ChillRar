import Cocoa

func drawAppIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let margin = size * 0.08
    let roundedRect = rect.insetBy(dx: margin, dy: margin)
    let cornerRadius = size * 0.22

    // Background Gradient (Deep indigo to cyan / chill rar theme)
    let path = CGPath(roundedRect: roundedRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.addPath(path)
    ctx.clip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [
        NSColor(red: 0.12, green: 0.45, blue: 0.95, alpha: 1.0).cgColor,
        NSColor(red: 0.05, green: 0.75, blue: 0.92, alpha: 1.0).cgColor
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])
    }

    // Draw stylized zipper / books / archive motif
    // 3 stacked color books/slabs like classic WinRAR/UnRAR but modernized with macOS flat-squircle style
    let bookWidth = roundedRect.width * 0.65
    let bookHeight = roundedRect.height * 0.13
    let startX = roundedRect.midX - bookWidth / 2
    let midY = roundedRect.midY

    let slabColors = [
        NSColor(red: 0.95, green: 0.28, blue: 0.35, alpha: 0.95), // Red
        NSColor(red: 0.22, green: 0.72, blue: 0.42, alpha: 0.95), // Green
        NSColor(red: 0.25, green: 0.55, blue: 0.95, alpha: 0.95), // Blue
    ]

    for (i, col) in slabColors.enumerated() {
        let yOffset = CGFloat(1 - i) * (bookHeight * 1.25)
        let slabRect = CGRect(x: startX, y: midY + yOffset - bookHeight / 2, width: bookWidth, height: bookHeight)
        let slabPath = CGPath(roundedRect: slabRect, cornerWidth: size * 0.03, cornerHeight: size * 0.03, transform: nil)

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.015), blur: size * 0.02, color: NSColor.black.withAlphaComponent(0.25).cgColor)
        ctx.addPath(slabPath)
        col.setFill()
        ctx.fillPath()
        ctx.restoreGState()

        // White stripe on left (spine effect)
        let spineRect = CGRect(x: startX + size * 0.02, y: slabRect.minY + size * 0.01, width: size * 0.025, height: slabRect.height - size * 0.02)
        NSColor.white.withAlphaComponent(0.4).setFill()
        ctx.fill(spineRect)
    }

    // Belt / Strap around the books
    let beltWidth = size * 0.09
    let beltRect = CGRect(x: roundedRect.midX - beltWidth / 2, y: midY - bookHeight * 1.8, width: beltWidth, height: bookHeight * 3.6)
    let beltPath = CGPath(roundedRect: beltRect, cornerWidth: size * 0.02, cornerHeight: size * 0.02, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.02), blur: size * 0.03, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    ctx.addPath(beltPath)
    NSColor(white: 0.15, alpha: 0.9).setFill()
    ctx.fillPath()
    ctx.restoreGState()

    // Buckle in center
    let buckleSize = beltWidth * 1.3
    let buckleRect = CGRect(x: roundedRect.midX - buckleSize / 2, y: midY - buckleSize / 2, width: buckleSize, height: buckleSize)
    let bucklePath = CGPath(roundedRect: buckleRect, cornerWidth: size * 0.02, cornerHeight: size * 0.02, transform: nil)
    NSColor(red: 0.95, green: 0.78, blue: 0.25, alpha: 1.0).setFill()
    ctx.addPath(bucklePath)
    ctx.fillPath()

    let buckleInner = buckleRect.insetBy(dx: buckleSize * 0.25, dy: buckleSize * 0.25)
    let buckleInnerPath = CGPath(roundedRect: buckleInner, cornerWidth: size * 0.01, cornerHeight: size * 0.01, transform: nil)
    NSColor(white: 0.15, alpha: 1.0).setFill()
    ctx.addPath(buckleInnerPath)
    ctx.fillPath()

    image.unlockFocus()
    return image
}

let iconsetURL = URL(fileURLWithPath: "/tmp/ChillRar.iconset")
try? FileManager.default.removeItem(at: iconsetURL)
try! FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let sizes: [(Int, Int, String)] = [
    (16, 1, "icon_16x16.png"),
    (16, 2, "icon_16x16@2x.png"),
    (32, 1, "icon_32x32.png"),
    (32, 2, "icon_32x32@2x.png"),
    (128, 1, "icon_128x128.png"),
    (128, 2, "icon_128x128@2x.png"),
    (256, 1, "icon_256x256.png"),
    (256, 2, "icon_256x256@2x.png"),
    (512, 1, "icon_512x512.png"),
    (512, 2, "icon_512x512@2x.png"),
]

for (base, scale, filename) in sizes {
    let px = CGFloat(base * scale)
    let img = drawAppIcon(size: px)
    guard let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { continue }
    try! png.write(to: iconsetURL.appendingPathComponent(filename))
}

let outURL = URL(fileURLWithPath: "Resources/AppIcon.icns")
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", "/tmp/ChillRar.iconset", "-o", outURL.path]
try! process.run()
process.waitUntilExit()

print("Generated \(outURL.path) successfully.")
