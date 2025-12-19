import Foundation

/// A reusable drum kit preset containing voice settings and effects.
/// Can be saved/loaded independently of projects for sound design reuse.
struct DrumKit: Identifiable, Codable, Equatable {
    let id: UUID

    /// Kit name
    var name: String

    /// Voice/synthesis settings for all drum voices
    var voices: [Voice]

    /// Master volume (0.0 - 1.0)
    var masterVolume: Float

    /// Reverb mix (0.0 - 1.0)
    var reverbMix: Float

    /// Delay mix (0.0 - 1.0)
    var delayMix: Float

    /// Delay time in beats
    var delayTime: Float

    /// Delay feedback (0.0 - 1.0)
    var delayFeedback: Float

    /// Creation date
    var createdAt: Date

    /// Last modified date
    var modifiedAt: Date

    // MARK: - Initialization

    init(name: String = "New Kit") {
        self.id = UUID()
        self.name = name
        self.voices = DrumVoiceType.allCases.map { Voice(voiceType: $0) }
        self.masterVolume = 0.8
        self.reverbMix = 0.3
        self.delayMix = 0.2
        self.delayTime = 0.5
        self.delayFeedback = 0.4
        self.createdAt = Date()
        self.modifiedAt = Date()
    }

    /// Creates a kit from a project's current sound settings
    init(from project: Project, name: String? = nil) {
        self.id = UUID()
        self.name = name ?? "\(project.name) Kit"
        self.voices = project.voices
        self.masterVolume = project.masterVolume
        self.reverbMix = project.reverbMix
        self.delayMix = project.delayMix
        self.delayTime = project.delayTime
        self.delayFeedback = project.delayFeedback
        self.createdAt = Date()
        self.modifiedAt = Date()
    }

    // MARK: - Voice Access

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
}

// MARK: - Factory Methods

extension DrumKit {
    /// Default 808-style kit
    static func tr808() -> DrumKit {
        var kit = DrumKit(name: "TR-808")
        // Uses default voice settings which are already 808-inspired
        return kit
    }

    /// Tight, punchy electronic kit
    static func electronic() -> DrumKit {
        var kit = DrumKit(name: "Electronic")

        // Modify voices for tighter, more electronic feel
        for i in kit.voices.indices {
            kit.voices[i].decay *= 0.7
            kit.voices[i].drive += 0.1
        }

        kit.reverbMix = 0.15
        kit.delayMix = 0.1
        return kit
    }

    /// Noisy, lo-fi industrial kit
    static func industrial() -> DrumKit {
        var kit = DrumKit(name: "Industrial")

        for i in kit.voices.indices {
            kit.voices[i].bitcrush = 0.3
            kit.voices[i].drive += 0.2
            kit.voices[i].filterResonance += 0.1
        }

        kit.reverbMix = 0.4
        kit.delayMix = 0.3
        kit.delayFeedback = 0.6
        return kit
    }
}
