import SwiftUI

/// Main mixer view with channel strips for all 10 voices.
struct UIMixerView: View {
    @Bindable var store: AppStore

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header
                mixerHeader

                // Channel strips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: UISpacing.sm) {
                        // Voice channels
                        ForEach(DrumVoiceType.allCases) { voiceType in
                            UIMixerChannel(
                                store: store,
                                voiceType: voiceType
                            )
                        }

                        // Divider
                        Rectangle()
                            .fill(UIColors.border)
                            .frame(width: 1)
                            .padding(.vertical, UISpacing.lg)

                        // Master channel
                        masterChannel
                    }
                    .padding(.horizontal, UISpacing.lg)
                    .padding(.vertical, UISpacing.md)
                }

                // Master effects section
                masterEffectsBar
            }
        }
        .background(UIColors.background)
    }

    // MARK: - Header

    private var mixerHeader: some View {
        HStack {
            Text("Mixer")
                .headerStyle()

            Spacer()

            // Quick actions
            HStack(spacing: UISpacing.md) {
                Button("Reset All") {
                    resetAllChannels()
                }
                .buttonStyle(SecondaryButtonStyle())

                Button("Clear Solos") {
                    clearAllSolos()
                }
                .buttonStyle(SecondaryButtonStyle())

                Button("Clear Mutes") {
                    clearAllMutes()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(.horizontal, UISpacing.lg)
        .padding(.vertical, UISpacing.md)
        .background(UIColors.surface)
    }

    // MARK: - Master Channel

    private var masterChannel: some View {
        VStack(spacing: UISpacing.sm) {
            Text("MASTER")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(UIColors.textPrimary)

            // Master fader
            UIFader(
                value: $store.project.masterVolume,
                label: "",
                accentColor: UIColors.accentCyan,
                width: 50,
                height: 180
            )

            // VU meter placeholder
            VUMeter(level: store.project.masterVolume)
                .frame(width: 20, height: 100)
        }
        .frame(width: UISizes.channelStripWidth + 20)
        .padding(.vertical, UISpacing.md)
        .background(UIColors.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Master Effects Bar

    private var masterEffectsBar: some View {
        HStack(spacing: UISpacing.xl) {
            // Reverb
            VStack(spacing: UISpacing.xs) {
                Text("REVERB")
                    .labelStyle()

                UIKnob(
                    value: $store.project.reverbMix,
                    label: "Mix",
                    accentColor: UIColors.accentMagenta,
                    size: UISizes.knobSmall
                )
            }

            // Delay
            VStack(spacing: UISpacing.xs) {
                Text("DELAY")
                    .labelStyle()

                HStack(spacing: UISpacing.sm) {
                    UIKnob(
                        value: $store.project.delayMix,
                        label: "Mix",
                        accentColor: UIColors.accentOrange,
                        size: UISizes.knobSmall
                    )

                    UIKnob(
                        value: $store.project.delayTime,
                        label: "Time",
                        accentColor: UIColors.accentOrange,
                        size: UISizes.knobSmall
                    )

                    UIKnob(
                        value: $store.project.delayFeedback,
                        label: "Feedback",
                        accentColor: UIColors.accentOrange,
                        size: UISizes.knobSmall
                    )
                }
            }

            Spacer()

            // Compressor
            VStack(spacing: UISpacing.xs) {
                Text("COMPRESSOR")
                    .labelStyle()

                HStack(spacing: UISpacing.sm) {
                    UIKnob(
                        value: Binding(
                            get: { (store.project.compressorThreshold + 40) / 40 },
                            set: { store.project.compressorThreshold = ($0 * 40) - 40 }
                        ),
                        label: "Threshold",
                        accentColor: UIColors.accentGreen,
                        size: UISizes.knobSmall,
                        valueFormatter: { String(format: "%.0fdB", ($0 * 40) - 40) }
                    )

                    UIKnob(
                        value: Binding(
                            get: { (store.project.compressorRatio - 1) / 19 },
                            set: { store.project.compressorRatio = ($0 * 19) + 1 }
                        ),
                        label: "Ratio",
                        accentColor: UIColors.accentGreen,
                        size: UISizes.knobSmall,
                        valueFormatter: { String(format: "%.1f:1", ($0 * 19) + 1) }
                    )
                }
            }
        }
        .padding(.horizontal, UISpacing.lg)
        .padding(.vertical, UISpacing.md)
        .background(UIColors.surface)
    }

    // MARK: - Actions

    private func resetAllChannels() {
        for voiceType in DrumVoiceType.allCases {
            store.setVolume(0.8, for: voiceType)
            store.setPan(0, for: voiceType)
            store.setMute(false, for: voiceType)
            store.setSolo(false, for: voiceType)
        }
    }

    private func clearAllSolos() {
        for voiceType in DrumVoiceType.allCases {
            store.setSolo(false, for: voiceType)
        }
    }

    private func clearAllMutes() {
        for voiceType in DrumVoiceType.allCases {
            store.setMute(false, for: voiceType)
        }
    }
}

// MARK: - VU Meter

/// Simple VU meter visualization
struct VUMeter: View {
    var level: Float
    var segmentCount: Int = 12

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 2) {
                ForEach((0..<segmentCount).reversed(), id: \.self) { index in
                    let threshold = Float(index) / Float(segmentCount)
                    let isLit = level > threshold

                    RoundedRectangle(cornerRadius: 1)
                        .fill(segmentColor(for: index, isLit: isLit))
                        .frame(height: geometry.size.height / CGFloat(segmentCount) - 2)
                }
            }
        }
    }

    private func segmentColor(for index: Int, isLit: Bool) -> Color {
        if !isLit {
            return UIColors.border
        }

        let position = Float(index) / Float(segmentCount)
        if position > 0.85 {
            return UIColors.muted // Red for clipping
        } else if position > 0.7 {
            return UIColors.accentYellow // Yellow for hot
        } else {
            return UIColors.accentGreen // Green for normal
        }
    }
}

// MARK: - Preview

#Preview {
    UIMixerView(store: AppStore(project: .demo()))
}
