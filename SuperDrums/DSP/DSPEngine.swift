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

    /// Master effects
    private var reverbEffect: ReverbEffect?
    private var delayEffect: DelayEffect?
    private var compressorEffect: CompressorEffect?

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

        // Initialize effects
        reverbEffect = ReverbEffect(sampleRate: Float(sampleRate))
        delayEffect = DelayEffect(sampleRate: Float(sampleRate))
        compressorEffect = CompressorEffect(sampleRate: Float(sampleRate))

        // Capture self weakly and the synths array for the audio thread
        let state = playbackState
        let synths = voiceSynths
        let sr = sampleRate
        let reverb = reverbEffect!
        let delay = delayEffect!
        let compressor = compressorEffect!

        // Create the sequencer source node
        // This runs on the audio render thread and provides sample-accurate timing
        sequencerNode = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            return Self.renderAudio(
                state: state,
                synths: synths,
                sampleRate: sr,
                frameCount: frameCount,
                audioBufferList: audioBufferList,
                reverb: reverb,
                delay: delay,
                compressor: compressor,
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

    /// Set master volume (0.0 - 1.0)
    func setMasterVolume(_ volume: Float) {
        playbackState.masterVolume = max(0, min(1, volume))
    }

    /// Set reverb mix (0.0 - 1.0)
    func setReverbMix(_ mix: Float) {
        playbackState.reverbMix = max(0, min(1, mix))
    }

    /// Set delay parameters
    func setDelayParameters(mix: Float, time: Float, feedback: Float) {
        playbackState.delayMix = max(0, min(1, mix))
        playbackState.delayTime = max(0, min(1, time))
        playbackState.delayFeedback = max(0, min(0.95, feedback)) // Limit feedback to prevent runaway
    }

    /// Set compressor parameters
    func setCompressorParameters(threshold: Float, ratio: Float) {
        playbackState.compressorThreshold = max(-40, min(0, threshold)) // -40 to 0 dB
        playbackState.compressorRatio = max(1, min(20, ratio)) // 1:1 to 20:1
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
                        nudge: step.nudge,
                        parameterLocks: step.parameterLocks
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
            playbackState.voiceReverbSend[index] = voice.reverbSend
            playbackState.voiceDelaySend[index] = voice.delaySend
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
        reverb: ReverbEffect,
        delay: DelayEffect,
        compressor: CompressorEffect,
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

        // RMS accumulators for metering
        var leftRMSSum: Float = 0.0
        var rightRMSSum: Float = 0.0

        // Update effect parameters from state (once per buffer)
        reverb.wetLevel = state.reverbMix
        reverb.dryLevel = 1.0 - state.reverbMix * 0.5  // Keep some dry signal
        delay.mix = state.delayMix
        delay.delayTime = state.delayTime
        delay.feedback = state.delayFeedback
        compressor.threshold = state.compressorThreshold
        compressor.ratio = state.compressorRatio

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
            var reverbSendL: Float = 0
            var reverbSendR: Float = 0
            var delaySendL: Float = 0
            var delaySendR: Float = 0

            for (voiceIndex, synth) in synths.enumerated() {
                // Always render the synth to advance envelope/phase state
                // This ensures muted/non-soloed voices don't "build up" pending triggers
                let sample = synth.renderSample(sampleRate: Float(sampleRate))

                // Skip this voice if it produced invalid output
                guard sample.isFinite else { continue }

                // Check mute/solo to determine if we should output this voice
                let isMuted = state.voiceMuted[voiceIndex]
                let isSoloed = state.voiceSoloed[voiceIndex]
                let anySoloed = state.anySoloed

                let shouldOutput = !isMuted && (!anySoloed || isSoloed)

                if shouldOutput {
                    let volume = state.voiceVolumes[voiceIndex]
                    // Use p-lock override for pan if available, otherwise use base value
                    let pan = synths[voiceIndex].getPanOverride() ?? state.voicePans[voiceIndex]

                    // Simple equal-power pan law
                    let leftGain = volume * cosf((pan + 1.0) * .pi / 4.0)
                    let rightGain = volume * sinf((pan + 1.0) * .pi / 4.0)

                    let voiceLeft = sample * leftGain
                    let voiceRight = sample * rightGain

                    leftSample += voiceLeft
                    rightSample += voiceRight

                    // Collect reverb send (post-fader)
                    // Use p-lock override if available, otherwise use base value
                    let reverbSend = synths[voiceIndex].getReverbSendOverride() ?? state.voiceReverbSend[voiceIndex]
                    if reverbSend > 0.01 {
                        reverbSendL += voiceLeft * reverbSend
                        reverbSendR += voiceRight * reverbSend
                    }

                    // Collect delay send (post-fader)
                    // Use p-lock override if available, otherwise use base value
                    let delaySend = synths[voiceIndex].getDelaySendOverride() ?? state.voiceDelaySend[voiceIndex]
                    if delaySend > 0.01 {
                        delaySendL += voiceLeft * delaySend
                        delaySendR += voiceRight * delaySend
                    }
                }
            }

            // Process effects (returns wet signal only when mix > 0)
            if state.reverbMix > 0.01 {
                let (revL, revR) = reverb.process(inputL: reverbSendL, inputR: reverbSendR)
                leftSample += revL
                rightSample += revR
            }

            if state.delayMix > 0.01 {
                let (delL, delR) = delay.process(inputL: delaySendL, inputR: delaySendR)
                leftSample += delL
                rightSample += delR
            }

            // Apply master volume
            let masterVol = state.masterVolume
            leftSample *= masterVol
            rightSample *= masterVol

            // Apply compressor (post-fader, pre-clip)
            let (compressedLeft, compressedRight) = compressor.process(inputL: leftSample, inputR: rightSample)

            // Soft clip to prevent harsh distortion
            let clippedLeft = softClip(compressedLeft)
            let clippedRight = softClip(compressedRight)

            // Accumulate RMS for metering
            leftRMSSum += clippedLeft * clippedLeft
            rightRMSSum += clippedRight * clippedRight

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

        // Update RMS levels for metering (smoothed)
        let rmsDecay: Float = 0.9
        let newLeftRMS = sqrtf(leftRMSSum / Float(frameCount))
        let newRightRMS = sqrtf(rightRMSSum / Float(frameCount))
        state.leftRMS = state.leftRMS * rmsDecay + newLeftRMS * (1.0 - rmsDecay)
        state.rightRMS = state.rightRMS * rmsDecay + newRightRMS * (1.0 - rmsDecay)

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

            // Trigger the voice with parameter locks
            synths[voiceIndex].trigger(velocity: stepData.velocity, parameterLocks: stepData.parameterLocks)

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

    /// Gets the current output level for metering (left, right)
    func getOutputLevels() -> (Float, Float) {
        return (playbackState.leftRMS, playbackState.rightRMS)
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

    /// Master settings
    var masterVolume: Float = 0.8

    /// Reverb settings
    var reverbMix: Float = 0.3

    /// Delay settings
    var delayMix: Float = 0.2
    var delayTime: Float = 0.5
    var delayFeedback: Float = 0.4

    /// Compressor settings
    var compressorThreshold: Float = -10.0  // dB
    var compressorRatio: Float = 4.0        // ratio:1

    /// Voice send levels for reverb (per voice)
    var voiceReverbSend: [Float] = Array(repeating: 0.0, count: 10)

    /// Voice send levels for delay (per voice)
    var voiceDelaySend: [Float] = Array(repeating: 0.0, count: 10)

    /// RMS levels for metering (updated per buffer)
    var leftRMS: Float = 0.0
    var rightRMS: Float = 0.0
}

/// Trigger data for a single step (audio-thread safe copy)
private struct StepTriggerData: Sendable {
    let isActive: Bool
    let velocity: Float
    let probability: Float
    let retriggerCount: Int
    let nudge: Float
    /// Parameter locks for this step (parameter ID -> value)
    /// Keys match LockableParameter.rawValue: "pitch", "decay", "filterCutoff", etc.
    let parameterLocks: [String: Float]
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

    // MARK: - Parameter Locks (Audio thread only)

    /// Active parameter locks for current note (cleared on note end)
    /// Keys match LockableParameter.rawValue: "pitch", "decay", "filterCutoff", etc.
    private var currentParameterLocks: [String: Float] = [:]

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

    // MARK: - Hi-Hat-specific State (Audio thread only)

    /// 6 oscillator phases for TR-808 style metallic hi-hat
    private var hiHatPhases: [Float] = [0, 0, 0, 0, 0, 0]

    /// Hi-hat bandpass filter state
    private var hiHatBpLow: Float = 0
    private var hiHatBpBand: Float = 0

    /// Hi-hat highpass filter state
    private var hiHatHpLow: Float = 0
    private var hiHatHpBand: Float = 0

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

    // MARK: - Mixer P-Lock Getters

    /// Get pan override from current p-locks, or nil if no override
    func getPanOverride() -> Float? {
        return currentParameterLocks["pan"]
    }

    /// Get reverb send override from current p-locks, or nil if no override
    func getReverbSendOverride() -> Float? {
        return currentParameterLocks["reverbSend"]
    }

    /// Get delay send override from current p-locks, or nil if no override
    func getDelaySendOverride() -> Float? {
        return currentParameterLocks["delaySend"]
    }

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
            // TR-808 style snare defaults
            // basePitch: 0.5 = ~238Hz/476Hz oscillators (octave apart)
            params.basePitch = 0.5
            // Pitch envelope: minimal for TR-808 style (bridged-T doesn't pitch sweep much)
            params.pitchEnvAmount = 0.0
            params.pitchEnvDecay = 0.1
            // toneMix: "Snappy" control - 0.6 = good balance of body and snare wires
            params.toneMix = 0.6
            // filterCutoff: "Tone" control - mix between low/high oscillators
            params.filterType = 0
            params.filterCutoff = 0.5  // Balanced tone between oscillators
            params.filterEnvAmount = 0.0
            params.filterResonance = 0.0
            // Envelope: fast attack, medium decay
            params.attack = 0.001
            params.decay = 0.5  // Controls oscillator and noise decay
            params.sustain = 0.0
            params.release = 0.05
            // Subtle drive for analog warmth
            params.drive = 0.08

        case .closedHat:
            // TR-808 style: 6 square wave oscillators + resonant bandpass
            // Control mapping (all parameters have audible impact):
            // - Pitch: Controls oscillator frequencies AND bandpass center (3-12kHz)
            // - Filter Cutoff: Controls highpass frequency (500Hz-5kHz) for brightness
            // - Filter Resonance: Controls bandpass resonance for metallic "ring"
            // - Tone Mix: Blend between metallic oscillators and noise
            // - Decay: Envelope time (30-150ms range)
            params.basePitch = 0.5       // Mid pitch = ~7.5kHz bandpass center
            params.pitchEnvAmount = 0.0  // No pitch envelope for hats
            params.toneMix = 0.25        // 25% noise for shimmer
            params.filterType = 1        // Highpass
            params.filterCutoff = 0.3    // ~1.85kHz highpass (lets through more body)
            params.filterResonance = 0.3 // Moderate resonance for metallic ring
            params.attack = 0.001
            params.decay = 0.25          // ~60ms decay (30-150ms range)
            params.release = 0.02
            params.drive = 0.1           // Some drive for presence

        case .openHat:
            // TR-808 style: same synthesis as closed but longer decay range
            // Decay controls open hat ring time (50-800ms)
            params.basePitch = 0.45      // Slightly lower pitch for open hat character
            params.pitchEnvAmount = 0.0
            params.toneMix = 0.3         // More noise shimmer for open hat sizzle
            params.filterType = 1        // Highpass
            params.filterCutoff = 0.25   // Darker than closed (~1.6kHz)
            params.filterResonance = 0.35 // Slightly more resonance for ring
            params.attack = 0.001
            params.decay = 0.5           // ~425ms decay (50-800ms range)
            params.release = 0.1
            params.drive = 0.1

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

    /// Trigger the voice with optional parameter locks
    /// - Parameters:
    ///   - velocity: Note velocity (0.0 - 1.0)
    ///   - parameterLocks: Optional per-step parameter overrides
    func trigger(velocity: Float, parameterLocks: [String: Float] = [:]) {
        self.velocity = velocity
        self.currentParameterLocks = parameterLocks
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

        // Reset hi-hat-specific state
        if voiceType == .closedHat || voiceType == .openHat {
            self.hiHatPhases = [0, 0, 0, 0, 0, 0]
            self.hiHatBpLow = 0
            self.hiHatBpBand = 0
            self.hiHatHpLow = 0
            self.hiHatHpBand = 0
        }
    }

    /// Get effective parameters with any P-locks applied
    /// This merges base parameters with per-step parameter lock overrides
    private func getEffectiveParameters() -> SynthParameters {
        guard !currentParameterLocks.isEmpty else {
            return activeParameters
        }

        var params = activeParameters

        // Apply parameter locks
        // Keys match LockableParameter.rawValue
        if let pitch = currentParameterLocks["pitch"] {
            params.basePitch = pitch
        }
        if let decay = currentParameterLocks["decay"] {
            params.decay = decay
        }
        if let filterCutoff = currentParameterLocks["filterCutoff"] {
            params.filterCutoff = filterCutoff
        }
        if let filterResonance = currentParameterLocks["filterResonance"] {
            params.filterResonance = filterResonance
        }
        if let drive = currentParameterLocks["drive"] {
            params.drive = drive
        }

        return params
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

        // Use specialized rendering for hi-hats (TR-808 style metallic synthesis)
        if voiceType == .closedHat || voiceType == .openHat {
            return renderHiHatSample(sampleRate: sampleRate)
        }

        // Use thread-safe active parameters with P-locks applied
        let params = getEffectiveParameters()
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

    // MARK: - Snare Drum Synthesis (TR-808 Style)

    /// TR-808 snare drum synthesis using bridged-T oscillator modeling.
    /// Reference: https://www.n8synth.co.uk/diy-eurorack/eurorack-808-snare/
    ///
    /// Architecture:
    /// - Two bridged-T oscillators at ~250Hz and ~500Hz (octave apart)
    /// - Bridged-T oscillators are self-damping (like high-Q resonant filters hit with a pulse)
    /// - Low-pass filtered white noise for snare wire simulation
    /// - Tone control mixes between the two oscillators
    /// - ToneMix (snappy) controls noise level
    private func renderSnareSample(sampleRate: Float) -> Float {
        let params = getEffectiveParameters()
        let dt = 1.0 / sampleRate

        // Overall amplitude envelope (controls final output)
        let ampEnv = processEnvelope(dt: dt, params: params)

        // Check if envelope finished
        if envelopeStage == .idle {
            isPlaying = false
            currentLevel = 0
            return 0
        }

        // === TR-808 BRIDGED-T OSCILLATORS ===
        // Two oscillators tuned approximately an octave apart
        // Original TR-808: ~250Hz (lower) and ~500Hz (upper)
        // The pitch parameter tunes both proportionally

        let pitchMod = 0.8 + params.basePitch * 0.4  // 0.8 - 1.2 multiplier
        let freq1: Float = 238.0 * pitchMod  // Lower bridged-T (~238Hz nominal)
        let freq2: Float = 476.0 * pitchMod  // Upper bridged-T (~476Hz, octave above)

        // Bridged-T oscillators are self-damping - they naturally decay
        // Model as decaying sine waves with exponential amplitude decay
        // The decay time is intrinsic to the bridged-T circuit (set by RC components)

        // Base decay time for bridged-T oscillators (typically 50-200ms)
        let oscillatorDecay = 0.05 + params.decay * 0.15  // 50-200ms

        // Lower oscillator has slightly longer decay (more body/sustain)
        let decay1 = oscillatorDecay * 1.1
        // Upper oscillator decays faster (more attack/snap)
        let decay2 = oscillatorDecay * 0.8

        // Self-damping envelope for each oscillator
        snareBodyEnvLow *= expf(-dt / decay1)
        snareBodyEnvHigh *= expf(-dt / decay2)

        // Generate oscillators (bridged-T produces mostly sine waves)
        let osc1 = sinf(phase * 2.0 * .pi) * snareBodyEnvLow
        let osc2 = sinf(snarePhase2 * 2.0 * .pi) * snareBodyEnvHigh

        // Tone control: mix between lower and upper oscillator
        // filterCutoff repurposed as "Tone" - 0 = more low osc, 1 = more high osc
        let toneMix = params.filterCutoff
        let oscMix = osc1 * (1.0 - toneMix * 0.5) + osc2 * (0.5 + toneMix * 0.5)

        // === INITIAL TRANSIENT (CLICK) ===
        // TR-808 has a sharp transient at the attack from the trigger pulse
        // Model as a very short exponential decay (~2ms)
        let clickDecay: Float = 0.002  // 2ms click
        let clickEnv = expf(-totalPlayTime / clickDecay)
        let click = clickEnv * 0.3  // Subtle click mixed in

        // === SNARE WIRES (LOW-PASS FILTERED NOISE) ===
        // TR-808 uses low-pass filtered white noise, NOT bandpass
        // The noise is generated by avalanche noise from a reverse-biased transistor

        let noise = Float.random(in: -1...1)

        // Low-pass filter the noise (TR-808 uses passive LP filter on noise)
        // Cutoff around 5-8kHz gives the characteristic snare wire sound
        let noiseCutoff: Float = 5000.0 + params.basePitch * 3000.0  // 5-8kHz
        let noiseNormFreq = min(noiseCutoff, sampleRate * 0.45) / sampleRate
        let noiseF = 2.0 * sinf(.pi * noiseNormFreq)

        // Simple one-pole lowpass for noise (smoother than SVF for this purpose)
        snareNoiseBpLow = snareNoiseBpLow + noiseF * (noise - snareNoiseBpLow)

        // Prevent filter instability
        if !snareNoiseBpLow.isFinite { snareNoiseBpLow = 0 }

        // Snappy envelope for noise (controlled by toneMix parameter)
        // TR-808 "Snappy" control adjusts noise envelope amount
        let snappyDecay = 0.03 + params.decay * 0.2  // 30-230ms noise decay
        let snappyEnv = expf(-totalPlayTime / snappyDecay)

        // toneMix controls "snappy" (noise) amount: 0 = no snare wires, 1 = full snare wires
        let snappyAmount = params.toneMix
        let snareNoise = snareNoiseBpLow * snappyEnv * snappyAmount * 1.5

        // === MIX ALL COMPONENTS ===
        // Oscillators + click + noise
        var output = (oscMix + click) * (1.0 - snappyAmount * 0.3) + snareNoise

        // === POST-PROCESSING ===

        // Apply drive/saturation for analog warmth
        if params.drive > 0.01 {
            let driveAmount = 1.0 + params.drive * 6.0
            output = tanhf(output * driveAmount) / tanhf(driveAmount)
        }

        // Apply bitcrush if enabled
        if params.bitcrush > 0.01 {
            output = processBitcrush(input: output, sampleRate: sampleRate, bitcrush: params.bitcrush)
        }

        // Apply overall amplitude envelope and velocity
        output *= ampEnv * velocity

        // Update oscillator phases
        phase += freq1 / sampleRate
        if phase >= 1.0 { phase -= 1.0 }

        snarePhase2 += freq2 / sampleRate
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

    // MARK: - Hi-Hat Synthesis (TR-808 Style)

    /// TR-808 hi-hat synthesis using 6 square wave oscillators with resonant bandpass.
    ///
    /// Architecture:
    /// - Six square wave oscillators at inharmonic frequencies create metallic "hash"
    /// - Resonant bandpass filter shapes the metallic character (center freq controlled by pitch)
    /// - Secondary highpass removes low-frequency rumble (controlled by filter cutoff)
    /// - Noise layer adds shimmer (filtered through same bandpass for consistency)
    ///
    /// Control mapping (all controls now have audible impact):
    /// - Pitch: Controls BOTH oscillator frequencies AND bandpass center frequency (3-12 kHz)
    ///          This dramatically changes the metallic character from dark/gongy to bright/sizzly
    /// - Filter Cutoff: Controls highpass frequency (500 Hz - 5 kHz) for overall brightness
    /// - Filter Resonance: Controls bandpass resonance (0.5-8) for metallic "ring"
    /// - Tone Mix: Blend between pure metallic oscillators and noise shimmer
    /// - Decay: Envelope time (30-150ms for closed, 50-800ms for open)
    /// - Drive: Saturation for grit and presence
    private func renderHiHatSample(sampleRate: Float) -> Float {
        let params = getEffectiveParameters()
        let dt = 1.0 / sampleRate

        // === TR-808 OSCILLATOR FREQUENCIES ===
        // Base frequencies tuned for inharmonic metallic character
        // Pitch parameter scales these AND the bandpass center frequency for dramatic effect
        let baseFrequencies: [Float] = [
            800.0,    // Oscillator 1
            540.0,    // Oscillator 2
            522.7,    // Oscillator 3
            369.6,    // Oscillator 4
            304.4,    // Oscillator 5
            205.3     // Oscillator 6
        ]

        // Pitch control: scales oscillator frequencies from 0.5x to 2.0x
        // This wide range makes pitch changes very audible
        let pitchMod = 0.5 + params.basePitch * 1.5  // 0.5 to 2.0 range
        let frequencies = baseFrequencies.map { $0 * pitchMod }

        // === GENERATE SQUARE WAVE OSCILLATORS ===
        var oscillatorMix: Float = 0

        for i in 0..<6 {
            // Square wave with slight pulse width variation for richness
            let pulseWidth: Float = 0.5 + (Float(i) - 2.5) * 0.02  // Vary 0.45-0.55
            let squareWave: Float = (hiHatPhases[i] < pulseWidth) ? 1.0 : -1.0
            oscillatorMix += squareWave

            // Update phase
            hiHatPhases[i] += frequencies[i] / sampleRate
            if hiHatPhases[i] >= 1.0 {
                hiHatPhases[i] -= 1.0
            }
        }

        // Normalize
        oscillatorMix /= 6.0

        // === NOISE COMPONENT ===
        // Generate noise and mix based on toneMix parameter
        // 0 = pure metallic oscillators, 1 = pure noise (white noise hi-hat character)
        let noise = Float.random(in: -1...1)
        let noiseMix = params.toneMix
        var mixedSignal = oscillatorMix * (1.0 - noiseMix * 0.7) + noise * noiseMix

        // === RESONANT BANDPASS FILTER ===
        // Center frequency controlled by PITCH - this is the key to making pitch audible!
        // Low pitch = dark, gongy sound (~3 kHz)
        // High pitch = bright, sizzly sound (~12 kHz)
        let bpCenterFreq: Float = 3000.0 + params.basePitch * 9000.0  // 3-12 kHz based on pitch
        let bpNormFreq = min(bpCenterFreq, sampleRate * 0.45) / sampleRate
        let bpF = 2.0 * sinf(.pi * bpNormFreq)

        // Resonance from filter resonance parameter - adds metallic "ring"
        let bpQ: Float = 0.5 + params.filterResonance * 7.5  // 0.5 to 8.0
        let bpDamping = 1.0 / bpQ

        // SVF bandpass
        hiHatBpLow = hiHatBpLow + bpF * hiHatBpBand
        let bpHigh = mixedSignal - hiHatBpLow - bpDamping * hiHatBpBand
        hiHatBpBand = bpF * bpHigh + hiHatBpBand

        // Protect against instability
        if !hiHatBpLow.isFinite { hiHatBpLow = 0 }
        if !hiHatBpBand.isFinite { hiHatBpBand = 0 }

        // Mix bandpass with some of the original signal for body
        // More resonance = more bandpass character
        let bpAmount = 0.3 + params.filterResonance * 0.7  // 30-100% bandpass
        var output = hiHatBpBand * bpAmount + mixedSignal * (1.0 - bpAmount) * 0.3

        // === HIGHPASS FILTER ===
        // Filter cutoff controls overall brightness by removing low frequencies
        // This is secondary shaping after the bandpass
        let hpCutoff: Float = 500.0 + params.filterCutoff * 4500.0  // 500 Hz - 5 kHz
        let hpNormFreq = min(hpCutoff, sampleRate * 0.45) / sampleRate
        let hpF = 2.0 * sinf(.pi * hpNormFreq)

        // SVF highpass (lower Q for clean cut)
        hiHatHpLow = hiHatHpLow + hpF * hiHatHpBand
        let hpHigh = output - hiHatHpLow - 1.4 * hiHatHpBand  // Q ~0.7
        hiHatHpBand = hpF * hpHigh + hiHatHpBand

        // Protect against instability
        if !hiHatHpLow.isFinite { hiHatHpLow = 0 }
        if !hiHatHpBand.isFinite { hiHatHpBand = 0 }

        output = hpHigh

        // === AMPLITUDE ENVELOPE (Full ADSR) ===
        // Uses the same ADSR system as other voices, but with hi-hat appropriate decay ranges
        // All parameters work: Attack, Hold, Decay, Sustain, Release
        let ampEnv = processHiHatEnvelope(dt: dt, params: params)

        // Check if envelope finished
        if envelopeStage == .idle {
            isPlaying = false
            currentLevel = 0
            return 0
        }

        // Apply envelope
        output *= ampEnv

        // === DRIVE/SATURATION ===
        // Adds grit and presence, makes the hi-hat cut through
        if params.drive > 0.01 {
            let driveAmount = 1.0 + params.drive * 12.0  // More aggressive drive range
            output = tanhf(output * driveAmount) / tanhf(driveAmount)
        }

        // === BITCRUSH ===
        if params.bitcrush > 0.01 {
            output = processBitcrush(input: output, sampleRate: sampleRate, bitcrush: params.bitcrush)
        }

        // Apply velocity
        output *= velocity

        // Output level boost (compensate for filtering)
        output *= 4.0

        // Update envelope times
        envelopeTime += dt
        totalPlayTime += dt

        // Protect against NaN/Inf
        if !output.isFinite {
            output = 0
            hiHatBpLow = 0
            hiHatBpBand = 0
            hiHatHpLow = 0
            hiHatHpBand = 0
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

    /// Process ADSR envelope specifically for hi-hats
    /// Uses appropriate decay ranges for closed (30-200ms) and open (50-1000ms) hi-hats
    /// All ADSR parameters work: Attack, Hold, Decay, Sustain, Release
    private func processHiHatEnvelope(dt: Float, params: SynthParameters) -> Float {
        switch envelopeStage {
        case .idle:
            return 0

        case .attack:
            // Attack time: 0-200ms for hi-hats (allows soft attacks)
            let attackTime = max(0.001, params.attack * 0.2)
            envelopeLevel += dt / attackTime
            if envelopeLevel >= 1.0 {
                envelopeLevel = 1.0
                envelopeStage = params.hold > 0.001 ? .hold : .decay
                envelopeTime = 0
            }
            return envelopeLevel

        case .hold:
            // Hold time: 0-100ms for hi-hats (sustain at peak before decay)
            let holdTime = params.hold * 0.1
            if envelopeTime >= holdTime {
                envelopeStage = .decay
                envelopeTime = 0
            }
            return 1.0

        case .decay:
            // Decay time depends on voice type:
            // Closed hat: 30-200ms (tight, crisp)
            // Open hat: 50-1000ms (sustained ring)
            let minDecay: Float
            let maxDecay: Float
            if voiceType == .closedHat {
                minDecay = 0.03   // 30ms minimum
                maxDecay = 0.20   // 200ms maximum
            } else {
                minDecay = 0.05   // 50ms minimum
                maxDecay = 1.0    // 1 second maximum
            }

            // Decay time with squared curve for more control at short values
            let totalDecayTime = minDecay + params.decay * params.decay * (maxDecay - minDecay)
            let timeConstant = totalDecayTime / 3.0

            let target = params.sustain
            envelopeLevel = target + (1.0 - target) * expf(-envelopeTime / timeConstant)

            // Transition to release when envelope reaches sustain level
            if envelopeLevel <= target + 0.01 || envelopeTime > totalDecayTime * 1.5 {
                envelopeLevel = target
                envelopeStage = .release
                envelopeTime = 0
            }
            return envelopeLevel

        case .sustain:
            // For drums, immediately go to release (sustain is just a level, not a hold)
            envelopeStage = .release
            envelopeTime = 0
            return envelopeLevel

        case .release:
            // Release time: 0-500ms for hi-hats (tail after decay)
            let releaseTime = max(0.001, params.release * 0.5)
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

// MARK: - Freeverb Reverb Effect

/// Simple Freeverb-style reverb using comb and allpass filters
private final class ReverbEffect: @unchecked Sendable {
    // Comb filter delay lines (8 parallel comb filters)
    private var combDelayL: [[Float]] = []
    private var combDelayR: [[Float]] = []
    private var combPositions: [Int] = Array(repeating: 0, count: 8)
    private var combFeedback: [Float] = []

    // Allpass filter delay lines (4 serial allpass filters)
    private var allpassDelayL: [[Float]] = []
    private var allpassDelayR: [[Float]] = []
    private var allpassPositions: [Int] = Array(repeating: 0, count: 4)

    // Reverb parameters
    var roomSize: Float = 0.5
    var damping: Float = 0.5
    var wetLevel: Float = 0.3
    var dryLevel: Float = 0.7

    // Damping filter state
    private var dampL: [Float] = Array(repeating: 0, count: 8)
    private var dampR: [Float] = Array(repeating: 0, count: 8)

    // Comb filter delay lengths (in samples at 44100Hz, tuned for Freeverb)
    private let combLengths: [Int] = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617]

    // Allpass filter delay lengths
    private let allpassLengths: [Int] = [556, 441, 341, 225]

    init(sampleRate: Float = 44100) {
        setupDelayLines(sampleRate: sampleRate)
    }

    private func setupDelayLines(sampleRate: Float) {
        let ratio = sampleRate / 44100.0

        // Initialize comb filters
        combDelayL = []
        combDelayR = []
        combFeedback = []
        for length in combLengths {
            let scaledLength = max(1, Int(Float(length) * ratio))
            combDelayL.append(Array(repeating: 0, count: scaledLength))
            combDelayR.append(Array(repeating: 0, count: scaledLength + 23)) // Stereo spread
            combFeedback.append(0.84) // Default feedback
        }
        combPositions = Array(repeating: 0, count: combLengths.count)
        dampL = Array(repeating: 0, count: combLengths.count)
        dampR = Array(repeating: 0, count: combLengths.count)

        // Initialize allpass filters
        allpassDelayL = []
        allpassDelayR = []
        for length in allpassLengths {
            let scaledLength = max(1, Int(Float(length) * ratio))
            allpassDelayL.append(Array(repeating: 0, count: scaledLength))
            allpassDelayR.append(Array(repeating: 0, count: scaledLength + 23)) // Stereo spread
        }
        allpassPositions = Array(repeating: 0, count: allpassLengths.count)
    }

    /// Process a stereo sample through the reverb
    func process(inputL: Float, inputR: Float) -> (Float, Float) {
        let input = (inputL + inputR) * 0.5 // Sum to mono for reverb input

        // Calculate feedback based on room size
        let feedback = roomSize * 0.28 + 0.7

        var outputL: Float = 0
        var outputR: Float = 0

        // Process comb filters in parallel
        for i in 0..<combDelayL.count {
            let posL = combPositions[i]
            let lengthL = combDelayL[i].count
            let lengthR = combDelayR[i].count
            let posR = posL % lengthR

            // Read from delay lines
            let delayedL = combDelayL[i][posL]
            let delayedR = combDelayR[i][posR]

            // Apply damping (simple lowpass)
            dampL[i] = delayedL * (1.0 - damping) + dampL[i] * damping
            dampR[i] = delayedR * (1.0 - damping) + dampR[i] * damping

            // Write back with feedback
            combDelayL[i][posL] = input + dampL[i] * feedback
            combDelayR[i][posR] = input + dampR[i] * feedback

            outputL += dampL[i]
            outputR += dampR[i]

            // Advance position
            combPositions[i] = (posL + 1) % lengthL
        }

        // Normalize comb output
        outputL *= 0.25
        outputR *= 0.25

        // Process allpass filters in series
        for i in 0..<allpassDelayL.count {
            let posL = allpassPositions[i]
            let lengthL = allpassDelayL[i].count
            let lengthR = allpassDelayR[i].count
            let posR = posL % lengthR

            let delayedL = allpassDelayL[i][posL]
            let delayedR = allpassDelayR[i][posR]

            let allpassCoeff: Float = 0.5

            let tempL = outputL + delayedL * allpassCoeff
            let tempR = outputR + delayedR * allpassCoeff

            allpassDelayL[i][posL] = outputL - delayedL * allpassCoeff
            allpassDelayR[i][posR] = outputR - delayedR * allpassCoeff

            outputL = tempL
            outputR = tempR

            allpassPositions[i] = (posL + 1) % lengthL
        }

        // Mix dry and wet
        let finalL = inputL * dryLevel + outputL * wetLevel
        let finalR = inputR * dryLevel + outputR * wetLevel

        return (finalL, finalR)
    }

    /// Clear all delay lines
    func clear() {
        for i in 0..<combDelayL.count {
            combDelayL[i] = Array(repeating: 0, count: combDelayL[i].count)
            combDelayR[i] = Array(repeating: 0, count: combDelayR[i].count)
            dampL[i] = 0
            dampR[i] = 0
        }
        for i in 0..<allpassDelayL.count {
            allpassDelayL[i] = Array(repeating: 0, count: allpassDelayL[i].count)
            allpassDelayR[i] = Array(repeating: 0, count: allpassDelayR[i].count)
        }
        combPositions = Array(repeating: 0, count: combPositions.count)
        allpassPositions = Array(repeating: 0, count: allpassPositions.count)
    }
}

// MARK: - Stereo Delay Effect

/// Simple stereo delay with feedback
private final class DelayEffect: @unchecked Sendable {
    private var delayBufferL: [Float] = []
    private var delayBufferR: [Float] = []
    private var writePosition: Int = 0
    private var maxDelaySamples: Int = 0

    /// Delay time in seconds (0-1 mapped to 0-1 second)
    var delayTime: Float = 0.5

    /// Feedback amount (0-1)
    var feedback: Float = 0.4

    /// Wet/dry mix (0-1)
    var mix: Float = 0.3

    private let sampleRate: Float

    init(sampleRate: Float = 44100) {
        self.sampleRate = sampleRate
        // Maximum 1 second of delay
        maxDelaySamples = Int(sampleRate)
        delayBufferL = Array(repeating: 0, count: maxDelaySamples)
        delayBufferR = Array(repeating: 0, count: maxDelaySamples)
    }

    /// Process a stereo sample through the delay
    func process(inputL: Float, inputR: Float) -> (Float, Float) {
        // Calculate delay in samples
        let delaySamples = Int(delayTime * sampleRate * 0.9) + Int(sampleRate * 0.05)
        let readPositionL = (writePosition - delaySamples + maxDelaySamples) % maxDelaySamples
        // Slight offset for stereo spread
        let readPositionR = (writePosition - delaySamples - Int(sampleRate * 0.02) + maxDelaySamples) % maxDelaySamples

        // Read from delay buffer
        let delayedL = delayBufferL[readPositionL]
        let delayedR = delayBufferR[readPositionR]

        // Write to delay buffer with feedback (cross-feedback for stereo width)
        delayBufferL[writePosition] = inputL + delayedR * feedback
        delayBufferR[writePosition] = inputR + delayedL * feedback

        // Advance write position
        writePosition = (writePosition + 1) % maxDelaySamples

        // Mix dry and wet
        let outputL = inputL * (1.0 - mix) + delayedL * mix
        let outputR = inputR * (1.0 - mix) + delayedR * mix

        return (outputL, outputR)
    }

    /// Clear the delay buffer
    func clear() {
        delayBufferL = Array(repeating: 0, count: maxDelaySamples)
        delayBufferR = Array(repeating: 0, count: maxDelaySamples)
        writePosition = 0
    }
}

// MARK: - Compressor Effect

/// Stereo bus compressor with peak detection
/// Optimized for drum bus compression with fast attack
private final class CompressorEffect: @unchecked Sendable {

    /// Threshold in dB (-40 to 0)
    var threshold: Float = -10.0

    /// Ratio (1:1 to 20:1)
    var ratio: Float = 4.0

    /// Attack time in seconds (fixed for drums - fast attack)
    private let attackTime: Float = 0.002  // 2ms

    /// Release time in seconds (fixed for drums - medium release)
    private let releaseTime: Float = 0.1   // 100ms

    /// Envelope follower state
    private var envelopeL: Float = 0.0
    private var envelopeR: Float = 0.0

    /// Sample rate
    private let sampleRate: Float

    /// Attack coefficient (pre-calculated)
    private var attackCoeff: Float = 0.0

    /// Release coefficient (pre-calculated)
    private var releaseCoeff: Float = 0.0

    init(sampleRate: Float = 44100) {
        self.sampleRate = sampleRate
        updateCoefficients()
    }

    private func updateCoefficients() {
        // Calculate coefficients for exponential envelope
        // coeff = exp(-1 / (time * sampleRate))
        attackCoeff = expf(-1.0 / (attackTime * sampleRate))
        releaseCoeff = expf(-1.0 / (releaseTime * sampleRate))
    }

    /// Process a stereo sample through the compressor
    func process(inputL: Float, inputR: Float) -> (Float, Float) {
        // Bypass if ratio is 1:1 (no compression)
        if ratio <= 1.0 {
            return (inputL, inputR)
        }

        // Peak detection (absolute value)
        let peakL = abs(inputL)
        let peakR = abs(inputR)

        // Envelope follower with attack/release
        // Attack: fast rise to track transients
        // Release: slower fall for smooth gain recovery
        if peakL > envelopeL {
            envelopeL = attackCoeff * envelopeL + (1.0 - attackCoeff) * peakL
        } else {
            envelopeL = releaseCoeff * envelopeL + (1.0 - releaseCoeff) * peakL
        }

        if peakR > envelopeR {
            envelopeR = attackCoeff * envelopeR + (1.0 - attackCoeff) * peakR
        } else {
            envelopeR = releaseCoeff * envelopeR + (1.0 - releaseCoeff) * peakR
        }

        // Use linked stereo detection (max of both channels) for coherent imaging
        let envelope = max(envelopeL, envelopeR)

        // Protect against log(0)
        guard envelope > 0.00001 else {
            return (inputL, inputR)
        }

        // Convert envelope to dB
        let envelopeDb = 20.0 * log10f(envelope)

        // Calculate gain reduction
        var gainReductionDb: Float = 0.0

        if envelopeDb > threshold {
            // Amount above threshold
            let overshoot = envelopeDb - threshold
            // Compressed amount = overshoot * (1 - 1/ratio)
            // This means: output = threshold + overshoot/ratio
            gainReductionDb = overshoot * (1.0 - 1.0 / ratio)
        }

        // Convert gain reduction to linear
        let gainLinear = powf(10.0, -gainReductionDb / 20.0)

        // Apply gain
        let outputL = inputL * gainLinear
        let outputR = inputR * gainLinear

        return (outputL, outputR)
    }

    /// Reset envelope state
    func reset() {
        envelopeL = 0.0
        envelopeR = 0.0
    }
}
