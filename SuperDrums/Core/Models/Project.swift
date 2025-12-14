import Foundation

/// Represents a complete project with patterns, kit, and global settings.
struct Project: Identifiable, Codable, Equatable {
    let id: UUID

    /// Project name
    var name: String

    /// All patterns in the project (up to 128)
    var patterns: [Pattern]

    /// Currently selected pattern index
    var currentPatternIndex: Int = 0

    /// Voice/kit settings
    var voices: [Voice]

    /// Song arrangement (ordered list of pattern entries with repeat counts)
    var songArrangement: [SongArrangementEntry] = []

    /// Global tempo (BPM)
    var bpm: Double = 120.0

    /// Global swing (0.5 = none, up to 0.75)
    var swing: Float = 0.5

    /// Master volume (0.0 - 1.0)
    var masterVolume: Float = 0.8

    /// Reverb mix (0.0 - 1.0)
    var reverbMix: Float = 0.3

    /// Delay mix (0.0 - 1.0)
    var delayMix: Float = 0.2

    /// Delay time in beats
    var delayTime: Float = 0.5

    /// Delay feedback (0.0 - 1.0)
    var delayFeedback: Float = 0.4

    /// Compressor threshold (dB)
    var compressorThreshold: Float = -10.0

    /// Compressor ratio
    var compressorRatio: Float = 4.0

    /// Creation date
    var createdAt: Date

    /// Last modified date
    var modifiedAt: Date

    // MARK: - Initialization

    init(name: String = "New Project") {
        self.id = UUID()
        self.name = name
        self.patterns = [Pattern(name: "Pattern 1")]
        self.createdAt = Date()
        self.modifiedAt = Date()

        // Initialize default voices
        self.voices = DrumVoiceType.allCases.map { Voice(voiceType: $0) }
    }

    // MARK: - Computed Properties

    /// The currently active pattern
    var currentPattern: Pattern {
        get {
            guard currentPatternIndex < patterns.count else {
                return patterns.first ?? Pattern()
            }
            return patterns[currentPatternIndex]
        }
        set {
            guard currentPatternIndex < patterns.count else { return }
            patterns[currentPatternIndex] = newValue
            modifiedAt = Date()
        }
    }

    /// Total number of patterns
    var patternCount: Int {
        patterns.count
    }

    // MARK: - Pattern Management

    /// Adds a new pattern
    mutating func addPattern(name: String? = nil) {
        let patternNumber = patterns.count + 1
        let newPattern = Pattern(name: name ?? "Pattern \(patternNumber)")
        patterns.append(newPattern)
        modifiedAt = Date()
    }

    /// Duplicates the current pattern
    mutating func duplicateCurrentPattern() {
        let copy = currentPattern.duplicate()
        patterns.insert(copy, at: currentPatternIndex + 1)
        currentPatternIndex += 1
        modifiedAt = Date()
    }

    /// Deletes a pattern at index
    mutating func deletePattern(at index: Int) {
        guard patterns.count > 1, index < patterns.count else { return }
        patterns.remove(at: index)
        if currentPatternIndex >= patterns.count {
            currentPatternIndex = patterns.count - 1
        }
        // Update song arrangement - remove entries referencing deleted pattern
        // and adjust indices for patterns after the deleted one
        songArrangement = songArrangement.compactMap { entry in
            if entry.patternIndex == index { return nil }
            if entry.patternIndex > index {
                var updated = entry
                updated.patternIndex -= 1
                return updated
            }
            return entry
        }
        modifiedAt = Date()
    }

    // MARK: - Voice Management

    /// Gets voice for a specific type
    func voice(for type: DrumVoiceType) -> Voice {
        voices.first { $0.voiceType == type } ?? Voice(voiceType: type)
    }

    /// Updates voice for a specific type
    mutating func setVoice(_ voice: Voice, for type: DrumVoiceType) {
        if let index = voices.firstIndex(where: { $0.voiceType == type }) {
            voices[index] = voice
        }
        modifiedAt = Date()
    }

    // MARK: - Song Mode

    /// Adds pattern to song arrangement with optional repeat count
    mutating func addToSong(patternIndex: Int, repeatCount: Int = 1) {
        guard patternIndex < patterns.count else { return }
        let entry = SongArrangementEntry(patternIndex: patternIndex, repeatCount: repeatCount)
        songArrangement.append(entry)
        modifiedAt = Date()
    }

    /// Clears song arrangement
    mutating func clearSongArrangement() {
        songArrangement = []
        modifiedAt = Date()
    }

    /// Total duration of song in pattern loops
    var songDurationInLoops: Int {
        songArrangement.reduce(0) { $0 + $1.repeatCount }
    }
}

// MARK: - Factory Methods

extension Project {
    /// Creates a demo project with some pre-filled patterns
    static func demo() -> Project {
        var project = Project(name: "Demo Project")

        // Set up a basic beat in pattern 1
        var pattern = project.patterns[0]

        // Kick on 1 and 3
        pattern.toggleStep(voice: .kick, stepIndex: 0)
        pattern.toggleStep(voice: .kick, stepIndex: 8)

        // Snare on 2 and 4
        pattern.toggleStep(voice: .snare, stepIndex: 4)
        pattern.toggleStep(voice: .snare, stepIndex: 12)

        // Closed hat eighth notes
        for i in stride(from: 0, to: 16, by: 2) {
            pattern.toggleStep(voice: .closedHat, stepIndex: i)
        }

        project.patterns[0] = pattern
        return project
    }
}
