import SwiftUI

/// Pattern bank showing 32 pattern slots in a grid with copy/paste/clear functionality.
struct UIPatternBank: View {
    @Bindable var store: AppStore
    @Binding var isVisible: Bool

    /// Number of patterns to display
    private let patternCount = 32

    /// Grid layout: 8 columns
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 8)

    /// Pattern slot height
    private let slotHeight: CGFloat = 44

    var body: some View {
        VStack(spacing: UISpacing.sm) {
            // Header
            HStack {
                Text("PATTERN BANK")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(UIColors.textSecondary)

                Spacer()

                // Clipboard indicator
                if store.copiedPattern != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 10))
                        Text("COPIED")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(UIColors.accentGreen)
                }

                // Close button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isVisible = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(UIColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, UISpacing.md)
            .padding(.top, UISpacing.sm)

            // Pattern grid
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<patternCount, id: \.self) { index in
                    PatternSlot(
                        store: store,
                        index: index,
                        isSelected: store.project.currentPatternIndex == index,
                        hasContent: patternHasContent(at: index)
                    )
                    .frame(height: slotHeight)
                }
            }
            .padding(.horizontal, UISpacing.md)
            .padding(.bottom, UISpacing.sm)
        }
        .background(UIColors.surface)
        .overlay(
            Rectangle()
                .fill(UIColors.border)
                .frame(height: 1),
            alignment: .bottom
        )
        .onAppear {
            // Ensure we have 32 patterns
            store.ensurePatternCount(patternCount)
        }
    }

    /// Check if a pattern has any active steps
    private func patternHasContent(at index: Int) -> Bool {
        guard index < store.project.patterns.count else { return false }
        let pattern = store.project.patterns[index]
        for track in pattern.tracks.values {
            for step in track.steps where step.isActive {
                return true
            }
        }
        return false
    }
}

// MARK: - Pattern Slot

/// Individual pattern slot button
struct PatternSlot: View {
    @Bindable var store: AppStore
    let index: Int
    let isSelected: Bool
    let hasContent: Bool

    @State private var showMenu: Bool = false

    var body: some View {
        Button {
            store.selectPattern(index)
        } label: {
            VStack(spacing: 2) {
                // Pattern number
                Text(String(format: "%02d", index + 1))
                    .font(.system(size: 14, weight: isSelected ? .bold : .medium, design: .monospaced))
                    .foregroundStyle(isSelected ? UIColors.accentCyan : (hasContent ? UIColors.textPrimary : UIColors.textSecondary))

                // Content indicator
                if hasContent {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(isSelected ? UIColors.accentCyan : UIColors.accentGreen)
                        .frame(width: 16, height: 3)
                } else {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(UIColors.border)
                        .frame(width: 16, height: 3)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                isSelected
                    ? UIColors.accentCyan.opacity(0.15)
                    : (hasContent ? UIColors.elevated : UIColors.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? UIColors.accentCyan : UIColors.border, lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .neonGlow(color: UIColors.accentCyan, radius: 4, isActive: isSelected)
        }
        .buttonStyle(.plain)
        .contextMenu {
            contextMenuContent
        }
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        // Copy
        Button {
            store.copyPattern(at: index)
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }

        // Paste (only if clipboard has content)
        if store.copiedPattern != nil {
            Button {
                store.pastePattern(to: index)
            } label: {
                Label("Paste", systemImage: "doc.on.clipboard")
            }
        }

        Divider()

        // Clear
        Button(role: .destructive) {
            store.clearPattern(at: index)
        } label: {
            Label("Clear", systemImage: "trash")
        }

        // Duplicate to next empty
        if hasContent {
            Button {
                duplicateToNextEmpty()
            } label: {
                Label("Duplicate to Next Empty", systemImage: "plus.square.on.square")
            }
        }
    }

    /// Duplicates pattern to the next empty slot
    private func duplicateToNextEmpty() {
        store.copyPattern(at: index)
        // Find next empty slot
        for i in (index + 1)..<store.project.patterns.count {
            if !patternHasContent(at: i) {
                store.pastePattern(to: i)
                store.selectPattern(i)
                return
            }
        }
        // Wrap around from beginning
        for i in 0..<index {
            if !patternHasContent(at: i) {
                store.pastePattern(to: i)
                store.selectPattern(i)
                return
            }
        }
    }

    /// Check if pattern at index has content
    private func patternHasContent(at index: Int) -> Bool {
        guard index < store.project.patterns.count else { return false }
        let pattern = store.project.patterns[index]
        for track in pattern.tracks.values {
            for step in track.steps where step.isActive {
                return true
            }
        }
        return false
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        UIPatternBank(
            store: AppStore(project: .demo()),
            isVisible: .constant(true)
        )
        Spacer()
    }
    .background(UIColors.background)
}
