import SwiftUI

/// A rotary knob control with vertical drag gesture.
struct UIKnob: View {
    /// Binding to the knob value (0.0 - 1.0)
    @Binding var value: Float

    /// Label displayed below the knob
    var label: String

    /// Accent color for the knob indicator
    var accentColor: Color = UIColors.accentCyan

    /// Size of the knob
    var size: CGFloat = UISizes.knobMedium

    /// Whether to show the value label
    var showValue: Bool = true

    /// Value formatter
    var valueFormatter: (Float) -> String = { String(format: "%.0f", $0 * 100) }

    /// Default value to reset to on double-tap
    var defaultValue: Float = 0.5

    /// Sensitivity of the drag gesture
    private let sensitivity: CGFloat = 0.005

    /// Tracks the drag state
    @State private var isDragging: Bool = false

    var body: some View {
        VStack(spacing: UISpacing.xs) {
            // Knob
            ZStack {
                // Background ring
                Circle()
                    .fill(UIColors.elevated)

                // Track arc (background)
                Arc(startAngle: .degrees(135), endAngle: .degrees(405), clockwise: false)
                    .stroke(UIColors.border, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .padding(6)

                // Value arc
                Arc(
                    startAngle: .degrees(135),
                    endAngle: .degrees(135 + Double(value) * 270),
                    clockwise: false
                )
                .stroke(accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .padding(6)
                .neonGlow(color: accentColor, radius: 4, isActive: isDragging)

                // Center indicator line
                Rectangle()
                    .fill(accentColor)
                    .frame(width: 2, height: size * 0.25)
                    .offset(y: -size * 0.2)
                    .rotationEffect(.degrees(135 + Double(value) * 270))

                // Value display (when dragging)
                if showValue && isDragging {
                    Text(valueFormatter(value))
                        .valueStyle()
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(UIColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
            .highPriorityGesture(
                TapGesture(count: 2)
                    .onEnded {
                        withAnimation(.easeOut(duration: 0.15)) {
                            value = defaultValue
                        }
                    }
            )
            .gesture(dragGesture)
            .hoverEffect()

            // Label
            Text(label)
                .labelStyle()
                .lineLimit(1)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                isDragging = true
                // Vertical drag: up increases, down decreases
                let delta = Float(-gesture.translation.height * sensitivity)
                value = max(0, min(1, value + delta))
            }
            .onEnded { _ in
                isDragging = false
            }
    }
}

// MARK: - Arc Shape

/// Arc shape for the knob track
struct Arc: Shape {
    var startAngle: Angle
    var endAngle: Angle
    var clockwise: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: clockwise
        )

        return path
    }
}

// MARK: - Bipolar Knob Variant

/// A knob for bipolar values (-1.0 to 1.0), with center detent
struct UIBipolarKnob: View {
    @Binding var value: Float
    var label: String
    var accentColor: Color = UIColors.accentCyan
    var size: CGFloat = UISizes.knobMedium
    var defaultValue: Float = 0.0

    private let sensitivity: CGFloat = 0.005
    @State private var isDragging: Bool = false

    var body: some View {
        VStack(spacing: UISpacing.xs) {
            ZStack {
                Circle()
                    .fill(UIColors.elevated)

                // Full track
                Arc(startAngle: .degrees(135), endAngle: .degrees(405), clockwise: false)
                    .stroke(UIColors.border, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .padding(6)

                // Center mark
                Arc(startAngle: .degrees(269), endAngle: .degrees(271), clockwise: false)
                    .stroke(UIColors.textSecondary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .padding(6)

                // Value arc from center
                let centerAngle = 270.0
                let valueAngle = centerAngle + Double(value) * 135
                Arc(
                    startAngle: .degrees(min(centerAngle, valueAngle)),
                    endAngle: .degrees(max(centerAngle, valueAngle)),
                    clockwise: false
                )
                .stroke(accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .padding(6)
                .neonGlow(color: accentColor, radius: 4, isActive: isDragging)

                // Indicator
                Rectangle()
                    .fill(accentColor)
                    .frame(width: 2, height: size * 0.25)
                    .offset(y: -size * 0.2)
                    .rotationEffect(.degrees(135 + Double((value + 1) / 2) * 270))

                if isDragging {
                    Text(String(format: "%.0f", value * 100))
                        .valueStyle()
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(UIColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
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
                        let delta = Float(-gesture.translation.height * sensitivity)
                        value = max(-1, min(1, value + delta))
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .hoverEffect()

            Text(label)
                .labelStyle()
                .lineLimit(1)
        }
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 32) {
        UIKnob(value: .constant(0.7), label: "Volume")
        UIKnob(value: .constant(0.3), label: "Decay", accentColor: UIColors.accentMagenta)
        UIBipolarKnob(value: .constant(0.0), label: "Pan")
        UIBipolarKnob(value: .constant(-0.5), label: "Pitch", accentColor: UIColors.accentOrange)
    }
    .padding(40)
    .background(UIColors.background)
}
