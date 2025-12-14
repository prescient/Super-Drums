import SwiftUI

/// A 2D touch control pad for manipulating two parameters simultaneously.
struct UIXYPad: View {
    /// X-axis value binding (0.0 - 1.0)
    @Binding var xValue: Float

    /// Y-axis value binding (0.0 - 1.0)
    @Binding var yValue: Float

    /// Label for X-axis
    var xLabel: String = "X"

    /// Label for Y-axis
    var yLabel: String = "Y"

    /// Accent color for the pad
    var accentColor: Color = UIColors.accentCyan

    /// Size of the pad
    var size: CGFloat = 180

    @State private var isDragging: Bool = false

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 12)
                .fill(UIColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isDragging ? accentColor : UIColors.border, lineWidth: isDragging ? 2 : 1)
                )

            // Grid lines
            gridLines

            // Axis labels
            axisLabels

            // Crosshair at current position
            crosshair

            // Touch indicator
            touchIndicator
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .gesture(xyGesture)
        .hoverEffect()
    }

    // MARK: - Grid Lines

    private var gridLines: some View {
        ZStack {
            // Vertical lines
            ForEach(1..<4, id: \.self) { i in
                Rectangle()
                    .fill(UIColors.border.opacity(0.5))
                    .frame(width: 1)
                    .offset(x: CGFloat(i) * size / 4 - size / 2)
            }

            // Horizontal lines
            ForEach(1..<4, id: \.self) { i in
                Rectangle()
                    .fill(UIColors.border.opacity(0.5))
                    .frame(height: 1)
                    .offset(y: CGFloat(i) * size / 4 - size / 2)
            }

            // Center lines (emphasized)
            Rectangle()
                .fill(UIColors.border)
                .frame(width: 1)
            Rectangle()
                .fill(UIColors.border)
                .frame(height: 1)
        }
        .padding(8)
    }

    // MARK: - Axis Labels

    private var axisLabels: some View {
        ZStack {
            // X label (bottom)
            VStack {
                Spacer()
                Text(xLabel)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(UIColors.textSecondary)
                    .padding(.bottom, 2)
            }

            // Y label (left, rotated)
            HStack {
                Text(yLabel)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(UIColors.textSecondary)
                    .rotationEffect(.degrees(-90))
                    .padding(.leading, 2)
                Spacer()
            }
        }
    }

    // MARK: - Crosshair

    private var crosshair: some View {
        let x = CGFloat(xValue) * (size - 16) + 8 - size / 2
        let y = -CGFloat(yValue) * (size - 16) - 8 + size / 2

        return ZStack {
            // Horizontal line
            Rectangle()
                .fill(accentColor.opacity(0.3))
                .frame(width: size - 16, height: 1)
                .offset(y: y)

            // Vertical line
            Rectangle()
                .fill(accentColor.opacity(0.3))
                .frame(width: 1, height: size - 16)
                .offset(x: x)
        }
    }

    // MARK: - Touch Indicator

    private var touchIndicator: some View {
        let x = CGFloat(xValue) * (size - 16) + 8 - size / 2
        let y = -CGFloat(yValue) * (size - 16) - 8 + size / 2

        return ZStack {
            // Outer glow
            Circle()
                .fill(accentColor.opacity(isDragging ? 0.3 : 0.1))
                .frame(width: isDragging ? 40 : 24, height: isDragging ? 40 : 24)

            // Inner dot
            Circle()
                .fill(accentColor)
                .frame(width: isDragging ? 16 : 12, height: isDragging ? 16 : 12)
                .neonGlow(color: accentColor, radius: 6, isActive: isDragging)
        }
        .offset(x: x, y: y)
        .animation(.easeOut(duration: 0.1), value: isDragging)
    }

    // MARK: - Gesture

    private var xyGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDragging = true

                // Convert touch position to normalized values
                let padding: CGFloat = 8
                let effectiveSize = size - padding * 2

                let newX = Float((value.location.x - padding) / effectiveSize)
                let newY = Float(1 - (value.location.y - padding) / effectiveSize)

                xValue = max(0, min(1, newX))
                yValue = max(0, min(1, newY))
            }
            .onEnded { _ in
                isDragging = false
            }
    }
}

// MARK: - Compact XY Pad

/// A smaller XY pad for inline use
struct UICompactXYPad: View {
    @Binding var xValue: Float
    @Binding var yValue: Float
    var accentColor: Color = UIColors.accentCyan
    var size: CGFloat = 80

    @State private var isDragging: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(UIColors.elevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(UIColors.border, lineWidth: 1)
                )

            // Simple crosshair
            let x = CGFloat(xValue) * (size - 8) + 4 - size / 2
            let y = -CGFloat(yValue) * (size - 8) - 4 + size / 2

            Circle()
                .fill(accentColor)
                .frame(width: 8, height: 8)
                .offset(x: x, y: y)
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let effectiveSize = size - 8
                    xValue = max(0, min(1, Float((value.location.x - 4) / effectiveSize)))
                    yValue = max(0, min(1, Float(1 - (value.location.y - 4) / effectiveSize)))
                }
        )
        .hoverEffect()
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 32) {
        HStack(spacing: 32) {
            UIXYPad(
                xValue: .constant(0.3),
                yValue: .constant(0.7),
                xLabel: "Cutoff",
                yLabel: "Resonance",
                accentColor: UIColors.accentMagenta
            )

            UIXYPad(
                xValue: .constant(0.5),
                yValue: .constant(0.5),
                xLabel: "Pitch",
                yLabel: "Decay",
                accentColor: UIColors.accentCyan
            )
        }

        HStack(spacing: 16) {
            UICompactXYPad(xValue: .constant(0.2), yValue: .constant(0.8))
            UICompactXYPad(xValue: .constant(0.5), yValue: .constant(0.5), accentColor: UIColors.accentMagenta)
            UICompactXYPad(xValue: .constant(0.9), yValue: .constant(0.1), accentColor: UIColors.accentOrange)
        }
    }
    .padding(40)
    .background(UIColors.background)
}
