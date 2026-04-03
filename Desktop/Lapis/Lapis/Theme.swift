import SwiftUI

// MARK: - Lapis Design System
// Premium dark theme with warm amber/gold accents — "Obsidian" palette

struct LapisTheme {
    
    // MARK: Colors
    struct Colors {
        // Backgrounds
        static let background       = Color(hex: "0D0D0F")
        static let surface          = Color(hex: "1A1A1E")
        static let surfaceLight     = Color(hex: "222226")
        static let sidebar          = Color(hex: "0A0A0C")
        
        // Glass
        static let glassBackground  = Color.white.opacity(0.06)
        static let glassBorder      = Color.white.opacity(0.08)
        static let glassHighlight   = Color.white.opacity(0.03)
        
        // Text
        static let textPrimary      = Color(hex: "E8E6E3")
        static let textSecondary    = Color(hex: "7A7A7D")
        static let textMuted        = Color(hex: "4A4A4D")
        
        // Accent — Warm Amber / Gold
        static let accent           = Color(hex: "C9A55C")
        static let accentLight      = Color(hex: "D4B56A")
        static let accentDark       = Color(hex: "A8873D")
        static let accentGlow       = Color(hex: "C9A55C").opacity(0.3)
        
        // Semantic
        static let success          = Color(hex: "4A7C59")
        static let danger           = Color(hex: "8B3A3A")
        static let warning          = Color(hex: "B8863B")
        static let info             = Color(hex: "4A6A8B")
        
        // Interactive
        static let hoverOverlay     = Color.white.opacity(0.04)
        static let pressedOverlay   = Color.white.opacity(0.08)
        static let divider          = Color.white.opacity(0.06)
    }
    
    // MARK: Corner Radius
    struct Radius {
        static let small: CGFloat   = 8
        static let medium: CGFloat  = 12
        static let large: CGFloat   = 16
        static let xl: CGFloat      = 20
        static let pill: CGFloat    = 100
    }
    
    // MARK: Spacing
    struct Spacing {
        static let xs: CGFloat      = 4
        static let sm: CGFloat      = 8
        static let md: CGFloat      = 12
        static let lg: CGFloat      = 16
        static let xl: CGFloat      = 24
        static let xxl: CGFloat     = 32
        static let xxxl: CGFloat    = 48
    }
    
    // MARK: Sidebar
    struct Sidebar {
        static let width: CGFloat   = 64
        static let iconSize: CGFloat = 22
    }
    
    // MARK: Animations
    struct Animation {
        static let fast             = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let normal           = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let smooth           = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.8)
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Glass Modifier
struct GlassBackground: ViewModifier {
    var cornerRadius: CGFloat = LapisTheme.Radius.large
    var opacity: Double = 0.06
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .opacity(0.7)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(opacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(LapisTheme.Colors.glassBorder, lineWidth: 1)
            )
    }
}

extension View {
    func glassBackground(cornerRadius: CGFloat = LapisTheme.Radius.large, opacity: Double = 0.06) -> some View {
        self.modifier(GlassBackground(cornerRadius: cornerRadius, opacity: opacity))
    }
}

// MARK: - Hover Button Style
struct LapisButtonStyle: ButtonStyle {
    var isAccent: Bool = false
    var fullWidth: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(isAccent ? LapisTheme.Colors.background : LapisTheme.Colors.textPrimary)
            .padding(.horizontal, LapisTheme.Spacing.xl)
            .padding(.vertical, LapisTheme.Spacing.md)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(
                RoundedRectangle(cornerRadius: LapisTheme.Radius.medium)
                    .fill(isAccent ? LapisTheme.Colors.accent : LapisTheme.Colors.surfaceLight)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LapisTheme.Radius.medium)
                    .stroke(isAccent ? LapisTheme.Colors.accentLight.opacity(0.3) : LapisTheme.Colors.glassBorder, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(LapisTheme.Animation.fast, value: configuration.isPressed)
    }
}
