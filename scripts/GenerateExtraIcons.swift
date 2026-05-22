#!/usr/bin/env swift
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Generates alternate app icons into Assets.xcassets:
//   IconVault.imageset/icon.png
//   IconStrata.imageset/icon.png
//   IconClassic.imageset/icon.png
//
// All icons follow the Quiet Apps icon standard:
//   - 1024×1024 canvas, 9% transparent safe-area ring
//   - True n=5 superellipse (not CGPath(roundedRect:))
//   - Brand blue gradient (#3D93D8 → #1A74C4 → #0E4E8A) background
//   - White motifs only — no decorative gradients, no off-brand colors
//
// Usage:
//   swift scripts/GenerateExtraIcons.swift <repo_root>

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("Usage: swift GenerateExtraIcons.swift <repo_root>")
    exit(1)
}
let repoRoot = URL(fileURLWithPath: args[1])
let assets = repoRoot
    .appendingPathComponent("QuietFinance")
    .appendingPathComponent("Assets.xcassets")

let pixelSize = 256

// MARK: - Helpers

func makeContext(_ size: Int) -> CGContext {
    let cs = CGColorSpaceCreateDeviceRGB()
    return CGContext(
        data: nil, width: size, height: size,
        bitsPerComponent: 8, bytesPerRow: 0, space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
}

// Brand palette helpers

func blueBgGradient(cs: CGColorSpace) -> CGGradient {
    CGGradient(colorsSpace: cs,
               colors: [CGColor(srgbRed: 0.239, green: 0.576, blue: 0.847, alpha: 1.0),  // #3D93D8
                        CGColor(srgbRed: 0.102, green: 0.455, blue: 0.769, alpha: 1.0),  // #1A74C4
                        CGColor(srgbRed: 0.055, green: 0.306, blue: 0.541, alpha: 1.0)] as CFArray, // #0E4E8A
               locations: [0.0, 0.55, 1.0])!
}

func darkInkGradient(cs: CGColorSpace) -> CGGradient {
    // Near-black: #0B0D11 → #1A1F2B — vault / premium feel
    CGGradient(colorsSpace: cs,
               colors: [CGColor(srgbRed: 0.133, green: 0.157, blue: 0.212, alpha: 1.0),  // #222436 top-light
                        CGColor(srgbRed: 0.067, green: 0.082, blue: 0.110, alpha: 1.0),  // #111520
                        CGColor(srgbRed: 0.043, green: 0.051, blue: 0.067, alpha: 1.0)] as CFArray, // #0B0D11
               locations: [0.0, 0.55, 1.0])!
}

func slateBgGradient(cs: CGColorSpace) -> CGGradient {
    // Cool dark slate: #1A2035 → #0D1117 — strata / layered feel
    CGGradient(colorsSpace: cs,
               colors: [CGColor(srgbRed: 0.137, green: 0.173, blue: 0.247, alpha: 1.0),  // #23303F top
                        CGColor(srgbRed: 0.082, green: 0.110, blue: 0.173, alpha: 1.0),  // #141C2C mid
                        CGColor(srgbRed: 0.051, green: 0.067, blue: 0.102, alpha: 1.0)] as CFArray, // #0D111A
               locations: [0.0, 0.55, 1.0])!
}

// True n=5 superellipse — matches macOS system squircle mask exactly.
// CGPath(roundedRect:) is NOT used because its corners diverge visually
// from the continuous-curvature superellipse macOS composites in the Dock.
func squirclePath(in rect: CGRect, n: CGFloat = 5.0) -> CGPath {
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

// Clips ctx to the squircle art area and fills the given gradient top→bottom.
// Returns artRect for callers to place motifs within.
@discardableResult
func applyBg(_ ctx: CGContext, size: CGFloat, gradient: CGGradient) -> CGRect {
    let pad: CGFloat = 0.09
    let artSize = size * (1 - 2 * pad)
    let artOff  = size * pad
    let artRect = CGRect(x: artOff, y: artOff, width: artSize, height: artSize)

    let sq = squirclePath(in: artRect)
    ctx.addPath(sq)
    ctx.clip()

    ctx.drawLinearGradient(gradient,
        start: CGPoint(x: artOff + artSize * 0.25, y: artOff + artSize),
        end:   CGPoint(x: artOff + artSize * 0.75, y: artOff),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

    return artRect
}

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

func writeContentsJSON(at imagesetURL: URL) throws {
    let json = """
    {
      "images" : [
        {
          "filename" : "icon.png",
          "idiom" : "universal",
          "scale" : "1x"
        },
        {
          "idiom" : "universal",
          "scale" : "2x"
        },
        {
          "idiom" : "universal",
          "scale" : "3x"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }
    """
    try json.write(to: imagesetURL.appendingPathComponent("Contents.json"),
                   atomically: true, encoding: .utf8)
}

// MARK: - Vault icon
// Motif: three concentric white arcs (radial snapshot timeline) + today dot.
// Reads as a vault dial / orbital tracker — each ring = a point in time.

func renderVault(_ pixels: Int) -> CGImage {
    let size = CGFloat(pixels)
    let ctx = makeContext(pixels)
    let cs = CGColorSpaceCreateDeviceRGB()
    let art = applyBg(ctx, size: size, gradient: darkInkGradient(cs: cs))

    let cx = art.midX
    let cy = art.midY

    // Three concentric arcs — innermost faintest, outermost brightest
    struct Ring { let radiusFrac: CGFloat; let alpha: CGFloat; let lineWidthFrac: CGFloat }
    let rings: [Ring] = [
        Ring(radiusFrac: 0.18, alpha: 0.35, lineWidthFrac: 0.028),
        Ring(radiusFrac: 0.28, alpha: 0.60, lineWidthFrac: 0.028),
        Ring(radiusFrac: 0.38, alpha: 1.00, lineWidthFrac: 0.032),
    ]

    // Arc spans ~300° (open at bottom-left for breathing room)
    let startAngle: CGFloat = .pi * 1.30   // ~234°
    let endAngle:   CGFloat = .pi * -0.10  // ~-18° = 342°

    for ring in rings {
        let r = art.width * ring.radiusFrac
        let lw = art.width * ring.lineWidthFrac
        ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: ring.alpha))
        ctx.setLineWidth(lw)
        ctx.setLineCap(.round)
        ctx.addArc(center: CGPoint(x: cx, y: cy),
                   radius: r,
                   startAngle: startAngle, endAngle: endAngle,
                   clockwise: false)
        ctx.strokePath()
    }

    // Today marker: bright dot on outermost arc at the end angle
    let outerR = art.width * rings[2].radiusFrac
    let dotX = cx + outerR * cos(endAngle)
    let dotY = cy + outerR * sin(endAngle)
    let dotR = art.width * 0.040

    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: art.width * 0.05,
                  color: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.60))
    ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.28))
    ctx.fillEllipse(in: CGRect(x: dotX - dotR * 1.9, y: dotY - dotR * 1.9,
                                width: dotR * 3.8, height: dotR * 3.8))
    ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1.0))
    ctx.fillEllipse(in: CGRect(x: dotX - dotR, y: dotY - dotR,
                                width: dotR * 2, height: dotR * 2))
    ctx.restoreGState()

    // Inner edge highlight
    let sq = squirclePath(in: art)
    ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.14))
    ctx.setLineWidth(max(1, size / 300))
    ctx.addPath(sq)
    ctx.strokePath()

    return ctx.makeImage()!
}

// MARK: - Strata icon
// Motif: five left-aligned white horizontal bars, descending width top→bottom.
// Represents asset allocation breakdown — each bar = a category's proportion.

func renderStrata(_ pixels: Int) -> CGImage {
    let size = CGFloat(pixels)
    let ctx = makeContext(pixels)
    let cs = CGColorSpaceCreateDeviceRGB()
    let art = applyBg(ctx, size: size, gradient: slateBgGradient(cs: cs))

    struct Bar { let widthFrac: CGFloat; let alpha: CGFloat }
    let bars: [Bar] = [
        Bar(widthFrac: 0.72, alpha: 1.00),
        Bar(widthFrac: 0.58, alpha: 0.78),
        Bar(widthFrac: 0.46, alpha: 0.60),
        Bar(widthFrac: 0.32, alpha: 0.45),
        Bar(widthFrac: 0.20, alpha: 0.32),
    ]

    let barCount  = CGFloat(bars.count)
    let leftPad   = art.minX + art.width * 0.155
    let topPad    = art.minY + art.height * 0.200
    let availH    = art.height * 0.600
    let gap       = art.height * 0.028
    let barH      = (availH - gap * (barCount - 1)) / barCount
    let barRadius = barH * 0.42
    let maxW      = art.width * 0.720

    for (i, bar) in bars.enumerated() {
        let y = topPad + CGFloat(i) * (barH + gap)
        let w = maxW * bar.widthFrac
        let rect = CGRect(x: leftPad, y: y, width: w, height: barH)
        let path = CGPath(roundedRect: rect, cornerWidth: barRadius,
                          cornerHeight: barRadius, transform: nil)
        ctx.addPath(path)
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: bar.alpha))
        ctx.fillPath()
    }

    // Left baseline rule
    ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.22))
    ctx.setLineWidth(max(1, size / 200))
    ctx.setLineCap(.round)
    let ruleX = leftPad - art.width * 0.030
    ctx.move(to: CGPoint(x: ruleX, y: topPad - barH * 0.2))
    ctx.addLine(to: CGPoint(x: ruleX, y: topPad + availH + barH * 0.2))
    ctx.strokePath()

    // Inner edge highlight
    let sq = squirclePath(in: art)
    ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.14))
    ctx.setLineWidth(max(1, size / 300))
    ctx.addPath(sq)
    ctx.strokePath()

    return ctx.makeImage()!
}

// MARK: - Classic icon (brand blue + ascending snapshot bars)

func renderClassic(_ pixels: Int) -> CGImage {
    let size = CGFloat(pixels)
    let ctx = makeContext(pixels)
    let cs = CGColorSpaceCreateDeviceRGB()
    let art = applyBg(ctx, size: size, gradient: blueBgGradient(cs: cs))

    struct Bar { let heightFrac: CGFloat; let alpha: CGFloat }
    let bars: [Bar] = [
        Bar(heightFrac: 0.22, alpha: 0.42),
        Bar(heightFrac: 0.30, alpha: 0.48),
        Bar(heightFrac: 0.26, alpha: 0.48),
        Bar(heightFrac: 0.40, alpha: 0.54),
        Bar(heightFrac: 0.36, alpha: 0.54),
        Bar(heightFrac: 0.54, alpha: 1.00),
    ]

    let barCount  = CGFloat(bars.count)
    let sidePad   = art.width * 0.195
    let bottomPad = art.height * 0.225
    let topPad    = art.height * 0.190
    let maxBarH   = art.height - topPad - bottomPad
    let totalBarW = art.width - sidePad * 2
    let gap       = art.width * 0.030
    let barW      = (totalBarW - gap * (barCount - 1)) / barCount
    let barRadius = barW * 0.34

    for (i, bar) in bars.enumerated() {
        let barH = maxBarH * bar.heightFrac
        let x = art.minX + sidePad + CGFloat(i) * (barW + gap)
        let y = art.minY + bottomPad
        let rect = CGRect(x: x, y: y, width: barW, height: barH)
        let path = CGPath(roundedRect: rect, cornerWidth: barRadius,
                          cornerHeight: barRadius, transform: nil)
        ctx.addPath(path)
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: bar.alpha))
        ctx.fillPath()
    }

    let lastIdx  = bars.count - 1
    let lastBarH = maxBarH * bars[lastIdx].heightFrac
    let lastX    = art.minX + sidePad + CGFloat(lastIdx) * (barW + gap) + barW / 2
    let dotY     = art.minY + bottomPad + lastBarH + art.height * 0.055
    let dotR     = art.width * 0.040

    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: art.width * 0.04,
                  color: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.55))
    ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.28))
    ctx.fillEllipse(in: CGRect(x: lastX - dotR * 1.9, y: dotY - dotR * 1.9,
                                width: dotR * 3.8, height: dotR * 3.8))
    ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1.0))
    ctx.fillEllipse(in: CGRect(x: lastX - dotR, y: dotY - dotR,
                                width: dotR * 2, height: dotR * 2))
    ctx.restoreGState()

    let sq = squirclePath(in: art)
    ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.14))
    ctx.setLineWidth(max(1, size / 300))
    ctx.addPath(sq)
    ctx.strokePath()

    return ctx.makeImage()!
}

// MARK: - Drive

let outputs: [(name: String, image: CGImage)] = [
    ("IconVault.imageset",   renderVault(pixelSize)),
    ("IconStrata.imageset",  renderStrata(pixelSize)),
    ("IconClassic.imageset", renderClassic(pixelSize)),
]

for (name, image) in outputs {
    let imagesetURL = assets.appendingPathComponent(name)
    let pngURL = imagesetURL.appendingPathComponent("icon.png")
    do {
        try writePNG(image, to: pngURL)
        try writeContentsJSON(at: imagesetURL)
        print("✓ \(name)")
    } catch {
        print("⚠️ failed \(name): \(error)")
    }
}
print("Done.")
