#!/usr/bin/env swift
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Usage:
//   swift scripts/GenerateIcon.swift <output_appiconset_dir>
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

// MARK: palette (approximate oklch → sRGB)

let paperColor   = CGColor(srgbRed: 0.972, green: 0.962, blue: 0.933, alpha: 1.0)
let inkTop       = CGColor(srgbRed: 0.295, green: 0.215, blue: 0.150, alpha: 1.0)
let inkMid       = CGColor(srgbRed: 0.160, green: 0.180, blue: 0.225, alpha: 1.0)
let inkBottom    = CGColor(srgbRed: 0.090, green: 0.105, blue: 0.140, alpha: 1.0)
let greenMain    = CGColor(srgbRed: 0.380, green: 0.820, blue: 0.545, alpha: 1.0)
let greenGlow    = CGColor(srgbRed: 0.480, green: 0.900, blue: 0.620, alpha: 1.0)

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

    // Squircle clip (~22.3% corner radius, standard macOS)
    let radius = size * 0.2234
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let squircle = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.addPath(squircle)
    ctx.clip()

    // Background: radial gradient from top (warm) to bottom (deep ink)
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [inkTop, inkMid, inkBottom] as CFArray,
        locations: [0.0, 0.55, 1.0]
    )!
    ctx.drawRadialGradient(
        gradient,
        startCenter: CGPoint(x: size / 2, y: size),
        startRadius: 0,
        endCenter: CGPoint(x: size / 2, y: size * 0.3),
        endRadius: size * 0.95,
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )

    // Subtle grid at >= 128px
    if pixelSize >= 128 {
        ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.025))
        ctx.setLineWidth(1)
        let step = size / 8
        for i in 1..<8 {
            let p = CGFloat(i) * step
            ctx.move(to: CGPoint(x: p, y: 0))
            ctx.addLine(to: CGPoint(x: p, y: size))
            ctx.move(to: CGPoint(x: 0, y: p))
            ctx.addLine(to: CGPoint(x: size, y: p))
        }
        ctx.strokePath()
    }

    // Sparkline at >= 64px. Coords in a 512-unit design space, mapped to current.
    if pixelSize >= 64 {
        let scale = size / 512
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            // Convert from HTML-top-origin 512 space to CG bottom-origin scaled space
            CGPoint(x: x * scale, y: (512 - y) * scale)
        }
        let path = CGMutablePath()
        path.move(to: pt(0, 380))
        path.addCurve(to: pt(160, 330), control1: pt(60, 360), control2: pt(100, 385))
        path.addCurve(to: pt(320, 260), control1: pt(220, 280), control2: pt(260, 240))
        path.addCurve(to: pt(512, 80),  control1: pt(420, 140), control2: pt(460, 100))

        // Area fill (faint green)
        let fillPath = path.mutableCopy()!
        fillPath.addLine(to: pt(512, 512))
        fillPath.addLine(to: pt(0, 512))
        fillPath.closeSubpath()
        ctx.saveGState()
        ctx.addPath(fillPath)
        ctx.clip()
        let fillGradient = CGGradient(
            colorsSpace: colorSpace,
            colors: [
                CGColor(srgbRed: 0.38, green: 0.82, blue: 0.545, alpha: 0.22),
                CGColor(srgbRed: 0.38, green: 0.82, blue: 0.545, alpha: 0.0)
            ] as CFArray,
            locations: [0.0, 1.0]
        )!
        ctx.drawLinearGradient(fillGradient,
            start: CGPoint(x: size / 2, y: size),
            end: CGPoint(x: size / 2, y: 0),
            options: [])
        ctx.restoreGState()

        // Line
        ctx.setStrokeColor(greenMain)
        ctx.setLineWidth(max(2, size / 100))
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.addPath(path)
        ctx.strokePath()

        // Endpoint dot
        let endR = max(3, size / 70)
        ctx.setFillColor(greenGlow)
        ctx.fillEllipse(in: CGRect(x: size - endR, y: size - endR * 2 + (size / 512) * 80 - endR,
                                   width: endR * 2, height: endR * 2))
    }

    // Big italic serif L (paper color)
    // Use NSString drawing via AppKit for text layout.
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)

    let fontSize: CGFloat
    let xRatio: CGFloat
    let yRatio: CGFloat
    if pixelSize >= 128 {
        fontSize = size * 0.70
        xRatio = 0.10
        yRatio = 0.08
    } else if pixelSize >= 48 {
        fontSize = size * 0.78
        xRatio = 0.12
        yRatio = 0.05
    } else {
        fontSize = size * 0.85
        xRatio = 0.12
        yRatio = 0.02
    }
    let font = NSFont(name: "Times-Italic", size: fontSize)
            ?? NSFont(name: "TimesNewRomanPS-ItalicMT", size: fontSize)
            ?? NSFontManager.shared.font(withFamily: "Times", traits: .italicFontMask, weight: 5, size: fontSize)
            ?? NSFont.systemFont(ofSize: fontSize)

    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(cgColor: paperColor) ?? .white,
        .kern: -fontSize * 0.05
    ]
    let lStr = NSAttributedString(string: "L", attributes: attrs)
    lStr.draw(at: CGPoint(x: size * xRatio, y: size * yRatio))

    NSGraphicsContext.restoreGraphicsState()

    // Green dot near top-right of L at >= 48px
    if pixelSize >= 48 {
        let dotSize = max(3, size * 0.05)
        let lSize = lStr.size()
        let dotX = size * xRatio + lSize.width * 0.75
        let dotY = size * (pixelSize >= 128 ? 0.60 : 0.62)
        ctx.setFillColor(greenMain)
        ctx.fillEllipse(in: CGRect(x: dotX, y: dotY, width: dotSize, height: dotSize))

        // Soft glow
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: dotSize * 2, color: greenMain)
        ctx.setFillColor(greenMain)
        ctx.fillEllipse(in: CGRect(x: dotX, y: dotY, width: dotSize, height: dotSize))
        ctx.restoreGState()
    }

    // Thin top highlight — faint white line at very top inside squircle
    if pixelSize >= 64 {
        ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.12))
        ctx.setLineWidth(max(1, size / 400))
        ctx.addPath(squircle)
        ctx.strokePath()
    }

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
