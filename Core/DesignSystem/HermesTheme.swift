import SwiftUI

// MARK: - Spacing Scale (like Tailwind's spacing)
enum HermesSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
    static let xxxxl: CGFloat = 48
}

// MARK: - Corner Radius Scale
enum HermesRadius {
    static let sm: CGFloat = 6
    static let md: CGFloat = 10
    static let lg: CGFloat = 14
    static let xl: CGFloat = 18
    static let full: CGFloat = 9999
}

// MARK: - Typography (System Fonts with proper weights)
extension Font {
    static let hermes = HermesTypography()
    
    struct HermesTypography {
        var h1: Font { .system(.title, design: .default).weight(.bold) }
        var h2: Font { .system(.title2, design: .default).weight(.semibold) }
        var h3: Font { .system(.headline, design: .default).weight(.semibold) }
        var body: Font { .system(.body, design: .default) }
        var bodyMedium: Font { .system(.body, design: .default).weight(.medium) }
        var caption: Font { .system(.caption, design: .default) }
        var captionMedium: Font { .system(.caption, design: .default).weight(.medium) }
        var badge: Font { .system(size: 10, weight: .semibold, design: .default) }
        var mono: Font { .system(.footnote, design: .monospaced) }
    }
}

// MARK: - Colors (Simplified, high-contrast)
extension Color {
    static let hermes = HermesColors()
    
    struct HermesColors {
        // Backgrounds
        let bg = Color(light: "#FAFAFA", dark: "#141414")
        let surface = Color(light: "#FFFFFF", dark: "#1C1C1E")
        let card = Color(light: "#FFFFFF", dark: "#242426")
        let hover = Color(light: "#F3F4F6", dark: "#2C2C2E")
        
        // Borders
        let border = Color(light: "#E5E7EB", dark: "#38383A")
        let borderLight = Color(light: "#F3F4F6", dark: "#2C2C2E")
        
        // Text
        let text = Color(light: "#111827", dark: "#F9FAFB")
        let textSecondary = Color(light: "#374151", dark: "#E5E7EB")
        let muted = Color(light: "#6B7280", dark: "#9CA3AF")
        
        // Brand
        let accent = Color(light: "#6366F1", dark: "#818CF8")
        let accentHover = Color(light: "#4F46E5", dark: "#6366F1")
        
        // Semantic
        let success = Color(light: "#10B981", dark: "#34D399")
        let warning = Color(light: "#F59E0B", dark: "#FBBF24")
        let danger = Color(light: "#EF4444", dark: "#F87171")
    }
}

// Helper to create adaptive colors
extension Color {
    init(light: String, dark: String) {
        #if os(macOS)
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(hex: dark)
                : NSColor(hex: light)
        })
        #else
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark)
                : UIColor(hex: light)
        })
        #endif
    }
}

#if os(macOS)
extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        (r, g, b) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
    }
}
#else
extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        (r, g, b) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
    }
}
#endif
