import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: String, alpha: CGFloat = 1) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        if s.count == 6 {
            self.init(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                      blue: CGFloat(v & 0xFF) / 255, alpha: alpha)
        } else {
            self.init(white: 0.5, alpha: alpha)
        }
    }

    static func dynamic(light: String, dark: String, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark, alpha: darkAlpha) : UIColor(hex: light, alpha: lightAlpha)
        }
    }

    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02x%02x%02x", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

extension Color {
    init(hex: String) { self.init(uiColor: UIColor(hex: hex)) }
}

/// Named colour tokens from the mockup. Dark values swap in automatically.
enum Theme {
    static let accent = Color(uiColor: .dynamic(light: "#2f6bff", dark: "#4d82ff"))
    static let accentSoft = Color(uiColor: .dynamic(light: "#2f6bff", dark: "#4d82ff", lightAlpha: 0.12, darkAlpha: 0.18))
    static let bg = Color(uiColor: .dynamic(light: "#ffffff", dark: "#121316"))
    /// Header bar, title row and sheet bands (the lighter dark grey in Mihai's screenshots).
    static let chrome = Color(uiColor: .dynamic(light: "#f6f7f9", dark: "#1d1f23"))
    static let sheet = Color(uiColor: .dynamic(light: "#ffffff", dark: "#1d1f23"))
    static let groupedBG = Color(uiColor: .dynamic(light: "#eef0f4", dark: "#121316"))
    static let fill = Color(uiColor: .dynamic(light: "#eef0f4", dark: "#25282c"))
    static let fill2 = Color(uiColor: .dynamic(light: "#e3e6ec", dark: "#2c2f34"))
    static let ink = Color(uiColor: .dynamic(light: "#121419", dark: "#f3f4f7"))
    static let ink2 = Color(uiColor: .dynamic(light: "#5c616e", dark: "#a3a7b2"))
    static let ink3 = Color(uiColor: .dynamic(light: "#9aa0ac", dark: "#6b707c"))
    static let line = Color(uiColor: .dynamic(light: "#121419", dark: "#ffffff", lightAlpha: 0.08, darkAlpha: 0.08))
    static let outsideMonth = Color(uiColor: .dynamic(light: "#f6f7fa", dark: "#17181b"))
    static let tile = Color(uiColor: .dynamic(light: "#f1f2f5", dark: "#1f2125"))
    static let danger = Color(hex: "#ff3b30")
    static let headerInk = Color(uiColor: .dynamic(light: "#121419", dark: "#f3f4f7"))

    /// Custom event colours offered in the editor.
    static let swatches: [(name: String, hex: String)] = [
        ("Green", "#2fb82f"), ("Grey", "#9b9ea6"), ("Teal", "#00c98a"), ("Blue", "#3e83f7")
    ]
    static let morePalette: [String] = [
        "#ff3b30", "#ff2d55", "#ffcc00", "#2fb35a", "#30b0c7", "#2f6bff", "#5856d6", "#a259e6", "#a2845e", "#636366"
    ]
}

/// Chip text: the calendar colour lifted towards the ink colour so it stays readable on its tint.
struct ChipColors {
    let base: Color
    let fill: Color
    let text: Color

    init(hex: String, scheme: ColorScheme) {
        let ui = UIColor(hex: hex)
        base = Color(uiColor: ui)
        fill = Color(uiColor: ui.withAlphaComponent(scheme == .dark ? 0.24 : 0.16))
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        if scheme == .dark {
            text = Color(uiColor: UIColor(hue: h, saturation: s * 0.55, brightness: min(1, b * 0.6 + 0.45), alpha: 1))
        } else {
            text = Color(uiColor: UIColor(hue: h, saturation: min(1, s * 1.05), brightness: b * 0.62, alpha: 1))
        }
    }
}
