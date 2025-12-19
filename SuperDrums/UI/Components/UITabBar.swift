import SwiftUI

/// Custom tab bar for main navigation.
struct UITabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                UITabBarItem(
                    tab: tab,
                    isSelected: selectedTab == tab
                ) {
                    selectedTab = tab
                }
            }
        }
        .frame(height: UISizes.tabBarHeight)
        .background(UIColors.surface)
        .overlay(
            Rectangle()
                .fill(UIColors.border)
                .frame(height: 1),
            alignment: .top
        )
    }
}

// MARK: - Tab Bar Item

struct UITabBarItem: View {
    let tab: AppTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: UISpacing.xs) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? UIColors.accentCyan : UIColors.textSecondary)
                    .neonGlow(color: UIColors.accentCyan, radius: 6, isActive: isSelected)

                Text(tab.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? UIColors.textPrimary : UIColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, UISpacing.sm)
            .background(
                isSelected
                    ? UIColors.accentCyan.opacity(0.1)
                    : Color.clear
            )
            .overlay(
                Rectangle()
                    .fill(isSelected ? UIColors.accentCyan : Color.clear)
                    .frame(height: 2),
                alignment: .top
            )
        }
        .buttonStyle(.plain)
        .hoverEffect()
        .keyboardShortcut(keyboardShortcut, modifiers: .command)
    }

    private var keyboardShortcut: KeyEquivalent {
        switch tab {
        case .sequencer: return "1"
        case .mixer: return "2"
        case .sound: return "3"
        case .perform: return "4"
        case .settings: return "5"
        }
    }
}

// MARK: - Transport Bar

/// Transport controls (play/stop, BPM, etc.)
struct UITransportBar: View {
    var isPlaying: Bool
    @Binding var bpm: Double
    var currentStep: Int
    var patternLength: Int = 16
    var onPlayToggle: () -> Void

    // Pattern navigation
    var currentPatternIndex: Int = 0
    var patternCount: Int = 1
    var patternName: String = "Pattern 1"
    var onPreviousPattern: (() -> Void)?
    var onNextPattern: (() -> Void)?
    var onAddPattern: (() -> Void)?
    var onSelectPattern: ((Int) -> Void)?

    // Pattern bank toggle
    @Binding var showPatternBank: Bool

    var body: some View {
        HStack(spacing: UISpacing.lg) {
            // Play/Stop
            Button {
                onPlayToggle()
            } label: {
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(isPlaying ? UIColors.accentGreen : UIColors.textPrimary)
                    .frame(width: 48, height: 48)
                    .background(UIColors.elevated)
                    .clipShape(Circle())
                    .neonGlow(color: UIColors.accentGreen, radius: 6, isActive: isPlaying)
            }
            .buttonStyle(.plain)
            .hoverEffect()
            .keyboardShortcut(.space, modifiers: [])

            // BPM
            HStack(spacing: UISpacing.xs) {
                Text("BPM")
                    .labelStyle()

                Text(String(format: "%.1f", bpm))
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(UIColors.textPrimary)
                    .frame(width: 70)

                Stepper("", value: $bpm, in: 30...300, step: 1)
                    .labelsHidden()
            }
            .padding(.horizontal, UISpacing.md)
            .padding(.vertical, UISpacing.sm)
            .background(UIColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Step indicator
            HStack(spacing: UISpacing.xxs) {
                ForEach(0..<patternLength, id: \.self) { step in
                    Circle()
                        .fill(step == currentStep ? UIColors.accentGreen : UIColors.border)
                        .frame(width: step % 4 == 0 ? 8 : 6, height: step % 4 == 0 ? 8 : 6)
                }
            }
            .padding(.horizontal, UISpacing.md)
            .padding(.vertical, UISpacing.sm)
            .background(UIColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer()

            // Pattern bank toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showPatternBank.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.grid.4x3.fill")
                        .font(.system(size: 14, weight: .medium))
                    Text("BANK")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(showPatternBank ? UIColors.accentMagenta : UIColors.textSecondary)
                .padding(.horizontal, UISpacing.md)
                .padding(.vertical, UISpacing.sm)
                .background(showPatternBank ? UIColors.accentMagenta.opacity(0.15) : UIColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(showPatternBank ? UIColors.accentMagenta : UIColors.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .neonGlow(color: UIColors.accentMagenta, radius: 4, isActive: showPatternBank)

            // Pattern selector
            HStack(spacing: UISpacing.xs) {
                // Previous pattern
                Button {
                    onPreviousPattern?()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(currentPatternIndex > 0 ? UIColors.textPrimary : UIColors.textSecondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .disabled(currentPatternIndex <= 0)

                // Pattern number and name
                Menu {
                    ForEach(0..<patternCount, id: \.self) { index in
                        Button {
                            onSelectPattern?(index)
                        } label: {
                            HStack {
                                Text(String(format: "%02d", index + 1))
                                if index == currentPatternIndex {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }

                    Divider()

                    Button {
                        onAddPattern?()
                    } label: {
                        Label("Add Pattern", systemImage: "plus")
                    }
                } label: {
                    HStack(spacing: UISpacing.xs) {
                        Text(String(format: "%02d", currentPatternIndex + 1))
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundStyle(UIColors.accentCyan)

                        Text("/")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(UIColors.textSecondary)

                        Text(String(format: "%02d", patternCount))
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(UIColors.textSecondary)
                    }
                }
                .buttonStyle(.plain)

                // Next pattern
                Button {
                    onNextPattern?()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(currentPatternIndex < patternCount - 1 ? UIColors.textPrimary : UIColors.textSecondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .disabled(currentPatternIndex >= patternCount - 1)

                // Add pattern button
                Button {
                    onAddPattern?()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(UIColors.accentGreen)
                        .frame(width: 24, height: 24)
                        .background(UIColors.elevated)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, UISpacing.md)
            .padding(.vertical, UISpacing.sm)
            .background(UIColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, UISpacing.lg)
        .padding(.vertical, UISpacing.md)
        .background(UIColors.background)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        Spacer()

        UITransportBar(
            isPlaying: true,
            bpm: .constant(120.0),
            currentStep: 4,
            onPlayToggle: {},
            showPatternBank: .constant(false)
        )

        UITabBar(selectedTab: .constant(.sequencer))
    }
    .background(UIColors.background)
}
