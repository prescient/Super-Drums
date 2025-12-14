import SwiftUI

/// Color palette for the iPad Drum Synth app.
/// Dark theme with neon accents in a minimal/flat style.
enum UIColors {

    // MARK: - Backgrounds

    /// Main app background - deepest dark
    static let background = Color(hex: "0D0D0D")

    /// Surface color for panels and cards
    static let surface = Color(hex: "1A1A1A")

    /// Elevated surfaces (modals, popovers)
    static let elevated = Color(hex: "252525")

    /// Subtle divider/border color
    static let border = Color(hex: "333333")

    // MARK: - Neon Accents

    /// Primary accent - Cyan (active steps, selected items)
    static let accentCyan = Color(hex: "00D4FF")

    /// Secondary accent - Magenta (highlights, warnings)
    static let accentMagenta = Color(hex: "FF00FF")

    /// Tertiary accent - Green (play state, success)
    static let accentGreen = Color(hex: "00FF88")

    /// Quaternary accent - Orange (velocity, warmth)
    static let accentOrange = Color(hex: "FF6B00")

    /// Accent - Yellow (caution, automation)
    static let accentYellow = Color(hex: "FFD700")

    // MARK: - Text

    /// Primary text - white
    static let textPrimary = Color(hex: "FFFFFF")

    /// Secondary text - muted gray
    static let textSecondary = Color(hex: "808080")

    /// Disabled text
    static let textDisabled = Color(hex: "4D4D4D")

    // MARK: - Semantic Colors

    /// Step is active/on
    static let stepActive = accentCyan

    /// Step is currently playing
    static let stepPlaying = accentGreen

    /// Muted channel
    static let muted = Color(hex: "FF4444")

    /// Soloed channel
    static let soloed = accentYellow

    // MARK: - Voice Colors (unique color per drum voice)

    /// Colors assigned to each of the 10 drum voices
    static let voiceColors: [Color] = [
        Color(hex: "FF5555"), // Kick - Red
        Color(hex: "FFAA00"), // Snare - Orange
        Color(hex: "00D4FF"), // Closed Hat - Cyan
        Color(hex: "00AAFF"), // Open Hat - Light Blue
        Color(hex: "FF00FF"), // Clap - Magenta
        Color(hex: "FFD700"), // Cowbell - Gold
        Color(hex: "AAAAFF"), // Cymbal - Lavender
        Color(hex: "FF8866"), // Conga - Coral
        Color(hex: "88FF88"), // Maracas - Light Green
        Color(hex: "FF66AA"), // Tom/Perc - Pink
    ]
}

// MARK: - Color Extension for Hex Support

extension Color {
    /// Creates a Color from a hex string (without #)
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b, a: UInt64
        switch hex.count {
        case 6: // RGB
            (r, g, b, a) = (
                (int >> 16) & 0xFF,
                (int >> 8) & 0xFF,
                int & 0xFF,
                255
            )
        case 8: // RGBA
            (r, g, b, a) = (
                (int >> 24) & 0xFF,
                (int >> 16) & 0xFF,
                (int >> 8) & 0xFF,
                int & 0xFF
            )
        default:
            (r, g, b, a) = (0, 0, 0, 255)
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
