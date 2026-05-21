#!/usr/bin/env swift
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Usage:
//   swift Scripts/GenerateIcon.swift <output_appiconset_dir>
// Writes all required macOS AppIcon PNGs + Contents.json.

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("Usage: swift GenerateIcon.swift <path_to_AppIcon.appiconset>")
    exit(1)
}
let outputPath = args[1]
let outputURL = URL(fileURLWithPath: outputPath)
try? FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

// macOS AppIcon sizes
let specs: [(filename: String, px: Int, size: String, scale: String)] = [
    ("icon_16x16.png",      16,   "16x16",   "1x"),
    ("icon_16x16@2x.png",   32,   "16x16",   "2x"),
    ("icon_32x32.png",      32,   "32x32",   "1x"),
    ("icon_32x32@2x.png",   64,   "32x32",   "2x"),
    ("icon_128x128.png",    128,  "128x128", "1x"),
    ("icon_128x128@2x.png", 256,  "128x128", "2x"),
    ("icon_256x256.png",    256,  "256x256", "1x"),
    ("icon_256x256@2x.png", 512,  "256x256", "2x"),
    ("icon_512x512.png",    512,  "512x512", "1x"),
    ("icon_512x512@2x.png", 1024, "512x512", "2x"),
]

// MARK: palette — Strata / Dusk Horizon
// Background: #1A1730  Moon/ridges: #F3EBFF

let bgColor   = CGColor(srgbRed: 26/255,  green: 23/255,  blue: 48/255,  alpha: 1.0)
let ridgeR: CGFloat = 243/255
let ridgeG: CGFloat = 235/255
let ridgeB: CGFloat = 255/255

func ridgeColor(_ alpha: CGFloat) -> CGColor {
    CGColor(srgbRed: ridgeR, green: ridgeG, blue: ridgeB, alpha: alpha)
}

// MARK: superellipse (Apple squircle, n≈5)
// CGPath(roundedRect:) produces a standard rounded rect whose corners differ
// visually from the macOS squircle (continuous-curvature superellipse).
// This function traces the true superellipse so baked-in corners match the
// system mask exactly.
func squirclePath(in rect: CGRect, exponent n: CGFloat = 5.0) -> CGPath {
    let path = CGMutablePath()
    let cx = rect.midX, cy = rect.midY
    let a = rect.width / 2, b = rect.height / 2
    let steps = 512
    func sgn(_ v: CGFloat) -> CGFloat { v >= 0 ? 1 : -1 }
    for i in 0...steps {
        let t = CGFloat(i) * 2 * .pi / CGFloat(steps)
        let ct = cos(t), st = sin(t)
        let x = cx + a * sgn(ct) * pow(abs(ct), 2.0 / n)
        let y = cy + b * sgn(st) * pow(abs(st), 2.0 / n)
        i == 0 ? path.move(to: CGPoint(x: x, y: y))
               : path.addLine(to: CGPoint(x: x, y: y))
    }
    path.closeSubpath()
    return path
}

// MARK: render

func renderIcon(size pixelSize: Int) -> CGImage? {
    let size = CGFloat(pixelSize)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: pixelSize, height: pixelSize,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    // Transparent outer padding — outer ring stays transparent so the Dock
    // composites the floating squircle at the same visual weight as other icons.
    let pad: CGFloat = 0.09   // 9% each side → 82% art area
    let artSize = size * (1 - 2 * pad)
    let artOff  = size * pad
    let artRect = CGRect(x: artOff, y: artOff, width: artSize, height: artSize)

    // True superellipse clip (n=5) — matches the macOS system squircle mask exactly
    let sq = squirclePath(in: artRect, exponent: 5.0)
    ctx.addPath(sq)
    ctx.clip()

    // Background fill (only inside the squircle — outside stays transparent)
    ctx.setFillColor(bgColor)
    ctx.addPath(sq)
    ctx.fillPath()

    // Scale from SVG 64-unit space into the inset art area; SVG Y flipped relative to CG
    let s = artSize / 64.0
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: artOff + x * s, y: artOff + (64 - y) * s)
    }

    // Moon — three concentric circles at SVG (48, 14)
    // outer halo
    ctx.setFillColor(ridgeColor(0.077))
    ctx.fillEllipse(in: CGRect(x: artOff + (48 - 8) * s, y: artOff + (64 - 14 - 8) * s, width: 16 * s, height: 16 * s))
    // mid halo
    ctx.setFillColor(ridgeColor(0.175))
    ctx.fillEllipse(in: CGRect(x: artOff + (48 - 5.4) * s, y: artOff + (64 - 14 - 5.4) * s, width: 10.8 * s, height: 10.8 * s))
    // bright core
    ctx.setFillColor(ridgeColor(0.65))
    ctx.fillEllipse(in: CGRect(x: artOff + (48 - 3.2) * s, y: artOff + (64 - 14 - 3.2) * s, width: 6.4 * s, height: 6.4 * s))

    // Back ridge — faintest
    let back = CGMutablePath()
    back.move(to: p(0, 34))
    back.addLine(to: p(6, 30))
    back.addLine(to: p(11, 34))
    back.addLine(to: p(17, 27))
    back.addLine(to: p(23, 31))
    back.addLine(to: p(29, 25))
    back.addLine(to: p(35, 29))
    back.addLine(to: p(41, 23))
    back.addLine(to: p(47, 27))
    back.addLine(to: p(53, 24))
    back.addLine(to: p(64, 28))
    back.addLine(to: p(64, 64))
    back.addLine(to: p(0, 64))
    back.closeSubpath()
    ctx.setFillColor(ridgeColor(0.1925))
    ctx.addPath(back)
    ctx.fillPath()

    // Middle ridge
    let mid = CGMutablePath()
    mid.move(to: p(0, 44))
    mid.addLine(to: p(7, 41))
    mid.addLine(to: p(13, 45))
    mid.addLine(to: p(19, 38))
    mid.addLine(to: p(25, 42))
    mid.addLine(to: p(31, 36))
    mid.addLine(to: p(37, 40))
    mid.addLine(to: p(43, 34))
    mid.addLine(to: p(49, 38))
    mid.addLine(to: p(55, 35))
    mid.addLine(to: p(64, 37))
    mid.addLine(to: p(64, 64))
    mid.addLine(to: p(0, 64))
    mid.closeSubpath()
    ctx.setFillColor(ridgeColor(0.325))
    ctx.addPath(mid)
    ctx.fillPath()

    // Front ridge — most solid
    let front = CGMutablePath()
    front.move(to: p(0, 54))
    front.addLine(to: p(9, 52))
    front.addLine(to: p(17, 55))
    front.addLine(to: p(25, 50))
    front.addLine(to: p(33, 53))
    front.addLine(to: p(41, 49))
    front.addLine(to: p(49, 51))
    front.addLine(to: p(57, 48))
    front.addLine(to: p(64, 50))
    front.addLine(to: p(64, 64))
    front.addLine(to: p(0, 64))
    front.closeSubpath()
    ctx.setFillColor(ridgeColor(0.572))
    ctx.addPath(front)
    ctx.fillPath()

    return ctx.makeImage()
}

// MARK: write PNG

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "icon", code: 1)
    }
    CGImageDestinationAddImage(dest, image, nil)
    if !CGImageDestinationFinalize(dest) {
        throw NSError(domain: "icon", code: 2)
    }
}

for spec in specs {
    guard let img = renderIcon(size: spec.px) else {
        print("⚠️  failed to render \(spec.px)")
        continue
    }
    let url = outputURL.appendingPathComponent(spec.filename)
    do {
        try writePNG(img, to: url)
        print("✓ \(spec.filename) (\(spec.px)px)")
    } catch {
        print("⚠️  write fail \(spec.filename): \(error)")
    }
}

// MARK: IconDusk.imageset — runtime default, must match AppIcon

let duskImagesetURL = outputURL
    .deletingLastPathComponent()          // Assets.xcassets
    .appendingPathComponent("IconDusk.imageset")
if let duskImg = renderIcon(size: 256) {
    let duskPNG = duskImagesetURL.appendingPathComponent("icon.png")
    do {
        try writePNG(duskImg, to: duskPNG)
        print("✓ IconDusk.imageset/icon.png (256px)")
    } catch {
        print("⚠️  write fail IconDusk: \(error)")
    }
}

// MARK: Contents.json

let entries = specs.map { spec in
    """
        {
          "size" : "\(spec.size)",
          "idiom" : "mac",
          "filename" : "\(spec.filename)",
          "scale" : "\(spec.scale)"
        }
    """
}.joined(separator: ",\n")

let contentsJSON = """
{
  "images" : [
\(entries)
  ],
  "info" : {
    "version" : 1,
    "author" : "xcode"
  }
}
"""

let contentsURL = outputURL.appendingPathComponent("Contents.json")
try? contentsJSON.write(to: contentsURL, atomically: true, encoding: .utf8)
print("✓ Contents.json")
print("\nDone. Rebuild in Xcode (⌘R).")
