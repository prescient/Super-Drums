import SwiftUI

/// Slide-up panel for editing song arrangement.
/// Shows pattern chain with drag-to-reorder and repeat counts.
struct UISongArrangementEditor: View {
    @Bindable var store: AppStore
    @Binding var isVisible: Bool

    private let panelHeight: CGFloat = 120
    private let entryWidth: CGFloat = 72
    private let entrySpacing: CGFloat = 8

    var body: some View {
        VStack(spacing: 0) {
            // Header with controls
            headerBar
                .frame(height: 36)

            // Arrangement lane
            arrangementLane
                .frame(maxHeight: .infinity)
        }
        .background(UIColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(UIColors.border, lineWidth: 1)
        )
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: UISpacing.md) {
            // Mode toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    store.toggleSongMode()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: store.isSongMode ? "music.note.list" : "repeat.1")
                        .font(.system(size: 12, weight: .semibold))
                    Text(store.isSongMode ? "SONG" : "PATTERN")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(store.isSongMode ? UIColors.accentGreen : UIColors.accentCyan)
                .padding(.horizontal, UISpacing.sm)
                .padding(.vertical, UISpacing.xs)
                .background(store.isSongMode ? UIColors.accentGreen.opacity(0.2) : UIColors.elevated)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            // Loop toggle (song mode only)
            if store.isSongMode {
                Button {
                    store.loopSong.toggle()
                } label: {
                    Image(systemName: store.loopSong ? "repeat" : "arrow.right.to.line")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(store.loopSong ? UIColors.accentYellow : UIColors.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Song length indicator
            if !store.project.songArrangement.isEmpty {
                Text("\(store.project.songArrangement.count) patterns")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(UIColors.textSecondary)
            }

            // Add current pattern button
            Button {
                store.addCurrentPatternToSong()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(UIColors.accentCyan)
            }
            .buttonStyle(.plain)

            // Clear arrangement
            Button {
                store.clearSongArrangement()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(UIColors.muted)
            }
            .buttonStyle(.plain)
            .disabled(store.project.songArrangement.isEmpty)
            .opacity(store.project.songArrangement.isEmpty ? 0.5 : 1)

            // Close button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isVisible = false
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(UIColors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, UISpacing.md)
        .background(UIColors.elevated)
    }

    // MARK: - Arrangement Lane

    private var arrangementLane: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: entrySpacing) {
                if store.project.songArrangement.isEmpty {
                    emptyState
                } else {
                    ForEach(Array(store.project.songArrangement.enumerated()), id: \.element.id) { index, entry in
                        SongEntryCell(
                            store: store,
                            entry: entry,
                            index: index,
                            isPlaying: store.isSongMode && store.currentSongPosition == index
                        )
                        .frame(width: entryWidth)
                    }
                }

                // Add pattern buttons
                patternPicker
            }
            .padding(.horizontal, UISpacing.md)
            .padding(.vertical, UISpacing.sm)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: UISpacing.xs) {
            Image(systemName: "music.note.list")
                .font(.system(size: 20))
                .foregroundStyle(UIColors.textSecondary)
            Text("No arrangement")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(UIColors.textSecondary)
            Text("Add patterns to create a song")
                .font(.system(size: 9))
                .foregroundStyle(UIColors.textDisabled)
        }
        .frame(width: 120)
    }

    // MARK: - Pattern Picker

    private var patternPicker: some View {
        VStack(spacing: UISpacing.xs) {
            Text("ADD")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(UIColors.textSecondary)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(Array(store.project.patterns.enumerated()), id: \.element.id) { index, pattern in
                        Button {
                            store.addPatternToSong(index)
                        } label: {
                            Text("\(index + 1)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(UIColors.textPrimary)
                                .frame(width: 28, height: 22)
                                .background(patternColor(for: index).opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(patternColor(for: index), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(width: 36)
        .padding(.vertical, UISpacing.xs)
        .background(UIColors.elevated.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func patternColor(for index: Int) -> Color {
        let colors: [Color] = [
            UIColors.accentCyan,
            UIColors.accentMagenta,
            UIColors.accentGreen,
            UIColors.accentOrange,
            UIColors.accentYellow
        ]
        return colors[index % colors.count]
    }
}

// MARK: - Song Entry Cell

struct SongEntryCell: View {
    @Bindable var store: AppStore
    let entry: SongArrangementEntry
    let index: Int
    let isPlaying: Bool

    private var pattern: Pattern? {
        guard entry.patternIndex < store.project.patterns.count else { return nil }
        return store.project.patterns[entry.patternIndex]
    }

    private var patternColor: Color {
        let colors: [Color] = [
            UIColors.accentCyan,
            UIColors.accentMagenta,
            UIColors.accentGreen,
            UIColors.accentOrange,
            UIColors.accentYellow
        ]
        return colors[entry.patternIndex % colors.count]
    }

    var body: some View {
        VStack(spacing: 4) {
            // Pattern preview (mini grid)
            patternPreview
                .frame(height: 40)

            // Pattern number
            Text("P\(entry.patternIndex + 1)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(patternColor)

            // Repeat count stepper
            HStack(spacing: 2) {
                Button {
                    if entry.repeatCount > 1 {
                        store.setSongEntryRepeatCount(at: index, count: entry.repeatCount - 1)
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(UIColors.textSecondary)
                }
                .buttonStyle(.plain)

                Text("x\(entry.repeatCount)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(UIColors.textPrimary)
                    .frame(width: 24)

                Button {
                    store.setSongEntryRepeatCount(at: index, count: entry.repeatCount + 1)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(UIColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, UISpacing.xs)
        .padding(.horizontal, UISpacing.xs)
        .background(isPlaying ? patternColor.opacity(0.2) : UIColors.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isPlaying ? patternColor : UIColors.border, lineWidth: isPlaying ? 2 : 1)
        )
        .contextMenu {
            Button(role: .destructive) {
                store.removeSongEntry(at: index)
            } label: {
                Label("Remove", systemImage: "trash")
            }

            Button {
                store.jumpToSongPosition(index)
            } label: {
                Label("Jump Here", systemImage: "arrow.right.circle")
            }
        }
        .onTapGesture {
            // Jump to this position
            store.jumpToSongPosition(index)
        }
    }

    // MARK: - Pattern Preview

    private var patternPreview: some View {
        GeometryReader { geometry in
            let stepCount = pattern?.defaultStepCount ?? 16
            let gridCols = min(stepCount, 16)
            let cellSize = (geometry.size.width - 4) / CGFloat(gridCols)

            VStack(spacing: 1) {
                // Show first 4 tracks (kick, snare, closed hat, clap)
                ForEach([DrumVoiceType.kick, .snare, .closedHat, .clap], id: \.self) { voiceType in
                    HStack(spacing: 1) {
                        ForEach(0..<gridCols, id: \.self) { stepIndex in
                            let step = pattern?.step(voice: voiceType, stepIndex: stepIndex)
                            RoundedRectangle(cornerRadius: 1)
                                .fill(step?.isActive == true ? voiceType.color.opacity(0.8) : UIColors.background)
                                .frame(width: cellSize - 1, height: (geometry.size.height - 6) / 4)
                        }
                    }
                }
            }
            .padding(2)
        }
        .background(UIColors.background)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        UISongArrangementEditor(
            store: AppStore(project: .demo()),
            isVisible: .constant(true)
        )
        .frame(height: 120)
    }
    .background(UIColors.background)
}
