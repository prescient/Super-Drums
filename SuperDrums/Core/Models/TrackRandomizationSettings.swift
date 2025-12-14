import Foundation

/// Settings for randomizing a single track's pattern.
struct TrackRandomizationSettings: Codable, Equatable {
    // MARK: - Per-Parameter Randomization Toggles

    /// Whether to randomize step on/off pattern
    var randomizeSteps: Bool = true

    /// Whether to randomize velocity
    var randomizeVelocity: Bool = true

    /// Whether to randomize probability
    var randomizeProbability: Bool = false

    /// Whether to randomize retriggers
    var randomizeRetriggers: Bool = false

    // MARK: - Step Pattern Settings

    /// Probability of each step being active (0.0 - 1.0)
    var density: Float = 0.3

    /// Whether to use Euclidean distribution
    var useEuclidean: Bool = false

    /// Number of hits for Euclidean mode
    var euclideanHits: Int = 4

    /// Whether to preserve existing downbeats (steps 1, 5, 9, 13)
    var preserveDownbeats: Bool = false

    // MARK: - Velocity Settings

    /// Minimum velocity for random steps (0-127)
    var velocityMin: UInt8 = 80

    /// Maximum velocity for random steps (0-127)
    var velocityMax: UInt8 = 127

    // MARK: - Probability Settings

    /// Minimum probability for random steps (0.0 - 1.0)
    var probabilityMin: Float = 0.5

    /// Maximum probability for random steps (0.0 - 1.0)
    var probabilityMax: Float = 1.0

    /// Probability variation per step (0.0 = all 100%, 1.0 = random 0-100%) - legacy, kept for compatibility
    var probabilityVariation: Float = 0.0

    // MARK: - Retrigger Settings

    /// Chance of adding retriggers (0.0 - 1.0)
    var retriggerChance: Float = 0.3

    /// Maximum retrigger count
    var retriggerMax: Int = 4

    /// Whether to add swing/humanization to timing
    var addSwing: Bool = false

    // MARK: - Presets

    static let sparse = TrackRandomizationSettings(
        randomizeSteps: true,
        randomizeVelocity: true,
        density: 0.15,
        velocityMin: 90,
        velocityMax: 120
    )

    static let medium = TrackRandomizationSettings(
        randomizeSteps: true,
        randomizeVelocity: true,
        density: 0.35,
        velocityMin: 80,
        velocityMax: 127
    )

    static let dense = TrackRandomizationSettings(
        randomizeSteps: true,
        randomizeVelocity: true,
        density: 0.6,
        velocityMin: 70,
        velocityMax: 127
    )

    static let euclidean4 = TrackRandomizationSettings(
        randomizeSteps: true,
        randomizeVelocity: true,
        density: 0.25,
        useEuclidean: true,
        euclideanHits: 4
    )

    static let euclidean8 = TrackRandomizationSettings(
        randomizeSteps: true,
        randomizeVelocity: true,
        density: 0.5,
        useEuclidean: true,
        euclideanHits: 8
    )

    /// Velocity only preset - keeps existing pattern
    static let velocityOnly = TrackRandomizationSettings(
        randomizeSteps: false,
        randomizeVelocity: true,
        velocityMin: 60,
        velocityMax: 127
    )

    /// Probability preset - adds variation to existing steps
    static let probabilityVariation = TrackRandomizationSettings(
        randomizeSteps: false,
        randomizeVelocity: false,
        randomizeProbability: true,
        probabilityMin: 0.5,
        probabilityMax: 1.0
    )
}

// MARK: - Euclidean Rhythm Generator

extension TrackRandomizationSettings {
    /// Generates a Euclidean rhythm pattern.
    /// Distributes `hits` evenly across `steps` using Bjorklund's algorithm.
    static func euclideanPattern(hits: Int, steps: Int) -> [Bool] {
        guard hits > 0, steps > 0, hits <= steps else {
            return Array(repeating: false, count: steps)
        }

        if hits == steps {
            return Array(repeating: true, count: steps)
        }

        // Bjorklund's algorithm
        var pattern: [[Bool]] = []

        // Initialize with hits and rests
        for _ in 0..<hits {
            pattern.append([true])
        }
        for _ in 0..<(steps - hits) {
            pattern.append([false])
        }

        // Iteratively distribute
        while true {
            let lastIndex = pattern.count - 1
            var numToDistribute = 0

            // Count trailing groups that are different from leading groups
            for i in stride(from: lastIndex, through: 0, by: -1) {
                if pattern[i] != pattern[0] {
                    numToDistribute += 1
                } else {
                    break
                }
            }

            if numToDistribute <= 1 {
                break
            }

            let numToAppendTo = min(pattern.count - numToDistribute, numToDistribute)

            for i in 0..<numToAppendTo {
                pattern[i].append(contentsOf: pattern[pattern.count - 1])
                pattern.removeLast()
            }
        }

        // Flatten the pattern
        return pattern.flatMap { $0 }
    }
}

// MARK: - Lockable Parameters

/// Parameters that can be locked per-step
enum LockableParameter: String, CaseIterable, Identifiable, Codable {
    // Step parameters (stored directly on Step)
    case velocity
    case probability
    case retrigger

    // Synth parameters (stored in Step.parameterLocks)
    case pitch
    case decay
    case filterCutoff
    case filterResonance
    case drive
    case pan
    case reverbSend
    case delaySend

    var id: String { rawValue }

    /// Whether this parameter is a step parameter (vs synth parameter lock)
    var isStepParameter: Bool {
        switch self {
        case .velocity, .probability, .retrigger:
            return true
        default:
            return false
        }
    }

    var displayName: String {
        switch self {
        case .velocity: return "Velocity"
        case .probability: return "Probability"
        case .retrigger: return "Retrigger"
        case .pitch: return "Pitch"
        case .decay: return "Decay"
        case .filterCutoff: return "Filter"
        case .filterResonance: return "Resonance"
        case .drive: return "Drive"
        case .pan: return "Pan"
        case .reverbSend: return "Reverb"
        case .delaySend: return "Delay"
        }
    }

    var shortName: String {
        switch self {
        case .velocity: return "VEL"
        case .probability: return "PRB"
        case .retrigger: return "RTG"
        case .pitch: return "PIT"
        case .decay: return "DCY"
        case .filterCutoff: return "FLT"
        case .filterResonance: return "RES"
        case .drive: return "DRV"
        case .pan: return "PAN"
        case .reverbSend: return "REV"
        case .delaySend: return "DLY"
        }
    }
}
