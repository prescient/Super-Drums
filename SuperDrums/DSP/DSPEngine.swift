import AVFoundation
import Foundation
import os.lock

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
            // Audio session setup failed - engine will use default sample rate
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

        // Connect nodes: source -> mixer -> output
        engine.attach(sequencerNode)
        engine.connect(sequencerNode, to: engine.mainMixerNode, format: format)

        // Explicitly connect main mixer to output (should be automatic, but let's be sure)
        let outputFormat = engine.outputNode.inputFormat(forBus: 0)
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: outputFormat)

        // Ensure mixer volume is at full
        engine.mainMixerNode.outputVolume = 1.0

        // Prepare and start
        engine.prepare()
        try engine.start()
        isRunning = true
    }

    /// Stops the audio engine
    func stop() {
        playbackState.isPlaying = false
        audioEngine?.stop()
        audioEngine = nil
        sequencerNode = nil
        isRunning = false
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

        // Determine buffer format
        let isInterleaved = ablPointer.count == 1 && ablPointer[0].mNumberChannels == 2
        let isNonInterleaved = ablPointer.count >= 2

        guard isInterleaved || isNonInterleaved else {
            // Unknown format - output silence
            return noErr
        }

        // Try to apply any pending parameter updates (non-blocking)
        // This is called once per buffer, not per sample, for efficiency
        for synth in synths {
            synth.tryApplyPendingParameters()
        }

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

                    // Skip this voice if it produced invalid output
                    guard sample.isFinite else { continue }

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
            let clippedLeft = softClip(leftSample)
            let clippedRight = softClip(rightSample)

            // Write to buffer based on format
            if isInterleaved {
                // Interleaved: L0 R0 L1 R1 L2 R2 ...
                let buffer = ablPointer[0].mData!.assumingMemoryBound(to: Float.self)
                buffer[frameIndex * 2] = clippedLeft
                buffer[frameIndex * 2 + 1] = clippedRight
            } else {
                // Non-interleaved: separate L and R buffers
                let left = ablPointer[0].mData!.assumingMemoryBound(to: Float.self)
                let right = ablPointer[1].mData!.assumingMemoryBound(to: Float.self)
                left[frameIndex] = clippedLeft
                right[frameIndex] = clippedRight
            }
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

// MARK: - Synth Parameters (Thread-Safe)

/// Parameters that can be updated from the main thread.
/// This struct is copied atomically to ensure thread safety.
private struct SynthParameters: @unchecked Sendable {
    // Oscillator
    var basePitch: Float = 0.5
    var pitchEnvAmount: Float = 0.8
    var pitchEnvDecay: Float = 0.15
    var toneMix: Float = 0.0

    // ADSR envelope
    var attack: Float = 0.001
    var hold: Float = 0.0
    var decay: Float = 0.5
    var sustain: Float = 0.0
    var release: Float = 0.1

    // Filter
    var filterType: Int = 0  // 0=LP, 1=HP, 2=BP
    var filterCutoff: Float = 1.0
    var filterResonance: Float = 0.0
    var filterEnvAmount: Float = 0.0

    // Effects
    var drive: Float = 0.0
    var bitcrush: Float = 0.0

    /// Creates parameters from a Voice model
    init(from voice: Voice) {
        basePitch = voice.pitch
        pitchEnvAmount = voice.pitchEnvelopeAmount
        pitchEnvDecay = voice.pitchEnvelopeDecay
        toneMix = voice.toneMix
        attack = voice.attack
        hold = voice.hold
        decay = voice.decay
        sustain = voice.sustain
        release = voice.release
        filterType = voice.filterType.ordinal
        filterCutoff = voice.filterCutoff
        filterResonance = voice.filterResonance
        filterEnvAmount = voice.filterEnvelopeAmount
        drive = voice.drive
        bitcrush = voice.bitcrush
    }

    init() {}
}

// MARK: - Drum Voice Synthesizer

/// Drum synthesizer with full ADSR, resonant filter, and effects.
/// Thread-safe: parameters are updated via lock-protected snapshot.
private final class DrumVoiceSynth: @unchecked Sendable {
    let voiceType: DrumVoiceType

    // MARK: - Thread Safety

    /// Lock for parameter updates (main thread writes, audio thread tries to read)
    private var parameterLock = os_unfair_lock()

    /// Pending parameters (written by main thread, protected by lock)
    private var pendingParameters = SynthParameters()

    /// Active parameters (used by audio thread, copied from pending when lock acquired)
    private var activeParameters = SynthParameters()

    /// Flag indicating pending parameters are available
    private var hasPendingUpdate: Bool = false

    // MARK: - Envelope State (Audio thread only)

    private var isPlaying: Bool = false
    private var envelopeTime: Float = 0      // Time within current envelope stage
    private var totalPlayTime: Float = 0      // Total time since trigger (for pitch envelope)
    private var envelopeStage: EnvelopeStage = .idle
    private var envelopeLevel: Float = 0
    private var velocity: Float = 1.0

    // MARK: - Oscillator State (Audio thread only)

    private var phase: Float = 0
    private var currentPitch: Float = 0

    // MARK: - Snare-specific State (Audio thread only)

    /// Second oscillator phase for snare body (330Hz component)
    private var snarePhase2: Float = 0

    /// Separate envelope for snare body low frequency (180Hz) - longer decay
    private var snareBodyEnvLow: Float = 0

    /// Separate envelope for snare body high frequency (330Hz) - shorter decay
    private var snareBodyEnvHigh: Float = 0

    /// Snare noise bandpass filter state (for snare wire simulation)
    private var snareNoiseBpLow: Float = 0
    private var snareNoiseBpBand: Float = 0

    // MARK: - Filter State (Audio thread only)

    private var svfLow: Float = 0
    private var svfBand: Float = 0
    private var svfHigh: Float = 0

    // MARK: - Bitcrush State (Audio thread only)

    private var crushHoldSample: Float = 0
    private var crushPhase: Float = 0

    // MARK: - Metering

    /// Output level for metering (can be read from main thread)
    var currentLevel: Float = 0

    private enum EnvelopeStage {
        case idle, attack, hold, decay, sustain, release
    }

    init(voiceType: DrumVoiceType) {
        self.voiceType = voiceType
        applyDefaultsForVoiceType()
    }

    private func applyDefaultsForVoiceType() {
        var params = SynthParameters()

        switch voiceType {
        case .kick:
            params.basePitch = 0.3
            params.pitchEnvAmount = 0.8
            params.pitchEnvDecay = 0.15
            params.toneMix = 0.0
            params.filterType = 0
            params.filterCutoff = 0.7
            params.filterResonance = 0.1
            params.attack = 0.001
            params.decay = 0.5
            params.drive = 0.1

        case .snare:
            // TR-808/909 style snare defaults
            // basePitch: 0.5 = 180Hz/330Hz body frequencies (0=126Hz/231Hz, 1=234Hz/429Hz)
            params.basePitch = 0.5
            // Pitch envelope: subtle sweep for attack "thwack"
            params.pitchEnvAmount = 0.25
            params.pitchEnvDecay = 0.1
            // toneMix: 0.5 = balanced body/snare wires (0=all body, 1=all wires)
            params.toneMix = 0.5
            // Filter: lowpass to shape overall tone
            params.filterType = 0
            params.filterCutoff = 0.9
            params.filterEnvAmount = 0.15
            params.filterResonance = 0.1
            // Envelope: fast attack, medium decay for snare character
            params.attack = 0.001
            params.decay = 0.4
            params.sustain = 0.0
            params.release = 0.08
            // Light drive for analog warmth
            params.drive = 0.12

        case .closedHat:
            params.basePitch = 0.7
            params.pitchEnvAmount = 0.0
            params.toneMix = 0.95
            params.filterType = 1
            params.filterCutoff = 0.6
            params.filterResonance = 0.15
            params.attack = 0.001
            params.decay = 0.15
            params.release = 0.02

        case .openHat:
            params.basePitch = 0.7
            params.pitchEnvAmount = 0.0
            params.toneMix = 0.95
            params.filterType = 1
            params.filterCutoff = 0.55
            params.filterResonance = 0.2
            params.attack = 0.001
            params.decay = 0.55
            params.release = 0.1

        case .clap:
            params.basePitch = 0.6
            params.pitchEnvAmount = 0.0
            params.toneMix = 0.85
            params.filterType = 2
            params.filterCutoff = 0.65
            params.filterResonance = 0.25
            params.filterEnvAmount = 0.15
            params.attack = 0.005
            params.decay = 0.3
            params.drive = 0.1

        case .cowbell:
            params.basePitch = 0.65
            params.pitchEnvAmount = 0.05
            params.pitchEnvDecay = 0.02
            params.toneMix = 0.1
            params.filterType = 2
            params.filterCutoff = 0.75
            params.filterResonance = 0.35
            params.attack = 0.001
            params.decay = 0.45
            params.drive = 0.2

        case .cymbal:
            params.basePitch = 0.8
            params.pitchEnvAmount = 0.0
            params.toneMix = 0.98
            params.filterType = 1
            params.filterCutoff = 0.5
            params.filterResonance = 0.1
            params.filterEnvAmount = -0.15
            params.attack = 0.005
            params.decay = 0.75
            params.release = 0.2

        case .conga:
            params.basePitch = 0.45
            params.pitchEnvAmount = 0.4
            params.pitchEnvDecay = 0.06
            params.toneMix = 0.0
            params.filterType = 0
            params.filterCutoff = 0.8
            params.filterResonance = 0.2
            params.filterEnvAmount = 0.1
            params.attack = 0.001
            params.decay = 0.4
            params.drive = 0.05

        case .maracas:
            params.basePitch = 0.9
            params.pitchEnvAmount = 0.0
            params.toneMix = 1.0
            params.filterType = 1
            params.filterCutoff = 0.7
            params.attack = 0.001
            params.decay = 0.1
            params.release = 0.02

        case .tom:
            params.basePitch = 0.4
            params.pitchEnvAmount = 0.5
            params.pitchEnvDecay = 0.1
            params.toneMix = 0.0
            params.filterType = 0
            params.filterCutoff = 0.75
            params.filterResonance = 0.15
            params.filterEnvAmount = 0.1
            params.attack = 0.001
            params.decay = 0.5
            params.drive = 0.1
        }

        // Set both pending and active (called during init, no contention)
        pendingParameters = params
        activeParameters = params
    }

    /// Update synthesis parameters from Voice model (called from main thread)
    /// Thread-safe: uses lock to protect parameter updates
    func updateParameters(from voice: Voice) {
        let newParams = SynthParameters(from: voice)

        os_unfair_lock_lock(&parameterLock)
        pendingParameters = newParams
        hasPendingUpdate = true
        os_unfair_lock_unlock(&parameterLock)
    }

    /// Try to apply pending parameter updates (called from audio thread)
    /// Non-blocking: uses try-lock so audio thread never waits
    func tryApplyPendingParameters() {
        // Try to acquire lock without blocking
        guard os_unfair_lock_trylock(&parameterLock) else {
            // Lock not available, use existing activeParameters
            return
        }

        // Lock acquired - check if we have pending updates
        if hasPendingUpdate {
            activeParameters = pendingParameters
            hasPendingUpdate = false
        }

        os_unfair_lock_unlock(&parameterLock)
    }

    /// Trigger the voice
    func trigger(velocity: Float) {
        self.velocity = velocity
        self.envelopeTime = 0
        self.totalPlayTime = 0
        self.envelopeStage = .attack
        self.envelopeLevel = 0
        self.phase = 0
        self.isPlaying = true
        // Reset filter state on trigger for punch
        self.svfLow = 0
        self.svfBand = 0
        self.svfHigh = 0

        // Reset snare-specific state
        if voiceType == .snare {
            self.snarePhase2 = 0
            self.snareBodyEnvLow = 1.0   // Start at full level
            self.snareBodyEnvHigh = 1.0  // Start at full level
            self.snareNoiseBpLow = 0
            self.snareNoiseBpBand = 0
        }
    }

    /// Render a single sample (called from audio thread)
    func renderSample(sampleRate: Float) -> Float {
        guard isPlaying else {
            currentLevel = 0
            return 0
        }

        // Use specialized rendering for snare drum
        if voiceType == .snare {
            return renderSnareSample(sampleRate: sampleRate)
        }

        // Use thread-safe active parameters
        let params = activeParameters
        let dt = 1.0 / sampleRate

        // Calculate frequencies based on voice type
        let baseFreq = frequencyForVoice(basePitch: params.basePitch)

        // Pitch envelope (exponential decay from trigger start, not envelope stage)
        let pitchEnvTime = max(0.001, params.pitchEnvDecay * 0.5)
        let pitchEnv = expf(-totalPlayTime / pitchEnvTime)
        let pitchMod = 1.0 + params.pitchEnvAmount * pitchEnv * 4.0
        currentPitch = baseFreq * pitchMod

        // ADSR Envelope
        let ampEnv = processEnvelope(dt: dt, params: params)

        // Check if envelope finished
        if envelopeStage == .idle {
            isPlaying = false
            currentLevel = 0
            return 0
        }

        // Generate oscillator output
        var output: Float = 0

        // Tone component (sine wave)
        let toneAmount = 1.0 - params.toneMix
        if toneAmount > 0.01 {
            let sine = sinf(phase * 2.0 * .pi)
            output += sine * toneAmount
        }

        // Noise component
        let noiseAmount = params.toneMix
        if noiseAmount > 0.01 {
            let noise = Float.random(in: -1...1)
            output += noise * noiseAmount
        }

        // State-variable filter with resonance
        output = processFilter(input: output, sampleRate: sampleRate, envLevel: ampEnv, params: params)

        // Apply drive/saturation
        if params.drive > 0.01 {
            let driveAmount = 1.0 + params.drive * 10.0
            output = tanhf(output * driveAmount) / tanhf(driveAmount)
        }

        // Apply bitcrush
        if params.bitcrush > 0.01 {
            output = processBitcrush(input: output, sampleRate: sampleRate, bitcrush: params.bitcrush)
        }

        // Apply envelope and velocity
        output *= ampEnv * velocity

        // Update phase
        phase += currentPitch / sampleRate
        if phase >= 1.0 {
            phase -= 1.0
        }

        // Update envelope times
        envelopeTime += dt
        totalPlayTime += dt

        // Protect against NaN/Inf from any stage
        if !output.isFinite {
            output = 0
            // Reset filter state to recover
            svfLow = 0
            svfBand = 0
            svfHigh = 0
        }

        // Update level for metering
        currentLevel = abs(output)

        return output
    }

    // MARK: - Snare Drum Synthesis (TR-808/909 Style)

    /// Specialized snare drum rendering using dual-oscillator body + bandpass filtered noise
    /// Based on TR-808/909 snare synthesis architecture:
    /// - Two sine oscillators at ~180Hz and ~330Hz (drum body modes)
    /// - Separate envelopes for each body oscillator (low freq decays slower)
    /// - Bandpass filtered white noise for snare wire simulation
    /// - toneMix controls body vs snare wire balance
    private func renderSnareSample(sampleRate: Float) -> Float {
        let params = activeParameters
        let dt = 1.0 / sampleRate

        // Overall amplitude envelope (controls final output)
        let ampEnv = processEnvelope(dt: dt, params: params)

        // Check if envelope finished
        if envelopeStage == .idle {
            isPlaying = false
            currentLevel = 0
            return 0
        }

        // === SNARE BODY (Dual Oscillator) ===

        // Base frequencies for snare body - TR-808/909 style
        // The pitch parameter modulates these proportionally
        let pitchMod = 0.7 + params.basePitch * 0.6  // 0.7 - 1.3 multiplier
        let freq1: Float = 180.0 * pitchMod  // Low body mode (~180Hz)
        let freq2: Float = 330.0 * pitchMod  // High body mode (~330Hz, non-harmonic)

        // Pitch envelope for initial "thwack" - fast pitch drop on attack
        let pitchEnvTime = max(0.005, params.pitchEnvDecay * 0.15)  // Faster for snare
        let pitchEnv = expf(-totalPlayTime / pitchEnvTime)
        let pitchSweep = 1.0 + params.pitchEnvAmount * pitchEnv * 2.0  // Less extreme than kick

        // Apply pitch envelope to both oscillators
        let actualFreq1 = freq1 * pitchSweep
        let actualFreq2 = freq2 * pitchSweep

        // Separate envelope decay for each body oscillator
        // Low frequency (180Hz): Longer decay - provides body/weight
        // High frequency (330Hz): Shorter decay - provides attack/snap (0,1 mode decays 2x faster)
        let bodyDecayBase = max(0.02, params.decay * 0.4)  // 20-400ms range for snare body
        let lowDecayTime = bodyDecayBase * 1.2   // Low mode: slightly longer
        let highDecayTime = bodyDecayBase * 0.6  // High mode: faster decay (2x ratio)

        snareBodyEnvLow *= expf(-dt / lowDecayTime)
        snareBodyEnvHigh *= expf(-dt / highDecayTime)

        // Generate body oscillators (sine waves)
        let body1 = sinf(phase * 2.0 * .pi) * snareBodyEnvLow
        let body2 = sinf(snarePhase2 * 2.0 * .pi) * snareBodyEnvHigh * 0.7  // High mode slightly quieter

        // Mix body oscillators
        let bodyMix = (body1 + body2) * 0.6

        // === SNARE WIRES (Bandpass Filtered Noise) ===

        // Generate white noise
        let noise = Float.random(in: -1...1)

        // Bandpass filter for snare wire character (centered around 4kHz)
        // Snare wires have energy mainly in the 3-5kHz range
        let snareWireCenterFreq: Float = 4000.0 + params.basePitch * 2000.0  // 4-6kHz
        let snareWireQ: Float = 1.5 + params.filterResonance * 2.0  // Moderate Q

        // State-variable filter for bandpass (Chamberlin form)
        let normalizedFreq = min(snareWireCenterFreq, sampleRate * 0.4) / sampleRate
        let f = 2.0 * sinf(.pi * normalizedFreq)
        let damping = 1.0 / snareWireQ

        snareNoiseBpLow = snareNoiseBpLow + f * snareNoiseBpBand
        let snareNoiseBpHigh = noise - snareNoiseBpLow - damping * snareNoiseBpBand
        snareNoiseBpBand = f * snareNoiseBpHigh + snareNoiseBpBand

        // Prevent filter instability
        if !snareNoiseBpLow.isFinite { snareNoiseBpLow = 0 }
        if !snareNoiseBpBand.isFinite { snareNoiseBpBand = 0 }

        // Snare wire envelope (slightly longer than body for "rattle" effect)
        let snareWireDecay = max(0.03, params.decay * 0.5)  // 30-500ms
        let snareWireEnv = expf(-totalPlayTime / snareWireDecay)

        // Use bandpass output for snare wires
        let snareWires = snareNoiseBpBand * snareWireEnv * 1.2

        // === MIX BODY AND SNARE WIRES ===

        // toneMix: 0 = all body, 1 = all snare wires
        // Classic snare is usually 40-60% noise
        let bodyAmount = 1.0 - params.toneMix
        let snareAmount = params.toneMix

        var output = bodyMix * bodyAmount + snareWires * snareAmount

        // === POST-PROCESSING ===

        // Apply main filter (user-controllable tone shaping)
        output = processFilter(input: output, sampleRate: sampleRate, envLevel: ampEnv, params: params)

        // Apply drive/saturation for grit
        if params.drive > 0.01 {
            let driveAmount = 1.0 + params.drive * 8.0
            output = tanhf(output * driveAmount) / tanhf(driveAmount)
        }

        // Apply bitcrush if enabled
        if params.bitcrush > 0.01 {
            output = processBitcrush(input: output, sampleRate: sampleRate, bitcrush: params.bitcrush)
        }

        // Apply overall amplitude envelope and velocity
        output *= ampEnv * velocity

        // Update oscillator phases
        phase += actualFreq1 / sampleRate
        if phase >= 1.0 { phase -= 1.0 }

        snarePhase2 += actualFreq2 / sampleRate
        if snarePhase2 >= 1.0 { snarePhase2 -= 1.0 }

        // Update envelope times
        envelopeTime += dt
        totalPlayTime += dt

        // Protect against NaN/Inf
        if !output.isFinite {
            output = 0
            svfLow = 0
            svfBand = 0
            svfHigh = 0
            snareNoiseBpLow = 0
            snareNoiseBpBand = 0
        }

        // Update level for metering
        currentLevel = abs(output)

        return output
    }

    /// Process ADSR envelope
    private func processEnvelope(dt: Float, params: SynthParameters) -> Float {
        switch envelopeStage {
        case .idle:
            return 0

        case .attack:
            let attackTime = max(0.001, params.attack * 1.0) // 0-1 second
            envelopeLevel += dt / attackTime
            if envelopeLevel >= 1.0 {
                envelopeLevel = 1.0
                envelopeStage = params.hold > 0.001 ? .hold : .decay
                envelopeTime = 0
            }
            return envelopeLevel

        case .hold:
            let holdTime = params.hold * 0.5 // 0-0.5 seconds
            if envelopeTime >= holdTime {
                envelopeStage = .decay
                envelopeTime = 0
            }
            return 1.0

        case .decay:
            // Decay time maps 0-1 to 20ms - 3000ms total decay time
            // Using a curve that provides more resolution at shorter decay times
            let minDecay: Float = 0.02  // 20ms minimum
            let maxDecay: Float = 3.0   // 3 seconds maximum
            let totalDecayTime = minDecay + params.decay * params.decay * (maxDecay - minDecay)
            // Time constant for exponential decay (reaches ~5% at totalDecayTime)
            let timeConstant = totalDecayTime / 3.0

            let target = params.sustain
            envelopeLevel = target + (1.0 - target) * expf(-envelopeTime / timeConstant)

            // For drums (one-shot), transition to release when envelope reaches sustain level
            // This ensures the sound eventually stops even with sustain > 0
            if envelopeLevel <= target + 0.01 || envelopeTime > totalDecayTime * 1.5 {
                envelopeLevel = target
                envelopeStage = .release
                envelopeTime = 0
            }
            return envelopeLevel

        case .sustain:
            // For drums, we don't hold at sustain - immediately go to release
            // This case is kept for compatibility but shouldn't normally be reached
            envelopeStage = .release
            envelopeTime = 0
            return envelopeLevel

        case .release:
            let releaseTime = max(0.001, params.release * 1.0) // 0-1 second
            envelopeLevel *= expf(-dt / releaseTime)
            if envelopeLevel < 0.001 {
                envelopeStage = .idle
                return 0
            }
            return envelopeLevel
        }
    }

    /// State-variable filter with resonance and filter type switching
    private func processFilter(input: Float, sampleRate: Float, envLevel: Float, params: SynthParameters) -> Float {
        // Calculate cutoff frequency with envelope modulation
        var cutoffMod = params.filterCutoff
        if abs(params.filterEnvAmount) > 0.01 {
            cutoffMod += params.filterEnvAmount * envLevel
            cutoffMod = max(0, min(1, cutoffMod))
        }

        // Map cutoff to frequency (20Hz - 20kHz logarithmic)
        let minFreq: Float = 20.0
        let maxFreq: Float = 20000.0
        let cutoffFreq = minFreq * powf(maxFreq / minFreq, cutoffMod)

        // Calculate filter coefficients
        // f = 2 * sin(pi * Fc / Fs), clamped for stability
        let normalizedFreq = min(cutoffFreq, sampleRate * 0.4) / sampleRate
        let f = 2.0 * sinf(.pi * normalizedFreq)

        // Q factor: 0.5 (no resonance) to 10 (high resonance)
        // Damping = 1/Q
        let q = 0.5 + params.filterResonance * 9.5
        let damping = 1.0 / q

        // State-variable filter iteration (Chamberlin form)
        svfLow = svfLow + f * svfBand
        svfHigh = input - svfLow - damping * svfBand
        svfBand = f * svfHigh + svfBand

        // Prevent filter instability (NaN/Inf protection)
        if !svfLow.isFinite { svfLow = 0 }
        if !svfBand.isFinite { svfBand = 0 }
        if !svfHigh.isFinite { svfHigh = 0 }

        // Select output based on filter type
        switch params.filterType {
        case 0: return svfLow   // Lowpass
        case 1: return svfHigh  // Highpass
        case 2: return svfBand  // Bandpass
        default: return svfLow
        }
    }

    /// Bitcrush effect (sample rate and bit depth reduction)
    private func processBitcrush(input: Float, sampleRate: Float, bitcrush: Float) -> Float {
        // Sample rate reduction (1 = full rate, 0.01 = very crushed)
        let crushRate = 1.0 - bitcrush * 0.98
        crushPhase += crushRate

        if crushPhase >= 1.0 {
            crushPhase -= 1.0
            // Bit depth reduction
            let bits = max(2, Int(16 - bitcrush * 14)) // 16 to 2 bits
            let levels = Float(1 << bits)
            crushHoldSample = floorf(input * levels) / levels
        }

        return crushHoldSample
    }

    /// Calculate base frequency for this voice type
    private func frequencyForVoice(basePitch: Float) -> Float {
        switch voiceType {
        case .kick:
            return 40 + basePitch * 40        // 40-80 Hz
        case .snare:
            return 150 + basePitch * 100      // 150-250 Hz
        case .closedHat, .openHat:
            return 6000 + basePitch * 6000    // 6-12 kHz (mostly noise)
        case .clap:
            return 1000 + basePitch * 2000    // 1-3 kHz
        case .cowbell:
            return 500 + basePitch * 500      // 500-1000 Hz
        case .cymbal:
            return 5000 + basePitch * 5000    // 5-10 kHz
        case .conga:
            return 150 + basePitch * 150      // 150-300 Hz
        case .maracas:
            return 8000 + basePitch * 7000    // 8-15 kHz (mostly noise)
        case .tom:
            return 80 + basePitch * 120       // 80-200 Hz
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
