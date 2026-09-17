// Usage: swift makeicons.swift <logo.png> <out-dir>
// Cleans the source glyph (drops faint noise and stray specks), then renders:
//   AppIcon.iconset/    app icon, glyph on a squircle gradient background
//   AppIconFlat.png     same glyph on transparency, for comparison
//   MenuBarIcon.png/@2x black silhouette for use as an NSImage template
import AppKit
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count == 3 else { fatalError("usage: makeicons.swift <logo.png> <out-dir>") }
let outDir = URL(fileURLWithPath: args[2])
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

guard let srcData = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil),
      let srcImage = CGImageSourceCreateImageAtIndex(srcData, 0, nil)
else { fatalError("could not read \(args[1])") }

let w = srcImage.width, h = srcImage.height
var px = [UInt8](repeating: 0, count: w * h * 4)
let readCtx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8,
                        bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
readCtx.draw(srcImage, in: CGRect(x: 0, y: 0, width: w, height: h))
print("source: \(w)x\(h)")

// --- Clean up -------------------------------------------------------------
// 1. Drop near-transparent noise.
var faint = 0
for i in stride(from: 3, to: px.count, by: 4) where px[i] > 0 && px[i] < 40 {
    px[i - 3] = 0; px[i - 2] = 0; px[i - 1] = 0; px[i] = 0
    faint += 1
}

// 2. Drop specks: connected components of visible pixels smaller than 0.01% of
//    the canvas. The artwork has no legitimate detached detail that small.
let minArea = max(64, (w * h) / 10_000)
var seen = [Bool](repeating: false, count: w * h)
var removedBlobs = 0, removedPixels = 0
for start in 0..<(w * h) where !seen[start] && px[start * 4 + 3] > 0 {
    var stack = [start], blob: [Int] = []
    seen[start] = true
    while let p = stack.popLast() {
        blob.append(p)
        let x = p % w, y = p / w
        for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
            let nx = x + dx, ny = y + dy
            guard nx >= 0, nx < w, ny >= 0, ny < h else { continue }
            let n = ny * w + nx
            if !seen[n] && px[n * 4 + 3] > 0 { seen[n] = true; stack.append(n) }
        }
    }
    if blob.count < minArea {
        for p in blob { px[p * 4] = 0; px[p * 4 + 1] = 0; px[p * 4 + 2] = 0; px[p * 4 + 3] = 0 }
        removedBlobs += 1; removedPixels += blob.count
    }
}
print("cleanup: \(faint) faint px, \(removedBlobs) specks (\(removedPixels) px)")

// --- Crop to content ------------------------------------------------------
var minX = w, minY = h, maxX = 0, maxY = 0
for y in 0..<h {
    for x in 0..<w where px[(y * w + x) * 4 + 3] > 0 {
        minX = min(minX, x); maxX = max(maxX, x)
        minY = min(minY, y); maxY = max(maxY, y)
    }
}
let cleanedFull = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8,
                            bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
let glyph = cleanedFull.cropping(to: CGRect(x: minX, y: minY,
                                            width: maxX - minX + 1, height: maxY - minY + 1))!
print("glyph: \(glyph.width)x\(glyph.height)")

// --- Helpers --------------------------------------------------------------
func newContext(_ size: Int) -> CGContext {
    let c = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.interpolationQuality = .high
    return c
}

func write(_ image: CGImage, _ url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

/// Apple-style continuous-corner squircle (superellipse), not a circular rounded rect.
func squircle(in rect: CGRect, exponent: Double = 5) -> CGPath {
    let path = CGMutablePath()
    let a = rect.width / 2, b = rect.height / 2
    let cx = rect.midX, cy = rect.midY
    let steps = 720
    for i in 0...steps {
        let t = Double(i) / Double(steps) * 2 * .pi
        let ct = cos(t), st = sin(t)
        let x = cx + a * CGFloat(copysign(pow(abs(ct), 2 / exponent), ct))
        let y = cy + b * CGFloat(copysign(pow(abs(st), 2 / exponent), st))
        i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
    }
    path.closeSubpath()
    return path
}

/// Fits the glyph into `box` preserving aspect ratio.
func glyphRect(in box: CGRect) -> CGRect {
    let scale = min(box.width / CGFloat(glyph.width), box.height / CGFloat(glyph.height))
    let size = CGSize(width: CGFloat(glyph.width) * scale, height: CGFloat(glyph.height) * scale)
    return CGRect(x: box.midX - size.width / 2, y: box.midY - size.height / 2,
                  width: size.width, height: size.height)
}

// --- App icon: glyph on a squircle gradient background --------------------
// Apple's icon grid: the shape fills 824 of a 1024 canvas.
func renderAppIcon(_ size: Int, background: Bool) -> CGImage {
    let c = newContext(size)
    let s = CGFloat(size) / 1024
    let shape = CGRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)

    if background {
        c.saveGState()
        c.addPath(squircle(in: shape))
        c.clip()
        let colors = [
            CGColor(red: 0.13, green: 0.15, blue: 0.36, alpha: 1),  // deep navy
            CGColor(red: 0.25, green: 0.17, blue: 0.42, alpha: 1),  // indigo
        ] as CFArray
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: colors, locations: [0, 1])!
        c.drawLinearGradient(gradient,
                             start: CGPoint(x: shape.minX, y: shape.maxY),
                             end: CGPoint(x: shape.maxX, y: shape.minY),
                             options: [])
        c.restoreGState()
    }

    let box = shape.insetBy(dx: shape.width * 0.17, dy: shape.height * 0.17)
    if background {
        c.setShadow(offset: CGSize(width: 0, height: -10 * s), blur: 24 * s,
                    color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.35))
    }
    c.draw(glyph, in: glyphRect(in: box))
    return c.makeImage()!
}

let iconset = outDir.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    write(renderAppIcon(size, background: true),
          iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    write(renderAppIcon(size * 2, background: true),
          iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
write(renderAppIcon(512, background: false), outDir.appendingPathComponent("AppIconFlat.png"))
write(renderAppIcon(512, background: true), outDir.appendingPathComponent("AppIconPreview.png"))

// --- Menu bar template: black silhouette from the glyph's alpha ------------
func renderTemplate(_ size: Int) -> CGImage {
    let c = newContext(size)
    let box = CGRect(x: 0, y: 0, width: size, height: size).insetBy(dx: CGFloat(size) * 0.02,
                                                                   dy: CGFloat(size) * 0.02)
    c.saveGState()
    c.clip(to: glyphRect(in: box), mask: glyph)
    c.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    c.fill(CGRect(x: 0, y: 0, width: size, height: size))
    c.restoreGState()
    return c.makeImage()!
}
write(renderTemplate(18), outDir.appendingPathComponent("MenuBarIcon.png"))
write(renderTemplate(36), outDir.appendingPathComponent("MenuBarIcon@2x.png"))
write(renderTemplate(144), outDir.appendingPathComponent("MenuBarPreview.png"))
print("written to \(outDir.path)")
