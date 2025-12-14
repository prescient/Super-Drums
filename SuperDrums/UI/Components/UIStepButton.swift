import SwiftUI

/// A toggle button for sequencer steps.
struct UIStepButton: View {
    /// Whether the step is active
    @Binding var isActive: Bool

    /// Velocity of the step (0.0 - 1.0)
    var velocity: Float = 1.0

    /// Whether this step is currently playing
    var isPlaying: Bool = false

    /// Color when active
    var activeColor: Color = UIColors.stepActive

    /// Size of the button
    var size: CGFloat = UISizes.stepButtonSize

    /// Step index (for visual indication of beat position)
    var stepIndex: Int = 0

    /// Whether this step has parameter locks
    var hasParameterLock: Bool = false

    /// Whether this step has probability
    var hasProbability: Bool = false

    var body: some View {
        Button {
            isActive.toggle()
        } label: {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(borderColor, lineWidth: isPlaying ? 2 : 1)
                    )

                // Velocity indicator (height based on velocity)
                if isActive {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(activeColor.opacity(Double(velocity)))
                        .padding(4)
                        .neonGlow(color: activeColor, radius: 4, isActive: isPlaying)
                }

                // Parameter lock indicator
                if hasParameterLock {
                    Circle()
                        .fill(UIColors.accentYellow)
                        .frame(width: 6, height: 6)
                        .offset(x: size/2 - 8, y: -size/2 + 8)
                }

                // Probability indicator
                if hasProbability {
                    Circle()
                        .stroke(UIColors.accentMagenta, lineWidth: 1.5)
                        .frame(width: 6, height: 6)
                        .offset(x: -size/2 + 8, y: -size/2 + 8)
                }
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .hoverEffect()
    }

    private var backgroundColor: Color {
        if isPlaying {
            return UIColors.stepPlaying.opacity(0.3)
        }
        // Highlight downbeats (1, 5, 9, 13 in 16-step)
        let isDownbeat = stepIndex % 4 == 0
        return isDownbeat ? UIColors.elevated : UIColors.surface
    }

    private var borderColor: Color {
        if isPlaying {
            return UIColors.stepPlaying
        }
        if isActive {
            return activeColor
        }
        return UIColors.border
    }
}

// MARK: - Step Row

/// A row of step buttons for a single voice track
struct UIStepRow: View {
    let voiceType: DrumVoiceType
    let steps: [Step]
    let currentStep: Int
    let onToggle: (Int) -> Void

    var body: some View {
        HStack(spacing: UISpacing.xs) {
            // Voice label
            Text(voiceType.abbreviation)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(voiceType.color)
                .frame(width: 28, alignment: .leading)

            // Steps
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                UIStepButton(
                    isActive: .init(
                        get: { step.isActive },
                        set: { _ in onToggle(index) }
                    ),
                    velocity: step.normalizedVelocity,
                    isPlaying: index == currentStep,
                    activeColor: voiceType.color,
                    size: 36,
                    stepIndex: index,
                    hasParameterLock: step.hasParameterLocks,
                    hasProbability: step.hasProbability
                )
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 8) {
            UIStepButton(isActive: .constant(false), stepIndex: 0)
            UIStepButton(isActive: .constant(true), velocity: 1.0, stepIndex: 1)
            UIStepButton(isActive: .constant(true), velocity: 0.5, stepIndex: 2)
            UIStepButton(isActive: .constant(true), isPlaying: true, stepIndex: 3)
            UIStepButton(isActive: .constant(true), stepIndex: 4, hasParameterLock: true)
            UIStepButton(isActive: .constant(true), stepIndex: 5, hasProbability: true)
        }

        UIStepRow(
            voiceType: .kick,
            steps: [
                Step(isActive: true, velocity: 127),
                Step(isActive: false),
                Step(isActive: false),
                Step(isActive: false),
                Step(isActive: true, velocity: 100),
                Step(isActive: false),
                Step(isActive: false),
                Step(isActive: false),
                Step(isActive: true, velocity: 127),
                Step(isActive: false),
                Step(isActive: false),
                Step(isActive: false),
                Step(isActive: true, velocity: 100),
                Step(isActive: false),
                Step(isActive: false),
                Step(isActive: false),
            ],
            currentStep: 4,
            onToggle: { _ in }
        )
    }
    .padding(40)
    .background(UIColors.background)
}
