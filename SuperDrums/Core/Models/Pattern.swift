import Foundation

/// A sequencer pattern containing steps for all 10 voices.
struct Pattern: Identifiable, Codable, Equatable {
    let id: UUID

    /// Pattern name
    var name: String

    /// Number of steps in this pattern (default 16, can vary per track in polymetric mode)
    var defaultStepCount: Int = 16

    /// Steps for each voice (voiceType.rawValue -> [Step])
    var tracks: [Int: Track]

    /// Pattern-level swing amount (0.5 = no swing, up to 0.75)
    var swing: Float = 0.5

    /// BPM override (nil = use project BPM)
    var bpmOverride: Double?

    // MARK: - Initialization

    init(name: String = "Pattern", stepCount: Int = 16) {
        self.id = UUID()
        self.name = name
        self.defaultStepCount = stepCount
        self.tracks = [:]

        // Initialize empty tracks for all voices
        for voiceType in DrumVoiceType.allCases {
            tracks[voiceType.rawValue] = Track(voiceType: voiceType, stepCount: stepCount)
        }
    }

    // MARK: - Track Access

    /// Gets the track for a specific voice type
    func track(for voiceType: DrumVoiceType) -> Track {
        tracks[voiceType.rawValue] ?? Track(voiceType: voiceType, stepCount: defaultStepCount)
    }

    /// Updates the track for a specific voice type
    mutating func setTrack(_ track: Track, for voiceType: DrumVoiceType) {
        tracks[voiceType.rawValue] = track
    }

    /// Gets a step at a specific position for a voice
    func step(voice: DrumVoiceType, stepIndex: Int) -> Step? {
        guard let track = tracks[voice.rawValue],
              stepIndex < track.steps.count else { return nil }
        return track.steps[stepIndex]
    }

    /// Toggles a step at a specific position
    mutating func toggleStep(voice: DrumVoiceType, stepIndex: Int) {
        guard var track = tracks[voice.rawValue],
              stepIndex < track.steps.count else { return }
        track.steps[stepIndex].isActive.toggle()
        tracks[voice.rawValue] = track
    }

    /// Sets velocity for a step
    mutating func setStepVelocity(voice: DrumVoiceType, stepIndex: Int, velocity: UInt8) {
        guard var track = tracks[voice.rawValue],
              stepIndex < track.steps.count else { return }
        track.steps[stepIndex].velocity = velocity
        tracks[voice.rawValue] = track
    }

    // MARK: - Pattern Operations

    /// Clears all steps in the pattern
    mutating func clear() {
        for voiceType in DrumVoiceType.allCases {
            if var track = tracks[voiceType.rawValue] {
                track.clear()
                tracks[voiceType.rawValue] = track
            }
        }
    }

    /// Shifts all active steps by an offset
    mutating func shift(by offset: Int) {
        for voiceType in DrumVoiceType.allCases {
            if var track = tracks[voiceType.rawValue] {
                track.shift(by: offset)
                tracks[voiceType.rawValue] = track
            }
        }
    }

    /// Creates a copy with a new ID
    func duplicate(newName: String? = nil) -> Pattern {
        var newPattern = Pattern(name: newName ?? "\(name) Copy", stepCount: defaultStepCount)
        newPattern.tracks = tracks
        newPattern.swing = swing
        newPattern.bpmOverride = bpmOverride
        return newPattern
    }
}

// MARK: - Track

/// A single track within a pattern (one voice's sequence)
struct Track: Identifiable, Codable, Equatable {
    let id: UUID
    var voiceType: DrumVoiceType
    var steps: [Step]

    /// Step count for polymetric mode (can differ from pattern default)
    var stepCount: Int {
        steps.count
    }

    // MARK: - Initialization

    init(voiceType: DrumVoiceType, stepCount: Int = 16) {
        self.id = UUID()
        self.voiceType = voiceType
        self.steps = .empty(count: stepCount)
    }

    // MARK: - Operations

    /// Clears all steps
    mutating func clear() {
        steps = .empty(count: stepCount)
    }

    /// Shifts steps by offset (wraps around). Positive offset moves steps right.
    mutating func shift(by offset: Int) {
        guard stepCount > 0 else { return }
        // Negate offset so positive values shift right (steps move toward higher indices)
        let normalizedOffset = (((-offset) % stepCount) + stepCount) % stepCount
        let rotated = Array(steps.suffix(stepCount - normalizedOffset) + steps.prefix(normalizedOffset))
        steps = rotated
    }

    /// Randomizes the track with given density (0.0 - 1.0)
    mutating func randomize(density: Float = 0.3) {
        for i in 0..<steps.count {
            steps[i].isActive = Float.random(in: 0...1) < density
            if steps[i].isActive {
                steps[i].velocity = UInt8.random(in: 80...127)
            }
        }
    }

    /// Sets the step count (for polymetric mode)
    mutating func setStepCount(_ count: Int) {
        if count > steps.count {
            steps.append(contentsOf: [Step].empty(count: count - steps.count))
        } else if count < steps.count {
            steps = Array(steps.prefix(count))
        }
    }
}
