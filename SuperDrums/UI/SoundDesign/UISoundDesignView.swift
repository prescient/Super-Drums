import SwiftUI

/// Sound design view for editing voice synthesis parameters.
struct UISoundDesignView: View {
    @Bindable var store: AppStore

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Voice selector sidebar
                voiceSelectorSidebar

                // Divider
                Rectangle()
                    .fill(UIColors.border)
                    .frame(width: 1)

                // Voice editor
                UIVoiceEditor(store: store)
            }
        }
        .background(UIColors.background)
    }

    // MARK: - Voice Selector Sidebar

    private var voiceSelectorSidebar: some View {
        VStack(spacing: 0) {
            // Header
            Text("VOICES")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(UIColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, UISpacing.md)
                .background(UIColors.surface)

            // Voice list
            ScrollView {
                VStack(spacing: UISpacing.xs) {
                    ForEach(DrumVoiceType.allCases) { voiceType in
                        voiceButton(for: voiceType)
                    }
                }
                .padding(UISpacing.sm)
            }

            // Actions
            VStack(spacing: UISpacing.sm) {
                Button("Randomize Sound") {
                    store.randomizeSoundDesign(for: store.selectedVoiceType)
                }
                .buttonStyle(SecondaryButtonStyle(accentColor: UIColors.accentMagenta))

                Button("Reset to Default") {
                    resetVoiceToDefault()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(UISpacing.md)
            .background(UIColors.surface)
        }
        .frame(width: 140)
    }

    private func voiceButton(for voiceType: DrumVoiceType) -> some View {
        let isSelected = store.selectedVoiceType == voiceType
        let voice = store.project.voice(for: voiceType)

        return Button {
            store.selectedVoiceType = voiceType
        } label: {
            HStack(spacing: UISpacing.sm) {
                // Color indicator
                RoundedRectangle(cornerRadius: 2)
                    .fill(voiceType.color)
                    .frame(width: 4, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(voiceType.displayName)
                        .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? UIColors.textPrimary : UIColors.textSecondary)

                    // Status indicators
                    HStack(spacing: 4) {
                        if voice.isMuted {
                            Text("M")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(UIColors.muted)
                        }
                        if voice.isSoloed {
                            Text("S")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(UIColors.soloed)
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, UISpacing.sm)
            .padding(.vertical, UISpacing.xs)
            .background(isSelected ? voiceType.color.opacity(0.15) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? voiceType.color.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .hoverEffect()
    }

    private func resetVoiceToDefault() {
        var voice = Voice(voiceType: store.selectedVoiceType)
        voice.isMuted = store.selectedVoice.isMuted
        voice.isSoloed = store.selectedVoice.isSoloed
        store.selectedVoice = voice
    }
}

// MARK: - Preview

#Preview {
    UISoundDesignView(store: AppStore(project: .demo()))
}
