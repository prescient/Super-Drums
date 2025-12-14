import AVFoundation
import Foundation

/// Audio engine with sample-accurate sequencer clock.
/// Uses AVAudioSourceNode for timing and synthesis.
@Observable
@MainActor
final class DSPEngine {

    // MARK: - Properties

    /// The AVAudioEngine instance
    private var audioEngine: AVAudioEngine?

    /// Source node for sequencer timing and synthesis
    private var sequencerNode: AVAudioSourceNode?

    /// Whether the engine is running
    private(set) var isRunning: Bool = false

    /// Current sample rate
    private(set) var sampleRate: Double = 44100.0

    /// Buffer size
    private(set) var bufferSize: AVAudioFrameCount = 512

    // MARK: - Sequencer State (Atomic for audio thread safety)

    /// Current playback state - shared with audio thread
    private let playbackState = PlaybackState()

    /// Voice synthesizers (one per voice type)
    private var voiceSynths: [DrumVoiceSynth] = []

    /// Callback for step advancement (called on main thread)
    var onStepAdvanced: ((Int) -> Void)?

    /// Callback for voice trigger (for UI feedback)
    var onVoiceTriggered: ((DrumVoiceType, Float) -> Void)?

    // MARK: - Initialization

    init() {
        setupVoiceSynths()
    }

    private func setupVoiceSynths() {
        voiceSynths = DrumVoiceType.allCases.map { DrumVoiceSynth(voiceType: $0) }
    }

    // MARK: - Audio Session

    private func setupAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setPreferredSampleRate(44100)
            try session.setPreferredIOBufferDuration(0.005) // ~5ms latency
            try session.setActive(true)
            sampleRate = session.sampleRate
        } catch {
            print("DSPEngine: Failed to setup audio session: \(error)")
        }
        #else
        sampleRate = 44100.0
        #endif
    }

    // MARK: - Engine Control

    /// Starts the audio engine
    func start() throws {
        guard !isRunning else { return }

        setupAudioSession()

        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

        // Capture self weakly and the synths array for the audio thread
        let state = playbackState
        let synths = voiceSynths
        let sr = sampleRate

        // Create the sequencer source node
        // This runs on the audio render thread and provides sample-accurate timing
        sequencerNode = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            return Self.renderAudio(
                state: state,
                synths: synths,
                sampleRate: sr,
                frameCount: frameCount,
                audioBufferList: audioBufferList,
                onStepAdvanced: { step in
                    DispatchQueue.main.async {
                        self?.onStepAdvanced?(step)
                    }
                },
                onVoiceTriggered: { voiceType, velocity in
                    DispatchQueue.main.async {
                        self?.onVoiceTriggered?(voiceType, velocity)
                    }
                }
            )
        }

        guard let sequencerNode = sequencerNode else { return }

        // Connect nodes
        engine.attach(sequencerNode)
        engine.connect(sequencerNode, to: engine.mainMixerNode, format: format)

        // Prepare and start
        engine.prepare()
        try engine.start()
        isRunning = true

        print("DSPEngine: Started at \(sampleRate) Hz")
    }

    /// Stops the audio engine
    func stop() {
        playbackState.isPlaying = false
        audioEngine?.stop()
        audioEngine = nil
        sequencerNode = nil
        isRunning = false
        print("DSPEngine: Stopped")
    }

    // MARK: - Transport Control

    /// Start sequencer playback
    func startPlayback(bpm: Double, stepCount: Int) {
        playbackState.bpm = bpm
        playbackState.stepCount = stepCount
        playbackState.currentStep = 0
        playbackState.samplePosition = 0
        playbackState.isPlaying = true
    }

    /// Stop sequencer playback
    func stopPlayback() {
        playbackState.isPlaying = false
        playbackState.currentStep = 0
        playbackState.samplePosition = 0
    }

    /// Update BPM during playback
    func setBPM(_ bpm: Double) {
        playbackState.bpm = bpm
    }

    /// Set swing amount (0.5 = none, up to 0.75)
    func setSwing(_ swing: Float) {
        playbackState.swing = swing
    }

    // MARK: - Pattern Data

    /// Updates the current pattern data for playback
    /// Must be called whenever the pattern changes
    func updatePattern(_ pattern: Pattern, voices: [Voice]) {
        var stepData: [[StepTriggerData]] = []

        for voiceType in DrumVoiceType.allCases {
            var voiceSteps: [StepTriggerData] = []
            if let track = pattern.tracks[voiceType.rawValue] {
                for step in track.steps {
                    let trigger = StepTriggerData(
                        isActive: step.isActive,
                        velocity: step.normalizedVelocity,
                        probability: step.probability,
                        retriggerCount: step.retriggerCount,
                        nudge: step.nudge
                    )
                    voiceSteps.append(trigger)
                }
            }
            stepData.append(voiceSteps)
        }

        playbackState.patternData = stepData

        // Update voice parameters
        for (index, voice) in voices.enumerated() {
            if index < voiceSynths.count {
                voiceSynths[index].updateParameters(from: voice)
            }
            playbackState.voiceMuted[index] = voice.isMuted
            playbackState.voiceSoloed[index] = voice.isSoloed
            playbackState.voiceVolumes[index] = voice.volume
            playbackState.voicePans[index] = voice.pan
        }

        // Calculate solo state
        let anySoloed = voices.contains { $0.isSoloed }
        playbackState.anySoloed = anySoloed
    }

    // MARK: - Audio Render (Audio Thread - Static)

    /// Main render callback - runs on audio thread
    /// MUST be lock-free and real-time safe
    private static func renderAudio(
        state: PlaybackState,
        synths: [DrumVoiceSynth],
        sampleRate: Double,
        frameCount: AVAudioFrameCount,
        audioBufferList: UnsafeMutablePointer<AudioBufferList>,
        onStepAdvanced: @escaping (Int) -> Void,
        onVoiceTriggered: @escaping (DrumVoiceType, Float) -> Void
    ) -> OSStatus {
        let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

        guard ablPointer.count >= 2 else { return noErr }

        let leftBuffer = ablPointer[0].mData?.assumingMemoryBound(to: Float.self)
        let rightBuffer = ablPointer[1].mData?.assumingMemoryBound(to: Float.self)

        guard let left = leftBuffer, let right = rightBuffer else { return noErr }

        // Clear buffers
        for i in 0..<Int(frameCount) {
            left[i] = 0
            right[i] = 0
        }

        // If not playing, just output silence (but still render active voices)
        let isPlaying = state.isPlaying
        let bpm = state.bpm
        let stepCount = state.stepCount

        // Calculate samples per step (16th note)
        // At 120 BPM: 60/120 = 0.5 sec per beat, /4 = 0.125 sec per 16th
        // At 44100 Hz: 0.125 * 44100 = 5512.5 samples per step
        let samplesPerBeat = sampleRate * 60.0 / bpm
        let samplesPerStep = samplesPerBeat / 4.0

        var currentSample = state.samplePosition

        // Process each sample
        for frameIndex in 0..<Int(frameCount) {

            // Handle sequencer timing if playing
            if isPlaying {
                // Check if we've crossed a step boundary
                let stepPosition = currentSample / samplesPerStep
                let currentStepIndex = Int(stepPosition) % max(1, stepCount)
                let previousStepIndex = state.currentStep

                // Check for step change
                if currentStepIndex != previousStepIndex {
                    state.currentStep = currentStepIndex

                    // Trigger voices for this step
                    triggerStepVoices(
                        state: state,
                        synths: synths,
                        step: currentStepIndex,
                        onVoiceTriggered: onVoiceTriggered
                    )

                    // Notify main thread about step change
                    onStepAdvanced(currentStepIndex)
                }

                currentSample += 1
            }

            // Render all voice synths (even when not playing, to finish decaying sounds)
            var leftSample: Float = 0
            var rightSample: Float = 0

            for (voiceIndex, synth) in synths.enumerated() {
                // Check mute/solo
                let isMuted = state.voiceMuted[voiceIndex]
                let isSoloed = state.voiceSoloed[voiceIndex]
                let anySoloed = state.anySoloed

                let shouldPlay = !isMuted && (!anySoloed || isSoloed)

                if shouldPlay {
                    let sample = synth.renderSample(sampleRate: Float(sampleRate))
                    let volume = state.voiceVolumes[voiceIndex]
                    let pan = state.voicePans[voiceIndex]

                    // Simple equal-power pan law
                    let leftGain = volume * cosf((pan + 1.0) * .pi / 4.0)
                    let rightGain = volume * sinf((pan + 1.0) * .pi / 4.0)

                    leftSample += sample * leftGain
                    rightSample += sample * rightGain
                }
            }

            // Soft clip to prevent harsh distortion
            left[frameIndex] = softClip(leftSample)
            right[frameIndex] = softClip(rightSample)
        }

        state.samplePosition = currentSample

        return noErr
    }

    /// Trigger voices for the current step
    private static func triggerStepVoices(
        state: PlaybackState,
        synths: [DrumVoiceSynth],
        step: Int,
        onVoiceTriggered: @escaping (DrumVoiceType, Float) -> Void
    ) {
        let patternData = state.patternData

        for (voiceIndex, voiceSteps) in patternData.enumerated() {
            guard step < voiceSteps.count else { continue }

            let stepData = voiceSteps[step]

            guard stepData.isActive else { continue }

            // Check probability
            if stepData.probability < 1.0 {
                let random = Float.random(in: 0...1)
                if random > stepData.probability {
                    continue
                }
            }

            // Trigger the voice
            synths[voiceIndex].trigger(velocity: stepData.velocity)

            // Notify UI
            let voiceType = DrumVoiceType.allCases[voiceIndex]
            let velocity = stepData.velocity
            onVoiceTriggered(voiceType, velocity)
        }
    }

    /// Soft clipper for final output
    private static func softClip(_ x: Float) -> Float {
        if x > 1.0 {
            return 1.0 - expf(-x + 1.0)
        } else if x < -1.0 {
            return -1.0 + expf(x + 1.0)
        }
        return x
    }

    // MARK: - Voice Triggering (Manual)

    /// Triggers a drum voice manually (e.g., from pads)
    func triggerVoice(_ voiceType: DrumVoiceType, velocity: Float) {
        let index = voiceType.rawValue
        guard index < voiceSynths.count else { return }
        voiceSynths[index].trigger(velocity: velocity)
    }

    // MARK: - Metering

    /// Gets the current output level for metering
    func getOutputLevels() -> (Float, Float) {
        // TODO: Implement RMS metering
        return (0.0, 0.0)
    }

    /// Gets the output level for a specific voice
    func getVoiceLevel(_ voiceType: DrumVoiceType) -> Float {
        let index = voiceType.rawValue
        guard index < voiceSynths.count else { return 0.0 }
        return voiceSynths[index].currentLevel
    }
}

// MARK: - Playback State

/// Thread-safe playback state container
/// Uses atomic operations for audio-thread safety
private final class PlaybackState: @unchecked Sendable {
    var isPlaying: Bool = false
    var bpm: Double = 120.0
    var swing: Float = 0.5
    var stepCount: Int = 16
    var currentStep: Int = 0
    var samplePosition: Double = 0

    /// Pattern data: [voiceIndex][stepIndex] -> trigger data
    var patternData: [[StepTriggerData]] = []

    /// Voice states
    var voiceMuted: [Bool] = Array(repeating: false, count: 10)
    var voiceSoloed: [Bool] = Array(repeating: false, count: 10)
    var voiceVolumes: [Float] = Array(repeating: 0.8, count: 10)
    var voicePans: [Float] = Array(repeating: 0.0, count: 10)
    var anySoloed: Bool = false
}

/// Trigger data for a single step (audio-thread safe copy)
private struct StepTriggerData: Sendable {
    let isActive: Bool
    let velocity: Float
    let probability: Float
    let retriggerCount: Int
    let nudge: Float
}

// MARK: - Drum Voice Synthesizer

/// Simple drum synthesizer for a single voice
private final class DrumVoiceSynth: @unchecked Sendable {
    let voiceType: DrumVoiceType

    // Envelope state
    private var isPlaying: Bool = false
    private var envelopePhase: Float = 0
    private var velocity: Float = 1.0

    // Oscillator state
    private var phase: Float = 0
    private var currentPitch: Float = 0

    // Parameters (updated from Voice)
    private var basePitch: Float = 0.5
    private var pitchEnvAmount: Float = 0.8
    private var pitchEnvDecay: Float = 0.15
    private var ampDecay: Float = 0.5
    private var toneMix: Float = 0.0
    private var filterCutoff: Float = 1.0
    private var drive: Float = 0.0

    // Simple one-pole lowpass filter state
    private var filterState: Float = 0

    // Output level for metering
    var currentLevel: Float = 0

    init(voiceType: DrumVoiceType) {
        self.voiceType = voiceType
        applyDefaultsForVoiceType()
    }

    private func applyDefaultsForVoiceType() {
        switch voiceType {
        case .kick:
            basePitch = 0.3
            pitchEnvAmount = 0.8
            pitchEnvDecay = 0.15
            ampDecay = 0.6
            toneMix = 0.0

        case .snare:
            basePitch = 0.5
            pitchEnvAmount = 0.3
            pitchEnvDecay = 0.1
            ampDecay = 0.35
            toneMix = 0.5

        case .closedHat:
            basePitch = 0.7
            ampDecay = 0.1
            toneMix = 0.9
            filterCutoff = 0.8

        case .openHat:
            basePitch = 0.7
            ampDecay = 0.5
            toneMix = 0.9
            filterCutoff = 0.8

        case .clap:
            basePitch = 0.6
            ampDecay = 0.25
            toneMix = 0.8

        case .cowbell:
            basePitch = 0.65
            ampDecay = 0.4
            toneMix = 0.1

        case .cymbal:
            basePitch = 0.8
            ampDecay = 0.7
            toneMix = 0.95
            filterCutoff = 0.9

        case .conga:
            basePitch = 0.45
            pitchEnvAmount = 0.4
            pitchEnvDecay = 0.08
            ampDecay = 0.4
            toneMix = 0.0

        case .maracas:
            basePitch = 0.9
            ampDecay = 0.08
            toneMix = 1.0
            filterCutoff = 0.6

        case .tom:
            basePitch = 0.4
            pitchEnvAmount = 0.5
            pitchEnvDecay = 0.12
            ampDecay = 0.5
            toneMix = 0.0
        }
    }

    /// Update synthesis parameters from Voice model
    func updateParameters(from voice: Voice) {
        basePitch = voice.pitch
        pitchEnvAmount = voice.pitchEnvelopeAmount
        pitchEnvDecay = voice.pitchEnvelopeDecay
        ampDecay = voice.decay
        toneMix = voice.toneMix
        filterCutoff = voice.filterCutoff
        drive = voice.drive
    }

    /// Trigger the voice
    func trigger(velocity: Float) {
        self.velocity = velocity
        self.envelopePhase = 0
        self.phase = 0
        self.isPlaying = true
    }

    /// Render a single sample
    func renderSample(sampleRate: Float) -> Float {
        guard isPlaying else {
            currentLevel = 0
            return 0
        }

        // Calculate frequencies based on voice type
        let baseFreq = frequencyForVoice()

        // Pitch envelope (exponential decay)
        let pitchEnvTime = max(0.001, pitchEnvDecay * 0.5) // 0-0.5 seconds
        let pitchEnv = expf(-envelopePhase / pitchEnvTime)
        let pitchMod = 1.0 + pitchEnvAmount * pitchEnv * 4.0 // Up to 5x frequency
        currentPitch = baseFreq * pitchMod

        // Amplitude envelope (exponential decay)
        let ampDecayTime = max(0.001, ampDecay * 1.5) // 0-1.5 seconds
        let ampEnv = expf(-envelopePhase / ampDecayTime)

        // Check if envelope has decayed enough to stop
        if ampEnv < 0.001 {
            isPlaying = false
            currentLevel = 0
            return 0
        }

        // Generate oscillator output
        var output: Float = 0

        // Tone component (sine wave)
        let toneAmount = 1.0 - toneMix
        if toneAmount > 0.01 {
            let sine = sinf(phase * 2.0 * .pi)
            output += sine * toneAmount
        }

        // Noise component
        let noiseAmount = toneMix
        if noiseAmount > 0.01 {
            let noise = Float.random(in: -1...1)
            output += noise * noiseAmount
        }

        // Simple one-pole lowpass filter
        let cutoffFreq = 100 + filterCutoff * 15000 // 100Hz - 15100Hz
        let rc = 1.0 / (cutoffFreq * 2.0 * .pi)
        let dt = 1.0 / sampleRate
        let alpha = dt / (rc + dt)
        filterState = filterState + alpha * (output - filterState)
        output = filterState

        // Apply drive/saturation
        if drive > 0.01 {
            let driveAmount = 1.0 + drive * 10.0
            output = tanhf(output * driveAmount) / tanhf(driveAmount)
        }

        // Apply envelope and velocity
        output *= ampEnv * velocity

        // Update phase
        phase += currentPitch / sampleRate
        if phase >= 1.0 {
            phase -= 1.0
        }

        // Update envelope time
        envelopePhase += 1.0 / sampleRate

        // Update level for metering
        currentLevel = abs(output)

        return output
    }

    /// Calculate base frequency for this voice type
    private func frequencyForVoice() -> Float {
        switch voiceType {
        case .kick:
            // 40-80 Hz
            return 40 + basePitch * 40
        case .snare:
            // 150-250 Hz
            return 150 + basePitch * 100
        case .closedHat, .openHat:
            // 6000-12000 Hz (mostly noise)
            return 6000 + basePitch * 6000
        case .clap:
            // 1000-3000 Hz
            return 1000 + basePitch * 2000
        case .cowbell:
            // 500-1000 Hz
            return 500 + basePitch * 500
        case .cymbal:
            // 5000-10000 Hz
            return 5000 + basePitch * 5000
        case .conga:
            // 150-300 Hz
            return 150 + basePitch * 150
        case .maracas:
            // 8000-15000 Hz (mostly noise)
            return 8000 + basePitch * 7000
        case .tom:
            // 80-200 Hz
            return 80 + basePitch * 120
        }
    }
}

// MARK: - DSP Constants

/// Constants for DSP calculations
enum DSPConstants {
    /// Minimum frequency for oscillators (Hz)
    static let minFrequency: Float = 20.0

    /// Maximum frequency for oscillators (Hz)
    static let maxFrequency: Float = 20000.0

    /// Minimum envelope time (seconds)
    static let minEnvelopeTime: Float = 0.001

    /// Maximum envelope time (seconds)
    static let maxEnvelopeTime: Float = 10.0

    /// DC blocker coefficient
    static let dcBlockerCoeff: Float = 0.995
}
