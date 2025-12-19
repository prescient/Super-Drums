import Foundation

/// Synthesis parameters for a single drum voice.
/// Uses struct for thread safety when passing to audio engine.
struct Voice: Identifiable, Codable, Equatable {
    let id: UUID
    var voiceType: DrumVoiceType

    // MARK: - Oscillator Parameters

    /// Base frequency/pitch (0.0 - 1.0, mapped to voice-appropriate range)
    var pitch: Float = 0.5

    /// Pitch envelope amount (-1.0 to 1.0)
    var pitchEnvelopeAmount: Float = 0.0

    /// Pitch envelope decay time (0.0 - 1.0)
    var pitchEnvelopeDecay: Float = 0.3

    /// Tone/noise mix for voices that support it (0.0 = tone, 1.0 = noise)
    var toneMix: Float = 0.5

    // MARK: - Filter Parameters

    /// Filter type (lowpass, highpass)
    var filterType: FilterType = .lowpass

    /// Filter cutoff frequency (0.0 - 1.0)
    var filterCutoff: Float = 1.0

    /// Filter resonance (0.0 - 1.0)
    var filterResonance: Float = 0.0

    /// Filter envelope amount (-1.0 to 1.0)
    var filterEnvelopeAmount: Float = 0.0

    // MARK: - Amp Envelope (ADSR)

    /// Attack time (0.0 - 1.0, typically short for drums)
    var attack: Float = 0.001

    /// Decay time (0.0 - 1.0)
    var decay: Float = 0.5

    /// Sustain level (0.0 - 1.0)
    var sustain: Float = 0.0

    /// Release time (0.0 - 1.0)
    var release: Float = 0.1

    /// Hold time before decay starts (0.0 - 1.0)
    var hold: Float = 0.0

    // MARK: - Effects

    /// Drive/overdrive amount (0.0 - 1.0)
    var drive: Float = 0.0

    /// Bitcrusher amount (0.0 - 1.0)
    var bitcrush: Float = 0.0

    // MARK: - Output

    /// Voice volume (0.0 - 1.0)
    var volume: Float = 0.8

    /// Pan position (-1.0 = left, 0.0 = center, 1.0 = right)
    var pan: Float = 0.0

    /// Send to reverb (0.0 - 1.0)
    var reverbSend: Float = 0.0

    /// Send to delay (0.0 - 1.0)
    var delaySend: Float = 0.0

    /// Mute state
    var isMuted: Bool = false

    /// Solo state
    var isSoloed: Bool = false

    // MARK: - Initialization

    init(voiceType: DrumVoiceType) {
        self.id = UUID()
        self.voiceType = voiceType
        applyDefaultsForVoiceType()
    }

    /// Applies sensible defaults based on voice type
    mutating func applyDefaultsForVoiceType() {
        switch voiceType {
        case .kick:
            // Deep, punchy kick with pitch sweep
            pitch = 0.3
            pitchEnvelopeAmount = 0.8
            pitchEnvelopeDecay = 0.15
            toneMix = 0.0
            filterType = .lowpass
            filterCutoff = 0.7
            filterResonance = 0.1
            filterEnvelopeAmount = 0.0
            attack = 0.001
            hold = 0.0
            decay = 0.5
            sustain = 0.0
            release = 0.05
            drive = 0.1
            bitcrush = 0.0

        case .snare:
            // Snappy snare with noise and tone blend
            pitch = 0.5
            pitchEnvelopeAmount = 0.3
            pitchEnvelopeDecay = 0.08
            toneMix = 0.5
            filterType = .lowpass
            filterCutoff = 0.85
            filterResonance = 0.0
            filterEnvelopeAmount = 0.2
            attack = 0.001
            hold = 0.0
            decay = 0.35
            sustain = 0.0
            release = 0.05
            drive = 0.15
            bitcrush = 0.0

        case .closedHat:
            // Tight, crisp closed hi-hat
            pitch = 0.7
            pitchEnvelopeAmount = 0.0
            pitchEnvelopeDecay = 0.05
            toneMix = 0.95
            filterType = .highpass
            filterCutoff = 0.6
            filterResonance = 0.15
            filterEnvelopeAmount = 0.0
            attack = 0.001
            hold = 0.0
            decay = 0.15
            sustain = 0.0
            release = 0.02
            drive = 0.0
            bitcrush = 0.0

        case .openHat:
            // Sustained open hi-hat with shimmer
            pitch = 0.7
            pitchEnvelopeAmount = 0.0
            pitchEnvelopeDecay = 0.05
            toneMix = 0.95
            filterType = .highpass
            filterCutoff = 0.55
            filterResonance = 0.2
            filterEnvelopeAmount = 0.0
            attack = 0.001
            hold = 0.0
            decay = 0.55
            sustain = 0.0
            release = 0.1
            drive = 0.0
            bitcrush = 0.0

        case .clap:
            // Layered clap with noise burst
            pitch = 0.6
            pitchEnvelopeAmount = 0.0
            pitchEnvelopeDecay = 0.05
            toneMix = 0.85
            filterType = .bandpass
            filterCutoff = 0.65
            filterResonance = 0.25
            filterEnvelopeAmount = 0.15
            attack = 0.005
            hold = 0.0
            decay = 0.3
            sustain = 0.0
            release = 0.08
            drive = 0.1
            bitcrush = 0.0

        case .cowbell:
            // Metallic cowbell with dual tones
            pitch = 0.65
            pitchEnvelopeAmount = 0.05
            pitchEnvelopeDecay = 0.02
            toneMix = 0.1
            filterType = .bandpass
            filterCutoff = 0.75
            filterResonance = 0.35
            filterEnvelopeAmount = 0.0
            attack = 0.001
            hold = 0.0
            decay = 0.45
            sustain = 0.0
            release = 0.1
            drive = 0.2
            bitcrush = 0.0

        case .cymbal:
            // Long, shimmering crash cymbal
            pitch = 0.8
            pitchEnvelopeAmount = 0.0
            pitchEnvelopeDecay = 0.05
            toneMix = 0.98
            filterType = .highpass
            filterCutoff = 0.5
            filterResonance = 0.1
            filterEnvelopeAmount = -0.15
            attack = 0.005
            hold = 0.0
            decay = 0.75
            sustain = 0.0
            release = 0.2
            drive = 0.0
            bitcrush = 0.0

        case .conga:
            // Warm, resonant conga with pitch sweep
            pitch = 0.45
            pitchEnvelopeAmount = 0.4
            pitchEnvelopeDecay = 0.06
            toneMix = 0.0
            filterType = .lowpass
            filterCutoff = 0.8
            filterResonance = 0.2
            filterEnvelopeAmount = 0.1
            attack = 0.001
            hold = 0.0
            decay = 0.4
            sustain = 0.0
            release = 0.05
            drive = 0.05
            bitcrush = 0.0

        case .maracas:
            // Short, bright shaker sound
            pitch = 0.9
            pitchEnvelopeAmount = 0.0
            pitchEnvelopeDecay = 0.02
            toneMix = 1.0
            filterType = .highpass
            filterCutoff = 0.7
            filterResonance = 0.0
            filterEnvelopeAmount = 0.0
            attack = 0.001
            hold = 0.0
            decay = 0.1
            sustain = 0.0
            release = 0.02
            drive = 0.0
            bitcrush = 0.0

        case .tom:
            // Deep tom with pitch envelope
            pitch = 0.4
            pitchEnvelopeAmount = 0.5
            pitchEnvelopeDecay = 0.1
            toneMix = 0.0
            filterType = .lowpass
            filterCutoff = 0.75
            filterResonance = 0.15
            filterEnvelopeAmount = 0.1
            attack = 0.001
            hold = 0.0
            decay = 0.5
            sustain = 0.0
            release = 0.08
            drive = 0.1
            bitcrush = 0.0
        }
    }
}

// MARK: - Filter Type

enum FilterType: String, Codable, CaseIterable {
    case lowpass
    case highpass
    case bandpass

    var displayName: String {
        switch self {
        case .lowpass: return "LP"
        case .highpass: return "HP"
        case .bandpass: return "BP"
        }
    }

    /// Integer value for DSP (0=LP, 1=HP, 2=BP)
    var ordinal: Int {
        switch self {
        case .lowpass: return 0
        case .highpass: return 1
        case .bandpass: return 2
        }
    }
}
