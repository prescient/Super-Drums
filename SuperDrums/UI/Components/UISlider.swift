import SwiftUI

/// A horizontal slider control with drag-left-right gesture.
/// Double-tap to reset to default value.
struct ParameterSlider: View {
    /// Binding to the slider value (0.0 - 1.0)
    @Binding var value: Float

    /// Label displayed to the left of the slider
    var label: String

    /// Accent color for the filled portion
    var accentColor: Color = UIColors.accentCyan

    /// Value formatter for display
    var valueFormatter: (Float) -> String = { String(format: "%.0f%%", $0 * 100) }

    /// Whether to show the value
    var showValue: Bool = true

    /// Default value to reset to on double-tap (0.0 - 1.0)
    var defaultValue: Float = 0.5

    /// Height of the slider track
    private let trackHeight: CGFloat = 8

    /// Sensitivity of the drag gesture
    private let sensitivity: CGFloat = 0.004

    /// Tracks the drag state
    @State private var isDragging: Bool = false

    var body: some View {
        HStack(spacing: UISpacing.sm) {
            // Label
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(UIColors.textSecondary)
                .frame(width: 70, alignment: .leading)

            // Slider track
            GeometryReader { geometry in
                let width = geometry.size.width
                let fillWidth = CGFloat(value) * width

                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: trackHeight / 2)
                        .fill(UIColors.border)
                        .frame(height: trackHeight)

                    // Filled track
                    RoundedRectangle(cornerRadius: trackHeight / 2)
                        .fill(accentColor)
                        .frame(width: max(0, fillWidth), height: trackHeight)
                        .neonGlow(color: accentColor, radius: 4, isActive: isDragging)

                    // Thumb
                    Circle()
                        .fill(UIColors.textPrimary)
                        .frame(width: 16, height: 16)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        .offset(x: max(0, min(fillWidth - 8, width - 16)))
                }
                .frame(height: 20)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    TapGesture(count: 2)
                        .onEnded {
                            // Double-tap to reset to default
                            withAnimation(.easeOut(duration: 0.15)) {
                                value = defaultValue
                            }
                        }
                )
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            isDragging = true
                            // Calculate value based on position
                            let newValue = Float(gesture.location.x / width)
                            value = max(0, min(1, newValue))
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
            }
            .frame(height: 20)

            // Value display
            if showValue {
                Text(valueFormatter(value))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(isDragging ? UIColors.textPrimary : UIColors.textSecondary)
                    .frame(width: 48, alignment: .trailing)
            }
        }
        .frame(height: 24)
    }
}

// MARK: - Bipolar Slider Variant

/// A slider for bipolar values (-1.0 to 1.0), with center indicator.
/// Double-tap to reset to default value (center).
struct BipolarSlider: View {
    @Binding var value: Float
    var label: String
    var accentColor: Color = UIColors.accentCyan
    var valueFormatter: (Float) -> String = { String(format: "%+.0f", $0 * 100) }
    var showValue: Bool = true

    /// Default value to reset to on double-tap (-1.0 to 1.0, typically 0.0 for center)
    var defaultValue: Float = 0.0

    private let trackHeight: CGFloat = 8

    @State private var isDragging: Bool = false

    var body: some View {
        HStack(spacing: UISpacing.sm) {
            // Label
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(UIColors.textSecondary)
                .frame(width: 70, alignment: .leading)

            // Slider track
            GeometryReader { geometry in
                let width = geometry.size.width
                let center = width / 2
                let normalizedValue = (value + 1) / 2 // Convert -1...1 to 0...1
                let valueX = CGFloat(normalizedValue) * width

                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: trackHeight / 2)
                        .fill(UIColors.border)
                        .frame(height: trackHeight)

                    // Center line
                    Rectangle()
                        .fill(UIColors.textSecondary)
                        .frame(width: 2, height: trackHeight + 4)
                        .offset(x: center - 1)

                    // Filled track from center
                    let fillStart = value >= 0 ? center : valueX
                    let fillWidth = abs(valueX - center)

                    RoundedRectangle(cornerRadius: trackHeight / 2)
                        .fill(accentColor)
                        .frame(width: fillWidth, height: trackHeight)
                        .offset(x: fillStart)
                        .neonGlow(color: accentColor, radius: 4, isActive: isDragging)

                    // Thumb
                    Circle()
                        .fill(UIColors.textPrimary)
                        .frame(width: 16, height: 16)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        .offset(x: max(0, min(valueX - 8, width - 16)))
                }
                .frame(height: 20)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    TapGesture(count: 2)
                        .onEnded {
                            // Double-tap to reset to default (center)
                            withAnimation(.easeOut(duration: 0.15)) {
                                value = defaultValue
                            }
                        }
                )
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            isDragging = true
                            let normalizedNewValue = Float(gesture.location.x / width)
                            let newValue = (normalizedNewValue * 2) - 1 // Convert 0...1 to -1...1
                            value = max(-1, min(1, newValue))
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
            }
            .frame(height: 20)

            // Value display
            if showValue {
                Text(valueFormatter(value))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(isDragging ? UIColors.textPrimary : UIColors.textSecondary)
                    .frame(width: 48, alignment: .trailing)
            }
        }
        .frame(height: 24)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        ParameterSlider(value: .constant(0.7), label: "Volume")
        ParameterSlider(value: .constant(0.3), label: "Decay", accentColor: UIColors.accentMagenta)
        ParameterSlider(value: .constant(0.5), label: "Cutoff", accentColor: UIColors.accentOrange)

        Divider().background(UIColors.border)

        BipolarSlider(value: .constant(0.0), label: "Pan")
        BipolarSlider(value: .constant(-0.5), label: "Pitch Env", accentColor: UIColors.accentMagenta)
        BipolarSlider(value: .constant(0.5), label: "Filter Env", accentColor: UIColors.accentGreen)
    }
    .padding(24)
    .background(UIColors.background)
}
