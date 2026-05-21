#!/usr/bin/env swift
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Generates two additional app icons as 256x256 PNGs into:
//   QuietFinance/Assets.xcassets/IconVault.imageset/icon.png
//   QuietFinance/Assets.xcassets/IconStrata.imageset/icon.png
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

func squircle(_ ctx: CGContext, size: CGFloat) -> CGPath {
    let r = size * 0.2234
    let path = CGPath(roundedRect: CGRect(x: 0, y: 0, width: size, height: size),
                      cornerWidth: r, cornerHeight: r, transform: nil)
    ctx.addPath(path)
    ctx.clip()
    return path
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
    if !CGImageDestinationFinalize(dest) {
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

func renderVault(_ pixels: Int) -> CGImage {
    let size = CGFloat(pixels)
    let ctx = makeContext(pixels)
    let cs = CGColorSpaceCreateDeviceRGB()
    let outline = squircle(ctx, size: size)

    // Background — deep teal radial.
    let bgTop    = CGColor(srgbRed: 0.060, green: 0.155, blue: 0.180, alpha: 1.0)
    let bgMid    = CGColor(srgbRed: 0.035, green: 0.095, blue: 0.120, alpha: 1.0)
    let bgBottom = CGColor(srgbRed: 0.018, green: 0.052, blue: 0.072, alpha: 1.0)
    let bgGrad = CGGradient(colorsSpace: cs,
                            colors: [bgTop, bgMid, bgBottom] as CFArray,
                            locations: [0.0, 0.55, 1.0])!
    ctx.drawRadialGradient(bgGrad,
        startCenter: CGPoint(x: size * 0.5, y: size * 0.95),
        startRadius: 0,
        endCenter: CGPoint(x: size * 0.5, y: size * 0.35),
        endRadius: size * 1.05,
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

    // Concentric gold rings — three "snapshot" rings + one bright outer.
    let center = CGPoint(x: size * 0.5, y: size * 0.5)
    let goldFaint  = CGColor(srgbRed: 0.78, green: 0.62, blue: 0.32, alpha: 0.35)
    let goldMid    = CGColor(srgbRed: 0.86, green: 0.70, blue: 0.38, alpha: 0.65)
    let goldBright = CGColor(srgbRed: 0.97, green: 0.83, blue: 0.50, alpha: 1.0)

    let radii: [(CGFloat, CGColor, CGFloat)] = [
        (size * 0.16, goldFaint,  max(1.5, size * 0.010)),
        (size * 0.24, goldMid,    max(1.5, size * 0.011)),
        (size * 0.32, goldBright, max(2.0, size * 0.014)),
    ]
    for (r, color, w) in radii {
        ctx.setStrokeColor(color)
        ctx.setLineWidth(w)
        ctx.strokeEllipse(in: CGRect(x: center.x - r, y: center.y - r,
                                      width: r * 2, height: r * 2))
    }

    // Soft glow on outer ring.
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: size * 0.04, color: goldBright)
    ctx.setStrokeColor(goldBright)
    ctx.setLineWidth(max(2, size * 0.012))
    let outerR = size * 0.32
    ctx.strokeEllipse(in: CGRect(x: center.x - outerR, y: center.y - outerR,
                                  width: outerR * 2, height: outerR * 2))
    ctx.restoreGState()

    // Bright marker dot on outer ring (top — "now").
    let markerR = size * 0.024
    let markerCenter = CGPoint(x: center.x, y: center.y + outerR)
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: size * 0.05, color: goldBright)
    ctx.setFillColor(goldBright)
    ctx.fillEllipse(in: CGRect(x: markerCenter.x - markerR,
                                y: markerCenter.y - markerR,
                                width: markerR * 2, height: markerR * 2))
    ctx.restoreGState()

    // Center dot.
    let coreR = size * 0.012
    ctx.setFillColor(goldBright)
    ctx.fillEllipse(in: CGRect(x: center.x - coreR, y: center.y - coreR,
                                width: coreR * 2, height: coreR * 2))

    // Faint vertical axis line through center for compass-like cue.
    ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.06))
    ctx.setLineWidth(max(1, size / 256))
    ctx.move(to: CGPoint(x: center.x, y: size * 0.10))
    ctx.addLine(to: CGPoint(x: center.x, y: size * 0.90))
    ctx.strokePath()

    // Squircle inner highlight.
    ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.10))
    ctx.setLineWidth(max(1, size / 400))
    ctx.addPath(outline)
    ctx.strokePath()

    return ctx.makeImage()!
}

// MARK: - Strata icon

func renderStrata(_ pixels: Int) -> CGImage {
    let size = CGFloat(pixels)
    let ctx = makeContext(pixels)
    let cs = CGColorSpaceCreateDeviceRGB()
    let outline = squircle(ctx, size: size)

    // Cream paper background with very faint grain (radial highlight).
    let paperHi = CGColor(srgbRed: 0.985, green: 0.972, blue: 0.940, alpha: 1.0)
    let paperLo = CGColor(srgbRed: 0.940, green: 0.918, blue: 0.876, alpha: 1.0)
    let paperGrad = CGGradient(colorsSpace: cs,
                               colors: [paperHi, paperLo] as CFArray,
                               locations: [0.0, 1.0])!
    ctx.drawRadialGradient(paperGrad,
        startCenter: CGPoint(x: size * 0.30, y: size * 0.78),
        startRadius: 0,
        endCenter:   CGPoint(x: size * 0.50, y: size * 0.50),
        endRadius:   size * 0.90,
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

    // Five stacked horizontal bars representing allocation categories.
    // Widths chosen to suggest a real distribution (largest to smallest).
    struct Bar { let widthFrac: CGFloat; let color: CGColor }
    let palette: [Bar] = [
        Bar(widthFrac: 0.78, color: CGColor(srgbRed: 0.110, green: 0.290, blue: 0.330, alpha: 1.0)), // deep teal
        Bar(widthFrac: 0.62, color: CGColor(srgbRed: 0.230, green: 0.470, blue: 0.420, alpha: 1.0)), // sage
        Bar(widthFrac: 0.50, color: CGColor(srgbRed: 0.820, green: 0.640, blue: 0.310, alpha: 1.0)), // gold
        Bar(widthFrac: 0.34, color: CGColor(srgbRed: 0.690, green: 0.380, blue: 0.220, alpha: 1.0)), // copper
        Bar(widthFrac: 0.20, color: CGColor(srgbRed: 0.380, green: 0.220, blue: 0.180, alpha: 1.0)), // ink-brown
    ]

    let leftPad   = size * 0.155
    let topPad    = size * 0.215
    let bottomPad = size * 0.215
    let totalH    = size - topPad - bottomPad
    let barCount  = CGFloat(palette.count)
    let gap       = size * 0.024
    let barH      = (totalH - gap * (barCount - 1)) / barCount
    let radius    = barH * 0.42
    let maxBarW   = size - leftPad * 2

    for (i, bar) in palette.enumerated() {
        // y from top — convert to CG bottom-origin.
        let topY = size - topPad - barH - CGFloat(i) * (barH + gap)
        let w = maxBarW * bar.widthFrac
        let rect = CGRect(x: leftPad, y: topY, width: w, height: barH)
        let path = CGPath(roundedRect: rect, cornerWidth: radius,
                          cornerHeight: radius, transform: nil)
        ctx.addPath(path)
        ctx.setFillColor(bar.color)
        ctx.fillPath()

        // Tiny tick at end of each bar for "value" mark.
        let tickR = barH * 0.18
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.55))
        ctx.fillEllipse(in: CGRect(x: leftPad + w - tickR * 2 - barH * 0.20,
                                    y: topY + barH / 2 - tickR,
                                    width: tickR * 2, height: tickR * 2))
    }

    // Vertical baseline guide on the left (paper rule).
    let inkBrown = CGColor(srgbRed: 0.380, green: 0.220, blue: 0.180, alpha: 0.55)
    ctx.setStrokeColor(inkBrown)
    ctx.setLineWidth(max(2, size * 0.012))
    ctx.move(to: CGPoint(x: leftPad - size * 0.022, y: bottomPad))
    ctx.addLine(to: CGPoint(x: leftPad - size * 0.022, y: size - topPad))
    ctx.strokePath()

    // Small gold "L" wordmark in top-left corner area.
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    let fontSize = size * 0.16
    let font = NSFont(name: "Times-Italic", size: fontSize)
            ?? NSFont(name: "TimesNewRomanPS-ItalicMT", size: fontSize)
            ?? NSFont.systemFont(ofSize: fontSize)
    let goldText = NSColor(srgbRed: 0.640, green: 0.470, blue: 0.180, alpha: 1.0)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: goldText,
        .kern: -fontSize * 0.04
    ]
    let lStr = NSAttributedString(string: "L", attributes: attrs)
    // Top-right: size * 0.78, top area
    let lSize = lStr.size()
    lStr.draw(at: CGPoint(x: size - lSize.width - size * 0.14,
                          y: size - lSize.height - size * 0.06))
    NSGraphicsContext.restoreGraphicsState()

    // Inner border (very subtle).
    ctx.setStrokeColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.06))
    ctx.setLineWidth(max(1, size / 256))
    ctx.addPath(outline)
    ctx.strokePath()

    return ctx.makeImage()!
}

// MARK: - Drive

let outputs: [(name: String, image: CGImage)] = [
    ("IconVault.imageset",  renderVault(pixelSize)),
    ("IconStrata.imageset", renderStrata(pixelSize)),
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
