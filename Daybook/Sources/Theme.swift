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
    static let bg = Color(uiColor: .dynamic(light: "#ffffff", dark: "#0f1013"))
    static let sheet = Color(uiColor: .dynamic(light: "#ffffff", dark: "#17181c"))
    static let groupedBG = Color(uiColor: .dynamic(light: "#f2f3f7", dark: "#0f1013"))
    static let fill = Color(uiColor: .dynamic(light: "#f2f3f7", dark: "#1c1d22"))
    static let fill2 = Color(uiColor: .dynamic(light: "#e8eaf0", dark: "#26282e"))
    static let ink = Color(uiColor: .dynamic(light: "#121419", dark: "#f3f4f7"))
    static let ink2 = Color(uiColor: .dynamic(light: "#5c616e", dark: "#a3a7b2"))
    static let ink3 = Color(uiColor: .dynamic(light: "#9aa0ac", dark: "#6b707c"))
    static let line = Color(uiColor: .dynamic(light: "#121419", dark: "#ffffff", lightAlpha: 0.08, darkAlpha: 0.08))
    static let outsideMonth = Color(uiColor: .dynamic(light: "#f6f7fa", dark: "#16171b"))
    static let danger = Color(hex: "#ff3b30")
    static let headerGradient = LinearGradient(colors: [Color(hex: "#121831"), Color(hex: "#33349a")],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)

    /// Custom event colours offered in the editor.
    static let swatches: [(name: String, hex: String)] = [
        ("Grey", "#8e8e93"), ("Green", "#34c759"), ("Purple", "#af52de"), ("Orange", "#ff9500")
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
