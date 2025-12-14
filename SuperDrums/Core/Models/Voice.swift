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
            pitch = 0.3
            pitchEnvelopeAmount = 0.8
            pitchEnvelopeDecay = 0.15
            decay = 0.6
            toneMix = 0.0

        case .snare:
            pitch = 0.5
            pitchEnvelopeAmount = 0.3
            pitchEnvelopeDecay = 0.1
            decay = 0.35
            toneMix = 0.5

        case .closedHat:
            pitch = 0.7
            decay = 0.1
            toneMix = 0.9
            filterCutoff = 0.8

        case .openHat:
            pitch = 0.7
            decay = 0.5
            toneMix = 0.9
            filterCutoff = 0.8

        case .clap:
            pitch = 0.6
            decay = 0.25
            toneMix = 0.8

        case .cowbell:
            pitch = 0.65
            decay = 0.4
            toneMix = 0.1

        case .cymbal:
            pitch = 0.8
            decay = 0.7
            toneMix = 0.95
            filterCutoff = 0.9

        case .conga:
            pitch = 0.45
            pitchEnvelopeAmount = 0.4
            pitchEnvelopeDecay = 0.08
            decay = 0.4
            toneMix = 0.0

        case .maracas:
            pitch = 0.9
            decay = 0.08
            toneMix = 1.0
            filterType = .highpass
            filterCutoff = 0.6

        case .tom:
            pitch = 0.4
            pitchEnvelopeAmount = 0.5
            pitchEnvelopeDecay = 0.12
            decay = 0.5
            toneMix = 0.0
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
}
