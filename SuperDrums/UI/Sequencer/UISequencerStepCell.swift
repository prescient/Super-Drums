import SwiftUI

/// Individual step cell in the sequencer grid.
struct UISequencerStepCell: View {
    let step: Step
    let stepIndex: Int
    let voiceType: DrumVoiceType
    let isCurrentStep: Bool
    var size: CGFloat = 36
    let onToggle: () -> Void
    var onVelocityChange: ((UInt8) -> Void)? = nil

    @State private var showVelocityPopover: Bool = false

    var body: some View {
        Button {
            onToggle()
        } label: {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(borderColor, lineWidth: isCurrentStep ? 2 : 1)
                    )

                // Velocity fill (height represents velocity)
                if step.isActive {
                    VStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 4)
                            .fill(voiceType.color)
                            .frame(height: CGFloat(step.normalizedVelocity) * (size - 8))
                            .padding(4)
                    }
                    .neonGlow(color: voiceType.color, radius: 4, isActive: isCurrentStep)
                }

                // Indicators overlay
                indicatorsOverlay
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .contextMenu {
            stepContextMenu
        }
        .popover(isPresented: $showVelocityPopover) {
            velocityEditor
        }
    }

    // MARK: - Background Color

    private var backgroundColor: Color {
        if isCurrentStep {
            return UIColors.stepPlaying.opacity(0.2)
        }
        // Downbeat highlighting
        let isDownbeat = stepIndex % 4 == 0
        return isDownbeat ? UIColors.elevated : UIColors.surface
    }

    // MARK: - Border Color

    private var borderColor: Color {
        if isCurrentStep {
            return UIColors.stepPlaying
        }
        if step.isActive {
            return voiceType.color.opacity(0.6)
        }
        return UIColors.border
    }

    // MARK: - Indicators

    @ViewBuilder
    private var indicatorsOverlay: some View {
        VStack {
            HStack {
                // Probability indicator (top left)
                if step.hasProbability {
                    Circle()
                        .stroke(UIColors.accentMagenta, lineWidth: 1.5)
                        .frame(width: 5, height: 5)
                }
                Spacer()
                // Parameter lock indicator (top right)
                if step.hasParameterLocks {
                    Circle()
                        .fill(UIColors.accentYellow)
                        .frame(width: 5, height: 5)
                }
            }
            Spacer()
            HStack {
                // Nudge indicator (bottom left)
                if step.hasNudge {
                    Image(systemName: step.nudge > 0 ? "arrow.right" : "arrow.left")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(UIColors.accentOrange)
                }
                Spacer()
                // Retrigger indicator (bottom right)
                if step.hasRatchet {
                    Text("\(step.retriggerCount)x")
                        .font(.system(size: 6, weight: .bold, design: .monospaced))
                        .foregroundStyle(UIColors.accentGreen)
                }
            }
        }
        .padding(3)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var stepContextMenu: some View {
        Button("Edit Velocity") {
            showVelocityPopover = true
        }

        Divider()

        Menu("Probability") {
            ForEach([100, 75, 50, 25], id: \.self) { percent in
                Button("\(percent)%") {
                    // Would update step probability
                }
            }
        }

        Menu("Retrigger") {
            ForEach([1, 2, 3, 4], id: \.self) { count in
                Button(count == 1 ? "Off" : "\(count)x") {
                    // Would update retrigger
                }
            }
        }

        Divider()

        Button("Clear Step") {
            if step.isActive {
                onToggle()
            }
        }
    }

    // MARK: - Velocity Editor Popover

    private var velocityEditor: some View {
        VStack(spacing: UISpacing.md) {
            Text("Velocity")
                .titleStyle()

            // Velocity slider
            Slider(
                value: Binding(
                    get: { Double(step.velocity) },
                    set: { onVelocityChange?(UInt8($0)) }
                ),
                in: 1...127,
                step: 1
            )
            .tint(voiceType.color)
            .frame(width: 150)

            Text("\(step.velocity)")
                .valueStyle()
        }
        .padding()
        .background(UIColors.surface)
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 8) {
        // Inactive step
        UISequencerStepCell(
            step: Step(),
            stepIndex: 0,
            voiceType: .kick,
            isCurrentStep: false,
            onToggle: {}
        )

        // Active step
        UISequencerStepCell(
            step: Step(isActive: true, velocity: 127),
            stepIndex: 1,
            voiceType: .kick,
            isCurrentStep: false,
            onToggle: {}
        )

        // Currently playing
        UISequencerStepCell(
            step: Step(isActive: true, velocity: 100),
            stepIndex: 2,
            voiceType: .snare,
            isCurrentStep: true,
            onToggle: {}
        )

        // Larger size
        UISequencerStepCell(
            step: Step(isActive: true, velocity: 80),
            stepIndex: 3,
            voiceType: .closedHat,
            isCurrentStep: false,
            size: 50,
            onToggle: {}
        )
    }
    .padding(40)
    .background(UIColors.background)
}
