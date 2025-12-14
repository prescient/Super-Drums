import SwiftUI

/// A single track row in the sequencer (one voice).
struct UISequencerTrackRow: View {
    @Bindable var store: AppStore
    let voiceType: DrumVoiceType
    var stepSize: CGFloat = 36
    var stepSpacing: CGFloat = 3
    var onTrackTap: (() -> Void)? = nil

    /// Whether this track is selected for editing
    private var isSelected: Bool {
        store.selectedVoiceType == voiceType
    }

    /// Voice settings for this track
    private var voice: Voice {
        store.project.voice(for: voiceType)
    }

    /// Track data
    private var track: Track {
        store.currentPattern.track(for: voiceType)
    }

    var body: some View {
        HStack(spacing: stepSpacing) {
            // Voice info / select button
            voiceInfoButton

            // Step cells
            ForEach(Array(track.steps.enumerated()), id: \.offset) { index, step in
                UISequencerStepCell(
                    step: step,
                    stepIndex: index,
                    voiceType: voiceType,
                    isCurrentStep: store.isPlaying && index == store.currentStep,
                    size: stepSize,
                    onToggle: {
                        store.toggleStep(voice: voiceType, stepIndex: index)
                    },
                    onVelocityChange: { velocity in
                        store.setStepVelocity(voice: voiceType, stepIndex: index, velocity: velocity)
                    }
                )
            }

            // Mute/Solo
            mutesoloButtons
        }
        .background(
            isSelected
                ? voiceType.color.opacity(0.05)
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Voice Info Button

    private var voiceInfoButton: some View {
        Button {
            if let onTrackTap {
                onTrackTap()
            } else {
                store.selectedVoiceType = voiceType
            }
        } label: {
            HStack(spacing: 4) {
                // Color indicator
                RoundedRectangle(cornerRadius: 2)
                    .fill(voiceType.color)
                    .frame(width: 3, height: stepSize * 0.7)

                Text(voiceType.abbreviation)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(voiceType.color)
            }
            .frame(width: 56, alignment: .leading)
            .padding(.leading, 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mute/Solo Buttons

    private var mutesoloButtons: some View {
        HStack(spacing: 2) {
            // Mute
            Button {
                store.toggleMute(for: voiceType)
            } label: {
                Text("M")
                    .font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(IconButtonStyle(isActive: voice.isMuted, activeColor: UIColors.muted))

            // Solo
            Button {
                store.toggleSolo(for: voiceType)
            } label: {
                Text("S")
                    .font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(IconButtonStyle(isActive: voice.isSoloed, activeColor: UIColors.soloed))
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 4) {
        ForEach(DrumVoiceType.allCases) { voiceType in
            UISequencerTrackRow(
                store: AppStore(project: .demo()),
                voiceType: voiceType,
                stepSize: 50
            )
            .frame(height: 50)
        }
    }
    .padding()
    .background(UIColors.background)
}
