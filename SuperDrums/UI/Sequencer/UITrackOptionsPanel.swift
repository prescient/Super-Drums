import SwiftUI

/// Slide-out panel for per-track options including randomization.
struct UITrackOptionsPanel: View {
    @Bindable var store: AppStore
    @Binding var isVisible: Bool

    @State private var settings = TrackRandomizationSettings()

    private var voiceType: DrumVoiceType {
        store.selectedVoiceType
    }

    private var track: Track {
        store.currentPattern.track(for: voiceType)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            ScrollView {
                VStack(spacing: UISpacing.lg) {
                    // Pattern Randomization Section
                    patternSection

                    Divider()
                        .background(UIColors.border)

                    // Sound Randomization Section
                    soundSection

                    Divider()
                        .background(UIColors.border)

                    // Track Actions Section
                    actionsSection
                }
                .padding(UISpacing.md)
            }
        }
        .frame(width: 280)
        .background(UIColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 10, x: -5, y: 0)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            // Voice indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(voiceType.color)
                .frame(width: 4, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(voiceType.fullName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(UIColors.textPrimary)

                Text("Track Options")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(UIColors.textSecondary)
            }

            Spacer()

            // Close button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isVisible = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(UIColors.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(UIColors.elevated)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(UISpacing.md)
        .background(UIColors.elevated)
    }

    // MARK: - Pattern Section

    private var patternSection: some View {
        VStack(alignment: .leading, spacing: UISpacing.md) {
            sectionHeader("PATTERN RANDOMIZATION")

            // Per-parameter toggles
            VStack(alignment: .leading, spacing: UISpacing.xs) {
                Text("Parameters to Randomize")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(UIColors.textSecondary)

                HStack(spacing: UISpacing.xs) {
                    parameterToggle("Steps", isOn: $settings.randomizeSteps)
                    parameterToggle("Vel", isOn: $settings.randomizeVelocity)
                    parameterToggle("Prob", isOn: $settings.randomizeProbability)
                    parameterToggle("Retrig", isOn: $settings.randomizeRetriggers)
                }
            }

            // Step Pattern Settings (only show if randomizing steps)
            if settings.randomizeSteps {
                VStack(alignment: .leading, spacing: UISpacing.xs) {
                    HStack {
                        Text("Density")
                            .labelStyle()
                        Spacer()
                        Text("\(Int(settings.density * 100))%")
                            .valueStyle()
                    }

                    Slider(value: $settings.density, in: 0...1)
                        .tint(voiceType.color)
                }

                // Euclidean Mode
                VStack(alignment: .leading, spacing: UISpacing.xs) {
                    Toggle(isOn: $settings.useEuclidean) {
                        HStack {
                            Text("Euclidean Mode")
                                .labelStyle()
                            if settings.useEuclidean {
                                Text("\(settings.euclideanHits)/16")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(voiceType.color)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(voiceType.color.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                    .tint(voiceType.color)

                    if settings.useEuclidean {
                        HStack {
                            Text("Hits")
                                .labelStyle()
                            Spacer()
                            Text("\(settings.euclideanHits)")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(voiceType.color)
                                .frame(width: 32)
                            Stepper(
                                "",
                                value: $settings.euclideanHits,
                                in: 1...16
                            )
                            .labelsHidden()
                        }
                    }
                }

                Toggle(isOn: $settings.preserveDownbeats) {
                    Text("Preserve Downbeats")
                        .labelStyle()
                }
                .tint(voiceType.color)
            }

            // Velocity Settings (only show if randomizing velocity)
            if settings.randomizeVelocity {
                VStack(alignment: .leading, spacing: UISpacing.xs) {
                    HStack {
                        Text("Velocity Range")
                            .labelStyle()
                        Spacer()
                        Text("\(settings.velocityMin) - \(settings.velocityMax)")
                            .valueStyle()
                    }

                    HStack(spacing: UISpacing.sm) {
                        Slider(
                            value: Binding(
                                get: { Float(settings.velocityMin) },
                                set: { settings.velocityMin = UInt8(min($0, Float(settings.velocityMax) - 1)) }
                            ),
                            in: 1...126
                        )
                        .tint(voiceType.color.opacity(0.6))

                        Slider(
                            value: Binding(
                                get: { Float(settings.velocityMax) },
                                set: { settings.velocityMax = UInt8(max($0, Float(settings.velocityMin) + 1)) }
                            ),
                            in: 2...127
                        )
                        .tint(voiceType.color)
                    }
                }
            }

            // Probability Settings (only show if randomizing probability)
            if settings.randomizeProbability {
                VStack(alignment: .leading, spacing: UISpacing.xs) {
                    HStack {
                        Text("Probability Range")
                            .labelStyle()
                        Spacer()
                        Text("\(Int(settings.probabilityMin * 100))% - \(Int(settings.probabilityMax * 100))%")
                            .valueStyle()
                    }

                    HStack(spacing: UISpacing.sm) {
                        Slider(
                            value: Binding(
                                get: { settings.probabilityMin },
                                set: { settings.probabilityMin = min($0, settings.probabilityMax - 0.05) }
                            ),
                            in: 0...0.95
                        )
                        .tint(UIColors.accentMagenta.opacity(0.6))

                        Slider(
                            value: Binding(
                                get: { settings.probabilityMax },
                                set: { settings.probabilityMax = max($0, settings.probabilityMin + 0.05) }
                            ),
                            in: 0.05...1
                        )
                        .tint(UIColors.accentMagenta)
                    }
                }
            }

            // Retrigger Settings (only show if randomizing retriggers)
            if settings.randomizeRetriggers {
                VStack(alignment: .leading, spacing: UISpacing.xs) {
                    HStack {
                        Text("Retrigger Chance")
                            .labelStyle()
                        Spacer()
                        Text("\(Int(settings.retriggerChance * 100))%")
                            .valueStyle()
                    }

                    Slider(value: $settings.retriggerChance, in: 0...1)
                        .tint(UIColors.accentGreen)

                    HStack {
                        Text("Max Retriggers")
                            .labelStyle()
                        Spacer()
                        Stepper(
                            "\(settings.retriggerMax)x",
                            value: $settings.retriggerMax,
                            in: 2...8
                        )
                        .labelsHidden()
                    }
                }
            }

            // Presets
            HStack(spacing: UISpacing.xs) {
                presetButton("Sparse", settings: .sparse)
                presetButton("Medium", settings: .medium)
                presetButton("Dense", settings: .dense)
            }

            // Randomize Button
            Button {
                store.randomizeTrack(voiceType, with: settings)
            } label: {
                Label("Randomize", systemImage: "dice")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle(accentColor: voiceType.color))
        }
    }

    private func parameterToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isOn.wrappedValue ? UIColors.textPrimary : UIColors.textSecondary)
                .padding(.horizontal, UISpacing.sm)
                .padding(.vertical, UISpacing.xs)
                .background(isOn.wrappedValue ? voiceType.color.opacity(0.3) : UIColors.elevated)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isOn.wrappedValue ? voiceType.color : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sound Section

    private var soundSection: some View {
        VStack(alignment: .leading, spacing: UISpacing.md) {
            sectionHeader("SOUND RANDOMIZATION")

            Text("Randomize synthesis parameters for this voice.")
                .font(.system(size: 11))
                .foregroundStyle(UIColors.textSecondary)

            Button {
                store.randomizeSoundDesign(for: voiceType)
            } label: {
                Label("Randomize Sound", systemImage: "waveform")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle(accentColor: UIColors.accentMagenta))
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: UISpacing.md) {
            sectionHeader("TRACK ACTIONS")

            HStack(spacing: UISpacing.sm) {
                // Clear Track
                Button {
                    store.clearTrack(voiceType)
                } label: {
                    Label("Clear", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle(accentColor: UIColors.muted))

                // Fill Track
                Button {
                    store.fillTrack(voiceType)
                } label: {
                    Label("Fill All", systemImage: "square.grid.2x2")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            HStack(spacing: UISpacing.sm) {
                // Shift Left
                Button {
                    store.shiftTrack(voiceType, by: -1)
                } label: {
                    Image(systemName: "arrow.left")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())

                // Shift Right
                Button {
                    store.shiftTrack(voiceType, by: 1)
                } label: {
                    Image(systemName: "arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())

                // Reverse
                Button {
                    store.reverseTrack(voiceType)
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            // Step count (max 16, reduction only)
            VStack(alignment: .leading, spacing: UISpacing.xs) {
                HStack {
                    Text("Step Count")
                        .labelStyle()
                    Spacer()
                    Text("\(track.stepCount)")
                        .valueStyle()
                }

                Stepper(
                    "",
                    value: Binding(
                        get: { track.stepCount },
                        set: { store.setTrackStepCount(voiceType, count: $0) }
                    ),
                    in: 1...16
                )
                .labelsHidden()
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(UIColors.textSecondary)
    }

    private func presetButton(_ title: String, settings preset: TrackRandomizationSettings) -> some View {
        Button {
            settings = preset
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(UIColors.textSecondary)
                .padding(.horizontal, UISpacing.sm)
                .padding(.vertical, UISpacing.xs)
                .background(UIColors.elevated)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    HStack {
        Spacer()
        UITrackOptionsPanel(
            store: AppStore(project: .demo()),
            isVisible: .constant(true)
        )
    }
    .background(UIColors.background)
}
