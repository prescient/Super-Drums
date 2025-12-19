import SwiftUI

/// Main content view with tab-based navigation.
struct ContentView: View {
    @State private var store = AppStore(project: .demo())

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Pattern bank panel (slides down from top)
                if store.showPatternBank {
                    UIPatternBank(
                        store: store,
                        isVisible: $store.showPatternBank
                    )
                    .transition(.move(edge: .top))
                }

                // Main content area
                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Tab bar
                UITabBar(selectedTab: $store.selectedTab)
            }
            .animation(.easeInOut(duration: 0.2), value: store.showPatternBank)
        }
        .background(UIColors.background)
        .preferredColorScheme(.dark)
        .onAppear {
            store.startAudioEngine()
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch store.selectedTab {
        case .sequencer:
            UISequencerView(store: store)
                .transition(.opacity)

        case .mixer:
            UIMixerView(store: store)
                .transition(.opacity)

        case .sound:
            UISoundDesignView(store: store)
                .transition(.opacity)

        case .perform:
            UIPerformanceView(store: store)
                .transition(.opacity)

        case .settings:
            UISettingsView(store: store)
                .transition(.opacity)
        }
    }
}

// MARK: - AUv3 Content View

/// Content view variant for AUv3 plugin context.
/// Adapts to smaller window sizes and removes some standalone-only features.
struct AUv3ContentView: View {
    @Bindable var store: AppStore

    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.height < 500

            VStack(spacing: 0) {
                // Pattern bank panel (slides down from top)
                if store.showPatternBank {
                    UIPatternBank(
                        store: store,
                        isVisible: $store.showPatternBank
                    )
                    .transition(.move(edge: .top))
                }

                // Compact mode shows simplified transport
                if isCompact {
                    compactTransport
                }

                // Main content
                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Tab bar (always shown)
                UITabBar(selectedTab: $store.selectedTab)
            }
            .animation(.easeInOut(duration: 0.2), value: store.showPatternBank)
        }
        .background(UIColors.background)
        .preferredColorScheme(.dark)
        .onAppear {
            store.startAudioEngine()
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch store.selectedTab {
        case .sequencer:
            UISequencerView(store: store)

        case .mixer:
            UIMixerView(store: store)

        case .sound:
            UISoundDesignView(store: store)

        case .perform:
            UIPerformanceView(store: store)

        case .settings:
            UISettingsView(store: store)
        }
    }

    private var compactTransport: some View {
        HStack(spacing: UISpacing.md) {
            // Play/Stop
            Button {
                store.togglePlayback()
            } label: {
                Image(systemName: store.isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(store.isPlaying ? UIColors.accentGreen : UIColors.textPrimary)
            }
            .buttonStyle(.plain)
            .hoverEffect()

            // BPM
            Text(String(format: "%.0f BPM", store.bpm))
                .valueStyle()

            Spacer()

            // Pattern indicator
            Text("P\(store.project.currentPatternIndex + 1)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(UIColors.accentCyan)
        }
        .padding(.horizontal, UISpacing.md)
        .padding(.vertical, UISpacing.sm)
        .background(UIColors.surface)
    }
}

// MARK: - Preview

#Preview("Standalone") {
    ContentView()
}

#Preview("AUv3 - Large") {
    AUv3ContentView(store: AppStore(project: .demo()))
        .frame(width: 800, height: 600)
}

#Preview("AUv3 - Compact") {
    AUv3ContentView(store: AppStore(project: .demo()))
        .frame(width: 600, height: 400)
}
