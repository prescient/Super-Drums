import SwiftUI

/// Slide-out panel below the sequencer for editing parameter locks per step.
/// Shows vertical bars for each step that can be dragged to set parameter values.
struct UIParameterLockEditor: View {
    @Bindable var store: AppStore
    @Binding var isVisible: Bool

    /// Currently selected parameter to edit
    @State private var selectedParameter: LockableParameter = .pitch

    /// Height of the editor panel
    private let panelHeight: CGFloat = 140

    private var voiceType: DrumVoiceType {
        store.selectedVoiceType
    }

    private var track: Track {
        store.currentPattern.track(for: voiceType)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with parameter selector
            header

            // Step bars
            stepBarsView
        }
        .frame(height: panelHeight)
        .background(UIColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 10, y: -5)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: UISpacing.md) {
            // Voice indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(voiceType.color)
                .frame(width: 4, height: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text("Parameter Locks")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(UIColors.textPrimary)

                Text(voiceType.abbreviation)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(UIColors.textSecondary)
            }

            Spacer()

            // Parameter selector
            parameterPicker

            // Clear all locks button
            Button {
                store.clearParameterLocks(for: voiceType, parameter: selectedParameter)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(UIColors.textSecondary)
            }
            .buttonStyle(.plain)

            // Close button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isVisible = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(UIColors.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(UIColors.elevated)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, UISpacing.md)
        .padding(.vertical, UISpacing.sm)
        .background(UIColors.elevated)
    }

    // MARK: - Parameter Picker

    private var parameterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: UISpacing.xs) {
                ForEach(LockableParameter.allCases) { param in
                    Button {
                        selectedParameter = param
                    } label: {
                        Text(param.shortName)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(
                                selectedParameter == param
                                    ? UIColors.textPrimary
                                    : UIColors.textSecondary
                            )
                            .padding(.horizontal, UISpacing.sm)
                            .padding(.vertical, 4)
                            .background(
                                selectedParameter == param
                                    ? parameterColor(param).opacity(0.3)
                                    : UIColors.surface
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(
                                        selectedParameter == param
                                            ? parameterColor(param)
                                            : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Step Bars

    private var stepBarsView: some View {
        GeometryReader { geometry in
            let stepCount = track.stepCount
            let spacing: CGFloat = 3
            let barWidth = (geometry.size.width - CGFloat(stepCount - 1) * spacing - UISpacing.md * 2) / CGFloat(stepCount)
            let barHeight = geometry.size.height - UISpacing.md * 2

            HStack(spacing: spacing) {
                ForEach(0..<stepCount, id: \.self) { stepIndex in
                    ParameterLockBar(
                        step: track.steps[stepIndex],
                        stepIndex: stepIndex,
                        parameter: selectedParameter,
                        barWidth: barWidth,
                        barHeight: barHeight,
                        color: parameterColor(selectedParameter),
                        voiceColor: voiceType.color,
                        onValueChange: { newValue in
                            store.setParameterLock(
                                for: voiceType,
                                stepIndex: stepIndex,
                                parameter: selectedParameter,
                                value: newValue
                            )
                        },
                        onClear: {
                            store.clearParameterLock(
                                for: voiceType,
                                stepIndex: stepIndex,
                                parameter: selectedParameter
                            )
                        }
                    )
                }
            }
            .padding(.horizontal, UISpacing.md)
            .padding(.vertical, UISpacing.md)
        }
    }

    // MARK: - Helpers

    private func parameterColor(_ param: LockableParameter) -> Color {
        switch param {
        case .velocity: return UIColors.accentGreen
        case .probability: return UIColors.accentYellow
        case .retrigger: return UIColors.accentMagenta
        case .pitch: return UIColors.accentCyan
        case .decay: return UIColors.accentOrange
        case .filterCutoff: return UIColors.accentMagenta
        case .filterResonance: return UIColors.accentMagenta.opacity(0.7)
        case .drive: return UIColors.accentYellow
        case .pan: return UIColors.accentGreen
        case .reverbSend: return UIColors.accentCyan.opacity(0.7)
        case .delaySend: return UIColors.accentOrange.opacity(0.7)
        }
    }
}

// MARK: - Parameter Lock Bar

/// Individual vertical bar for setting a parameter lock value.
struct ParameterLockBar: View {
    let step: Step
    let stepIndex: Int
    let parameter: LockableParameter
    let barWidth: CGFloat
    let barHeight: CGFloat
    let color: Color
    let voiceColor: Color
    let onValueChange: (Float) -> Void
    let onClear: () -> Void

    @State private var isDragging = false

    /// Current value for this parameter (handles both step params and p-locks)
    private var currentValue: Float {
        switch parameter {
        case .velocity:
            return step.normalizedVelocity
        case .probability:
            return step.probability
        case .retrigger:
            // Map 1-4 retriggers to 0-1 range
            return Float(step.retriggerCount - 1) / 3.0
        default:
            return step.parameterLocks[parameter.rawValue] ?? 0.5
        }
    }

    /// Whether this step has a value set (for step params, always true if active)
    private var hasLock: Bool {
        if parameter.isStepParameter {
            return step.isActive
        }
        return step.parameterLocks[parameter.rawValue] != nil
    }

    /// Display value (0-1)
    private var displayValue: Float {
        currentValue
    }

    /// Format the display value for the current parameter
    private var formattedValue: String {
        switch parameter {
        case .velocity:
            return "\(Int(currentValue * 127))"
        case .probability:
            return "\(Int(currentValue * 100))%"
        case .retrigger:
            return "\(step.retriggerCount)x"
        default:
            return String(format: "%.0f%%", currentValue * 100)
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            // Step number
            Text("\(stepIndex + 1)")
                .font(.system(size: 7, weight: stepIndex % 4 == 0 ? .bold : .regular, design: .monospaced))
                .foregroundStyle(stepIndex % 4 == 0 ? UIColors.textPrimary : UIColors.textSecondary)

            // Bar container
            ZStack(alignment: .bottom) {
                // Background
                RoundedRectangle(cornerRadius: 3)
                    .fill(step.isActive ? UIColors.elevated : UIColors.surface.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(
                                step.isActive
                                    ? (hasLock ? color.opacity(0.6) : UIColors.border)
                                    : UIColors.border.opacity(0.3),
                                lineWidth: 1
                            )
                    )

                // Value fill (only if locked)
                if hasLock {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(isDragging ? 0.8 : 0.6))
                        .frame(height: CGFloat(displayValue) * (barHeight - 20))
                        .padding(2)
                }

                // Center line indicator (when no lock)
                if !hasLock && step.isActive {
                    Rectangle()
                        .fill(UIColors.border)
                        .frame(height: 1)
                        .offset(y: -(barHeight - 20) / 2 + 10)
                }
            }
            .frame(width: barWidth, height: barHeight - 20)
            .opacity(step.isActive ? 1.0 : 0.3)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        guard step.isActive else { return }
                        isDragging = true

                        // Calculate value from drag position (inverted Y)
                        let availableHeight = barHeight - 20
                        let yPosition = gesture.location.y
                        let normalizedValue = 1.0 - Float(max(0, min(yPosition, availableHeight))) / Float(availableHeight)
                        onValueChange(max(0, min(1, normalizedValue)))
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .onTapGesture(count: 2) {
                // Double tap to clear lock
                if hasLock {
                    onClear()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        UIParameterLockEditor(
            store: AppStore(project: .demo()),
            isVisible: .constant(true)
        )
    }
    .background(UIColors.background)
}
