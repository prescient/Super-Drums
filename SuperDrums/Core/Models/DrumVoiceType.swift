import SwiftUI

/// Represents the 10 drum voice types available in the synthesizer.
enum DrumVoiceType: Int, CaseIterable, Identifiable, Codable {
    case kick = 0
    case snare
    case closedHat
    case openHat
    case clap
    case cowbell
    case cymbal
    case conga
    case maracas
    case tom

    var id: Int { rawValue }

    /// Display name for the voice
    var displayName: String {
        switch self {
        case .kick: return "Kick"
        case .snare: return "Snare"
        case .closedHat: return "CH"
        case .openHat: return "OH"
        case .clap: return "Clap"
        case .cowbell: return "Cowbell"
        case .cymbal: return "Cymbal"
        case .conga: return "Conga"
        case .maracas: return "Maracas"
        case .tom: return "Tom"
        }
    }

    /// Full name for the voice
    var fullName: String {
        switch self {
        case .kick: return "Kick Drum"
        case .snare: return "Snare Drum"
        case .closedHat: return "Closed Hi-Hat"
        case .openHat: return "Open Hi-Hat"
        case .clap: return "Hand Clap"
        case .cowbell: return "Cowbell"
        case .cymbal: return "Crash Cymbal"
        case .conga: return "Conga"
        case .maracas: return "Maracas"
        case .tom: return "Tom / Perc"
        }
    }

    /// Short abbreviation (2-3 chars)
    var abbreviation: String {
        switch self {
        case .kick: return "KK"
        case .snare: return "SN"
        case .closedHat: return "CH"
        case .openHat: return "OH"
        case .clap: return "CP"
        case .cowbell: return "CB"
        case .cymbal: return "CY"
        case .conga: return "CG"
        case .maracas: return "MA"
        case .tom: return "TM"
        }
    }

    /// Associated color for this voice
    var color: Color {
        UIColors.voiceColors[rawValue]
    }

    /// MIDI note number (General MIDI drum map)
    var midiNote: UInt8 {
        switch self {
        case .kick: return 36      // C1 - Bass Drum 1
        case .snare: return 38     // D1 - Acoustic Snare
        case .closedHat: return 42 // F#1 - Closed Hi-Hat
        case .openHat: return 46   // A#1 - Open Hi-Hat
        case .clap: return 39      // D#1 - Hand Clap
        case .cowbell: return 56   // G#2 - Cowbell
        case .cymbal: return 49    // C#2 - Crash Cymbal 1
        case .conga: return 63     // D#3 - Open Hi Conga
        case .maracas: return 70   // A#3 - Maracas
        case .tom: return 45       // A1 - Low Tom
        }
    }

    /// Returns the voice that this voice chokes (if any)
    var chokesVoice: DrumVoiceType? {
        switch self {
        case .openHat: return .closedHat
        default: return nil
        }
    }
}
