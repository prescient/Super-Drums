import SwiftUI

/// Main sequencer view with 10-track grid.
struct UISequencerView: View {
    @Bindable var store: AppStore

    // Layout constants
    private let voiceLabelWidth: CGFloat = 56
    private let muteSoloWidth: CGFloat = 76
    private let horizontalPadding: CGFloat = 12
    private let stepSpacing: CGFloat = 3
    private let trackSpacing: CGFloat = 3
    private let transportHeight: CGFloat = 56
    private let toolbarHeight: CGFloat = 52
    private let stepHeaderHeight: CGFloat = 18
    private let trackOptionsPanelWidth: CGFloat = 280
    private let parameterLockEditorHeight: CGFloat = 140
    private let songArrangementHeight: CGFloat = 120

    var body: some View {
        GeometryReader { geometry in
            let panelVisible = store.showTrackOptions
            let paramLockVisible = store.showParameterLocks
            let songArrangementVisible = store.showSongArrangement
            let panelOffset = panelVisible ? trackOptionsPanelWidth : 0
            let effectiveWidth = geometry.size.width - panelOffset
            let paramLockOffset = paramLockVisible ? parameterLockEditorHeight : 0
            let songOffset = songArrangementVisible ? songArrangementHeight : 0

            let availableHeight = geometry.size.height - transportHeight - toolbarHeight - stepHeaderHeight - 16 - paramLockOffset - songOffset
            let availableWidth = effectiveWidth - voiceLabelWidth - muteSoloWidth - (horizontalPadding * 2)
            let stepCount = CGFloat(store.currentPattern.defaultStepCount)
            let stepSize = min(
                (availableWidth - (stepSpacing * (stepCount - 1))) / stepCount,
                (availableHeight - (trackSpacing * 9)) / 10
            )

            HStack(spacing: 0) {
                // Main sequencer content
                VStack(spacing: 0) {
                    // Transport bar
                    UITransportBar(
                        isPlaying: store.isPlaying,
                        bpm: $store.bpm,
                        currentStep: store.currentStep,
                        patternLength: store.currentPattern.defaultStepCount,
                        onPlayToggle: { store.togglePlayback() },
                        currentPatternIndex: store.project.currentPatternIndex,
                        patternCount: store.project.patterns.count,
                        patternName: store.currentPattern.name,
                        onPreviousPattern: {
                            if store.project.currentPatternIndex > 0 {
                                store.selectPattern(store.project.currentPatternIndex - 1)
                            }
                        },
                        onNextPattern: {
                            if store.project.currentPatternIndex < store.project.patterns.count - 1 {
                                store.selectPattern(store.project.currentPatternIndex + 1)
                            }
                        },
                        onAddPattern: {
                            store.addPattern()
                            store.selectPattern(store.project.patterns.count - 1)
                        },
                        onSelectPattern: { index in
                            store.selectPattern(index)
                        },
                        showPatternBank: $store.showPatternBank
                    )
                    .frame(height: transportHeight)

                    // Step numbers header (compact)
                    stepNumbersHeader(stepSize: stepSize)
                        .frame(height: stepHeaderHeight)

                    // Sequencer grid - fills remaining space
                    VStack(spacing: trackSpacing) {
                        ForEach(DrumVoiceType.allCases) { voiceType in
                            UISequencerTrackRow(
                                store: store,
                                voiceType: voiceType,
                                stepSize: stepSize,
                                stepSpacing: stepSpacing,
                                onTrackTap: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if store.selectedVoiceType == voiceType && store.showTrackOptions {
                                            store.showTrackOptions = false
                                        } else {
                                            store.selectedVoiceType = voiceType
                                            store.showTrackOptions = true
                                        }
                                    }
                                }
                            )
                            .frame(height: stepSize)
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, 8)
                    .frame(maxHeight: .infinity)

                    // Song arrangement editor (slides up from bottom)
                    if songArrangementVisible {
                        UISongArrangementEditor(
                            store: store,
                            isVisible: $store.showSongArrangement
                        )
                        .frame(height: songArrangementHeight)
                        .transition(.move(edge: .bottom))
                    }

                    // Parameter lock editor (slides up from bottom)
                    if paramLockVisible {
                        UIParameterLockEditor(
                            store: store,
                            isVisible: $store.showParameterLocks
                        )
                        .frame(height: parameterLockEditorHeight)
                        .transition(.move(edge: .bottom))
                    }

                    // Bottom toolbar
                    sequencerToolbar
                        .frame(height: toolbarHeight)
                }
                .frame(width: effectiveWidth)
                .animation(.easeInOut(duration: 0.2), value: songArrangementVisible)
                .animation(.easeInOut(duration: 0.2), value: paramLockVisible)

                // Slide-out track options panel
                if panelVisible {
                    UITrackOptionsPanel(
                        store: store,
                        isVisible: $store.showTrackOptions
                    )
                    .frame(width: trackOptionsPanelWidth)
                    .transition(.move(edge: .trailing))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: panelVisible)
        }
        .background(UIColors.background)
    }

    // MARK: - Step Numbers Header

    private func stepNumbersHeader(stepSize: CGFloat) -> some View {
        HStack(spacing: stepSpacing) {
            // Spacer for voice label column
            Color.clear
                .frame(width: voiceLabelWidth)

            // Step numbers
            ForEach(0..<store.currentPattern.defaultStepCount, id: \.self) { index in
                Text("\(index + 1)")
                    .font(.system(size: 9, weight: index % 4 == 0 ? .bold : .regular, design: .monospaced))
                    .foregroundStyle(index % 4 == 0 ? UIColors.textPrimary : UIColors.textSecondary)
                    .frame(width: stepSize)
            }

            // Spacer for mute/solo
            Color.clear
                .frame(width: muteSoloWidth)
        }
        .padding(.horizontal, horizontalPadding)
    }

    // MARK: - Toolbar

    private var sequencerToolbar: some View {
        HStack(spacing: UISpacing.lg) {
            // Clear pattern
            Button {
                store.clearCurrentPattern()
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .buttonStyle(SecondaryButtonStyle(accentColor: UIColors.muted))

            // Shift left
            Button {
                store.shiftPattern(by: -1)
            } label: {
                Label("Shift Left", systemImage: "arrow.left")
            }
            .buttonStyle(SecondaryButtonStyle())

            // Shift right
            Button {
                store.shiftPattern(by: 1)
            } label: {
                Label("Shift Right", systemImage: "arrow.right")
            }
            .buttonStyle(SecondaryButtonStyle())

            Spacer()

            // Song mode toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    store.showSongArrangement.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: store.isSongMode ? "music.note.list" : "repeat.1")
                    Text(store.isSongMode ? "SONG" : "PTN")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                }
            }
            .buttonStyle(SecondaryButtonStyle(accentColor: store.showSongArrangement ? UIColors.accentGreen : (store.isSongMode ? UIColors.accentGreen : UIColors.accentCyan)))

            // Parameter locks toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    store.showParameterLocks.toggle()
                }
            } label: {
                Label("P-Locks", systemImage: "lock.rectangle.stack")
            }
            .buttonStyle(SecondaryButtonStyle(accentColor: store.showParameterLocks ? UIColors.accentYellow : UIColors.accentCyan))

            // Track options toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    store.showTrackOptions.toggle()
                }
            } label: {
                Label("Track Options", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(SecondaryButtonStyle(accentColor: store.showTrackOptions ? store.selectedVoiceType.color : UIColors.accentCyan))

            // Randomize all
            Menu {
                Button("Randomize All Tracks") {
                    store.randomizePattern()
                }
                Button("Randomize (Keep Kick/Snare Simple)") {
                    store.randomizePattern(keepKickSnareSimple: true)
                }
            } label: {
                Label("Randomize All", systemImage: "dice")
            }
            .buttonStyle(SecondaryButtonStyle(accentColor: UIColors.accentMagenta))

            // Duplicate pattern
            Button {
                store.duplicateCurrentPattern()
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            .buttonStyle(SecondaryButtonStyle(accentColor: UIColors.accentGreen))
        }
        .padding(.horizontal, UISpacing.lg)
        .padding(.vertical, UISpacing.sm)
        .background(UIColors.surface)
    }
}

// MARK: - Preview

#Preview {
    UISequencerView(store: AppStore(project: .demo()))
}
