import SwiftUI

/// A trigger pad for live performance.
struct UIPadButton: View {
    /// Voice type this pad triggers
    let voiceType: DrumVoiceType

    /// Action when pad is triggered (with velocity 0.0-1.0)
    var onTrigger: ((Float) -> Void)?

    /// Size of the pad
    var size: CGFloat = UISizes.padButtonSize

    /// Whether the pad is currently triggered
    @State private var isPressed: Bool = false

    /// Current velocity based on touch pressure
    @State private var velocity: Float = 0.0

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            UIColors.elevated,
                            UIColors.surface
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(voiceType.color.opacity(isPressed ? 1 : 0.3), lineWidth: 2)
                )

            // Active state glow
            if isPressed {
                RoundedRectangle(cornerRadius: 12)
                    .fill(voiceType.color.opacity(0.3 * Double(velocity)))
                    .neonGlow(color: voiceType.color, radius: 8, isActive: true)
            }

            // Label
            VStack(spacing: UISpacing.xs) {
                Text(voiceType.abbreviation)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(isPressed ? UIColors.textPrimary : voiceType.color)

                Text(voiceType.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(UIColors.textSecondary)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeOut(duration: 0.05), value: isPressed)
        .gesture(padGesture)
        .hoverEffect()
    }

    private var padGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isPressed {
                    isPressed = true
                    // Calculate velocity based on initial tap position
                    // Bottom of pad = lower velocity, top = higher
                    let normalizedY = 1 - Float(value.location.y / size)
                    velocity = max(0.3, min(1.0, normalizedY))
                    onTrigger?(velocity)
                }
            }
            .onEnded { _ in
                isPressed = false
            }
    }
}

// MARK: - Pad Grid

/// A grid of trigger pads for all voices
struct UIPadGrid: View {
    let onTrigger: (DrumVoiceType, Float) -> Void

    /// Columns in the grid
    var columns: Int = 5

    var body: some View {
        let voices = DrumVoiceType.allCases
        let rows = (voices.count + columns - 1) / columns

        VStack(spacing: UISpacing.md) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: UISpacing.md) {
                    ForEach(0..<columns, id: \.self) { col in
                        let index = row * columns + col
                        if index < voices.count {
                            UIPadButton(voiceType: voices[index]) { velocity in
                                onTrigger(voices[index], velocity)
                            }
                        } else {
                            Color.clear
                                .frame(width: UISizes.padButtonSize, height: UISizes.padButtonSize)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 32) {
        HStack(spacing: 16) {
            UIPadButton(voiceType: .kick)
            UIPadButton(voiceType: .snare)
            UIPadButton(voiceType: .closedHat)
        }

        UIPadGrid(columns: 5) { voice, velocity in
            print("Triggered \(voice.displayName) at velocity \(velocity)")
        }
    }
    .padding(40)
    .background(UIColors.background)
}
