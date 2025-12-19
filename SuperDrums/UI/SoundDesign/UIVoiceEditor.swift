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
            VStack(spacing: UISpacing.lg) {
                // Header
                header

                // Two-column layout for sections
                HStack(alignment: .top, spacing: UISpacing.lg) {
                    // Left column
                    VStack(spacing: UISpacing.lg) {
                        oscillatorSection
                        filterSection
                        effectsSection
                    }

                    // Right column
                    VStack(spacing: UISpacing.lg) {
                        envelopeSection
                        outputSection
                    }
                }
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
        sectionPanel(title: "OSCILLATOR", color: voiceType.color) {
            VStack(spacing: UISpacing.sm) {
                ParameterSlider(
                    value: binding(\.pitch),
                    label: "Pitch",
                    accentColor: voiceType.color,
                    valueFormatter: { String(format: "%.0f%%", $0 * 100) },
                    defaultValue: 0.5
                )

                BipolarSlider(
                    value: binding(\.pitchEnvelopeAmount),
                    label: "Pitch Env",
                    accentColor: voiceType.color,
                    defaultValue: 0.0
                )

                ParameterSlider(
                    value: binding(\.pitchEnvelopeDecay),
                    label: "P.Env Decay",
                    accentColor: voiceType.color,
                    valueFormatter: { String(format: "%.0fms", $0 * 500) },
                    defaultValue: 0.3
                )

                // Tone/Noise mix (for voices that support it)
                if supportsToneMix {
                    ParameterSlider(
                        value: binding(\.toneMix),
                        label: "Tone/Noise",
                        accentColor: voiceType.color,
                        valueFormatter: { $0 < 0.3 ? "Tone" : ($0 > 0.7 ? "Noise" : "Mix") },
                        defaultValue: 0.5
                    )
                }
            }
        }
    }

    // MARK: - Filter Section

    private var filterSection: some View {
        sectionPanel(title: "FILTER", color: UIColors.accentMagenta) {
            VStack(spacing: UISpacing.sm) {
                // Filter type picker
                HStack {
                    Text("Type")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(UIColors.textSecondary)
                        .frame(width: 70, alignment: .leading)

                    Picker("Filter Type", selection: binding(\.filterType)) {
                        ForEach(FilterType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .frame(height: 24)

                ParameterSlider(
                    value: binding(\.filterCutoff),
                    label: "Cutoff",
                    accentColor: UIColors.accentMagenta,
                    valueFormatter: { String(format: "%.0f%%", $0 * 100) },
                    defaultValue: 1.0
                )

                ParameterSlider(
                    value: binding(\.filterResonance),
                    label: "Resonance",
                    accentColor: UIColors.accentMagenta,
                    valueFormatter: { String(format: "%.0f%%", $0 * 100) },
                    defaultValue: 0.0
                )

                BipolarSlider(
                    value: binding(\.filterEnvelopeAmount),
                    label: "Filter Env",
                    accentColor: UIColors.accentMagenta,
                    defaultValue: 0.0
                )
            }
        }
    }

    // MARK: - Envelope Section

    private var envelopeSection: some View {
        sectionPanel(title: "AMP ENVELOPE", color: UIColors.accentGreen) {
            VStack(spacing: UISpacing.sm) {
                ParameterSlider(
                    value: binding(\.attack),
                    label: "Attack",
                    accentColor: UIColors.accentGreen,
                    valueFormatter: { String(format: "%.0fms", $0 * 1000) },
                    defaultValue: 0.001
                )

                ParameterSlider(
                    value: binding(\.hold),
                    label: "Hold",
                    accentColor: UIColors.accentGreen,
                    valueFormatter: { String(format: "%.0fms", $0 * 500) },
                    defaultValue: 0.0
                )

                ParameterSlider(
                    value: binding(\.decay),
                    label: "Decay",
                    accentColor: UIColors.accentGreen,
                    valueFormatter: { String(format: "%.0fms", $0 * 2000) },
                    defaultValue: 0.5
                )

                ParameterSlider(
                    value: binding(\.sustain),
                    label: "Sustain",
                    accentColor: UIColors.accentGreen,
                    valueFormatter: { String(format: "%.0f%%", $0 * 100) },
                    defaultValue: 0.0
                )

                ParameterSlider(
                    value: binding(\.release),
                    label: "Release",
                    accentColor: UIColors.accentGreen,
                    valueFormatter: { String(format: "%.0fms", $0 * 1000) },
                    defaultValue: 0.1
                )

                // Envelope visualization
                EnvelopeView(
                    attack: voice.attack,
                    hold: voice.hold,
                    decay: voice.decay,
                    sustain: voice.sustain,
                    release: voice.release
                )
                .frame(height: 60)
            }
        }
    }

    // MARK: - Effects Section

    private var effectsSection: some View {
        sectionPanel(title: "EFFECTS", color: UIColors.accentOrange) {
            VStack(spacing: UISpacing.sm) {
                ParameterSlider(
                    value: binding(\.drive),
                    label: "Drive",
                    accentColor: UIColors.accentOrange,
                    valueFormatter: { $0 < 0.05 ? "Off" : String(format: "%.0f%%", $0 * 100) },
                    defaultValue: 0.0
                )

                ParameterSlider(
                    value: binding(\.bitcrush),
                    label: "Bitcrush",
                    accentColor: UIColors.accentOrange,
                    valueFormatter: { $0 < 0.05 ? "Off" : String(format: "%.0f%%", $0 * 100) },
                    defaultValue: 0.0
                )
            }
        }
    }

    // MARK: - Output Section

    private var outputSection: some View {
        sectionPanel(title: "OUTPUT", color: voiceType.color) {
            VStack(spacing: UISpacing.sm) {
                ParameterSlider(
                    value: binding(\.volume),
                    label: "Volume",
                    accentColor: voiceType.color,
                    valueFormatter: { String(format: "%.0f%%", $0 * 100) },
                    defaultValue: 0.8
                )

                BipolarSlider(
                    value: binding(\.pan),
                    label: "Pan",
                    accentColor: voiceType.color,
                    valueFormatter: {
                        if abs($0) < 0.05 { return "C" }
                        return $0 < 0 ? String(format: "L%.0f", abs($0) * 100) : String(format: "R%.0f", $0 * 100)
                    },
                    defaultValue: 0.0
                )

                ParameterSlider(
                    value: binding(\.reverbSend),
                    label: "Reverb",
                    accentColor: UIColors.accentMagenta,
                    valueFormatter: { String(format: "%.0f%%", $0 * 100) },
                    defaultValue: 0.0
                )

                ParameterSlider(
                    value: binding(\.delaySend),
                    label: "Delay",
                    accentColor: UIColors.accentOrange,
                    valueFormatter: { String(format: "%.0f%%", $0 * 100) },
                    defaultValue: 0.0
                )
            }
        }
    }

    // MARK: - Helpers

    /// Creates a section panel with title and content
    private func sectionPanel<Content: View>(
        title: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: UISpacing.sm) {
            // Section header - outside the panel background for visibility
            HStack(spacing: UISpacing.xs) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 3, height: 12)

                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(UIColors.textSecondary)
            }

            // Content panel with proper internal padding
            VStack(alignment: .leading, spacing: UISpacing.sm) {
                content()
            }
            .padding(UISpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(UIColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(UIColors.border, lineWidth: 1)
            )
        }
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
        .background(UIColors.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview {
    UIVoiceEditor(store: AppStore(project: .demo()))
        .frame(width: 700)
        .background(UIColors.background)
}
