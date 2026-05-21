import SwiftUI
import AppKit
import CoreText

// MARK: - oklch → sRGB

enum Oklch {
    static func srgb(_ L: Double, _ C: Double, _ hDeg: Double) -> Color {
        let h = hDeg * .pi / 180
        let a = C * cos(h)
        let b = C * sin(h)

        let l_ = L + 0.3963377774 * a + 0.2158037573 * b
        let m_ = L - 0.1055613458 * a - 0.0638541728 * b
        let s_ = L - 0.0894841775 * a - 1.2914855480 * b

        let l = l_ * l_ * l_
        let m = m_ * m_ * m_
        let s = s_ * s_ * s_

        let r  =  4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        let g  = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        let b2 = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

        return Color(.sRGB, red: gamma(r), green: gamma(g), blue: gamma(b2), opacity: 1)
    }

    private static func gamma(_ x: Double) -> Double {
        let v = max(0, min(1, x))
        return v <= 0.0031308 ? 12.92 * v : 1.055 * pow(v, 1.0 / 2.4) - 0.055
    }
}

// MARK: - Quiet Finance palette (light + dark aware)

enum Ink {
    static let bg        = DualColor(light: Oklch.srgb(0.985, 0.004, 85),  dark: Oklch.srgb(0.16,  0.008, 270))
    static let bg2       = DualColor(light: Oklch.srgb(0.975, 0.005, 85),  dark: Oklch.srgb(0.185, 0.008, 270))
    static let bgPanel   = DualColor(light: Color.white,                    dark: Oklch.srgb(0.205, 0.009, 270))
    static let bgSunken  = DualColor(light: Oklch.srgb(0.965, 0.006, 85),  dark: Oklch.srgb(0.14,  0.008, 270))

    static let line       = DualColor(light: Oklch.srgb(0.90, 0.006, 85),  dark: Oklch.srgb(0.28, 0.010, 270))
    static let lineStrong = DualColor(light: Oklch.srgb(0.82, 0.008, 85),  dark: Oklch.srgb(0.36, 0.012, 270))

    static let ink  = DualColor(light: Oklch.srgb(0.18, 0.010, 270), dark: Oklch.srgb(0.97, 0.004, 85))
    static let ink2 = DualColor(light: Oklch.srgb(0.38, 0.012, 270), dark: Oklch.srgb(0.82, 0.006, 85))
    static let ink3 = DualColor(light: Oklch.srgb(0.58, 0.010, 270), dark: Oklch.srgb(0.62, 0.008, 85))
    static let ink4 = DualColor(light: Oklch.srgb(0.72, 0.008, 270), dark: Oklch.srgb(0.45, 0.010, 85))

    static let gain     = DualColor(light: Oklch.srgb(0.58, 0.13, 155), dark: Oklch.srgb(0.75, 0.15, 155))
    static let gainSoft = DualColor(light: Oklch.srgb(0.92, 0.05, 155), dark: Oklch.srgb(0.30, 0.06, 155))
    static let loss     = DualColor(light: Oklch.srgb(0.55, 0.17, 25),  dark: Oklch.srgb(0.72, 0.16, 25))
    static let lossSoft = DualColor(light: Oklch.srgb(0.93, 0.05, 25),  dark: Oklch.srgb(0.30, 0.08, 25))

    static let accent = DualColor(light: Oklch.srgb(0.45, 0.08, 250), dark: Oklch.srgb(0.75, 0.10, 250))

    static let chart: [DualColor] = [
        // chart[0] — real estate: warm brown in dark (was near-white, clashed with text)
        DualColor(light: Oklch.srgb(0.45, 0.09, 55),  dark: Oklch.srgb(0.68, 0.10, 55)),
        // chart[1] — investment: green
        DualColor(light: Oklch.srgb(0.55, 0.12, 155), dark: Oklch.srgb(0.72, 0.14, 155)),
        // chart[2] — cash: orange
        DualColor(light: Oklch.srgb(0.62, 0.14, 60),  dark: Oklch.srgb(0.78, 0.14, 60)),
        // chart[3] — debt: red
        DualColor(light: Oklch.srgb(0.55, 0.13, 25),  dark: Oklch.srgb(0.72, 0.15, 25)),
        // chart[4] — retirement: purple
        DualColor(light: Oklch.srgb(0.50, 0.10, 280), dark: Oklch.srgb(0.72, 0.13, 280)),
        // chart[5] — crypto: teal
        DualColor(light: Oklch.srgb(0.62, 0.08, 200), dark: Oklch.srgb(0.78, 0.10, 200)),
        // chart[6] — insurance: yellow in dark (was desaturated gray)
        DualColor(light: Oklch.srgb(0.65, 0.10, 95),  dark: Oklch.srgb(0.82, 0.13, 95)),
    ]
}

struct DualColor {
    let light: Color
    let dark: Color
    var color: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua, .accessibilityHighContrastVibrantDark]) != nil
            return NSColor(isDark ? dark : light)
        })
    }
}

extension Color {
    static var lBg: Color         { Ink.bg.color }
    static var lBg2: Color        { Ink.bg2.color }
    static var lPanel: Color      { Ink.bgPanel.color }
    static var lSunken: Color     { Ink.bgSunken.color }
    static var lLine: Color       { Ink.line.color }
    static var lLineStrong: Color { Ink.lineStrong.color }
    static var lInk: Color        { Ink.ink.color }
    static var lInk2: Color       { Ink.ink2.color }
    static var lInk3: Color       { Ink.ink3.color }
    static var lInk4: Color       { Ink.ink4.color }
    static var lGain: Color       { Ink.gain.color }
    static var lGainSoft: Color   { Ink.gainSoft.color }
    static var lLoss: Color       { Ink.loss.color }
    static var lLossSoft: Color   { Ink.lossSoft.color }
    static var lAccent: Color     { Ink.accent.color }
}

// MARK: - Fonts (Geist + Geist Mono + Instrument Serif)

enum Typo {
    static let sans    = "Geist"
    static let sansMed = "Geist-Medium"
    static let sansSB  = "Geist-SemiBold"
    static let sansB   = "Geist-Bold"
    static let mono    = "GeistMono-Regular"
    static let monoMed = "GeistMono-Medium"
    static let monoSB  = "GeistMono-SemiBold"
    static let serif   = "InstrumentSerif-Regular"
    static let serifIt = "InstrumentSerif-Italic"

    static func serifNum(_ size: CGFloat) -> Font {
        .custom(serif, size: size).weight(.regular)
    }
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .medium:   name = monoMed
        case .semibold: name = monoSB
        case .bold:     name = monoSB
        default:        name = mono
        }
        return .custom(name, size: size)
    }
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .medium:   name = sansMed
        case .semibold: name = sansSB
        case .bold:     name = sansB
        default:        name = sans
        }
        return .custom(name, size: size)
    }
    static func serifItalic(_ size: CGFloat) -> Font {
        .custom(serifIt, size: size)
    }

    /// eyebrow: tiny uppercase mono label
    static let eyebrow    = Font.custom(mono, size: 10).weight(.medium)
    static let label      = Font.custom(mono, size: 11).weight(.medium)
    static let bodySans   = Font.custom(sans, size: 13)
    static let bodyMono   = Font.custom(mono, size: 12)
}

// MARK: - Font registrar

enum FontRegistrar {
    private static var registered = false

    static func registerIfNeeded() {
        guard !registered else { return }
        registered = true
        let names = [
            "Geist-Regular", "Geist-Medium", "Geist-SemiBold", "Geist-Bold",
            "GeistMono-Regular", "GeistMono-Medium", "GeistMono-SemiBold",
            "InstrumentSerif-Regular", "InstrumentSerif-Italic",
        ]
        let bundle = Bundle.main
        for name in names {
            guard let url = bundle.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
                       ?? bundle.url(forResource: name, withExtension: "ttf") else {
                print("[FontRegistrar] missing: \(name).ttf")
                continue
            }
            var err: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &err) {
                if let e = err?.takeRetainedValue() {
                    let code = CFErrorGetCode(e)
                    // 105 = already registered — fine
                    if code != 105 { print("[FontRegistrar] \(name): \(e)") }
                }
            }
        }
    }
}

// MARK: - Legacy palette (kept so old views still compile until replaced)

enum Palette {
    static func defaultColor(for category: AssetCategory) -> Color {
        switch category {
        case .retirement: return Ink.chart[4].color
        case .investment: return Ink.chart[1].color
        case .cash:       return Ink.chart[2].color
        case .crypto:     return Ink.chart[5].color
        case .insurance:  return Ink.chart[6].color
        case .realEstate: return Ink.chart[0].color
        case .debt:       return Ink.chart[3].color
        }
    }

    static func color(for category: AssetCategory) -> Color {
        Color.fromHex(CategoryColorStore.hex(for: category)) ?? defaultColor(for: category)
    }

    static func fallback(for key: String) -> Color {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        let idx = Int(hash % UInt64(Ink.chart.count))
        return Ink.chart[idx].color
    }

    static func unusedFallback(taken: [String]) -> Color {
        let takenSet = Set(taken.compactMap { $0.isEmpty ? nil : $0.lowercased() })
        let available = Ink.chart.filter { dc in
            let lh = dc.light.toHex()?.lowercased()
            let dh = dc.dark.toHex()?.lowercased()
            if let lh, takenSet.contains(lh) { return false }
            if let dh, takenSet.contains(dh) { return false }
            return true
        }
        let pool = available.isEmpty ? Ink.chart : available
        return pool.randomElement()!.color
    }

    static var up:   Color { Ink.gain.color }
    static var down: Color { Ink.loss.color }

    static func deltaColor(_ value: Double) -> Color {
        value >= 0 ? up : down
    }
}

// MARK: - Hex helpers

extension Color {
    static func fromHex(_ hex: String?) -> Color? {
        guard let hex, !hex.isEmpty else { return nil }
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let val = UInt32(s, radix: 16) else { return nil }
        let r = Double((val >> 16) & 0xFF) / 255
        let g = Double((val >> 8) & 0xFF) / 255
        let b = Double(val & 0xFF) / 255
        return Color(red: r, green: g, blue: b)
    }

    func toHex() -> String? {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        let r = Int(round(ns.redComponent * 255))
        let g = Int(round(ns.greenComponent * 255))
        let b = Int(round(ns.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

enum CategoryColorStore {
    private static let keyPrefix = "categoryColor."

    static func hex(for category: AssetCategory) -> String? {
        UserDefaults.standard.string(forKey: keyPrefix + category.rawValue)
    }

    static func setHex(_ hex: String?, for category: AssetCategory) {
        let key = keyPrefix + category.rawValue
        if let hex { UserDefaults.standard.set(hex, forKey: key) }
        else { UserDefaults.standard.removeObject(forKey: key) }
    }
}

enum TargetAllocationStore {
    private static let keyPrefix = "targetAlloc."
    private static let existsSuffix = ".set"

    static func pct(for category: AssetCategory) -> Double? {
        let base = keyPrefix + category.rawValue
        guard UserDefaults.standard.bool(forKey: base + existsSuffix) else { return nil }
        return UserDefaults.standard.double(forKey: base)
    }

    static func setPct(_ value: Double?, for category: AssetCategory) {
        let base = keyPrefix + category.rawValue
        if let value {
            UserDefaults.standard.set(value, forKey: base)
            UserDefaults.standard.set(true, forKey: base + existsSuffix)
        } else {
            UserDefaults.standard.removeObject(forKey: base)
            UserDefaults.standard.removeObject(forKey: base + existsSuffix)
        }
    }

    static func all() -> [AssetCategory: Double] {
        var map: [AssetCategory: Double] = [:]
        for c in AssetCategory.allCases {
            if let v = pct(for: c) { map[c] = v }
        }
        return map
    }

    static func totalSet() -> Double {
        all().values.reduce(0, +)
    }
}

