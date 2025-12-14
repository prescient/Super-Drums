import Foundation

/// Represents a single step in a sequencer pattern.
/// Uses struct for thread safety.
struct Step: Identifiable, Codable, Equatable {
    let id: UUID

    /// Whether the step is active (will trigger)
    var isActive: Bool = false

    /// Velocity (0-127, MIDI standard)
    var velocity: UInt8 = 100

    /// Micro-timing nudge (-0.5 to +0.5, as fraction of step length)
    var nudge: Float = 0.0

    /// Probability of triggering (0.0 - 1.0)
    var probability: Float = 1.0

    /// Number of retriggers within this step (1 = normal, 2-4 = ratchet)
    var retriggerCount: Int = 1

    /// Parameter locks for this step (parameter ID -> value)
    var parameterLocks: [String: Float] = [:]

    // MARK: - Initialization

    init() {
        self.id = UUID()
    }

    init(isActive: Bool, velocity: UInt8 = 100) {
        self.id = UUID()
        self.isActive = isActive
        self.velocity = velocity
    }

    // MARK: - Computed Properties

    /// Velocity as normalized float (0.0 - 1.0)
    var normalizedVelocity: Float {
        get { Float(velocity) / 127.0 }
        set { velocity = UInt8(max(0, min(127, newValue * 127))) }
    }

    /// Whether this step has any parameter locks
    var hasParameterLocks: Bool {
        !parameterLocks.isEmpty
    }

    /// Whether this step uses ratcheting
    var hasRatchet: Bool {
        retriggerCount > 1
    }

    /// Whether this step has non-default probability
    var hasProbability: Bool {
        probability < 1.0
    }

    /// Whether this step has micro-timing offset
    var hasNudge: Bool {
        abs(nudge) > 0.01
    }
}

// MARK: - Step Array Extension

extension Array where Element == Step {
    /// Creates an array of empty steps
    static func empty(count: Int) -> [Step] {
        (0..<count).map { _ in Step() }
    }

    /// Creates a common pattern (e.g., four-on-the-floor)
    static func fourOnFloor(stepCount: Int = 16) -> [Step] {
        var steps = [Step].empty(count: stepCount)
        for i in stride(from: 0, to: stepCount, by: 4) {
            steps[i].isActive = true
            steps[i].velocity = 127
        }
        return steps
    }

    /// Creates an offbeat pattern
    static func offbeat(stepCount: Int = 16) -> [Step] {
        var steps = [Step].empty(count: stepCount)
        for i in stride(from: 2, to: stepCount, by: 4) {
            steps[i].isActive = true
            steps[i].velocity = 110
        }
        return steps
    }

    /// Creates a hi-hat eighth note pattern
    static func eighthNotes(stepCount: Int = 16) -> [Step] {
        var steps = [Step].empty(count: stepCount)
        for i in stride(from: 0, to: stepCount, by: 2) {
            steps[i].isActive = true
            steps[i].velocity = i % 4 == 0 ? 100 : 80
        }
        return steps
    }
}
