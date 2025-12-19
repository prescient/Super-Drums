import SwiftUI

/// A vertical fader/slider control for mixer channels.
struct UIFader: View {
    /// Binding to the fader value (0.0 - 1.0)
    @Binding var value: Float

    /// Label displayed below the fader
    var label: String = ""

    /// Accent color for the fader
    var accentColor: Color = UIColors.accentCyan

    /// Width of the fader
    var width: CGFloat = UISizes.faderWidth

    /// Height of the fader
    var height: CGFloat = UISizes.faderHeight

    /// Whether to show dB scale
    var showScale: Bool = true

    /// Default value to reset to on double-tap
    var defaultValue: Float = 0.8

    @State private var isDragging: Bool = false

    var body: some View {
        VStack(spacing: UISpacing.xs) {
            HStack(spacing: UISpacing.xs) {
                // Scale markings
                if showScale {
                    VStack(alignment: .trailing, spacing: 0) {
                        ForEach(scaleMarks, id: \.self) { mark in
                            if mark == scaleMarks.first {
                                Text(mark)
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                                    .foregroundStyle(UIColors.textSecondary)
                            } else {
                                Spacer()
                                Text(mark)
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                                    .foregroundStyle(UIColors.textSecondary)
                            }
                        }
                    }
                    .frame(width: 24, height: height)
                }

                // Fader track
                ZStack(alignment: .bottom) {
                    // Track background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(UIColors.elevated)
                        .frame(width: 8)

                    // Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.3), accentColor],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 8, height: height * CGFloat(value))
                        .neonGlow(color: accentColor, radius: 4, isActive: isDragging)

                    // Fader cap
                    RoundedRectangle(cornerRadius: 4)
                        .fill(UIColors.textPrimary)
                        .frame(width: width - 8, height: 24)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 2)
                        .offset(y: -CGFloat(value) * (height - 24))
                }
                .frame(width: width - (showScale ? 32 : 0), height: height)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    TapGesture(count: 2)
                        .onEnded {
                            withAnimation(.easeOut(duration: 0.15)) {
                                value = defaultValue
                            }
                        }
                )
                .gesture(faderGesture)
                .hoverEffect()
            }

            // Value display
            Text(dBString)
                .valueStyle()
                .frame(width: width + (showScale ? 24 : 0))

            // Label
            if !label.isEmpty {
                Text(label)
                    .labelStyle()
                    .lineLimit(1)
            }
        }
    }

    private var faderGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                isDragging = true
                // Calculate value based on position
                let position = height - gesture.location.y
                let newValue = Float(position / height)
                value = max(0, min(1, newValue))
            }
            .onEnded { _ in
                isDragging = false
            }
    }

    private var scaleMarks: [String] {
        ["+6", "0", "-6", "-12", "-24", "-∞"]
    }

    /// Converts linear value to dB string
    private var dBString: String {
        if value < 0.001 {
            return "-∞ dB"
        }
        let dB = 20 * log10(value)
        if dB > 0 {
            return String(format: "+%.1f", dB)
        }
        return String(format: "%.1f", dB)
    }
}

// MARK: - Compact Fader

/// A more compact fader for space-constrained layouts
struct UICompactFader: View {
    @Binding var value: Float
    var accentColor: Color = UIColors.accentCyan
    var height: CGFloat = 120
    var defaultValue: Float = 0.8

    @State private var isDragging: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Track
            RoundedRectangle(cornerRadius: 3)
                .fill(UIColors.elevated)
                .frame(width: 6)

            // Fill
            RoundedRectangle(cornerRadius: 3)
                .fill(accentColor)
                .frame(width: 6, height: height * CGFloat(value))
                .neonGlow(color: accentColor, radius: 3, isActive: isDragging)

            // Cap
            Capsule()
                .fill(UIColors.textPrimary)
                .frame(width: 20, height: 16)
                .offset(y: -CGFloat(value) * (height - 16))
        }
        .frame(width: 24, height: height)
        .contentShape(Rectangle())
        .highPriorityGesture(
            TapGesture(count: 2)
                .onEnded {
                    withAnimation(.easeOut(duration: 0.15)) {
                        value = defaultValue
                    }
                }
        )
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { gesture in
                    isDragging = true
                    let position = height - gesture.location.y
                    value = max(0, min(1, Float(position / height)))
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
        .hoverEffect()
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 40) {
        UIFader(value: .constant(0.75), label: "Master")
        UIFader(value: .constant(0.5), label: "Kick", accentColor: UIColors.voiceColors[0])
        UIFader(value: .constant(0.0), label: "Snare", accentColor: UIColors.voiceColors[1], showScale: false)
        UICompactFader(value: .constant(0.6))
    }
    .padding(40)
    .background(UIColors.background)
}
