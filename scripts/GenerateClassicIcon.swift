#!/usr/bin/env swift
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Generates the new Classic icon at all AppIcon sizes and writes to:
//   QuietFinance/Assets.xcassets/AppIcon.appiconset/
//   QuietFinance/Assets.xcassets/IconClassic.imageset/
//
// Usage:
//   swift scripts/GenerateClassicIcon.swift <repo_root>

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("Usage: swift GenerateClassicIcon.swift <repo_root>")
    exit(1)
}
let repoRoot = URL(fileURLWithPath: args[1])
let assets = repoRoot.appendingPathComponent("QuietFinance").appendingPathComponent("Assets.xcassets")

// MARK: - True n=5 superellipse (matches macOS system squircle mask)

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

// MARK: - Classic icon renderer

func renderClassic(pixelSize: Int) -> CGImage {
    let size = CGFloat(pixelSize)
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(
        data: nil, width: pixelSize, height: pixelSize,
        bitsPerComponent: 8, bytesPerRow: 0, space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    // 9% transparent safe-area ring — Dock composites at correct visual weight
    let pad: CGFloat = 0.09
    let artSize = size * (1 - 2 * pad)
    let artOff  = size * pad
    let artRect = CGRect(x: artOff, y: artOff, width: artSize, height: artSize)

    // True n=5 superellipse clip
    let sq = squirclePath(in: artRect, exponent: 5.0)
    ctx.addPath(sq)
    ctx.clip()

    // Background: brand blue gradient (UI-kit qf-appicon: #3D93D8 → #1A74C4 → #0E4E8A)
    let bgTop    = CGColor(srgbRed: 0.239, green: 0.576, blue: 0.847, alpha: 1.0) // #3D93D8
    let bgMid    = CGColor(srgbRed: 0.102, green: 0.455, blue: 0.769, alpha: 1.0) // #1A74C4
    let bgBottom = CGColor(srgbRed: 0.055, green: 0.306, blue: 0.541, alpha: 1.0) // #0E4E8A
    let bgGrad = CGGradient(colorsSpace: cs,
                            colors: [bgTop, bgMid, bgBottom] as CFArray,
                            locations: [0.0, 0.55, 1.0])!
    ctx.drawLinearGradient(bgGrad,
        start: CGPoint(x: artOff + artSize * 0.25, y: artOff + artSize),
        end:   CGPoint(x: artOff + artSize * 0.75, y: artOff),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

    // Six ascending snapshot bars (net worth over time), white
    struct Bar { let heightFrac: CGFloat; let alpha: CGFloat }
    let bars: [Bar] = [
        Bar(heightFrac: 0.22, alpha: 0.42),
        Bar(heightFrac: 0.30, alpha: 0.48),
        Bar(heightFrac: 0.26, alpha: 0.48),
        Bar(heightFrac: 0.40, alpha: 0.54),
        Bar(heightFrac: 0.36, alpha: 0.54),
        Bar(heightFrac: 0.54, alpha: 1.00),  // tallest = today
    ]

    let barCount  = CGFloat(bars.count)
    let sidePad   = artSize * 0.195
    let bottomPad = artSize * 0.225
    let topPad    = artSize * 0.190
    let maxBarH   = artSize - topPad - bottomPad
    let totalBarW = artSize - sidePad * 2
    let gap       = artSize * 0.030
    let barW      = (totalBarW - gap * (barCount - 1)) / barCount
    let barRadius = barW * 0.34

    for (i, bar) in bars.enumerated() {
        let barH = maxBarH * bar.heightFrac
        let x = artOff + sidePad + CGFloat(i) * (barW + gap)
        let y = artOff + bottomPad  // CG origin = bottom-left
        let rect = CGRect(x: x, y: y, width: barW, height: barH)
        let path = CGPath(roundedRect: rect, cornerWidth: barRadius,
                          cornerHeight: barRadius, transform: nil)
        ctx.addPath(path)
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: bar.alpha))
        ctx.fillPath()
    }

    // Today indicator: glowing dot above tallest bar
    let lastIdx  = bars.count - 1
    let lastBarH = maxBarH * bars[lastIdx].heightFrac
    let lastX    = artOff + sidePad + CGFloat(lastIdx) * (barW + gap) + barW / 2
    let dotY     = artOff + bottomPad + lastBarH + artSize * 0.055
    let dotR     = artSize * 0.040

    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: artSize * 0.04,
                  color: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.55))
    ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.28))
    ctx.fillEllipse(in: CGRect(x: lastX - dotR * 1.9, y: dotY - dotR * 1.9,
                                width: dotR * 3.8, height: dotR * 3.8))
    ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1.0))
    ctx.fillEllipse(in: CGRect(x: lastX - dotR, y: dotY - dotR,
                                width: dotR * 2, height: dotR * 2))
    ctx.restoreGState()

    // Subtle inner edge highlight on squircle
    ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.14))
    ctx.setLineWidth(max(1, size / 300))
    ctx.addPath(sq)
    ctx.strokePath()

    return ctx.makeImage()!
}

// MARK: - File helpers

func writePNG(_ image: CGImage, to url: URL) throws {
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                             withIntermediateDirectories: true)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL,
                                                     UTType.png.identifier as CFString,
                                                     1, nil) else {
        throw NSError(domain: "icon", code: 1)
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else {
        throw NSError(domain: "icon", code: 2)
    }
}

// MARK: - AppIcon.appiconset sizes

let appIconSpecs: [(filename: String, px: Int)] = [
    ("icon_16x16.png",      16),
    ("icon_16x16@2x.png",   32),
    ("icon_32x32.png",      32),
    ("icon_32x32@2x.png",   64),
    ("icon_128x128.png",    128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png",    256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png",    512),
    ("icon_512x512@2x.png", 1024),
]

let appIconDir = assets.appendingPathComponent("AppIcon.appiconset")

for spec in appIconSpecs {
    let image = renderClassic(pixelSize: spec.px)
    let url = appIconDir.appendingPathComponent(spec.filename)
    do {
        try writePNG(image, to: url)
        print("✓ AppIcon/\(spec.filename)")
    } catch {
        print("⚠️ \(spec.filename): \(error)")
    }
}

// MARK: - IconClassic.imageset (256px preview for in-app switcher)

let classicPreviewDir = assets.appendingPathComponent("IconClassic.imageset")
let classicImage = renderClassic(pixelSize: 256)
do {
    try writePNG(classicImage, to: classicPreviewDir.appendingPathComponent("icon.png"))
    print("✓ IconClassic.imageset/icon.png")
} catch {
    print("⚠️ IconClassic: \(error)")
}

print("Done.")
