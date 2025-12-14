import SwiftUI

/// Editor panel for voice synthesis parameters.
struct UIVoiceEditor: View {
    @Bindable var store: AppStore

    /// The voice being edited
    private var voice: Voice {
        get { store.selectedVoice }
        nonmutating set { store.selectedVoice = newValue }
    }

    private var voiceType: DrumVoiceType {
        store.selectedVoiceType
    }

    var body: some View {
        ScrollView {
            VStack(spacing: UISpacing.xl) {
                // Header
                header

                // Oscillator section
                oscillatorSection

                // Filter section
                filterSection

                // Envelope section
                envelopeSection

                // Effects section
                effectsSection

                // Output section
                outputSection
            }
            .padding(UISpacing.lg)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            // Voice name and color
            HStack(spacing: UISpacing.sm) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(voiceType.color)
                    .frame(width: 6, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(voiceType.fullName)
                        .headerStyle()

                    Text("Sound Design")
                        .labelStyle()
                }
            }

            Spacer()

            // Trigger button for auditioning
            Button {
                // Would trigger the voice for preview
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 18))
            }
            .buttonStyle(PrimaryButtonStyle(accentColor: voiceType.color))
        }
    }

    // MARK: - Oscillator Section

    private var oscillatorSection: some View {
        VStack(alignment: .leading, spacing: UISpacing.md) {
            sectionHeader("OSCILLATOR")

            HStack(spacing: UISpacing.xl) {
                UIKnob(
                    value: binding(\.pitch),
                    label: "Pitch",
                    accentColor: voiceType.color
                )

                UIBipolarKnob(
                    value: binding(\.pitchEnvelopeAmount),
                    label: "Pitch Env",
                    accentColor: voiceType.color
                )

                UIKnob(
                    value: binding(\.pitchEnvelopeDecay),
                    label: "P.Env Decay",
                    accentColor: voiceType.color
                )

                // Tone/Noise mix (for voices that support it)
                if supportsToneMix {
                    UIKnob(
                        value: binding(\.toneMix),
                        label: "Tone/Noise",
                        accentColor: voiceType.color,
                        valueFormatter: { $0 < 0.5 ? "Tone" : ($0 > 0.5 ? "Noise" : "50/50") }
                    )
                }
            }
        }
        .panelStyle()
        .padding(UISpacing.md)
    }

    // MARK: - Filter Section

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: UISpacing.md) {
            sectionHeader("FILTER")

            HStack(spacing: UISpacing.xl) {
                // Filter type picker
                VStack(spacing: UISpacing.xs) {
                    Text("Type")
                        .labelStyle()

                    Picker("Filter Type", selection: binding(\.filterType)) {
                        ForEach(FilterType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 100)
                }

                UIKnob(
                    value: binding(\.filterCutoff),
                    label: "Cutoff",
                    accentColor: UIColors.accentMagenta
                )

                UIKnob(
                    value: binding(\.filterResonance),
                    label: "Resonance",
                    accentColor: UIColors.accentMagenta
                )

                UIBipolarKnob(
                    value: binding(\.filterEnvelopeAmount),
                    label: "Filter Env",
                    accentColor: UIColors.accentMagenta
                )
            }
        }
        .panelStyle()
        .padding(UISpacing.md)
    }

    // MARK: - Envelope Section

    private var envelopeSection: some View {
        VStack(alignment: .leading, spacing: UISpacing.md) {
            sectionHeader("AMP ENVELOPE")

            HStack(spacing: UISpacing.xl) {
                UIKnob(
                    value: binding(\.attack),
                    label: "Attack",
                    accentColor: UIColors.accentGreen,
                    valueFormatter: { String(format: "%.0fms", $0 * 1000) }
                )

                UIKnob(
                    value: binding(\.hold),
                    label: "Hold",
                    accentColor: UIColors.accentGreen,
                    valueFormatter: { String(format: "%.0fms", $0 * 500) }
                )

                UIKnob(
                    value: binding(\.decay),
                    label: "Decay",
                    accentColor: UIColors.accentGreen,
                    valueFormatter: { String(format: "%.0fms", $0 * 2000) }
                )

                UIKnob(
                    value: binding(\.sustain),
                    label: "Sustain",
                    accentColor: UIColors.accentGreen
                )

                UIKnob(
                    value: binding(\.release),
                    label: "Release",
                    accentColor: UIColors.accentGreen,
                    valueFormatter: { String(format: "%.0fms", $0 * 1000) }
                )
            }

            // Envelope visualization
            EnvelopeView(
                attack: voice.attack,
                hold: voice.hold,
                decay: voice.decay,
                sustain: voice.sustain,
                release: voice.release
            )
            .frame(height: 80)
        }
        .panelStyle()
        .padding(UISpacing.md)
    }

    // MARK: - Effects Section

    private var effectsSection: some View {
        VStack(alignment: .leading, spacing: UISpacing.md) {
            sectionHeader("EFFECTS")

            HStack(spacing: UISpacing.xl) {
                UIKnob(
                    value: binding(\.drive),
                    label: "Drive",
                    accentColor: UIColors.accentOrange
                )

                UIKnob(
                    value: binding(\.bitcrush),
                    label: "Bitcrush",
                    accentColor: UIColors.accentOrange,
                    valueFormatter: { $0 < 0.1 ? "Off" : String(format: "%.0f%%", $0 * 100) }
                )
            }
        }
        .panelStyle()
        .padding(UISpacing.md)
    }

    // MARK: - Output Section

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: UISpacing.md) {
            sectionHeader("OUTPUT")

            HStack(spacing: UISpacing.xl) {
                UIKnob(
                    value: binding(\.volume),
                    label: "Volume",
                    accentColor: voiceType.color
                )

                UIBipolarKnob(
                    value: binding(\.pan),
                    label: "Pan",
                    accentColor: voiceType.color
                )

                UIKnob(
                    value: binding(\.reverbSend),
                    label: "Reverb",
                    accentColor: UIColors.accentMagenta
                )

                UIKnob(
                    value: binding(\.delaySend),
                    label: "Delay",
                    accentColor: UIColors.accentOrange
                )
            }
        }
        .panelStyle()
        .padding(UISpacing.md)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(UIColors.textSecondary)
    }

    /// Whether this voice type supports tone/noise mix
    private var supportsToneMix: Bool {
        switch voiceType {
        case .snare, .closedHat, .openHat, .clap, .cymbal, .maracas:
            return true
        default:
            return false
        }
    }

    /// Creates a binding to a voice property
    private func binding<T>(_ keyPath: WritableKeyPath<Voice, T>) -> Binding<T> {
        Binding(
            get: { store.selectedVoice[keyPath: keyPath] },
            set: { store.selectedVoice[keyPath: keyPath] = $0 }
        )
    }
}

// MARK: - Envelope Visualization

/// Visual representation of ADSR envelope
struct EnvelopeView: View {
    var attack: Float
    var hold: Float
    var decay: Float
    var sustain: Float
    var release: Float

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            // Normalize times for visualization
            let totalTime = max(attack + hold + decay + release, 0.001)
            let aWidth = CGFloat(attack / totalTime) * width * 0.4
            let hWidth = CGFloat(hold / totalTime) * width * 0.2
            let dWidth = CGFloat(decay / totalTime) * width * 0.2
            let rWidth = CGFloat(release / totalTime) * width * 0.2

            Path { path in
                // Start at bottom left
                path.move(to: CGPoint(x: 0, y: height))

                // Attack: rise to peak
                path.addLine(to: CGPoint(x: aWidth, y: 0))

                // Hold: stay at peak
                path.addLine(to: CGPoint(x: aWidth + hWidth, y: 0))

                // Decay: fall to sustain
                let sustainY = height * CGFloat(1 - sustain)
                path.addLine(to: CGPoint(x: aWidth + hWidth + dWidth, y: sustainY))

                // Sustain line (implied by decay end)

                // Release: fall to zero
                path.addLine(to: CGPoint(x: aWidth + hWidth + dWidth + rWidth, y: height))
            }
            .stroke(
                LinearGradient(
                    colors: [UIColors.accentGreen, UIColors.accentCyan],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )

            // Fill under curve
            Path { path in
                path.move(to: CGPoint(x: 0, y: height))
                path.addLine(to: CGPoint(x: aWidth, y: 0))
                path.addLine(to: CGPoint(x: aWidth + hWidth, y: 0))
                let sustainY = height * CGFloat(1 - sustain)
                path.addLine(to: CGPoint(x: aWidth + hWidth + dWidth, y: sustainY))
                path.addLine(to: CGPoint(x: aWidth + hWidth + dWidth + rWidth, y: height))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [UIColors.accentGreen.opacity(0.3), UIColors.accentCyan.opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .background(UIColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview {
    UIVoiceEditor(store: AppStore(project: .demo()))
        .frame(width: 600)
        .background(UIColors.background)
}
