import SwiftUI

// MARK: - Panel Style

/// Style for surface panels/cards
struct PanelStyle: ViewModifier {
    var cornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .background(UIColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(UIColors.border, lineWidth: 1)
            )
    }
}

extension View {
    /// Applies panel styling with dark surface and border
    func panelStyle(cornerRadius: CGFloat = 12) -> some View {
        modifier(PanelStyle(cornerRadius: cornerRadius))
    }
}

// MARK: - Neon Glow Style

/// Adds a neon glow effect to a view
struct NeonGlowStyle: ViewModifier {
    let color: Color
    let radius: CGFloat
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .shadow(color: isActive ? color.opacity(0.8) : .clear, radius: radius)
            .shadow(color: isActive ? color.opacity(0.4) : .clear, radius: radius * 2)
    }
}

extension View {
    /// Applies a neon glow effect
    func neonGlow(color: Color, radius: CGFloat = 8, isActive: Bool = true) -> some View {
        modifier(NeonGlowStyle(color: color, radius: radius, isActive: isActive))
    }
}

// MARK: - Button Styles

/// Style for primary action buttons
struct PrimaryButtonStyle: ButtonStyle {
    let accentColor: Color

    init(accentColor: Color = UIColors.accentCyan) {
        self.accentColor = accentColor
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(UIColors.background)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .hoverEffect()
    }
}

/// Style for secondary/outline buttons
struct SecondaryButtonStyle: ButtonStyle {
    let accentColor: Color

    init(accentColor: Color = UIColors.accentCyan) {
        self.accentColor = accentColor
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(accentColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(UIColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(accentColor, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .hoverEffect()
    }
}

/// Style for icon buttons (mute, solo, etc.)
struct IconButtonStyle: ButtonStyle {
    let isActive: Bool
    let activeColor: Color

    init(isActive: Bool = false, activeColor: Color = UIColors.accentCyan) {
        self.isActive = isActive
        self.activeColor = activeColor
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(isActive ? UIColors.background : UIColors.textSecondary)
            .frame(width: 36, height: 36)
            .background(isActive ? activeColor : UIColors.elevated)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Text Styles

extension View {
    /// Header text style
    func headerStyle() -> some View {
        self
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(UIColors.textPrimary)
    }

    /// Title text style
    func titleStyle() -> some View {
        self
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(UIColors.textPrimary)
    }

    /// Label text style
    func labelStyle() -> some View {
        self
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(UIColors.textSecondary)
    }

    /// Value/number display style
    func valueStyle() -> some View {
        self
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(UIColors.textPrimary)
    }
}

// MARK: - Layout Helpers

/// Standard spacing values
enum UISpacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

/// Standard sizes for UI elements
enum UISizes {
    static let knobSmall: CGFloat = 40
    static let knobMedium: CGFloat = 56
    static let knobLarge: CGFloat = 72

    static let faderWidth: CGFloat = 40
    static let faderHeight: CGFloat = 200

    static let stepButtonSize: CGFloat = 44
    static let padButtonSize: CGFloat = 80

    static let tabBarHeight: CGFloat = 60
    static let channelStripWidth: CGFloat = 80
}
