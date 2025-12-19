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

            // Master fader (uses computed property that syncs to DSP)
            UIFader(
                value: $store.masterVolume,
                label: "",
                accentColor: UIColors.accentCyan,
                width: 50,
                height: 180,
                defaultValue: 0.8
            )

            // VU meter showing actual output level
            StereoVUMeter(store: store)
                .frame(width: 30, height: 100)
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
            VStack(alignment: .leading, spacing: UISpacing.xs) {
                Text("REVERB")
                    .labelStyle()

                ParameterSlider(
                    value: $store.reverbMix,
                    label: "Mix",
                    accentColor: UIColors.accentMagenta,
                    defaultValue: 0.3
                )
            }
            .frame(width: 200)

            // Delay
            VStack(alignment: .leading, spacing: UISpacing.xs) {
                Text("DELAY")
                    .labelStyle()

                ParameterSlider(
                    value: $store.delayMix,
                    label: "Mix",
                    accentColor: UIColors.accentOrange,
                    defaultValue: 0.2
                )

                ParameterSlider(
                    value: $store.delayTime,
                    label: "Time",
                    accentColor: UIColors.accentOrange,
                    defaultValue: 0.5
                )

                ParameterSlider(
                    value: $store.delayFeedback,
                    label: "Feedback",
                    accentColor: UIColors.accentOrange,
                    defaultValue: 0.4
                )
            }
            .frame(width: 200)

            Spacer()

            // Compressor
            VStack(alignment: .leading, spacing: UISpacing.xs) {
                Text("COMPRESSOR")
                    .labelStyle()

                ParameterSlider(
                    value: Binding(
                        get: { (store.project.compressorThreshold + 40) / 40 },
                        set: { store.project.compressorThreshold = ($0 * 40) - 40 }
                    ),
                    label: "Threshold",
                    accentColor: UIColors.accentGreen,
                    valueFormatter: { String(format: "%.0fdB", ($0 * 40) - 40) },
                    defaultValue: 0.75  // -10dB
                )

                ParameterSlider(
                    value: Binding(
                        get: { (store.project.compressorRatio - 1) / 19 },
                        set: { store.project.compressorRatio = ($0 * 19) + 1 }
                    ),
                    label: "Ratio",
                    accentColor: UIColors.accentGreen,
                    valueFormatter: { String(format: "%.1f:1", ($0 * 19) + 1) },
                    defaultValue: 0.158  // 4:1
                )
            }
            .frame(width: 200)
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

// MARK: - Stereo VU Meter

/// Stereo VU meter with real-time audio levels from DSP engine
struct StereoVUMeter: View {
    @Bindable var store: AppStore
    @State private var leftLevel: Float = 0
    @State private var rightLevel: Float = 0
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 4) {
            VUMeter(level: leftLevel)
            VUMeter(level: rightLevel)
        }
        .onAppear {
            startMetering()
        }
        .onDisappear {
            stopMetering()
        }
    }

    private func startMetering() {
        // Update at 30fps for smooth metering
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            let levels = store.outputLevels
            // Scale RMS to approximate VU meter response (RMS is typically 0-0.5 for normal levels)
            leftLevel = min(1.0, levels.0 * 2.0)
            rightLevel = min(1.0, levels.1 * 2.0)
        }
    }

    private func stopMetering() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Preview

#Preview {
    UIMixerView(store: AppStore(project: .demo()))
}
