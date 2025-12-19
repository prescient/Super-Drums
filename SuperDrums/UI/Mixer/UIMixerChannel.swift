import SwiftUI

/// A single channel strip in the mixer.
struct UIMixerChannel: View {
    @Bindable var store: AppStore
    let voiceType: DrumVoiceType

    /// Voice for this channel
    private var voice: Voice {
        store.project.voice(for: voiceType)
    }

    /// Whether this voice is selected
    private var isSelected: Bool {
        store.selectedVoiceType == voiceType
    }

    var body: some View {
        VStack(spacing: UISpacing.sm) {
            // Voice name
            Button {
                store.selectedVoiceType = voiceType
            } label: {
                VStack(spacing: 2) {
                    Text(voiceType.abbreviation)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(voiceType.color)

                    Text(voiceType.displayName)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(UIColors.textSecondary)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)
            .hoverEffect()

            // Pan slider (-100 to +100, 0 = center)
            VStack(spacing: 2) {
                Text("PAN")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(UIColors.textSecondary)

                CompactBipolarSlider(
                    value: Binding(
                        get: { voice.pan },
                        set: { store.setPan($0, for: voiceType) }
                    ),
                    accentColor: voiceType.color,
                    defaultValue: 0.0
                )
            }

            // Reverb send slider (0-100)
            VStack(spacing: 2) {
                Text("REV")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(UIColors.textSecondary)

                CompactParameterSlider(
                    value: Binding(
                        get: { voice.reverbSend },
                        set: { updateVoice { $0.reverbSend = $1 }($0) }
                    ),
                    accentColor: UIColors.accentMagenta,
                    defaultValue: 0.0
                )
            }

            // Delay send slider (0-100)
            VStack(spacing: 2) {
                Text("DLY")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(UIColors.textSecondary)

                CompactParameterSlider(
                    value: Binding(
                        get: { voice.delaySend },
                        set: { updateVoice { $0.delaySend = $1 }($0) }
                    ),
                    accentColor: UIColors.accentOrange,
                    defaultValue: 0.0
                )
            }

            // Fader
            UICompactFader(
                value: Binding(
                    get: { voice.volume },
                    set: { store.setVolume($0, for: voiceType) }
                ),
                accentColor: voiceType.color,
                height: 140,
                defaultValue: 0.8
            )

            // Volume value
            Text(volumeString)
                .valueStyle()

            // Mute/Solo buttons
            HStack(spacing: UISpacing.xxs) {
                // Mute
                Button {
                    store.toggleMute(for: voiceType)
                } label: {
                    Text("M")
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(IconButtonStyle(isActive: voice.isMuted, activeColor: UIColors.muted))

                // Solo
                Button {
                    store.toggleSolo(for: voiceType)
                } label: {
                    Text("S")
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(IconButtonStyle(isActive: voice.isSoloed, activeColor: UIColors.soloed))
            }
        }
        .frame(width: UISizes.channelStripWidth)
        .padding(.vertical, UISpacing.md)
        .padding(.horizontal, UISpacing.xs)
        .background(
            isSelected
                ? voiceType.color.opacity(0.1)
                : UIColors.surface
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? voiceType.color.opacity(0.5) : UIColors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private var volumeString: String {
        if voice.volume < 0.001 {
            return "-∞"
        }
        let dB = 20 * log10(voice.volume)
        if dB > 0 {
            return String(format: "+%.1f", dB)
        }
        return String(format: "%.1f", dB)
    }

    /// Helper to update voice properties
    private func updateVoice(_ update: @escaping (inout Voice, Float) -> Void) -> (Float) -> Void {
        return { newValue in
            var updatedVoice = store.project.voice(for: voiceType)
            update(&updatedVoice, newValue)
            store.project.setVoice(updatedVoice, for: voiceType)
        }
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 16) {
        UIMixerChannel(store: AppStore(project: .demo()), voiceType: .kick)
        UIMixerChannel(store: AppStore(project: .demo()), voiceType: .snare)
        UIMixerChannel(store: AppStore(project: .demo()), voiceType: .closedHat)
    }
    .padding(40)
    .background(UIColors.background)
}
