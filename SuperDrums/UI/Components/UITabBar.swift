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
        }
    }
}

// MARK: - Transport Bar

/// Transport controls (play/stop, BPM, etc.)
struct UITransportBar: View {
    @Binding var isPlaying: Bool
    @Binding var bpm: Double
    @Binding var currentStep: Int
    var patternLength: Int = 16

    var body: some View {
        HStack(spacing: UISpacing.lg) {
            // Play/Stop
            Button {
                isPlaying.toggle()
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

            // Pattern selector placeholder
            HStack(spacing: UISpacing.xs) {
                Text("Pattern")
                    .labelStyle()

                Text("01")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(UIColors.accentCyan)
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
            isPlaying: .constant(true),
            bpm: .constant(120.0),
            currentStep: .constant(4)
        )

        UITabBar(selectedTab: .constant(.sequencer))
    }
    .background(UIColors.background)
}
