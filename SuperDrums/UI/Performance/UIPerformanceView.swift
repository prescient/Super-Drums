import SwiftUI

/// Performance view with trigger pads and XY controls.
struct UIPerformanceView: View {
    @Bindable var store: AppStore

    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < 800

            if isCompact {
                // Vertical layout for narrow windows
                VStack(spacing: UISpacing.lg) {
                    padsSection
                    xyPadsSection
                }
                .padding(UISpacing.lg)
            } else {
                // Horizontal layout for wide windows
                HStack(spacing: UISpacing.xl) {
                    // Pads
                    padsSection
                        .frame(maxWidth: .infinity)

                    // Divider
                    Rectangle()
                        .fill(UIColors.border)
                        .frame(width: 1)

                    // XY Pads
                    xyPadsSection
                        .frame(maxWidth: .infinity)
                }
                .padding(UISpacing.lg)
            }
        }
        .background(UIColors.background)
    }

    // MARK: - Pads Section

    private var padsSection: some View {
        VStack(spacing: UISpacing.md) {
            // Header
            HStack {
                Text("TRIGGER PADS")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(UIColors.textSecondary)

                Spacer()

                // Velocity mode indicator
                HStack(spacing: UISpacing.xs) {
                    Text("Velocity:")
                        .labelStyle()
                    Text("Touch Position")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(UIColors.accentCyan)
                }
            }

            // Pad grid
            UIPadGrid(columns: 5) { voiceType, velocity in
                triggerVoice(voiceType, velocity: velocity)
            }
        }
        .panelStyle()
        .padding(UISpacing.md)
    }

    // MARK: - XY Pads Section

    private var xyPadsSection: some View {
        VStack(spacing: UISpacing.md) {
            // Header
            HStack {
                Text("XY CONTROLS")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(UIColors.textSecondary)

                Spacer()
            }

            HStack(spacing: UISpacing.lg) {
                // Filter XY Pad
                VStack(spacing: UISpacing.sm) {
                    UIXYPad(
                        xValue: Binding(
                            get: { store.selectedVoice.filterCutoff },
                            set: { store.selectedVoice.filterCutoff = $0 }
                        ),
                        yValue: Binding(
                            get: { store.selectedVoice.filterResonance },
                            set: { store.selectedVoice.filterResonance = $0 }
                        ),
                        xLabel: "Cutoff",
                        yLabel: "Resonance",
                        accentColor: UIColors.accentMagenta
                    )

                    Text("FILTER")
                        .labelStyle()
                }

                // Pitch/Decay XY Pad
                VStack(spacing: UISpacing.sm) {
                    UIXYPad(
                        xValue: Binding(
                            get: { store.selectedVoice.pitch },
                            set: { store.selectedVoice.pitch = $0 }
                        ),
                        yValue: Binding(
                            get: { store.selectedVoice.decay },
                            set: { store.selectedVoice.decay = $0 }
                        ),
                        xLabel: "Pitch",
                        yLabel: "Decay",
                        accentColor: UIColors.accentCyan
                    )

                    Text("PITCH / DECAY")
                        .labelStyle()
                }
            }

            // Selected voice indicator
            HStack(spacing: UISpacing.sm) {
                Text("Controlling:")
                    .labelStyle()

                HStack(spacing: UISpacing.xs) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(store.selectedVoiceType.color)
                        .frame(width: 4, height: 16)

                    Text(store.selectedVoiceType.fullName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(store.selectedVoiceType.color)
                }
            }
            .padding(.top, UISpacing.sm)
        }
        .panelStyle()
        .padding(UISpacing.md)
    }

    // MARK: - Actions

    private func triggerVoice(_ voiceType: DrumVoiceType, velocity: Float) {
        // Select the voice
        store.selectedVoiceType = voiceType

        // In a real implementation, this would send a MIDI note or
        // directly trigger the audio engine
        print("Triggered \(voiceType.fullName) at velocity \(velocity)")
    }
}

// MARK: - Preview

#Preview {
    UIPerformanceView(store: AppStore(project: .demo()))
}
